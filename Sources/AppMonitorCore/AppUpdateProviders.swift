import Darwin
import Foundation

public struct ShellCommandResult: Hashable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public protocol UpdateCommandRunning: Sendable {
    func run(_ executable: String, arguments: [String]) -> ShellCommandResult
    func run(_ executable: String, arguments: [String], environment: [String: String]) -> ShellCommandResult
    func runPrivileged(_ executable: String, arguments: [String]) -> ShellCommandResult
}

public struct ProcessUpdateCommandRunner: UpdateCommandRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String]) -> ShellCommandResult {
        runProcess(executable, arguments: arguments)
    }

    public func run(_ executable: String, arguments: [String], environment: [String: String]) -> ShellCommandResult {
        runProcess(executable, arguments: arguments, environment: environment)
    }

    public func runPrivileged(_ executable: String, arguments: [String]) -> ShellCommandResult {
        let environment = [
            "SUDO_UID=\(getuid())",
            "SUDO_GID=\(getgid())",
            "SUDO_USER=\(Self.shellQuote(NSUserName()))",
            "USER=\(Self.shellQuote(NSUserName()))",
            "LOGNAME=\(Self.shellQuote(NSUserName()))",
            "HOME=\(Self.shellQuote(NSHomeDirectory()))"
        ].joined(separator: " ")
        let command = environment + " " + ([executable] + arguments).map(Self.shellQuote).joined(separator: " ")
        let script = "do shell script \(Self.appleScriptString(command)) with administrator privileges"
        return runProcess("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func runProcess(
        _ executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let standardError = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let output: String
            if process.terminationStatus == 0 {
                output = standardOutput.isEmpty ? standardError : standardOutput
            } else {
                output = [standardOutput, standardError]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            }
            return ShellCommandResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return ShellCommandResult(exitCode: 127, output: error.localizedDescription)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptString(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

public protocol AppUpdateProvider: Sendable {
    var source: AppUpdateSource { get }
    func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord]
    func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult
}

private let homebrewAdoptPrefix = "adopt:"
private let homebrewReplacePrefix = "replace:"
private let defaultHomebrewCaskRoots = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]

public enum HomebrewAskpassHelper {
    public static let executableName = "AppMonitorAskpass"

    public static func executableURL(fileManager: FileManager = .default) -> URL? {
        var candidates: [URL] = [
            Bundle.main.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent(executableName)
        ]
        if let executableURL = Bundle.main.executableURL {
            candidates.append(
                executableURL.deletingLastPathComponent().appendingPathComponent(executableName)
            )
        }
        return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}

public struct MacAppStoreUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .macAppStore
    private let masPath: String
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager

    public init(
        masPath: String = "/opt/homebrew/bin/mas",
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.masPath = masPath
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: masPath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: source, name: "Mac App Store", message: "mas is not installed or is not executable.")]
            }
            let result = commandRunner.run(masPath, arguments: ["outdated", "--json", "--inaccurate", "--check-min-os"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: source, name: "Mac App Store", message: result.output)]
            }
            return Self.parseOutdated(json: result.output, apps: apps, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            guard mode == .manual else {
                return skippedResult(record: record, runID: runID, message: "Mac App Store updates require explicit authorization.")
            }
            if openMacAppStoreFallback(record: record).exitCode == 0 {
                return manualActionResult(
                    record: record,
                    runID: runID,
                    message: "Opened the App Store to finish this update. App Store updates require Apple's confirmation flow."
                )
            }
            return skippedResult(record: record, runID: runID, message: "Could not open the App Store update page.")
        }.value
    }

    public static func parseOutdated(json: String, apps: [MonitoredApp], checkedAt: Date = Date()) -> [AppUpdateRecord] {
        guard let objects = jsonObjectList(from: json) else {
            return []
        }
        let appsByBundleID = appLookupByBundleID(apps)

        return objects.compactMap { object in
            let bundleID = stringValue(
                object["bundleID"]
                    ?? object["bundleId"]
                    ?? object["bundleIdentifier"]
                    ?? object["bundle_id"]
            )
            let appStoreID = stringValue(
                object["appID"]
                    ?? object["appId"]
                    ?? object["adamID"]
                    ?? object["adamId"]
                    ?? object["id"]
            )
            let matchedApp = bundleID.flatMap { appsByBundleID[$0] }
            let name = stringValue(
                object["title"]
                    ?? object["name"]
                    ?? object["displayName"]
                    ?? object["displayNameWithExtensions"]
            ) ?? matchedApp?.name ?? "Mac App Store App"
            let explicitCurrentVersion = stringValue(
                object["installedVersion"]
                    ?? object["currentVersion"]
                    ?? object["installed"]
            )
            let masCurrentVersion = object["newVersion"] == nil ? nil : stringValue(object["version"])
            let currentVersion = explicitCurrentVersion
                ?? masCurrentVersion
                ?? matchedApp?.version
            let legacyAvailableVersion = explicitCurrentVersion == nil ? nil : stringValue(object["version"])
            let availableVersion = stringValue(
                object["newVersion"]
                    ?? object["latestVersion"]
                    ?? object["availableVersion"]
                    ?? object["available"]
            ) ?? legacyAvailableVersion
                ?? (explicitCurrentVersion == nil && masCurrentVersion == nil ? stringValue(object["version"]) : nil)
            let sourceIdentifier = appStoreID ?? bundleID ?? name
            return AppUpdateRecord(
                appID: matchedApp?.id,
                appName: name,
                bundleIdentifier: bundleID ?? matchedApp?.bundleIdentifier,
                appPath: matchedApp?.path,
                source: .macAppStore,
                sourceIdentifier: sourceIdentifier,
                currentVersion: currentVersion,
                availableVersion: availableVersion,
                status: .needsAdmin,
                checkedAt: checkedAt,
                installActionTitle: "Update from App Store",
                installActionURL: appStoreID.map { "macappstore://itunes.apple.com/app/id\($0)" },
                requiresAdmin: true,
                canInstall: true,
                isAutoEligible: false,
                message: "Requires App Store authorization."
            )
        }
    }
}

private func appLookupByBundleID(_ apps: [MonitoredApp]) -> [String: MonitoredApp] {
    var lookup: [String: MonitoredApp] = [:]
    for app in apps {
        guard let bundleIdentifier = app.bundleIdentifier,
              lookup[bundleIdentifier] == nil else {
            continue
        }
        lookup[bundleIdentifier] = app
    }
    return lookup
}

private func hasExplicitSparkleFeed(app: MonitoredApp, fileManager: FileManager) -> Bool {
    let infoURL = URL(fileURLWithPath: app.path)
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("Info.plist")
    guard fileManager.fileExists(atPath: infoURL.path),
          let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
        return false
    }
    return info["SUFeedURL"] is String
}

