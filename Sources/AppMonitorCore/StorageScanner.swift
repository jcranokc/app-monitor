import Foundation

public typealias StorageScanProgressHandler = @Sendable (StorageScanProgress) -> Void

public struct StorageScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scanStorage(
        for app: MonitoredApp,
        progress: StorageScanProgressHandler? = nil
    ) -> [StorageScanItem] {
        var items: [StorageScanItem] = []
        var scannedFileCount = 0
        var scannedBytes: Int64 = 0
        var lastProgressEmit = Date.distantPast

        func emitProgress(phase: String, path: String, force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            guard force || now.timeIntervalSince(lastProgressEmit) >= 0.12 else { return }
            lastProgressEmit = now
            progress(StorageScanProgress(
                phase: phase,
                currentPath: path,
                scannedFileCount: scannedFileCount,
                scannedBytes: scannedBytes
            ))
        }

        func measure(_ url: URL, category: StorageCategory) -> SizeResult {
            emitProgress(phase: "Scanning \(category.rawValue)", path: url.path, force: true)
            let measured = size(of: url) { child, bytes in
                scannedFileCount += 1
                scannedBytes += bytes
                emitProgress(phase: "Scanning \(category.rawValue)", path: child.path)
            }
            emitProgress(phase: "Scanned \(category.rawValue)", path: url.path, force: true)
            return measured
        }

        emitProgress(phase: "Starting \(app.name)", path: app.path, force: true)

        let appURL = URL(fileURLWithPath: app.path)
        let bundleSize = measure(appURL, category: .bundle)
        items.append(StorageScanItem(
            appID: app.id,
            category: .bundle,
            path: app.path,
            sizeBytes: bundleSize.bytes,
            warning: bundleSize.warning
        ))

        for extensionURL in extensionLocations(in: appURL) {
            let measured = measure(extensionURL, category: .extensions)
            items.append(StorageScanItem(
                appID: app.id,
                category: .extensions,
                path: extensionURL.path,
                sizeBytes: measured.bytes,
                warning: measured.warning
            ))
        }

        for location in Self.relatedLocations {
            emitProgress(phase: "Searching \(location.category.rawValue)", path: location.url.path, force: true)
            for candidate in candidates(for: app, in: location.url) {
                let measured = measure(candidate, category: location.category)
                items.append(StorageScanItem(
                    appID: app.id,
                    category: location.category,
                    path: candidate.path,
                    sizeBytes: measured.bytes,
                    warning: measured.warning
                ))
            }
        }

        emitProgress(phase: "Finished \(app.name)", path: app.path, force: true)

        return items.sorted { lhs, rhs in
            if lhs.category.rawValue == rhs.category.rawValue {
                return lhs.path < rhs.path
            }
            return lhs.category.rawValue < rhs.category.rawValue
        }
    }

    public func largeFiles(
        in items: [StorageScanItem],
        thresholdBytes: Int64 = 100_000_000,
        progress: StorageScanProgressHandler? = nil
    ) -> [LargeFileRecord] {
        let scannedAt = Date()
        var records: [LargeFileRecord] = []
        var seen = Set<String>()
        var scannedFileCount = 0
        var scannedBytes: Int64 = 0
        var lastProgressEmit = Date.distantPast

        func emitProgress(path: String, force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            guard force || now.timeIntervalSince(lastProgressEmit) >= 0.12 else { return }
            lastProgressEmit = now
            progress(StorageScanProgress(
                phase: "Indexing large files",
                currentPath: path,
                scannedFileCount: scannedFileCount,
                scannedBytes: scannedBytes
            ))
        }

        for item in items {
            let url = URL(fileURLWithPath: item.path)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) else { continue }
            emitProgress(path: item.path, force: true)

            if !isDirectory.boolValue {
                scannedFileCount += 1
                scannedBytes += item.sizeBytes
                emitProgress(path: item.path)
                if item.sizeBytes >= thresholdBytes, seen.insert(item.path).inserted {
                    records.append(record(for: item, path: item.path, sizeBytes: item.sizeBytes, scannedAt: scannedAt))
                }
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let child as URL in enumerator {
                let measured = fileSize(child)
                if measured.bytes > 0 {
                    scannedFileCount += 1
                    scannedBytes += measured.bytes
                    emitProgress(path: child.path)
                }
                guard measured.bytes >= thresholdBytes else { continue }
                let path = child.standardizedFileURL.path
                guard seen.insert(path).inserted else { continue }
                records.append(record(for: item, path: path, sizeBytes: measured.bytes, scannedAt: scannedAt))
            }
        }

        if let path = items.last?.path {
            emitProgress(path: path, force: true)
        }

        return records.sorted { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes { return lhs.path < rhs.path }
            return lhs.sizeBytes > rhs.sizeBytes
        }
    }

    private func extensionLocations(in appURL: URL) -> [URL] {
        [
            appURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("PlugIns", isDirectory: true),
            appURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Extensions", isDirectory: true),
            appURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Library", isDirectory: true).appendingPathComponent("LoginItems", isDirectory: true)
        ]
        .map(\.standardizedFileURL)
        .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func record(for item: StorageScanItem, path: String, sizeBytes: Int64, scannedAt: Date) -> LargeFileRecord {
        LargeFileRecord(
            id: stableID(appID: item.appID, path: path),
            appID: item.appID,
            path: path,
            category: item.category,
            sizeBytes: sizeBytes,
            riskScore: riskScore(category: item.category, sizeBytes: sizeBytes),
            riskReason: riskReason(category: item.category, sizeBytes: sizeBytes),
            modifiedAt: (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
            scannedAt: scannedAt
        )
    }

    private func stableID(appID: String, path: String) -> String {
        "\(appID)|\(path)"
    }

    private func riskScore(category: StorageCategory, sizeBytes: Int64) -> Int {
        let sizePoints: Int
        switch sizeBytes {
        case 1_000_000_000...:
            sizePoints = 35
        case 250_000_000...:
            sizePoints = 25
        default:
            sizePoints = 15
        }

        let categoryPoints: Int
        switch category {
        case .bundle, .preferences, .containers, .groupContainers:
            categoryPoints = 45
        case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies:
            categoryPoints = 30
        case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
            categoryPoints = 10
        }

        return min(100, sizePoints + categoryPoints)
    }

    private func riskReason(category: StorageCategory, sizeBytes: Int64) -> String {
        let size = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        switch category {
        case .bundle:
            return "\(size) inside the app bundle. Review before removing."
        case .preferences, .containers, .groupContainers:
            return "\(size) in app state. Removing may delete settings or user data."
        case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies:
            return "\(size) in support or extension storage. Quarantine before deletion."
        case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
            return "\(size) in a usually rebuildable category."
        }
    }

    private func candidates(for app: MonitoredApp, in root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        var matches: [URL] = []
        var seen = Set<String>()

        func addIfMatching(_ url: URL) -> Bool {
            let standardized = url.standardizedFileURL
            guard RelatedFileMatcher.matches(candidateName: standardized.lastPathComponent, app: app) else {
                return false
            }
            if seen.insert(standardized.path).inserted {
                matches.append(standardized)
            }
            return true
        }

        guard let topLevel = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for url in topLevel {
            if addIfMatching(url) {
                continue
            }

            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            guard let children = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for child in children {
                _ = addIfMatching(child)
            }
        }

        return matches
    }

    private func size(
        of url: URL,
        visit: ((URL, Int64) -> Void)? = nil
    ) -> SizeResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return SizeResult(bytes: 0, warning: "Path no longer exists")
        }
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            let bytes = attributes?[.size] as? NSNumber
            return SizeResult(
                bytes: bytes?.int64Value ?? 0,
                warning: "Symbolic link. App Monitor will not follow the destination when cleaning up."
            )
        }

        if !isDirectory.boolValue {
            let measured = fileSize(url)
            visit?(url, measured.bytes)
            return measured
        }

        var total: Int64 = 0
        var warnings: [String] = []
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [],
            errorHandler: { url, error in
                warnings.append("\(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            return SizeResult(bytes: 0, warning: "Unable to enumerate \(url.path)")
        }

        for case let child as URL in enumerator {
            let measured = fileSize(child)
            total += measured.bytes
            if measured.bytes > 0 {
                visit?(child, measured.bytes)
            }
            if let warning = measured.warning {
                warnings.append(warning)
            }
        }

        return SizeResult(bytes: total, warning: warnings.first)
    }

    private func fileSize(_ url: URL) -> SizeResult {
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
            if values.isSymbolicLink == true {
                return SizeResult(bytes: 0, warning: "\(url.path): symbolic link skipped")
            }
            guard values.isRegularFile == true else { return SizeResult(bytes: 0, warning: nil) }
            let bytes = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
            return SizeResult(bytes: Int64(bytes), warning: nil)
        } catch {
            return SizeResult(bytes: 0, warning: "\(url.path): \(error.localizedDescription)")
        }
    }
}

