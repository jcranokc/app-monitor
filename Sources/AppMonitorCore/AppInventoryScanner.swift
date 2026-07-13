import AppKit
import Foundation

public struct AppInventoryScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(includeAllBundles: Bool) -> [MonitoredApp] {
        var paths = Set<String>()

        for root in Self.userFacingRoots {
            for path in appBundlePaths(under: root.url, maxDepth: root.maxDepth) {
                paths.insert(path)
            }
        }

        if includeAllBundles {
            for path in spotlightApplicationBundlePaths() {
                paths.insert(path)
            }

            for root in Self.broaderRoots {
                for path in appBundlePaths(under: root.url, maxDepth: root.maxDepth) {
                    paths.insert(path)
                }
            }
        }

        let discoveredApps = paths.compactMap { path in
            app(at: URL(fileURLWithPath: path))
        }

        return Self.reconcileInventory(discoveredApps).sorted { lhs, rhs in
            let nameCompare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameCompare == .orderedSame {
                return lhs.path < rhs.path
            }
            return nameCompare == .orderedAscending
        }
    }

    /// Produces one inventory identity for each installed application.
    ///
    /// Bundle identifiers are the primary identity when present. If Spotlight or a
    /// broad scan also finds a build artifact, the canonical user-facing install
    /// wins. Apps without bundle identifiers remain distinct by canonical path.
    public static func reconcileInventory(_ apps: [MonitoredApp]) -> [MonitoredApp] {
        var selected: [String: MonitoredApp] = [:]

        for app in apps {
            let key: String
            if let bundleID = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
               !bundleID.isEmpty {
                key = "bundle:\(bundleID.lowercased())"
            } else {
                key = "path:\(canonicalPath(app.path).lowercased())"
            }

            guard let current = selected[key] else {
                selected[key] = app
                continue
            }
            if isPreferred(app, over: current) {
                selected[key] = app
            }
        }

        return Array(selected.values)
    }

    private static func isPreferred(_ candidate: MonitoredApp, over current: MonitoredApp) -> Bool {
        let candidateRank = pathRank(candidate.path, isUserFacing: candidate.isUserFacing)
        let currentRank = pathRank(current.path, isUserFacing: current.isUserFacing)
        if candidateRank != currentRank { return candidateRank < currentRank }

        let candidatePath = canonicalPath(candidate.path)
        let currentPath = canonicalPath(current.path)
        if candidatePath.count != currentPath.count { return candidatePath.count < currentPath.count }
        return candidatePath.localizedStandardCompare(currentPath) == .orderedAscending
    }

    private static func pathRank(_ path: String, isUserFacing: Bool) -> Int {
        let canonical = canonicalPath(path)
        if canonical.hasPrefix("/Applications/") { return 0 }
        if canonical.hasPrefix("/System/Applications/") { return 1 }
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").standardizedFileURL.path + "/"
        if canonical.hasPrefix(userApplications) { return 2 }
        if isUserFacing { return 3 }
        if canonical.contains("/DerivedData/") || canonical.contains("/.build/") { return 5 }
        return 4
    }

    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    public func app(for runningApplication: NSRunningApplication) -> MonitoredApp? {
        guard let bundleURL = runningApplication.bundleURL else { return nil }
        return app(at: bundleURL)
    }

    public func app(at url: URL) -> MonitoredApp? {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.pathExtension == "app" else { return nil }

        let bundle = Bundle(url: standardizedURL)
        let info = bundle?.infoDictionary ?? NSDictionary(contentsOf: standardizedURL.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
        let fallbackName = standardizedURL.deletingPathExtension().lastPathComponent
        let displayName = info?["CFBundleDisplayName"] as? String
        let bundleName = info?["CFBundleName"] as? String
        let executableName = info?["CFBundleExecutable"] as? String
        let name = [displayName, bundleName, executableName, fallbackName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallbackName
        let bundleID = bundle?.bundleIdentifier ?? info?["CFBundleIdentifier"] as? String
        let version = info?["CFBundleShortVersionString"] as? String ?? info?["CFBundleVersion"] as? String
        let path = standardizedURL.path
        let id = "\(bundleID ?? "no.bundle.identifier")|\(path)"
        let bundleCreatedAt = try? standardizedURL.resourceValues(forKeys: [.creationDateKey]).creationDate
        let bundleModifiedAt = try? standardizedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let receiptCreatedAt = receiptDate(in: standardizedURL)
        let installedAt = receiptCreatedAt ?? bundleCreatedAt ?? bundleModifiedAt

        return MonitoredApp(
            id: id,
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            path: path,
            isUserFacing: Self.isDefaultUserFacingPath(path),
            installedAt: installedAt,
            bundleCreatedAt: bundleCreatedAt
        )
    }

    private func receiptDate(in appURL: URL) -> Date? {
        let receiptURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("_MASReceipt", isDirectory: true)
            .appendingPathComponent("receipt")
        guard fileManager.fileExists(atPath: receiptURL.path) else { return nil }
        return try? receiptURL.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    private func appBundlePaths(under root: URL, maxDepth: Int) -> [String] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        var paths: [String] = []
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return paths
        }

        let rootDepth = root.standardizedFileURL.pathComponents.count
        for case let url as URL in enumerator {
            let standardized = url.standardizedFileURL
            let depth = standardized.pathComponents.count - rootDepth
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            if standardized.pathExtension == "app" {
                paths.append(standardized.path)
                enumerator.skipDescendants()
            }
        }
        return paths
    }

    private func spotlightApplicationBundlePaths() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasSuffix(".app") }
    }
}

private extension AppInventoryScanner {
    struct ScanRoot {
        let url: URL
        let maxDepth: Int
    }

    static var userFacingRoots: [ScanRoot] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ScanRoot(url: URL(fileURLWithPath: "/Applications"), maxDepth: 2),
            ScanRoot(url: URL(fileURLWithPath: "/System/Applications"), maxDepth: 2),
            ScanRoot(url: home.appendingPathComponent("Applications"), maxDepth: 3)
        ]
    }

    static var broaderRoots: [ScanRoot] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ScanRoot(url: URL(fileURLWithPath: "/System/Library/CoreServices"), maxDepth: 3),
            ScanRoot(url: URL(fileURLWithPath: "/Library"), maxDepth: 5),
            ScanRoot(url: home.appendingPathComponent("Library"), maxDepth: 6)
        ]
    }

    static func isDefaultUserFacingPath(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        return userFacingRoots.contains { root in
            let rootPath = root.url.standardizedFileURL.path
            guard standardized == rootPath || standardized.hasPrefix(rootPath + "/") else { return false }
            return !standardized.contains("/Contents/") && !standardized.contains("/DerivedData/")
        }
    }
}
