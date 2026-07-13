import Foundation

public struct AppHealthAuditor {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func audit(app: MonitoredApp) -> [AppHealthFinding] {
        let checkedAt = Date()
        var findings: [AppHealthFinding] = []

        if !fileManager.fileExists(atPath: app.path) {
            return [
                AppHealthFinding(
                    appID: app.id,
                    severity: .critical,
                    title: "Bundle Missing",
                    detail: "The application path no longer exists.",
                    source: "Filesystem",
                    checkedAt: checkedAt
                )
            ]
        }

        findings.append(signatureFinding(for: app, checkedAt: checkedAt))

        if let gatekeeper = gatekeeperFinding(for: app, checkedAt: checkedAt) {
            findings.append(gatekeeper)
        }

        if !fileManager.isReadableFile(atPath: app.path) {
            findings.append(AppHealthFinding(
                appID: app.id,
                severity: .critical,
                title: "Not Readable",
                detail: "App Monitor cannot read this bundle with current permissions.",
                source: "Filesystem",
                checkedAt: checkedAt
            ))
        }

        if app.path.hasPrefix("/Applications/"), hasUnsafeWritePermissions(atPath: app.path) {
            findings.append(AppHealthFinding(
                appID: app.id,
                severity: .warning,
                title: "Writable Bundle",
                detail: "The bundle is writable by group or other users, which increases tamper risk.",
                source: "Filesystem",
                checkedAt: checkedAt
            ))
        }

        let crashCount = crashReportCount(for: app)
        if crashCount > 0 {
            findings.append(AppHealthFinding(
                appID: app.id,
                severity: .warning,
                title: "Recent Crash Reports",
                detail: "\(crashCount) matching crash report\(crashCount == 1 ? "" : "s") found in DiagnosticReports.",
                source: "Crash History",
                checkedAt: checkedAt
            ))
        }

        if let modified = try? URL(fileURLWithPath: app.path).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           modified < checkedAt.addingTimeInterval(-540 * 24 * 60 * 60) {
            findings.append(AppHealthFinding(
                appID: app.id,
                severity: .warning,
                title: "Stale Bundle",
                detail: "The app bundle has not changed in more than 18 months. Check for available updates.",
                source: "Update Signal",
                checkedAt: checkedAt
            ))
        }

        if findings.allSatisfy({ $0.severity == .info }) {
            findings.append(AppHealthFinding(
                appID: app.id,
                severity: .info,
                title: "No Local Issues Found",
                detail: "Code signature, Gatekeeper, filesystem, crash, and stale-update checks did not report a warning.",
                source: "Health Audit",
                checkedAt: checkedAt
            ))
        }

        return findings
    }

    private func hasUnsafeWritePermissions(atPath path: String) -> Bool {
        guard let permissions = try? fileManager.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber else {
            return false
        }
        return permissions.intValue & 0o022 != 0
    }

    private func signatureFinding(for app: MonitoredApp, checkedAt: Date) -> AppHealthFinding {
        let result = run("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", app.path])
        if result.exitCode == 0 {
            return AppHealthFinding(
                appID: app.id,
                severity: .info,
                title: "Code Signature Valid",
                detail: "codesign accepted the app bundle.",
                source: "Code Signing",
                checkedAt: checkedAt
            )
        }

        return AppHealthFinding(
            appID: app.id,
            severity: .critical,
            title: "Code Signature Issue",
            detail: result.output.isEmpty ? "codesign rejected the app bundle." : result.output,
            source: "Code Signing",
            checkedAt: checkedAt
        )
    }

    private func gatekeeperFinding(for app: MonitoredApp, checkedAt: Date) -> AppHealthFinding? {
        guard fileManager.fileExists(atPath: "/usr/sbin/spctl") else { return nil }
        let result = run("/usr/sbin/spctl", arguments: ["--assess", "--type", "execute", app.path])
        if result.exitCode == 0 {
            return AppHealthFinding(
                appID: app.id,
                severity: .info,
                title: "Gatekeeper Accepted",
                detail: result.output.isEmpty ? "spctl accepted this executable." : result.output,
                source: "Gatekeeper",
                checkedAt: checkedAt
            )
        }

        return AppHealthFinding(
            appID: app.id,
            severity: .warning,
            title: "Gatekeeper Review Needed",
            detail: result.output.isEmpty ? "spctl did not accept this executable." : result.output,
            source: "Gatekeeper",
            checkedAt: checkedAt
        )
    }

    private func crashReportCount(for app: MonitoredApp) -> Int {
        let diagnosticsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DiagnosticReports", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: diagnosticsURL, includingPropertiesForKeys: nil) else {
            return 0
        }

        let nameToken = app.name.lowercased()
        let bundleToken = app.bundleIdentifier?.split(separator: ".").last.map { String($0).lowercased() }
        return files.filter { url in
            let filename = url.lastPathComponent.lowercased()
            return filename.contains(nameToken) || bundleToken.map { filename.contains($0) } == true
        }.count
    }

    private func run(_ executable: String, arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CommandResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return CommandResult(exitCode: 1, output: error.localizedDescription)
        }
    }
}

private struct CommandResult {
    let exitCode: Int32
    let output: String
}