private func isHomebrewCaskInstalled(
    token: String,
    fileManager: FileManager,
    caskroomRoots: [String] = defaultHomebrewCaskRoots
) -> Bool {
    caskroomRoots.contains { root in
        fileManager.fileExists(atPath: "\(root)/\(token)")
    }
}

private func isHomebrewCaskManaged(
    app: MonitoredApp,
    fileManager: FileManager,
    caskroomRoots: [String] = defaultHomebrewCaskRoots
) -> Bool {
    caskTokenCandidates(for: app).contains { token in
        isHomebrewCaskInstalled(token: token, fileManager: fileManager, caskroomRoots: caskroomRoots)
    }
}

private func homebrewAdoptSourceIdentifier(token: String) -> String {
    "\(homebrewAdoptPrefix)\(token)"
}

private func homebrewAdoptToken(from sourceIdentifier: String) -> String? {
    guard sourceIdentifier.hasPrefix(homebrewAdoptPrefix) else { return nil }
    let token = String(sourceIdentifier.dropFirst(homebrewAdoptPrefix.count))
    return token.isEmpty ? nil : token
}

private func homebrewReplaceToken(from sourceIdentifier: String) -> String? {
    guard sourceIdentifier.hasPrefix(homebrewReplacePrefix) else { return nil }
    let token = String(sourceIdentifier.dropFirst(homebrewReplacePrefix.count))
    return token.isEmpty ? nil : token
}

private func caskTokenCandidates(for app: MonitoredApp) -> [String] {
    var candidates: [String] = []

    func append(_ value: String?) {
        guard let value else { return }
        for candidate in tokenVariants(from: value) where !candidates.contains(candidate) {
            candidates.append(candidate)
        }
    }

    append(app.name)
    append(app.bundleIdentifier?.split(separator: ".").last.map(String.init))
    if let bundleIdentifier = app.bundleIdentifier {
        let components = bundleIdentifier.split(separator: ".").map(String.init)
        for size in stride(from: min(3, components.count), through: 1, by: -1) {
            append(components.suffix(size).joined(separator: "-"))
        }
    }
    append(URL(fileURLWithPath: app.path).deletingPathExtension().lastPathComponent)

    return Array(candidates.prefix(12))
}

private func tokenVariants(from value: String) -> [String] {
    let words = wordsForToken(value)
    guard !words.isEmpty else { return [] }

    var variants = [
        words.joined(separator: "-"),
        words.joined()
    ]

    if words.last == "app" {
        let withoutApp = words.dropLast()
        variants.append(withoutApp.joined(separator: "-"))
        variants.append(withoutApp.joined())
    }
    if words.last == "macos" || words.last == "mac" {
        let withoutPlatform = words.dropLast()
        variants.append(withoutPlatform.joined(separator: "-"))
        variants.append(withoutPlatform.joined())
    }

    var unique: [String] = []
    for variant in variants where !variant.isEmpty && !unique.contains(variant) {
        unique.append(variant)
    }
    return unique
}

private func wordsForToken(_ value: String) -> [String] {
    let expandedCamelCase = value.replacingOccurrences(
        of: "([a-z0-9])([A-Z])",
        with: "$1 $2",
        options: .regularExpression
    )
    return expandedCamelCase
        .lowercased()
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init)
}