public enum RelatedFileMatcher {
    public static func matches(candidateName: String, app: MonitoredApp) -> Bool {
        let candidate = normalize(candidateName)
        guard !candidate.isEmpty else { return false }

        if let bundleID = app.bundleIdentifier {
            let normalizedBundle = normalize(bundleID)
            if candidate.contains(normalizedBundle) { return true }
        }

        let normalizedName = normalize(app.name)
        if normalizedName.count >= 4, candidate.contains(normalizedName) {
            return true
        }

        let candidateTokens = tokens(in: candidateName)
        return !candidateTokens.isDisjoint(with: tokens(for: app))
    }

    public static func tokens(for app: MonitoredApp) -> Set<String> {
        var appTokens = Set<String>()
        var rawPieces = [
            app.name,
            URL(fileURLWithPath: app.path).deletingPathExtension().lastPathComponent
        ]
        if let bundleLastComponent = app.bundleIdentifier?.split(separator: ".").last {
            rawPieces.append(String(bundleLastComponent))
        }

        let stopWords: Set<String> = [
            "app", "mac", "macos", "desktop", "helper", "launcher", "the",
            "inc", "llc", "com", "org", "net", "apple", "microsoft", "google",
            "openai", "application", "support", "cache", "caches", "container"
        ]

        for piece in rawPieces {
            for token in tokens(in: piece) {
                guard token.count >= 4, !stopWords.contains(token) else { continue }
                appTokens.insert(token)
            }
        }

        return appTokens
    }

