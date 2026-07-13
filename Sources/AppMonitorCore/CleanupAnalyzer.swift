import Foundation

public struct CleanupAnalyzer {
    public init() {}

    public func suggestions(for row: AppUsageRow, items: [StorageScanItem], now: Date = Date()) -> [CleanupSuggestion] {
        items.compactMap { item in
            suggestion(for: row, item: item, now: now)
        }
        .sorted { lhs, rhs in
            if lhs.severity == rhs.severity { return lhs.sizeBytes > rhs.sizeBytes }
            return severityRank(lhs.severity) > severityRank(rhs.severity)
        }
    }

    public func storageRisk(for item: StorageScanItem) -> StorageRiskLevel {
        switch item.category {
        case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
            return .low
        case .extensions, .applicationSupport, .launchAgents, .applicationScripts, .webKit, .cookies:
            return .medium
        case .bundle, .containers, .groupContainers, .preferences:
            return .high
        }
    }

    private func suggestion(for row: AppUsageRow, item: StorageScanItem, now: Date) -> CleanupSuggestion? {
        guard item.sizeBytes >= 1_000_000 else { return nil }
        guard !CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(
            category: item.category,
            path: item.path,
            app: row.app
        ) else { return nil }

        let unusedForThirtyDays = isVerifiedUnused(row: row, days: 30, now: now)
        let lowRiskCategory = [
            .caches,
            .logs,
            .httpStorages,
            .savedApplicationState,
            .diagnosticReports
        ].contains(item.category)
        let mediumReviewCategory = [
            .extensions,
            .applicationSupport,
            .launchAgents,
            .applicationScripts,
            .webKit,
            .cookies
        ].contains(item.category)

        let hasRecentStorageEvidence = item.scannedAt >= now.addingTimeInterval(-7 * 24 * 60 * 60)
        guard lowRiskCategory || (mediumReviewCategory && unusedForThirtyDays && hasRecentStorageEvidence) else { return nil }

        let severity = cleanupSeverity(sizeBytes: item.sizeBytes, category: item.category)
        let title = cleanupTitle(for: row, item: item, unusedForThirtyDays: unusedForThirtyDays)
        let rationale: String
        if unusedForThirtyDays {
            rationale = "\(row.app.name) has not been used in at least 30 days, and this related path uses \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))."
        } else {
            rationale = "This \(item.category.rawValue.lowercased()) path is usually rebuildable and uses \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))."
        }

        return CleanupSuggestion(
            id: "\(row.app.id)|\(item.category.rawValue)|\(item.path)",
            appID: row.app.id,
            title: title,
            path: item.path,
            category: item.category,
            sizeBytes: item.sizeBytes,
            severity: severity,
            rationale: rationale,
            riskNotes: riskNotes(for: item.category)
        )
    }

    private func isVerifiedUnused(row: AppUsageRow, days: Int, now: Date) -> Bool {
        guard let lastSeen = row.lastSeen else { return row.activityState == .verifiedInactive }
        return lastSeen < now.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
    }

    private func cleanupSeverity(sizeBytes: Int64, category: StorageCategory) -> CleanupSeverity {
        if sizeBytes >= 1_000_000_000 { return .high }
        if sizeBytes >= 250_000_000
            || category == .applicationSupport
            || category == .extensions
            || category == .launchAgents
            || category == .applicationScripts
            || category == .webKit
            || category == .cookies {
            return .medium
        }
        return .low
    }

    private func cleanupTitle(for row: AppUsageRow, item: StorageScanItem, unusedForThirtyDays: Bool) -> String {
        let appName = row.app.name
        if unusedForThirtyDays {
            return "Unused \(appName) Storage"
        }

        switch item.category {
        case .caches, .httpStorages:
            return "\(appName) Cache"
        case .logs, .diagnosticReports:
            return "\(appName) Logs"
        case .savedApplicationState:
            return "\(appName) Saved State"
        case .applicationSupport:
            return "\(appName) Support Files"
        case .extensions:
            return "\(appName) Extensions"
        case .launchAgents:
            return "\(appName) Launch Agents"
        case .applicationScripts:
            return "\(appName) Scripts"
        case .webKit:
            return "\(appName) WebKit Data"
        case .cookies:
            return "\(appName) Cookies"
        case .bundle, .containers, .groupContainers, .preferences:
            return "\(appName) Related Files"
        }
    }

    private func riskNotes(for category: StorageCategory) -> String {
        switch category {
        case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
            return "Low-risk candidate. App Monitor moves this to quarantine before final deletion."
        case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies:
            return "Medium-risk candidate. Review ownership and restore from quarantine if the app needs it."
        case .bundle, .containers, .groupContainers, .preferences:
            return "High-risk storage. App Monitor does not auto-suggest this category."
        }
    }

    private func severityRank(_ severity: CleanupSeverity) -> Int {
        switch severity {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}