public struct HomebrewUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .homebrewCask
    private let brewPath: String
    private let includeFormulae: Bool
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager
    private let askpassHelperURL: URL?

    public init(
        brewPath: String = "/opt/homebrew/bin/brew",
        includeFormulae: Bool,
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default,
        askpassHelperURL: URL? = nil
    ) {
        self.brewPath = brewPath
        self.includeFormulae = includeFormulae
        self.commandRunner = commandRunner
        self.fileManager = fileManager
        self.askpassHelperURL = askpassHelperURL
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: brewPath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: .homebrewCask, name: "Homebrew", message: "brew is not installed or is not executable.")]
            }
            _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
            let result = commandRunner.run(brewPath, arguments: ["outdated", "--json=v2", "--greedy"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: .homebrewCask, name: "Homebrew", message: result.output)]
            }
            return Self.parseOutdated(json: result.output, includeFormulae: includeFormulae, apps: apps, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            if let adoptToken = homebrewAdoptToken(from: record.sourceIdentifier) {
                guard record.source == .homebrewCask else {
                    return skippedResult(record: record, runID: runID, message: "Only Homebrew casks can be adopted.")
                }
                guard mode == .manual else {
                    return skippedResult(record: record, runID: runID, message: "Homebrew adoption requires manual confirmation.")
                }
                let authorization: HomebrewAskpassAuthorization
                do {
                    authorization = try makeAskpassAuthorization(
                        context: "adopt \(record.appName) as the \(adoptToken) Homebrew cask"
                    )
                } catch {
                    return UpdateItemResult(
                        runID: runID,
                        updateID: record.id,
                        appID: record.appID,
                        appName: record.appName,
                        source: record.source,
                        sourceIdentifier: record.sourceIdentifier,
                        status: .failed,
                        message: "Could not prepare secure Homebrew authorization: \(error.localizedDescription)"
                    )
                }
                defer {
                    try? fileManager.removeItem(at: authorization.markerURL)
                }
                _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
                let result = commandRunner.run(
                    brewPath,
                    arguments: ["install", "--cask", "--adopt", adoptToken],
                    environment: authorization.environment
                )
                if result.exitCode == 0 {
                    return UpdateItemResult(
                        runID: runID,
                        updateID: record.id,
                        appID: record.appID,
                        appName: record.appName,
                        source: record.source,
                        sourceIdentifier: record.sourceIdentifier,
                        status: .updated,
                        message: result.output.nilIfEmpty ?? "Adopted \(record.appName) as the \(adoptToken) Homebrew cask."
                    )
                }
                return itemResult(record: record, runID: runID, commandResult: result)
            }

            if let replaceToken = homebrewReplaceToken(from: record.sourceIdentifier) {
                guard record.source == .homebrewCask else {
                    return skippedResult(record: record, runID: runID, message: "Only Homebrew casks can be replaced by Homebrew.")
                }
                guard mode == .manual else {
                    return skippedResult(record: record, runID: runID, message: "Homebrew replacement requires manual confirmation.")
                }
                let authorization: HomebrewAskpassAuthorization
                do {
                    authorization = try makeAskpassAuthorization(
                        context: "update \(record.appName) with the \(replaceToken) Homebrew cask"
                    )
                } catch {
                    return UpdateItemResult(
                        runID: runID,
                        updateID: record.id,
                        appID: record.appID,
                        appName: record.appName,
                        source: record.source,
                        sourceIdentifier: record.sourceIdentifier,
                        status: .failed,
                        message: "Could not prepare secure Homebrew authorization: \(error.localizedDescription)"
                    )
                }
                defer {
                    try? fileManager.removeItem(at: authorization.markerURL)
                }
                _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
                let result = commandRunner.run(
                    brewPath,
                    arguments: ["install", "--cask", "--force", replaceToken],
                    environment: authorization.environment
                )
                if result.exitCode == 0 {
                    return UpdateItemResult(
                        runID: runID,
                        updateID: record.id,
                        appID: record.appID,
                        appName: record.appName,
                        source: record.source,
                        sourceIdentifier: record.sourceIdentifier,
                        status: .updated,
                        message: result.output.nilIfEmpty ?? "Updated \(record.appName) with the \(replaceToken) Homebrew cask."
                    )
                }
                return itemResult(record: record, runID: runID, commandResult: result)
            }

            guard mode == .manual || AppUpdateEligibility.isAutoEligible(
                record: record,
                isAppRunning: false,
                settings: AppUpdateSettings(automaticUpdatesEnabled: true)
            ) else {
                return skippedResult(record: record, runID: runID, message: "Update is not eligible for automatic Homebrew install.")
            }
            _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
            let upgradeArguments: [String]
            switch record.source {
            case .homebrewFormula:
                upgradeArguments = ["upgrade", "--formula", record.sourceIdentifier, "--no-ask"]
            case .homebrewCask:
                upgradeArguments = ["upgrade", "--cask", record.sourceIdentifier, "--no-ask", "--greedy"]
            default:
                return skippedResult(record: record, runID: runID, message: "This record is not a Homebrew package.")
            }
            let authorization: HomebrewAskpassAuthorization
            do {
                authorization = try makeAskpassAuthorization(
                    context: "update \(record.appName) with Homebrew"
                )
            } catch {
                return UpdateItemResult(
                    runID: runID,
                    updateID: record.id,
                    appID: record.appID,
                    appName: record.appName,
                    source: record.source,
                    sourceIdentifier: record.sourceIdentifier,
                    status: .failed,
                    message: "Could not prepare secure Homebrew authorization: \(error.localizedDescription)"
                )
            }
            defer {
                try? fileManager.removeItem(at: authorization.markerURL)
            }
            let result = commandRunner.run(
                brewPath,
                arguments: upgradeArguments,
                environment: authorization.environment
            )
            if record.source == .homebrewCask,
               result.exitCode != 0,
               isMissingHomebrewCaskArtifactFailure(result.output) {
                let repairAuthorization: HomebrewAskpassAuthorization
                do {
                    repairAuthorization = try makeAskpassAuthorization(
                        context: "repair \(record.appName) by reinstalling its Homebrew cask"
                    )
                } catch {
                    return itemResult(
                        record: record,
                        runID: runID,
                        commandResult: ShellCommandResult(
                            exitCode: result.exitCode,
                            output: "\(result.output)\n\nAutomatic repair could not start: \(error.localizedDescription)"
                        )
                    )
                }
                defer {
                    try? fileManager.removeItem(at: repairAuthorization.markerURL)
                }
                let repairResult = commandRunner.run(
                    brewPath,
                    arguments: ["reinstall", "--cask", "--force", record.sourceIdentifier],
                    environment: repairAuthorization.environment
                )
                if repairResult.exitCode == 0 {
                    return itemResult(
                        record: record,
                        runID: runID,
                        commandResult: ShellCommandResult(
                            exitCode: 0,
                            output: "Repaired the missing app artifact by reinstalling the Homebrew cask.\n\(repairResult.output)"
                        )
                    )
                }
                return itemResult(
                    record: record,
                    runID: runID,
                    commandResult: ShellCommandResult(
                        exitCode: repairResult.exitCode,
                        output: "\(result.output)\n\nAutomatic repair failed:\n\(repairResult.output)"
                    )
                )
            }
            return itemResult(
                record: record,
                runID: runID,
                commandResult: conciseHomebrewCommandResult(result)
            )
        }.value
    }

    private func makeAskpassAuthorization(context: String) throws -> HomebrewAskpassAuthorization {
        guard let helperURL = askpassHelperURL ?? HomebrewAskpassHelper.executableURL(fileManager: fileManager) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "The signed App Monitor askpass helper is missing."
            ])
        }
        let attemptID = UUID().uuidString
        let markerDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("AppMonitorAskpassAttempts", isDirectory: true)
        try fileManager.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: markerDirectory.path)
        return HomebrewAskpassAuthorization(
            environment: [
                "SUDO_ASKPASS": helperURL.path,
                "APP_MONITOR_ASKPASS_ATTEMPT_ID": attemptID,
                "APP_MONITOR_ASKPASS_CONTEXT": context
            ],
            markerURL: markerDirectory.appendingPathComponent(attemptID)
        )
    }

    public static func parseOutdated(
        json: String,
        includeFormulae: Bool,
        apps: [MonitoredApp],
        checkedAt: Date = Date()
    ) -> [AppUpdateRecord] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var records: [AppUpdateRecord] = []
        let appsByNormalizedName = Dictionary(grouping: apps, by: { normalizeName($0.name) })

        if let casks = root["casks"] as? [[String: Any]] {
            records += casks.map { object in
                brewRecord(
                    object: object,
                    source: .homebrewCask,
                    appsByNormalizedName: appsByNormalizedName,
                    checkedAt: checkedAt
                )
            }
        }

        if includeFormulae, let formulae = root["formulae"] as? [[String: Any]] {
            records += formulae.map { object in
                brewRecord(
                    object: object,
                    source: .homebrewFormula,
                    appsByNormalizedName: appsByNormalizedName,
                    checkedAt: checkedAt
                )
            }
        }

        return records
    }

    private static func brewRecord(
        object: [String: Any],
        source: AppUpdateSource,
        appsByNormalizedName: [String: [MonitoredApp]],
        checkedAt: Date
    ) -> AppUpdateRecord {
        let token = stringValue(object["name"] ?? object["token"]) ?? "unknown"
        let displayName = stringValue(object["full_name"] ?? object["name"] ?? object["token"]) ?? token
        let installedVersions = stringArrayValue(object["installed_versions"] ?? object["installedVersions"])
        let currentVersion = installedVersions.isEmpty ? stringValue(object["installed_version"]) : installedVersions.joined(separator: ", ")
        let availableVersion = stringValue(object["current_version"] ?? object["currentVersion"] ?? object["version"])
        let appNameKey = normalizeName(token.replacingOccurrences(of: "-", with: " "))
        let matchedApp = appsByNormalizedName[appNameKey]?.first
        return AppUpdateRecord(
            appID: matchedApp?.id,
            appName: matchedApp?.name ?? displayName,
            bundleIdentifier: matchedApp?.bundleIdentifier,
            appPath: matchedApp?.path,
            source: source,
            sourceIdentifier: token,
            currentVersion: currentVersion ?? matchedApp?.version,
            availableVersion: availableVersion,
            status: .available,
            checkedAt: checkedAt,
            installActionTitle: "Update with Homebrew",
            installActionURL: "https://formulae.brew.sh/\(source == .homebrewFormula ? "formula" : "cask")/\(token)",
            canInstall: true,
            isAutoEligible: true,
            releaseNotesTitle: "\(displayName) \(availableVersion ?? "update")",
            releaseNotesSummary: "Homebrew reports an update from \(currentVersion ?? "the installed version") to \(availableVersion ?? "the latest version").",
            releaseNotesURL: "https://formulae.brew.sh/\(source == .homebrewFormula ? "formula" : "cask")/\(token)",
            message: source == .homebrewFormula ? "Homebrew formula update available." : "Homebrew cask update available."
        )
    }
}