    private static func tokens(in value: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        return Set(value.lowercased().components(separatedBy: separators).map(normalize).filter { !$0.isEmpty })
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}

private struct SizeResult {
    let bytes: Int64
    let warning: String?
}

private extension StorageScanner {
    struct RelatedLocation {
        let category: StorageCategory
        let url: URL
    }

    static var relatedLocations: [RelatedLocation] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        return [
            RelatedLocation(category: .applicationSupport, url: library.appendingPathComponent("Application Support", isDirectory: true)),
            RelatedLocation(category: .caches, url: library.appendingPathComponent("Caches", isDirectory: true)),
            RelatedLocation(category: .containers, url: library.appendingPathComponent("Containers", isDirectory: true)),
            RelatedLocation(category: .groupContainers, url: library.appendingPathComponent("Group Containers", isDirectory: true)),
            RelatedLocation(category: .preferences, url: library.appendingPathComponent("Preferences", isDirectory: true)),
            RelatedLocation(category: .savedApplicationState, url: library.appendingPathComponent("Saved Application State", isDirectory: true)),
            RelatedLocation(category: .httpStorages, url: library.appendingPathComponent("HTTPStorages", isDirectory: true)),
            RelatedLocation(category: .logs, url: library.appendingPathComponent("Logs", isDirectory: true)),
            RelatedLocation(category: .launchAgents, url: library.appendingPathComponent("LaunchAgents", isDirectory: true)),
            RelatedLocation(category: .applicationScripts, url: library.appendingPathComponent("Application Scripts", isDirectory: true)),
            RelatedLocation(category: .webKit, url: library.appendingPathComponent("WebKit", isDirectory: true)),
            RelatedLocation(category: .cookies, url: library.appendingPathComponent("Cookies", isDirectory: true)),
            RelatedLocation(
                category: .diagnosticReports,
                url: library
                    .appendingPathComponent("Logs", isDirectory: true)
                    .appendingPathComponent("DiagnosticReports", isDirectory: true)
            )
        ]
    }
}
