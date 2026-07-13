import Foundation

public struct AppWarningPolicy {
    public init() {}

    public func actionableWarnings(from warnings: [AppWarningItem]) -> [AppWarningItem] {
        var bestByKey: [String: AppWarningItem] = [:]

        for warning in warnings where isActionable(warning) {
            let key = deduplicationKey(for: warning)
            if let existing = bestByKey[key], !isHigherPriority(warning, than: existing) {
                continue
            }
            bestByKey[key] = warning
        }

        return bestByKey.values.sorted(by: isHigherPriority)
    }

    public func isProtectedSystemPath(_ path: String) -> Bool {
        let normalized = normalizedPath(path)
        return normalized == "/System"
            || normalized.hasPrefix("/System/")
            || normalized == "/usr"
            || normalized.hasPrefix("/usr/")
            || normalized == "/bin"
            || normalized.hasPrefix("/bin/")
            || normalized == "/sbin"
            || normalized.hasPrefix("/sbin/")
    }

    private func isActionable(_ warning: AppWarningItem) -> Bool {
        guard !isProtectedSystemPath(warning.appPath) else { return false }
        guard warning.affectedItems.compactMap(\.path).allSatisfy({ !isProtectedSystemPath($0) }) else {
            return false
        }

        if warning.source == "Usage Analytics" || warning.source == "Update Signal" {
            return false
        }
        if warning.title.localizedCaseInsensitiveContains("Writable Bundle") {
            return false
        }
        return warning.severity >= .medium
    }

    private func deduplicationKey(for warning: AppWarningItem) -> String {
        let paths = warning.affectedItems.compactMap(\.path)
        let path = paths.first.map(normalizedPath) ?? normalizedPath(warning.appPath)
        return [warning.appID, warning.category.rawValue.lowercased(), path.lowercased()]
            .joined(separator: "|")
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func isHigherPriority(_ lhs: AppWarningItem, than rhs: AppWarningItem) -> Bool {
        if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
        let lhsConfidence = sourceConfidence(lhs.source)
        let rhsConfidence = sourceConfidence(rhs.source)
        if lhsConfidence != rhsConfidence { return lhsConfidence > rhsConfidence }
        if lhs.detectedAt != rhs.detectedAt { return lhs.detectedAt > rhs.detectedAt }
        return lhs.id < rhs.id
    }

    private func sourceConfidence(_ source: String) -> Int {
        switch source {
        case "Code Signing", "Gatekeeper", "Filesystem": return 4
        case "Crash History", "Storage Scan": return 3
        case "Cleanup Analyzer", "Large File Index": return 2
        default: return 1
        }
    }
}