private struct HomebrewAskpassAuthorization {
    let environment: [String: String]
    let markerURL: URL
}

private func isMissingHomebrewCaskArtifactFailure(_ output: String) -> Bool {
    output.localizedCaseInsensitiveContains("App source")
        && (output.localizedCaseInsensitiveContains("is not there")
            || output.localizedCaseInsensitiveContains("does not exist"))
}

private func conciseHomebrewCommandResult(_ result: ShellCommandResult) -> ShellCommandResult {
    guard result.exitCode != 0,
          result.output.localizedCaseInsensitiveContains("Usage: brew"),
          let errorLine = result.output
          .split(separator: "\n")
          .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
          .last(where: { $0.hasPrefix("Error:") }) else {
        return result
    }
    return ShellCommandResult(exitCode: result.exitCode, output: errorLine)
}

public struct AppleSoftwareUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .appleSoftwareUpdate
    private let softwareUpdatePath: String
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager

    public init(
        softwareUpdatePath: String = "/usr/sbin/softwareupdate",
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.softwareUpdatePath = softwareUpdatePath
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: softwareUpdatePath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: source, name: "Apple Software Update", message: "softwareupdate is not available.")]
            }
            let result = commandRunner.run(softwareUpdatePath, arguments: ["--list", "--product-types", "macOS,Safari"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: source, name: "Apple Software Update", message: result.output)]
            }
            return Self.parseList(output: result.output, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            guard mode == .manual else {
                return skippedResult(record: record, runID: runID, message: "Apple software updates are held for manual confirmation.")
            }
            let result = commandRunner.runPrivileged(softwareUpdatePath, arguments: ["--install", record.sourceIdentifier])
            if result.exitCode == 0, record.requiresRestart {
                return UpdateItemResult(
                    runID: runID,
                    updateID: record.id,
                    appID: record.appID,
                    appName: record.appName,
                    source: record.source,
                    sourceIdentifier: record.sourceIdentifier,
                    status: .needsRestart,
                    message: result.output.isEmpty ? "Installed. Restart may be required." : result.output
                )
            }
            return itemResult(record: record, runID: runID, commandResult: result)
        }.value
    }

    public static func parseList(output: String, checkedAt: Date = Date()) -> [AppUpdateRecord] {
        let lines = output.components(separatedBy: .newlines)
        var records: [AppUpdateRecord] = []
        var currentLabel: String?
        var detailLines: [String] = []

        func flush() {
            guard let label = currentLabel else { return }
            let detail = detailLines.joined(separator: " ")
            let title = value(after: "Title:", in: detail, stoppingAt: ",") ?? label
            let version = value(after: "Version:", in: detail, stoppingAt: ",")
            let restart = detail.localizedCaseInsensitiveContains("restart")
            records.append(AppUpdateRecord(
                appID: nil,
                appName: title,
                bundleIdentifier: nil,
                appPath: nil,
                source: .appleSoftwareUpdate,
                sourceIdentifier: label,
                currentVersion: nil,
                availableVersion: version,
                status: restart ? .needsRestart : .needsAdmin,
                checkedAt: checkedAt,
                installActionTitle: "Install Apple Update",
                installActionURL: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension",
                requiresAdmin: true,
                requiresRestart: restart,
                canInstall: true,
                isAutoEligible: false,
                message: restart ? "Requires administrator approval and restart." : "Requires administrator approval."
            ))
            detailLines = []
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("* Label:") {
                flush()
                currentLabel = line.replacingOccurrences(of: "* Label:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentLabel != nil {
                detailLines.append(line)
            }
        }
        flush()

        return records
    }
}

public struct DirectDownloadUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .directDownload
    private let timeout: TimeInterval
    private let fileManager: FileManager
    private let homebrewCaskRoots: [String]

    public init(
        timeout: TimeInterval = 5,
        fileManager: FileManager = .default,
        homebrewCaskRoots: [String] = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
    ) {
        self.timeout = timeout
        self.fileManager = fileManager
        self.homebrewCaskRoots = homebrewCaskRoots
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        var records: [AppUpdateRecord] = []
        for app in apps {
            guard !isHomebrewCaskManaged(app: app, fileManager: fileManager, caskroomRoots: homebrewCaskRoots) else {
                continue
            }
            guard let feedURL = sparkleFeedURL(for: app) else { continue }
            let checkedAt = Date()
            do {
                let latest = try await latestSparkleItem(from: feedURL)
                let hasUpdate = latest.version.map { version in
                    VersionComparator.isVersion(version, newerThan: app.version)
                } ?? false
                guard hasUpdate || latest.version == nil else { continue }
                let releaseNotesLink = latest.releaseNotesURL
                    ?? latest.url.flatMap { releaseNotesURL(fromDownloadURL: $0, version: latest.version) }
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .directDownload,
                    sourceIdentifier: feedURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: latest.version,
                    status: .manualAction,
                    checkedAt: checkedAt,
                    installActionTitle: "Open Updater",
                    installActionURL: latest.url?.absoluteString ?? feedURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: true,
                    isAutoEligible: false,
                    releaseNotesTitle: latest.title,
                    releaseNotesSummary: latest.summary,
                    releaseNotesURL: releaseNotesLink?.absoluteString,
                    message: "Sparkle update feed detected. Open the app to run its built-in updater."
                ))
            } catch {
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .directDownload,
                    sourceIdentifier: feedURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: nil,
                    status: .manualAction,
                    checkedAt: checkedAt,
                    installActionTitle: "Open Updater",
                    installActionURL: feedURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: true,
                    isAutoEligible: false,
                    releaseNotesTitle: "\(app.name) update feed",
                    releaseNotesSummary: "Sparkle feed detected, but App Monitor could not read the latest release notes.",
                    releaseNotesURL: feedURL.absoluteString,
                    message: "Sparkle feed detected, but App Monitor could not read the latest version: \(error.localizedDescription)"
                ))
            }
        }
        return records
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .userInitiated) {
            guidedManualUpdateResult(record: record, runID: runID, sourceLabel: "Sparkle/direct-download")
        }.value
    }

    private func sparkleFeedURL(for app: MonitoredApp) -> URL? {
        let infoURL = URL(fileURLWithPath: app.path)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
              let value = info["SUFeedURL"] as? String,
              let url = URL(string: value) else {
            return nil
        }
        return url
    }

    private func latestSparkleItem(from url: URL) async throws -> SparkleAppcastItem {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, _) = try await URLSession.shared.data(for: request)
        return try SparkleAppcastParser.latestItem(from: data)
    }
}

public struct MetadataUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .metadata
    private let caskAPIURL: URL
    private let timeout: TimeInterval

    public init(
        caskAPIURL: URL = URL(string: "https://formulae.brew.sh/api/cask.json")!,
        timeout: TimeInterval = 20
    ) {
        self.caskAPIURL = caskAPIURL
        self.timeout = timeout
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        do {
            var request = URLRequest(url: caskAPIURL)
            request.timeoutInterval = timeout
            let (data, _) = try await URLSession.shared.data(for: request)
            return Self.parseCaskMetadata(json: data, apps: apps, checkedAt: Date())
        } catch {
            return [providerUnavailableRecord(
                source: .metadata,
                name: "App Metadata",
                message: "Homebrew Cask metadata could not be loaded: \(error.localizedDescription)"
            )]
        }
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .userInitiated) {
            guidedManualUpdateResult(record: record, runID: runID, sourceLabel: "metadata")
        }.value
    }

    public static func parseCaskMetadata(
        json data: Data,
        apps: [MonitoredApp],
        checkedAt: Date = Date(),
        fileManager: FileManager = .default
    ) -> [AppUpdateRecord] {
        guard let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let casksByToken = Dictionary(uniqueKeysWithValues: objects.compactMap { object -> (String, [String: Any])? in
            guard let token = stringValue(object["token"]) else { return nil }
            return (token, object)
        })

        var seenAppIDs: Set<String> = []
        var seenTokens: Set<String> = []
        var records: [AppUpdateRecord] = []

        for app in apps where app.isUserFacing {
            guard seenAppIDs.insert(app.id).inserted else { continue }
            let hasSparkleFeed = hasExplicitSparkleFeed(app: app, fileManager: fileManager)

            for token in caskTokenCandidates(for: app) {
                guard seenTokens.insert(token).inserted,
                      !isHomebrewCaskInstalled(token: token, fileManager: fileManager),
                      let object = casksByToken[token] else {
                    continue
                }
                if let managementRecord = homebrewCaskManagementRecord(object: object, app: app, checkedAt: checkedAt) {
                    records.append(managementRecord)
                }
                if !hasSparkleFeed,
                   let record = metadataRecord(object: object, app: app, checkedAt: checkedAt) {
                    records.append(record)
                }
                break
            }
        }

        return records
    }

    private static func homebrewCaskManagementRecord(
        object: [String: Any],
        app: MonitoredApp,
        checkedAt: Date
    ) -> AppUpdateRecord? {
        guard let token = stringValue(object["token"]) else { return nil }
        let version = stringValue(object["version"]).map(displayVersion(fromCaskVersion:))
        if let installedVersion = app.version,
           let version,
           VersionComparator.isVersion(installedVersion, newerThan: version) {
            return nil
        }
        let shouldReplace = version.map { VersionComparator.isVersion($0, newerThan: app.version) } ?? false
        let names = stringArrayValue(object["name"])
        let displayName = names.first ?? app.name
        let formulaURL = "https://formulae.brew.sh/cask/\(token)"
        let description = stringValue(object["desc"])
        let sourceIdentifier = shouldReplace
            ? "\(homebrewReplacePrefix)\(token)"
            : homebrewAdoptSourceIdentifier(token: token)

        return AppUpdateRecord(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .homebrewCask,
            sourceIdentifier: sourceIdentifier,
            currentVersion: app.version,
            availableVersion: version,
            status: .adoptable,
            checkedAt: checkedAt,
            installActionTitle: "Adopt with Homebrew",
            installActionURL: formulaURL,
            requiresAdmin: false,
            requiresRestart: false,
            canInstall: true,
            isAutoEligible: false,
            releaseNotesTitle: "\(displayName) Homebrew cask",
            releaseNotesSummary: description ?? "Homebrew can manage this app as the \(token) cask.",
            releaseNotesURL: formulaURL,
            message: shouldReplace
                ? "Homebrew has a newer cask. Adopt with Homebrew to replace the existing app and manage future updates."
                : "Homebrew cask is available. Adopt it so Homebrew can manage future updates."
        )
    }

    private static func metadataRecord(
        object: [String: Any],
        app: MonitoredApp,
        checkedAt: Date
    ) -> AppUpdateRecord? {
        guard let token = stringValue(object["token"]) else { return nil }
        guard let rawVersion = stringValue(object["version"]) else { return nil }
        let version = displayVersion(fromCaskVersion: rawVersion)
        guard
              VersionComparator.isVersion(version, newerThan: app.version) else {
            return nil
        }

        let names = stringArrayValue(object["name"])
        let displayName = names.first ?? app.name
        let homepage = stringValue(object["homepage"])
        let url = stringValue(object["url"]) ?? homepage
        let metadataReleaseNotesLink = url
            .flatMap(URL.init(string:))
            .flatMap { releaseNotesURL(fromDownloadURL: $0, version: version) }?
            .absoluteString ?? homepage
        let description = stringValue(object["desc"])
        return AppUpdateRecord(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .metadata,
            sourceIdentifier: "homebrew-cask:\(token)",
            currentVersion: app.version,
            availableVersion: version,
            status: .manualAction,
            checkedAt: checkedAt,
            installActionTitle: "Open Download",
            installActionURL: url,
            requiresAdmin: false,
            requiresRestart: false,
            canInstall: true,
            isAutoEligible: false,
            releaseNotesTitle: "\(displayName) \(version)",
            releaseNotesSummary: description ?? "Homebrew Cask metadata reports an update from \(app.version ?? "the installed version") to \(version).",
            releaseNotesURL: metadataReleaseNotesLink,
            message: "Metadata reports an update. Open the vendor download to update."
        )
    }

    private static func displayVersion(fromCaskVersion version: String) -> String {
        version
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? version
    }
}

public struct ElectronUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .electron
    private let timeout: TimeInterval
    private let fileManager: FileManager
    private let homebrewCaskRoots: [String]

    public init(
        timeout: TimeInterval = 15,
        fileManager: FileManager = .default,
        homebrewCaskRoots: [String] = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
    ) {
        self.timeout = timeout
        self.fileManager = fileManager
        self.homebrewCaskRoots = homebrewCaskRoots
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        var records: [AppUpdateRecord] = []
        for app in apps where app.isUserFacing {
            guard !isHomebrewCaskManaged(app: app, fileManager: fileManager, caskroomRoots: homebrewCaskRoots) else {
                continue
            }
            guard let updateURL = electronLatestURL(for: app) else { continue }
            do {
                var request = URLRequest(url: updateURL)
                request.timeoutInterval = timeout
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let item = Self.parseLatestYAML(data: data, baseURL: updateURL.deletingLastPathComponent()),
                      VersionComparator.isVersion(item.version, newerThan: app.version) else {
                    continue
                }
                let electronReleaseNotesLink = item.url
                    .flatMap { releaseNotesURL(fromDownloadURL: $0, version: item.version) }?
                    .absoluteString ?? updateURL.absoluteString
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .electron,
                    sourceIdentifier: updateURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: item.version,
                    status: .manualAction,
                    checkedAt: Date(),
                    installActionTitle: "Open Updater",
                    installActionURL: item.url?.absoluteString ?? updateURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: true,
                    isAutoEligible: false,
                    releaseNotesTitle: "\(app.name) \(item.version)",
                    releaseNotesSummary: item.releaseNotes?.nilIfEmpty ?? "Electron update metadata reports an update.",
                    releaseNotesURL: electronReleaseNotesLink,
                    message: "Electron updater metadata reports an update. Open the app to run its built-in updater."
                ))
            } catch {
                continue
            }
        }
        return records
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .userInitiated) {
            guidedManualUpdateResult(record: record, runID: runID, sourceLabel: "Electron")
        }.value
    }

    public static func parseLatestYAML(data: Data, baseURL: URL) -> ElectronLatestItem? {
        guard let text = String(data: data, encoding: .utf8),
              let version = yamlValue("version", in: text) else {
            return nil
        }
        let candidates = yamlURLCandidates(in: text)
        let selected = candidates.first { $0.localizedCaseInsensitiveContains("arm64.dmg") }
            ?? candidates.first { $0.localizedCaseInsensitiveContains(".dmg") }
            ?? candidates.first { $0.localizedCaseInsensitiveContains("arm64.zip") }
            ?? candidates.first
            ?? yamlValue("path", in: text)
        let url = selected.flatMap { electronDownloadURL(value: $0, baseURL: baseURL) }
        return ElectronLatestItem(
            version: version,
            url: url,
            releaseNotes: yamlValue("releaseNotes", in: text)
        )
    }

    private func electronLatestURL(for app: MonitoredApp) -> URL? {
        let configURL = URL(fileURLWithPath: app.path)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("app-update.yml")
        guard fileManager.fileExists(atPath: configURL.path),
              let text = try? String(contentsOf: configURL, encoding: .utf8),
              yamlValue("provider", in: text) == "generic",
              let baseValue = yamlValue("url", in: text),
              !baseValue.localizedCaseInsensitiveContains("electron-vite"),
              let baseURL = URL(string: baseValue) else {
            return nil
        }
        return URL(string: "latest-mac.yml", relativeTo: baseURL)?.absoluteURL
    }
}

public struct ElectronLatestItem: Hashable, Sendable {
    public let version: String
    public let url: URL?
    public let releaseNotes: String?
}

public struct SparkleAppcastItem: Hashable, Sendable {
    public let version: String?
    public let title: String?
    public let url: URL?
    public let summary: String?
    public let releaseNotesURL: URL?
    public let sha256: String?

    public init(
        version: String?,
        title: String?,
        url: URL?,
        summary: String? = nil,
        releaseNotesURL: URL? = nil,
        sha256: String? = nil
    ) {
        self.version = version
        self.title = title
        self.url = url
        self.summary = summary
        self.releaseNotesURL = releaseNotesURL
        self.sha256 = sha256
    }
}

public enum SparkleAppcastParser {
    public static func latestItem(from data: Data) throws -> SparkleAppcastItem {
        let delegate = SparkleParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let item = delegate.items.first else {
            throw AppUpdateProviderError.parseFailed
        }
        return item
    }
}

public enum VersionComparator {
    public static func isVersion(_ candidate: String, newerThan current: String?) -> Bool {
        guard let current, !current.isEmpty else { return true }
        return compare(candidate, current) == .orderedDescending
    }

    public static func isVersion(_ candidate: String, atLeast current: String) -> Bool {
        compare(candidate, current) != .orderedAscending
    }

    private static func compare(_ candidate: String, _ current: String) -> ComparisonResult {
        let candidateParts = numericParts(candidate)
        let currentParts = numericParts(current)
        if !candidateParts.isEmpty, !currentParts.isEmpty {
            let count = max(candidateParts.count, currentParts.count)
            for index in 0..<count {
                let lhs = index < candidateParts.count ? candidateParts[index] : 0
                let rhs = index < currentParts.count ? currentParts[index] : 0
                if lhs < rhs { return .orderedAscending }
                if lhs > rhs { return .orderedDescending }
            }
            return .orderedSame
        }
        return candidate.localizedStandardCompare(current)
    }

    private static func numericParts(_ version: String) -> [Int] {
        version
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

public enum AppUpdateProviderError: Error, LocalizedError {
    case parseFailed

    public var errorDescription: String? {
        switch self {
        case .parseFailed:
            return "Could not parse update metadata."
        }
    }
}

private final class SparkleParserDelegate: NSObject, XMLParserDelegate {
    var items: [SparkleAppcastItem] = []
    private var isInsideItem = false
    private var isInsideDeltas = false
    private var currentElement = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentReleaseNotesURL: URL?
    private var currentVersion: String?
    private var currentURL: URL?
    private var currentSHA256: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            isInsideDeltas = false
            currentTitle = ""
            currentSummary = ""
            currentReleaseNotesURL = nil
            currentVersion = nil
            currentURL = nil
            currentSHA256 = nil
        }
        guard isInsideItem else { return }
        if elementName == "sparkle:deltas" || elementName == "deltas" {
            isInsideDeltas = true
        } else if elementName == "enclosure", !isInsideDeltas {
            currentVersion = attributeDict["sparkle:shortVersionString"]
                ?? attributeDict["sparkle:version"]
                ?? currentVersion
            currentURL = attributeDict["url"].flatMap(URL.init(string:))
            currentSHA256 = attributeDict["sparkle:sha256"] ?? currentSHA256
            currentReleaseNotesURL = attributeDict["sparkle:releaseNotesLink"].flatMap(URL.init(string:))
                ?? currentReleaseNotesURL
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "description":
            currentSummary += string
        case "sparkle:shortVersionString", "shortVersionString":
            let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                currentVersion = value
            }
        case "sparkle:version", "version":
            let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, currentVersion == nil {
                currentVersion = value
            }
        case "sparkle:releaseNotesLink", "releaseNotesLink":
            currentReleaseNotesURL = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? currentReleaseNotesURL
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "sparkle:deltas" || elementName == "deltas" {
            isInsideDeltas = false
        }
        if elementName == "item" {
            items.append(SparkleAppcastItem(
                version: currentVersion,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                url: currentURL,
                summary: currentSummary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                releaseNotesURL: currentReleaseNotesURL,
                sha256: currentSHA256
            ))
            isInsideItem = false
        }
        currentElement = ""
    }
}

private func isExecutable(at path: String, fileManager: FileManager) -> Bool {
    fileManager.isExecutableFile(atPath: path)
}

private func providerUnavailableRecord(source: AppUpdateSource, name: String, message: String) -> AppUpdateRecord {
    AppUpdateRecord(
        appID: nil,
        appName: name,
        bundleIdentifier: nil,
        appPath: nil,
        source: source,
        sourceIdentifier: "provider-\(source.rawValue)",
        currentVersion: nil,
        availableVersion: nil,
        status: .providerUnavailable,
        installActionTitle: "Open Source",
        canInstall: false,
        isAutoEligible: false,
        message: message
    )
}

private func guidedManualUpdateResult(record: AppUpdateRecord, runID: String, sourceLabel: String) -> UpdateItemResult {
    var actions: [String] = []

    if let deepLink = guidedUpdateDeepLink(for: record) {
        let result = openApplication(record: record, additionalArguments: [deepLink])
        if result.exitCode == 0 {
            return manualActionResult(
                record: record,
                runID: runID,
                message: "\(sourceLabel) updater opened \(record.appName)'s update page."
            )
        }
        if !result.output.isEmpty {
            actions.append(result.output)
        }
    }

    if let appPath = record.appPath,
       FileManager.default.fileExists(atPath: appPath) {
        let openResult = openApplication(record: record)
        if openResult.exitCode == 0 {
            actions.append("opened \(record.appName)")
            let menuResult = triggerUpdateMenu(record: record)
            if menuResult.exitCode == 0,
               menuResult.output.localizedCaseInsensitiveContains("clicked") {
                return manualActionResult(
                    record: record,
                    runID: runID,
                    message: "\(sourceLabel) updater launched in \(record.appName). Follow the app's updater prompt to finish."
                )
            }
            if !menuResult.output.isEmpty {
                actions.append(menuResult.output)
            }
        } else if !openResult.output.isEmpty {
            actions.append(openResult.output)
        }
    }

    if let fallbackURL = GuidedUpdateURLPolicy.userFacingURL(from: record.installActionURL) {
        let urlResult = runLocalProcess("/usr/bin/open", arguments: [fallbackURL.absoluteString])
        if urlResult.exitCode == 0 {
            actions.append("opened \(record.installActionTitle.lowercased())")
            return manualActionResult(
                record: record,
                runID: runID,
                message: "\(sourceLabel) update requires confirmation. \(actions.joined(separator: "; "))."
            )
        }
        if !urlResult.output.isEmpty {
            actions.append(urlResult.output)
        }
    }

    return manualActionResult(
        record: record,
        runID: runID,
        message: actions.isEmpty ? "\(sourceLabel) update needs a manual vendor updater." : actions.joined(separator: "; ")
    )
}

private func guidedUpdateDeepLink(for record: AppUpdateRecord) -> String? {
    switch record.bundleIdentifier?.lowercased() {
    case "com.google.chrome":
        return "chrome://settings/help"
    default:
        return nil
    }
}

enum GuidedUpdateURLPolicy {
    private static let payloadExtensions: Set<String> = [
        "7z", "app", "bz2", "delta", "dmg", "exe", "gz", "json", "mpkg",
        "msi", "pkg", "tar", "xip", "xml", "xz", "yaml", "yml", "zip"
    ]

    static func userFacingURL(from value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              !payloadExtensions.contains(url.pathExtension.lowercased()) else {
            return nil
        }
        return url
    }
}

private func openApplication(record: AppUpdateRecord, additionalArguments: [String] = []) -> ShellCommandResult {
    if let bundleIdentifier = record.bundleIdentifier, !bundleIdentifier.isEmpty {
        let result = runLocalProcess("/usr/bin/open", arguments: ["-b", bundleIdentifier] + additionalArguments)
        if result.exitCode == 0 {
            return result
        }
    }

    if let appPath = record.appPath,
       FileManager.default.fileExists(atPath: appPath) {
        return runLocalProcess("/usr/bin/open", arguments: [appPath] + additionalArguments)
    }

    return ShellCommandResult(exitCode: 1, output: "App bundle was not found.")
}

private func triggerUpdateMenu(record: AppUpdateRecord) -> ShellCommandResult {
    let processSelector: String
    if let bundleIdentifier = record.bundleIdentifier, !bundleIdentifier.isEmpty {
        processSelector = "whose bundle identifier is \(appleScriptString(bundleIdentifier))"
    } else {
        processSelector = "whose name is \(appleScriptString(record.appName))"
    }

    let script = """
    tell application "System Events"
      set matchingProcesses to {}
      repeat 32 times
        set matchingProcesses to every process \(processSelector)
        if (count of matchingProcesses) is greater than 0 then exit repeat
        delay 0.25
      end repeat
      if (count of matchingProcesses) is 0 then return "update menu unavailable"
      set targetProcess to item 1 of matchingProcesses
      set frontmost of targetProcess to true
      repeat 32 times
        try
          if (count of menu bar items of menu bar 1 of targetProcess) is greater than 0 then exit repeat
        end try
        delay 0.25
      end repeat
      set updateItemNames to {"Check for App Monitor Updates", "Check for Updates…", "Check for Updates...", "Check for Updates", "Check for Update…", "Check for Update...", "Check for Update", "Check for Software Updates…", "Check for Software Updates...", "Software Update…", "Software Update...", "Software Update", "Update…", "Update...", "Update", "Update Now", "Install Update"}
      repeat with targetMenuBarItem in menu bar items of menu bar 1 of targetProcess
        try
          set targetMenu to menu 1 of targetMenuBarItem
          repeat with updateItemName in updateItemNames
            set updateItemNameText to contents of updateItemName
            if exists menu item updateItemNameText of targetMenu then
              click menu item updateItemNameText of targetMenu
              return "clicked " & updateItemNameText
            end if
          end repeat
        end try
      end repeat
      return "update menu unavailable"
    end tell
    """
    return runLocalProcess("/usr/bin/osascript", arguments: ["-e", script])
}

private func manualActionResult(record: AppUpdateRecord, runID: String, message: String) -> UpdateItemResult {
    UpdateItemResult(
        runID: runID,
        updateID: record.id,
        appID: record.appID,
        appName: record.appName,
        source: record.source,
        sourceIdentifier: record.sourceIdentifier,
        status: .manualAction,
        message: message
    )
}

private func openMacAppStoreFallback(record: AppUpdateRecord) -> ShellCommandResult {
    if let urlString = record.installActionURL,
       URL(string: urlString) != nil {
        return runLocalProcess("/usr/bin/open", arguments: [urlString])
    }
    if Int(record.sourceIdentifier) != nil {
        return runLocalProcess("/usr/bin/open", arguments: ["macappstore://itunes.apple.com/app/id\(record.sourceIdentifier)"])
    }
    return runLocalProcess("/usr/bin/open", arguments: ["macappstore://showUpdatesPage"])
}

private func skippedResult(record: AppUpdateRecord, runID: String, message: String) -> UpdateItemResult {
    UpdateItemResult(
        runID: runID,
        updateID: record.id,
        appID: record.appID,
        appName: record.appName,
        source: record.source,
        sourceIdentifier: record.sourceIdentifier,
        status: .skipped,
        message: message
    )
}

private func itemResult(record: AppUpdateRecord, runID: String, commandResult: ShellCommandResult) -> UpdateItemResult {
    UpdateItemResult(
        runID: runID,
        updateID: record.id,
        appID: record.appID,
        appName: record.appName,
        source: record.source,
        sourceIdentifier: record.sourceIdentifier,
        status: commandResult.exitCode == 0 ? .updated : .failed,
        message: commandResult.output.isEmpty ? nil : commandResult.output
    )
}

private func runLocalProcess(_ executable: String, arguments: [String]) -> ShellCommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ShellCommandResult(
            exitCode: process.terminationStatus,
            output: [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
        )
    } catch {
        return ShellCommandResult(exitCode: 127, output: error.localizedDescription)
    }
}

private func appleScriptString(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

private func releaseNotesURL(fromDownloadURL url: URL, version: String?) -> URL? {
    guard url.host?.localizedCaseInsensitiveContains("github.com") == true else { return nil }
    let components = url.pathComponents
    guard let releasesIndex = components.firstIndex(of: "releases"),
          components.indices.contains(releasesIndex + 2),
          components[releasesIndex + 1] == "download" else {
        return nil
    }

    let tag = components[releasesIndex + 2]
    var releaseComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    releaseComponents?.path = "/" + components
        .prefix(releasesIndex)
        .dropFirst()
        .joined(separator: "/") + "/releases/tag/\(tag)"
    releaseComponents?.query = nil
    releaseComponents?.fragment = nil

    if let releaseURL = releaseComponents?.url {
        return releaseURL
    }

    guard let version else { return nil }
    return url.deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("tag")
        .appendingPathComponent(version)
}

private func stringValue(_ value: Any?) -> String? {
    switch value {
    case let value as String:
        return value
    case let value as Int:
        return String(value)
    case let value as Int64:
        return String(value)
    case let value as Double:
        return String(value)
    default:
        return nil
    }
}

private func stringArrayValue(_ value: Any?) -> [String] {
    if let values = value as? [String] {
        return values
    }
    if let values = value as? [Any] {
        return values.compactMap(stringValue)
    }
    return stringValue(value).map { [$0] } ?? []
}

private func jsonObjectList(from output: String) -> [[String: Any]]? {
    for candidate in jsonPayloadCandidates(from: output) {
        guard let data = candidate.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data),
              let objects = objectList(from: root) else {
            continue
        }
        return objects
    }

    let lineObjects = output
        .split(separator: "\n")
        .compactMap { line -> [String: Any]? in
            guard let data = line.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    return lineObjects.isEmpty ? nil : lineObjects
}

private func jsonPayloadCandidates(from output: String) -> [String] {
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var candidates = [trimmed]
    if let start = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }) {
        let closer: Character = trimmed[start] == "{" ? "}" : "]"
        if let end = trimmed.lastIndex(of: closer) {
            let payload = String(trimmed[start...end])
            if payload != trimmed {
                candidates.append(payload)
            }
        }
    }
    return candidates
}

private func objectList(from root: Any) -> [[String: Any]]? {
    if let objects = root as? [[String: Any]] {
        return objects
    }
    guard let object = root as? [String: Any] else {
        return nil
    }
    for key in ["apps", "items", "updates", "outdated"] {
        if let objects = object[key] as? [[String: Any]] {
            return objects
        }
    }
    return [object]
}

private func yamlValue(_ key: String, in text: String) -> String? {
    for rawLine in text.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("\(key):") else { continue }
        let value = String(line.dropFirst(key.count + 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return unquotedYAMLValue(value).nilIfEmpty
    }
    return nil
}

private func yamlURLCandidates(in text: String) -> [String] {
    text.components(separatedBy: .newlines).compactMap { rawLine in
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("- url:") {
            return unquotedYAMLValue(String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if line.hasPrefix("url:") {
            return unquotedYAMLValue(String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

private func electronDownloadURL(value: String, baseURL: URL) -> URL? {
    if let url = URL(string: value, relativeTo: baseURL)?.absoluteURL {
        return url
    }
    let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    return encoded.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
}

private func unquotedYAMLValue(_ value: String) -> String {
    var value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
    } else if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
    }
    return value
}

private func normalizeName(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: ".app", with: "")
        .filter { $0.isLetter || $0.isNumber }
}

private func value(after marker: String, in text: String, stoppingAt stop: Character) -> String? {
    guard let markerRange = text.range(of: marker, options: .caseInsensitive) else { return nil }
    let tail = text[markerRange.upperBound...]
    let value = tail.split(separator: stop, maxSplits: 1, omittingEmptySubsequences: false).first
    return value.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
