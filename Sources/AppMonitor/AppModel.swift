import AppKit
import AppMonitorCore
import CryptoKit
import Foundation
import ServiceManagement
import SwiftUI

struct OperationProgressSnapshot: Equatable {
    let title: String
    let detail: String
    let completedUnitCount: Int
    let totalUnitCount: Int
    let currentPath: String?
    let scannedFileCount: Int
    let scannedBytes: Int64

    static let idle = OperationProgressSnapshot(
        title: "",
        detail: "",
        completedUnitCount: 0,
        totalUnitCount: 0,
        currentPath: nil,
        scannedFileCount: 0,
        scannedBytes: 0
    )

    var isVisible: Bool {
        !title.isEmpty || !detail.isEmpty
    }

    var fraction: Double? {
        guard totalUnitCount > 0 else { return nil }
        return min(1, max(0, Double(completedUnitCount) / Double(totalUnitCount)))
    }

    var percentText: String {
        guard let fraction else { return "Working" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    var unitText: String {
        guard totalUnitCount > 0 else { return "" }
        return "\(completedUnitCount) of \(totalUnitCount)"
    }

    var metricsText: String {
        var parts: [String] = []
        if scannedFileCount > 0 {
            parts.append("\(Self.numberFormatter.string(from: NSNumber(value: scannedFileCount)) ?? "\(scannedFileCount)") files")
        }
        if scannedBytes > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: scannedBytes, countStyle: .file))
        }
        return parts.joined(separator: " / ")
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

private struct AppMonitorUpdateInstallPlan: Sendable {
    let stagedAppURL: URL
    let workDirectoryURL: URL
    let currentBundleURL: URL
}

private enum AppMonitorSelfUpdateError: LocalizedError {
    case missingPackageURL
    case unsupportedPackage(String)
    case appBundleNotFound
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .missingPackageURL:
            return "The update feed did not include a downloadable package."
        case let .unsupportedPackage(pathExtension):
            return "App Monitor cannot install .\(pathExtension) update packages yet."
        case .appBundleNotFound:
            return "The update package did not contain App Monitor.app."
        case .checksumMismatch:
            return "The downloaded update did not match the appcast checksum."
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum DashboardDestination: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case storage = "Storage Overview"
        case largeFiles = "Large Files"
        case usageTable = "All Usage"
        case usageTrends = "Usage Trends"
        case activityTimeline = "Activity Timeline"
        case warnings = "Warnings"
        case updates = "Updates"
        case cleanup = "Cleanup Suggestions"
        case history = "History"
        case settings = "Settings"

        var id: String { rawValue }
    }

    enum AppListQuickFilter: String, CaseIterable, Identifiable {
        case all = "All Apps"
        case recentlyUsed = "Recently Used"
        case neverUsed = "Never Used"
        case systemApps = "System Apps"

        var id: String { rawValue }

        var tableTitle: String { rawValue }

        var tableSubtitle: String {
            switch self {
            case .all:
                return "Sortable app usage and storage table"
            case .recentlyUsed:
                return "Apps used during the selected reporting period"
            case .neverUsed:
                return "Apps with no recorded local or imported activity"
            case .systemApps:
                return "Non-user-facing apps and system bundles"
            }
        }
    }

    enum SortKey: String, CaseIterable {
        case app = "App"
        case usage = "Usage"
        case importedDays = "Imported Days"
        case importedUseCount = "Imported Opens"
        case importedLastUsed = "Imported Last Used"
        case lastUsed = "Last Used"
        case appSize = "App Size"
        case relatedSize = "Related Size"
        case totalSize = "Total Size"
        case location = "Location"
        case scanStatus = "Scan Status"
    }

    enum CleanupSuggestionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case caches = "Caches"
        case unusedApps = "Unused Apps"
        case largeFiles = "Large Files"
        case downloads = "Downloads"
        case logs = "Logs"
        case other = "Other"

        var id: String { rawValue }
    }

    enum CleanupSuggestionSort: String, CaseIterable, Identifiable {
        case size = "Size"
        case risk = "Risk"
        case app = "App"
        case category = "Category"
        case updated = "Updated"

        var id: String { rawValue }
    }

    struct CleanupPreviewItem: Identifiable, Hashable {
        let id: String
        let name: String
        let path: String
        let sizeBytes: Int64?
        let isDirectory: Bool
    }

    @Published var period: ReportingPeriod = .week {
        didSet {
            selectedTimelineSession = nil
            let defaultGrouping = UsageTrendGrouping.defaultGrouping(for: period)
            if usageTrendGrouping != defaultGrouping {
                usageTrendGrouping = defaultGrouping
            }
            reloadRows()
        }
    }
    @Published var usageTrendGrouping: UsageTrendGrouping = .day {
        didSet { reloadUsageAnalytics() }
    }
    @Published var includeAllBundles = false {
        didSet { Task { await refreshInventory() } }
    }
    @Published var searchText = "" {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: true, reloadTimeline: true) }
    }
    @Published var rows: [AppUsageRow] = []
    @Published private(set) var displayedRows: [AppUsageRow] = []
    @Published var usageAnalytics = UsageAnalyticsSnapshot.empty()
    @Published private(set) var dailyUsageRows: [DailyUsageRow] = []
    @Published private(set) var selectedDailyUsageRows: [DailyUsageRow] = []
    @Published private(set) var timelineSessions: [TimelineSession] = []
    @Published private(set) var timelineSummary = AppModel.emptyTimelineSummary()
    @Published private(set) var timelineDayGroups: [TimelineDayGroup] = []
    @Published private(set) var timelineHourBuckets: [TimelineHourBucket] = []
    @Published var selectedAppID: String?
    @Published var selectedTimelineSession: TimelineSession?
    @Published var selectedStorageItems: [StorageScanItem] = []
    @Published var isLoadingInventory = false
    @Published var isScanningStorage = false
    @Published var isImportingHistory = false
    @Published var storageScanProgress = OperationProgressSnapshot.idle
    @Published var historyImportProgress = ""
    @Published var isRunningCleanup = false
    @Published var cleanupProgress = OperationProgressSnapshot.idle
    @Published var isCheckingUpdates = false
    @Published var isRunningUpdates = false
    @Published var isCheckingAppMonitorUpdate = false
    @Published var isInstallingAppMonitorUpdate = false
    @Published var updateProgress = OperationProgressSnapshot.idle
    @Published var updateRecords: [AppUpdateRecord] = []
    @Published var selectedUpdateIDs: Set<String> = []
    @Published var updateSettings = AppUpdateSettings()
    @Published var appMonitorUpdateRecord: AppUpdateRecord?
    @Published var appMonitorUpdateItem: SparkleAppcastItem?
    @Published var appMonitorUpdateLastCheckAt = AppModel.loadAppMonitorUpdateLastCheckAt()
    @Published var appMonitorUpdateNextCheckAt = AppModel.loadAppMonitorUpdateNextCheckAt()
    @Published var appMonitorUpdateChecksEnabled = AppModel.loadAppMonitorUpdateChecksEnabled()
    @Published var appMonitorAutomaticUpdatesEnabled = AppModel.loadAppMonitorAutomaticUpdatesEnabled()
    @Published var appMonitorUpdateCadenceHours = AppModel.loadAppMonitorUpdateCadenceHours()
    @Published var appMonitorUpdateMessage = AppModel.loadAppMonitorUpdateLastCheckAt() == nil ? "Not checked yet" : "No App Monitor update loaded."
    @Published var updateRuns: [UpdateRunRecord] = []
    @Published var updateItemResults: [UpdateItemResult] = []
    @Published var changeLogEntries: [AppChangeLogEntry] = []
    @Published var isPreparingUninstall = false
    @Published var isRunningUninstall = false
    @Published var uninstallProgress = OperationProgressSnapshot.idle
    @Published var uninstallPlan: UninstallPlan?
    @Published var selectedUninstallItemIDs: Set<String> = []
    @Published var uninstallResults: [UninstallItemResult] = []
    @Published var lastMessage = ""
    @Published var sortKey: SortKey = .usage {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: false, reloadTimeline: true) }
    }
    @Published var sortAscending = false {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: false, reloadTimeline: true) }
    }
    @Published var loginItemEnabled = false
    @Published var loginItemStatus = "Unknown"
    @Published var keepRunningWhenClosed = AppLifecycleSettings.keepRunningWhenClosed
    @Published var appearancePreference = AppAppearanceSettings.preference {
        didSet { AppAppearanceSettings.preference = appearancePreference }
    }
    @Published var trackingStartedAt: Date?
    @Published var destination: DashboardDestination = .overview
    @Published var appListQuickFilter: AppListQuickFilter = .all {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: false, reloadTimeline: true) }
    }
    @Published var filterState = AppFilterState() {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: true, reloadTimeline: true) }
    }
    @Published var savedFilters: [SavedAppFilter] = []
    @Published var healthFindingsByAppID: [String: [AppHealthFinding]] = [:]
    @Published var cleanupSuggestions: [CleanupSuggestion] = []
    @Published var cleanupSuggestionFilter: CleanupSuggestionFilter = .all
    @Published var cleanupSuggestionSort: CleanupSuggestionSort = .size
    @Published var focusedCleanupSuggestionID: String?
    @Published var largeFiles: [LargeFileRecord] = []
    @Published private(set) var allStorageItems: [StorageScanItem] = []
    @Published private(set) var warningItems: [AppWarningItem] = []
    @Published var selectedWarningID: String?
    @Published var tagsByAppID: [String: [String]] = [:]
    @Published var ignoredAppIDs: Set<String> = []
    @Published var includeIgnoredApps = false {
        didSet { refreshNavigationSnapshots(reloadUsageAnalytics: true, reloadTimeline: true) }
    }
    @Published var scanSchedule = AppScanSchedule()
    @Published var actionHistory: [(Date, String, String)] = []
    @Published var selectedHistoryActionID: String?
    @Published var searchFocusToken = UUID()

    let tracker: UsageTracker

    private let dataStore: AppDataStore
    private let inventoryScanner = AppInventoryScanner()
    private let storageScanner = StorageScanner()
    private let cleanupAnalyzer = CleanupAnalyzer()
    private let uninstallPlanner = AppUninstallPlanner()
    private let uninstallExecutor = AppUninstallExecutor()
    private let healthAuditor = AppHealthAuditor()
    private let spotlightImporter = SpotlightUsageImporter()
    private var hasBootstrapped = false
    private var terminationObserver: NSObjectProtocol?
    private var schedulerTimer: Timer?
    private var updateSchedulerTimer: Timer?
    private var appMonitorUpdateSchedulerTimer: Timer?
    private var appListRowCounts: [AppListQuickFilter: Int] = [:]
    private var storageCategoriesByAppID: [String: Set<StorageCategory>] = [:]
    private static let appMonitorUpdateLastCheckAtKey = "AppMonitorUpdateLastCheckAt"
    private static let appMonitorUpdateNextCheckAtKey = "AppMonitorUpdateNextCheckAt"
    private static let appMonitorUpdateChecksEnabledKey = "AppMonitorUpdateChecksEnabled"
    private static let appMonitorAutomaticUpdatesEnabledKey = "AppMonitorAutomaticUpdatesEnabled"
    private static let appMonitorUpdateCadenceHoursKey = "AppMonitorUpdateCadenceHours"

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static func hourLabel(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    private static func loadAppMonitorUpdateLastCheckAt() -> Date? {
        UserDefaults.standard.object(forKey: appMonitorUpdateLastCheckAtKey) as? Date
    }

    private static func loadAppMonitorUpdateNextCheckAt() -> Date? {
        UserDefaults.standard.object(forKey: appMonitorUpdateNextCheckAtKey) as? Date
    }

    private static func loadAppMonitorUpdateChecksEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: appMonitorUpdateChecksEnabledKey)
    }

    private static func loadAppMonitorAutomaticUpdatesEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: appMonitorAutomaticUpdatesEnabledKey)
    }

    private static func loadAppMonitorUpdateCadenceHours() -> Int {
        let value = UserDefaults.standard.integer(forKey: appMonitorUpdateCadenceHoursKey)
        return value > 0 ? value : 24
    }

    init() {
        do {
            dataStore = try AppDataStore()
        } catch {
            fatalError("Unable to create App Monitor datastore: \(error)")
        }
        tracker = UsageTracker(dataStore: dataStore)
        AppAppearanceSettings.apply(appearancePreference)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: .appMonitorWillTerminate,
            object: nil,
            queue: .main
        ) { [weak tracker] _ in
            Task { @MainActor in tracker?.flush() }
        }
        refreshLoginItemStatus()
    }

    deinit {
        schedulerTimer?.invalidate()
        updateSchedulerTimer?.invalidate()
        appMonitorUpdateSchedulerTimer?.invalidate()
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    private static func emptyTimelineSummary() -> TimelineSummary {
        let zeroDuration = TimelineMetricDelta(currentValue: 0, previousValue: 0, kind: .duration)
        let zeroCount = TimelineMetricDelta(currentValue: 0, previousValue: 0, kind: .count)
        return TimelineSummary(
            totalUsageSeconds: 0,
            dailyAverageSeconds: 0,
            longestSession: nil,
            mostActiveDay: nil,
            sessionCount: 0,
            totalUsageDelta: zeroDuration,
            dailyAverageDelta: zeroDuration,
            longestSessionDelta: zeroDuration,
            mostActiveDayDelta: zeroDuration,
            sessionCountDelta: zeroCount
        )
    }

    private func makeDisplayedRows() -> [AppUsageRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = rows.filter { row in
            guard passesInfrastructureFilters(row) else { return false }
            guard passesAppListQuickFilter(row) else { return false }
            guard !query.isEmpty else { return true }
            return row.app.name.lowercased().contains(query)
                || (row.app.bundleIdentifier?.lowercased().contains(query) ?? false)
                || row.app.path.lowercased().contains(query)
                || (tagsByAppID[row.app.id]?.contains { $0.lowercased().contains(query) } ?? false)
        }

        return filtered.sorted { lhs, rhs in
            let primary = compare(lhs, rhs, by: sortKey)
            if primary == .orderedSame {
                let nameCompare = lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name)
                if nameCompare == .orderedSame {
                    return lhs.app.path < rhs.app.path
                }
                return nameCompare == .orderedAscending
            }
            return sortAscending ? primary == .orderedAscending : primary == .orderedDescending
        }
    }

    var selectedRow: AppUsageRow? {
        guard let selectedAppID else { return displayedRows.first }
        return displayedRows.first { $0.app.id == selectedAppID } ?? displayedRows.first
    }

    var totalUsageSeconds: TimeInterval {
        rows.reduce(0) { $0 + $1.usageSeconds }
    }

    var todayUsageRows: [AppUsageRow] {
        (try? dataStore.fetchRows(period: .today, includeAll: includeAllBundles)) ?? rows
    }

    var todayUsageSeconds: TimeInterval {
        todayUsageRows.reduce(0) { $0 + $1.usageSeconds }
    }

    var scannedSizeBytes: Int64 {
        rows.reduce(0) { $0 + $1.totalSizeBytes }
    }

    var scannedAppCount: Int {
        rows.filter { $0.scannedAt != nil }.count
    }

    var importedAppCount: Int {
        rows.filter {
            $0.importedLastUsed != nil || $0.importedUseCount != nil || $0.importedDaysInPeriod > 0
        }.count
    }

    var importedDaysTotal: Int {
        rows.reduce(0) { $0 + $1.importedDaysInPeriod }
    }

    var activeCleanupSuggestions: [CleanupSuggestion] {
        cleanupSuggestions.filter { $0.state == .pending || $0.state == .approved }
    }

    var displayedCleanupSuggestions: [CleanupSuggestion] {
        activeCleanupSuggestions
            .filter(passesCleanupSuggestionFilter)
            .sorted(by: cleanupSuggestionComparator)
    }

    var focusedCleanupSuggestion: CleanupSuggestion? {
        if let focusedCleanupSuggestionID,
           let suggestion = activeCleanupSuggestions.first(where: { $0.id == focusedCleanupSuggestionID }) {
            return suggestion
        }
        return displayedCleanupSuggestions.first ?? activeCleanupSuggestions.first
    }

    var approvedCleanupCount: Int {
        cleanupSuggestions.filter { $0.state == .approved }.count
    }

    var approvedCleanupBytes: Int64 {
        cleanupSuggestions
            .filter { $0.state == .approved }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var potentialSavingsBytes: Int64 {
        activeCleanupSuggestions.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedUninstallBytes: Int64 {
        uninstallPlan?.items
            .filter { selectedUninstallItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.sizeBytes } ?? 0
    }

    var selectedUninstallCount: Int {
        uninstallPlan?.items.filter { selectedUninstallItemIDs.contains($0.id) }.count ?? 0
    }

    var warningCount: Int {
        warningItems.count
    }

    var availableUpdateCount: Int {
        updateRecords.filter { $0.status.countsAsAvailable }.count
    }

    var autoEligibleUpdateCount: Int {
        updateRecords.filter(isUpdateAutoEligible).count
    }

    var manualUpdateCount: Int {
        updateRecords.filter { $0.status == .manualAction || $0.requiresAdmin || $0.requiresRestart }.count
    }

    var selectedUpdateCount: Int {
        selectedUpdateIDs.count
    }

    var selectedUpdateRecords: [AppUpdateRecord] {
        updateRecords.filter { selectedUpdateIDs.contains($0.id) }
    }

    var selectedWarningItem: AppWarningItem? {
        selectedWarning(for: selectedRow)
    }

    var selectedUpdateRecord: AppUpdateRecord? {
        guard let selectedAppID else { return nil }
        return updateRecords.first { $0.appID == selectedAppID }
    }

    var selectedUpdateResult: UpdateItemResult? {
        guard let selectedAppID else { return nil }
        return updateItemResults.first { $0.appID == selectedAppID }
    }

    var selectedChangeLogEntries: [AppChangeLogEntry] {
        guard let selectedAppID else { return [] }
        return changeLogEntries.filter { $0.appID == selectedAppID }
    }

    var reviewLargeFileCount: Int {
        largeFiles.filter { $0.state == .needsReview }.count
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadTrackingStart()
        loadInfrastructureState()
        tracker.start()
        startScheduler()
        startUpdateScheduler()
        startAppMonitorUpdateScheduler()
        await refreshInventory()
        await refreshImportedActivity()
    }

    func refreshInventory() async {
        isLoadingInventory = true
        lastMessage = "Scanning installed apps..."
        let includeAll = includeAllBundles
        let scanner = inventoryScanner
        let apps = await Task.detached(priority: .userInitiated) {
            scanner.scan(includeAllBundles: includeAll)
        }.value

        do {
            try dataStore.upsertApps(apps)
            reloadRows()
            loadInfrastructureState()
            lastMessage = "Found \(apps.count) apps"
        } catch {
            lastMessage = "Inventory scan failed: \(error.localizedDescription)"
        }
        isLoadingInventory = false
    }

    func runFullScan() async {
        await refreshStorage()
        await refreshHealthAudit()
        markScanCompleted()
    }

    func refreshStorage() async {
        guard !isScanningStorage else { return }
        isScanningStorage = true
        storageScanProgress = OperationProgressSnapshot(
            title: "Scanning storage",
            detail: "Preparing scan...",
            completedUnitCount: 0,
            totalUnitCount: 0,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: 0
        )
        lastMessage = "Scanning storage..."

        do {
            let apps = try dataStore.fetchApps(includeAll: includeAllBundles)
            let scanner = storageScanner
            let store = dataStore
            let count = apps.count
            var allLargeFiles: [LargeFileRecord] = []

            for (index, app) in apps.enumerated() {
                storageScanProgress = OperationProgressSnapshot(
                    title: "Scanning storage",
                    detail: "Starting \(app.name)",
                    completedUnitCount: index,
                    totalUnitCount: count,
                    currentPath: app.path,
                    scannedFileCount: 0,
                    scannedBytes: 0
                )
                let progressHandler: StorageScanProgressHandler = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.updateStorageScanProgress(
                            appName: app.name,
                            appIndex: index,
                            appCount: count,
                            progress: progress
                        )
                    }
                }
                let scanResult = await Task.detached(priority: .utility) {
                    let items = scanner.scanStorage(for: app, progress: progressHandler)
                    let largeFiles = scanner.largeFiles(in: items, progress: progressHandler)
                    return (items: items, largeFiles: largeFiles)
                }.value
                try store.replaceStorageItems(for: app.id, items: scanResult.items)
                allLargeFiles.append(contentsOf: scanResult.largeFiles)
                storageScanProgress = OperationProgressSnapshot(
                    title: "Scanning storage",
                    detail: "Completed \(app.name)",
                    completedUnitCount: index + 1,
                    totalUnitCount: count,
                    currentPath: app.path,
                    scannedFileCount: 0,
                    scannedBytes: scanResult.items.reduce(0) { $0 + $1.sizeBytes }
                )
                if index % 5 == 0 {
                    reloadRows()
                }
            }

            reloadRows()
            try regenerateCleanupSuggestions(for: apps)
            try dataStore.replaceLargeFiles(allLargeFiles)
            loadInfrastructureState()
            loadSelectedStorageItems()
            lastMessage = "Storage scan complete for \(count) apps"
        } catch {
            lastMessage = "Storage scan failed: \(error.localizedDescription)"
        }

        storageScanProgress = .idle
        isScanningStorage = false
    }

    func refreshHealthAudit() async {
        lastMessage = "Running app health audit..."
        do {
            let apps = try dataStore.fetchApps(includeAll: includeAllBundles)
            let auditor = healthAuditor
            let store = dataStore
            for app in apps {
                let findings = await Task.detached(priority: .utility) {
                    auditor.audit(app: app)
                }.value
                try store.replaceHealthFindings(for: app.id, findings: findings)
            }
            loadInfrastructureState()
            lastMessage = "Health audit complete for \(apps.count) apps"
        } catch {
            lastMessage = "Health audit failed: \(error.localizedDescription)"
        }
    }

    func refreshImportedActivity() async {
        isImportingHistory = true
        historyImportProgress = "Reading Spotlight activity..."
        lastMessage = "Importing historical activity..."

        do {
            let apps = try dataStore.fetchApps(includeAll: includeAllBundles)
            let importer = spotlightImporter
            let imported = await Task.detached(priority: .utility) {
                importer.importHistory(for: apps)
            }.value

            try dataStore.replaceImportedUsage(imported)
            reloadRows()
            loadInfrastructureState()
            let withDays = imported.filter { !$0.usedDays.isEmpty }.count
            lastMessage = "Imported Spotlight activity for \(withDays) of \(apps.count) apps"
        } catch {
            lastMessage = "Activity import failed: \(error.localizedDescription)"
        }

        historyImportProgress = ""
        isImportingHistory = false
    }

    func checkForUpdates(runAutomaticEligible: Bool = false) async {
        guard !isCheckingUpdates, !isRunningUpdates else { return }
        isCheckingUpdates = true
        updateProgress = OperationProgressSnapshot(
            title: "Checking updates",
            detail: "Preparing providers...",
            completedUnitCount: 0,
            totalUnitCount: 4,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: 0
        )
        lastMessage = "Checking for installed app updates..."

        do {
            let apps = try appsForUpdateChecks()
            let providers = makeUpdateProviders(settings: updateSettings)
            var records: [AppUpdateRecord] = []

            for (index, provider) in providers.enumerated() {
                updateProgress = OperationProgressSnapshot(
                    title: "Checking updates",
                    detail: "Checking \(provider.source.displayName)",
                    completedUnitCount: index,
                    totalUnitCount: providers.count,
                    currentPath: nil,
                    scannedFileCount: 0,
                    scannedBytes: 0
                )
                records.append(contentsOf: await provider.checkUpdates(apps: apps))
            }

            records = records
                .map(recordWithCurrentAutoEligibility)
                .sorted(by: updateRecordComparator)
            updateSettings.lastCheckAt = Date()
            updateSettings.nextCheckAt = updateSettings.scheduledChecksEnabled
                ? updateSettings.nextCheckDate(from: updateSettings.lastCheckAt ?? Date())
                : nil
            let discoveredChangeLogs = changeLogEntries(from: records, runID: nil, results: [])
            try dataStore.saveUpdateSettings(updateSettings)
            try dataStore.replaceAppUpdates(records)
            try dataStore.upsertChangeLogEntries(discoveredChangeLogs)
            updateRecords = records
            selectedUpdateIDs.formIntersection(Set(records.map(\.id)))
            updateRuns = try dataStore.fetchUpdateRuns()
            updateItemResults = try dataStore.fetchUpdateItemResults()
            changeLogEntries = try dataStore.fetchChangeLogEntries()
            try dataStore.recordAction(
                title: "Checked Installed App Updates",
                detail: "\(records.filter { $0.status.countsAsAvailable }.count) installed app update\(records.filter { $0.status.countsAsAvailable }.count == 1 ? "" : "s") found"
            )
            actionHistory = try dataStore.fetchActionHistory()
            lastMessage = "Found \(availableUpdateCount) installed app update\(availableUpdateCount == 1 ? "" : "s")"

            if runAutomaticEligible, updateSettings.automaticUpdatesEnabled {
                let eligible = updateRecords.filter(isUpdateAutoEligible)
                if !eligible.isEmpty {
                    await performUpdates(eligible, mode: .automatic)
                }
            }
        } catch {
            lastMessage = "Installed app update check failed: \(error.localizedDescription)"
        }

        updateProgress = .idle
        isCheckingUpdates = false
    }

    func checkForAppMonitorUpdate(installIfAvailable: Bool = false) async {
        guard !isCheckingAppMonitorUpdate, !isInstallingAppMonitorUpdate else { return }
        isCheckingAppMonitorUpdate = true
        appMonitorUpdateMessage = "Checking App Monitor..."
        lastMessage = "Checking for App Monitor updates..."

        defer {
            isCheckingAppMonitorUpdate = false
        }

        guard let appcastURL = appMonitorAppcastURL() else {
            appMonitorUpdateRecord = nil
            appMonitorUpdateItem = nil
            appMonitorUpdateMessage = "No App Monitor update feed is configured for this build."
            lastMessage = appMonitorUpdateMessage
            return
        }

        guard let currentApp = currentAppForUpdateDetection() else {
            appMonitorUpdateRecord = nil
            appMonitorUpdateItem = nil
            appMonitorUpdateMessage = "App Monitor update checks are available from the packaged app."
            lastMessage = appMonitorUpdateMessage
            return
        }

        do {
            let item = try await fetchAppMonitorUpdateItem(from: appcastURL)
            let checkedAt = Date()
            appMonitorUpdateLastCheckAt = checkedAt
            UserDefaults.standard.set(checkedAt, forKey: Self.appMonitorUpdateLastCheckAtKey)
            updateNextAppMonitorUpdateCheck(from: checkedAt)

            guard item.version.map({ VersionComparator.isVersion($0, newerThan: currentApp.version) }) ?? false else {
                appMonitorUpdateRecord = nil
                appMonitorUpdateItem = nil
                appMonitorUpdateMessage = "App Monitor is up to date."
                lastMessage = appMonitorUpdateMessage
                return
            }

            appMonitorUpdateItem = item
            appMonitorUpdateRecord = appMonitorUpdateRecord(from: item, currentApp: currentApp, appcastURL: appcastURL, checkedAt: checkedAt)
            appMonitorUpdateMessage = "App Monitor \(item.version ?? "update") is available."
            lastMessage = appMonitorUpdateMessage

            if installIfAvailable {
                await installAppMonitorUpdate()
            }
        } catch {
            appMonitorUpdateRecord = nil
            appMonitorUpdateItem = nil
            appMonitorUpdateMessage = "App Monitor update check failed: \(error.localizedDescription)"
            lastMessage = appMonitorUpdateMessage
        }
    }

    func setUpdateSelected(_ record: AppUpdateRecord, selected: Bool) {
        if selected {
            selectedUpdateIDs.insert(record.id)
        } else {
            selectedUpdateIDs.remove(record.id)
        }
    }

    func selectAllAvailableUpdates() {
        selectedUpdateIDs = Set(updateRecords.filter { $0.canInstall && $0.status.countsAsAvailable }.map(\.id))
    }

    func clearSelectedUpdates() {
        selectedUpdateIDs = []
    }

    func updateSelectedRecords() async {
        await performUpdates(selectedUpdateRecords.filter { $0.canInstall }, mode: .manual)
    }

    func updateAllEligibleRecords() async {
        await performUpdates(updateRecords.filter(isUpdateAutoEligible), mode: .automatic)
    }

    func openUpdateSource(_ record: AppUpdateRecord) {
        if let urlString = record.installActionURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            return
        }
        if let appPath = record.appPath {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
        }
    }

    func openChangeLogReleaseNotes(_ entry: AppChangeLogEntry) {
        guard let urlString = entry.releaseNotesURL, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func openGitHubRepository() {
        guard let url = URL(string: "https://github.com/jcranokc/app-monitor") else { return }
        NSWorkspace.shared.open(url)
    }

    func installAppMonitorUpdate() async {
        guard !isInstallingAppMonitorUpdate else { return }
        guard let item = appMonitorUpdateItem, item.url != nil else {
            appMonitorUpdateMessage = "Check App Monitor first to load an update package."
            lastMessage = appMonitorUpdateMessage
            return
        }

        isInstallingAppMonitorUpdate = true
        appMonitorUpdateMessage = "Preparing App Monitor update..."
        lastMessage = appMonitorUpdateMessage

        do {
            let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
            let plan = try await Task.detached(priority: .userInitiated) {
                try await Self.prepareAppMonitorUpdateInstall(item: item, currentBundleURL: currentBundleURL)
            }.value
            try launchAppMonitorUpdateInstaller(plan: plan)
            appMonitorUpdateMessage = "Installing App Monitor update. App Monitor will relaunch."
            lastMessage = appMonitorUpdateMessage
            NSApp.terminate(nil)
        } catch {
            appMonitorUpdateMessage = "App Monitor update install failed: \(error.localizedDescription)"
            lastMessage = appMonitorUpdateMessage
            isInstallingAppMonitorUpdate = false
        }
    }

    func isUpdateAutoEligible(_ record: AppUpdateRecord) -> Bool {
        AppUpdateEligibility.isAutoEligible(
            record: record,
            isAppRunning: isAppRunning(for: record),
            settings: updateSettings
        )
    }

    func updateUpdateSchedule(enabled: Bool? = nil, cadenceHours: Int? = nil) {
        if let enabled {
            updateSettings.scheduledChecksEnabled = enabled
            updateSettings.nextCheckAt = enabled ? updateSettings.nextCheckDate() : nil
        }
        if let cadenceHours {
            updateSettings.cadenceHours = cadenceHours
            if updateSettings.scheduledChecksEnabled {
                updateSettings.nextCheckAt = updateSettings.nextCheckDate()
            }
        }
        persistUpdateSettings()
        startUpdateScheduler()
    }

    func updateAppMonitorUpdateSchedule(enabled: Bool? = nil, cadenceHours: Int? = nil) {
        if let enabled {
            appMonitorUpdateChecksEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: Self.appMonitorUpdateChecksEnabledKey)
            appMonitorUpdateNextCheckAt = enabled ? nextAppMonitorUpdateCheckDate() : nil
            persistAppMonitorUpdateNextCheckAt()
        }
        if let cadenceHours {
            appMonitorUpdateCadenceHours = cadenceHours
            UserDefaults.standard.set(cadenceHours, forKey: Self.appMonitorUpdateCadenceHoursKey)
            if appMonitorUpdateChecksEnabled {
                appMonitorUpdateNextCheckAt = nextAppMonitorUpdateCheckDate()
                persistAppMonitorUpdateNextCheckAt()
            }
        }
        startAppMonitorUpdateScheduler()
    }

    func updateAppMonitorAutomaticUpdates(enabled: Bool) {
        appMonitorAutomaticUpdatesEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.appMonitorAutomaticUpdatesEnabledKey)
        if enabled, !appMonitorUpdateChecksEnabled {
            updateAppMonitorUpdateSchedule(enabled: true)
        }
    }

    func updateAutomaticUpdates(enabled: Bool) {
        updateSettings.automaticUpdatesEnabled = enabled
        updateRecords = updateRecords.map(recordWithCurrentAutoEligibility)
        persistUpdateSettings()
    }

    func updateUpdateSourceSettings(
        includeHomebrewFormulae: Bool? = nil,
        includeAppleSoftwareUpdates: Bool? = nil,
        includeDirectDownloadDetection: Bool? = nil
    ) {
        if let includeHomebrewFormulae {
            updateSettings.includeHomebrewFormulae = includeHomebrewFormulae
        }
        if let includeAppleSoftwareUpdates {
            updateSettings.includeAppleSoftwareUpdates = includeAppleSoftwareUpdates
        }
        if let includeDirectDownloadDetection {
            updateSettings.includeDirectDownloadDetection = includeDirectDownloadDetection
        }
        persistUpdateSettings()
    }

    private func performUpdates(_ records: [AppUpdateRecord], mode: UpdateRunMode) async {
        let records = records.filter { $0.canInstall }
        guard !records.isEmpty else {
            lastMessage = "No eligible updates selected"
            return
        }
        guard !isRunningUpdates, !isCheckingUpdates else { return }

        var runnableRecords: [AppUpdateRecord] = []
        for record in records {
            if mode == .automatic, !isUpdateAutoEligible(record) {
                continue
            }
            if mode == .manual, let app = app(for: record), isAppRunning(for: record) {
                guard await promptIfAppIsRunningForUpdate(app) else { continue }
            }
            runnableRecords.append(record)
        }

        guard !runnableRecords.isEmpty else {
            lastMessage = "No updates were runnable"
            return
        }

        isRunningUpdates = true
        let runID = UUID().uuidString
        let startedAt = Date()
        var results: [UpdateItemResult] = []
        updateProgress = OperationProgressSnapshot(
            title: mode == .automatic ? "Running automatic updates" : "Running updates",
            detail: "Starting updates...",
            completedUnitCount: 0,
            totalUnitCount: runnableRecords.count,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: 0
        )

        for (index, record) in runnableRecords.enumerated() {
            updateProgress = OperationProgressSnapshot(
                title: mode == .automatic ? "Running automatic updates" : "Running updates",
                detail: "Updating \(record.appName)",
                completedUnitCount: index,
                totalUnitCount: runnableRecords.count,
                currentPath: record.appPath,
                scannedFileCount: 0,
                scannedBytes: 0
            )
            let provider = updateProvider(for: record.source)
            let result = await provider.performUpdate(record: record, mode: mode, runID: runID)
            results.append(result)
            applyUpdateResult(result)
        }

        let updatedCount = results.filter { $0.status == .updated || $0.status == .needsRestart }.count
        let failedCount = results.filter { $0.status == .failed }.count
        let skippedCount = results.count - updatedCount - failedCount
        let status: UpdateRunStatus
        if updatedCount == 0, failedCount > 0 {
            status = .failed
        } else if failedCount > 0 || skippedCount > 0 {
            status = .partial
        } else if updatedCount == 0 {
            status = .skipped
        } else {
            status = .completed
        }

        let run = UpdateRunRecord(
            id: runID,
            mode: mode,
            status: status,
            startedAt: startedAt,
            selectedItemCount: runnableRecords.count,
            updatedItemCount: updatedCount,
            failedItemCount: failedCount,
            skippedItemCount: skippedCount,
            message: failedCount > 0 ? "Review failed update results." : nil
        )

        do {
            updateRecords = updateRecords.map(recordWithCurrentAutoEligibility).sorted(by: updateRecordComparator)
            let resultChangeLogs = changeLogEntries(from: runnableRecords, runID: runID, results: results)
            try dataStore.replaceAppUpdates(updateRecords)
            try dataStore.recordUpdateRun(run, itemResults: results)
            try dataStore.upsertChangeLogEntries(resultChangeLogs)
            try dataStore.recordAction(
                title: mode == .automatic ? "Automatic Updates \(status.rawValue.capitalized)" : "Updates \(status.rawValue.capitalized)",
                detail: "\(updatedCount) updated, \(failedCount) failed, \(skippedCount) skipped"
            )
            updateRuns = try dataStore.fetchUpdateRuns()
            updateItemResults = try dataStore.fetchUpdateItemResults()
            changeLogEntries = try dataStore.fetchChangeLogEntries()
            actionHistory = try dataStore.fetchActionHistory()
            selectedUpdateIDs.subtract(Set(results.map(\.updateID)))
            lastMessage = "\(updatedCount) update\(updatedCount == 1 ? "" : "s") completed, \(failedCount) failed"
        } catch {
            lastMessage = "Saving update results failed: \(error.localizedDescription)"
        }

        updateProgress = OperationProgressSnapshot(
            title: "Updates complete",
            detail: "\(updatedCount) updated, \(failedCount) failed, \(skippedCount) skipped",
            completedUnitCount: runnableRecords.count,
            totalUnitCount: runnableRecords.count,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: 0
        )
        isRunningUpdates = false
    }

    func reloadRows() {
        do {
            rows = try dataStore.fetchRows(period: period, includeAll: includeAllBundles)
            reloadDailyUsageRows()
            refreshNavigationSnapshots(reloadUsageAnalytics: true, reloadTimeline: true)
            loadSelectedStorageItems()
        } catch {
            lastMessage = "Unable to load rows: \(error.localizedDescription)"
        }
    }

    func reloadUsageAnalytics() {
        do {
            usageAnalytics = try dataStore.usageAnalytics(
                period: period,
                includeAll: includeAllBundles,
                grouping: usageTrendGrouping,
                includedAppIDs: usageAnalyticsIncludedAppIDs,
                excludedAppIDs: includeIgnoredApps ? [] : ignoredAppIDs
            )
        } catch {
            usageAnalytics = UsageAnalyticsSnapshot.empty(
                period: period,
                grouping: usageTrendGrouping
            )
            lastMessage = "Unable to load usage analytics: \(error.localizedDescription)"
        }
    }

    private func reloadDailyUsageRows() {
        do {
            dailyUsageRows = try dataStore.dailyUsageRows(period: period, includeAll: includeAllBundles)
            refreshSelectedDailyRows()
        } catch {
            dailyUsageRows = []
            selectedDailyUsageRows = []
        }
    }

    private func reloadTimelineSnapshots() {
        let includedAppIDs = timelineIncludedAppIDs
        guard !includedAppIDs.isEmpty else {
            timelineSessions = []
            timelineSummary = Self.emptyTimelineSummary()
            timelineDayGroups = []
            timelineHourBuckets = []
            return
        }

        do {
            let sessions = try dataStore.timelineSessions(
                period: period,
                includeAll: includeAllBundles,
                allowedAppIDs: includedAppIDs
            )
            timelineSessions = sessions
            timelineSummary = try dataStore.timelineSummary(
                period: period,
                includeAll: includeAllBundles,
                allowedAppIDs: includedAppIDs
            )
            timelineDayGroups = TimelineDataBuilder.dayGroups(from: sessions, calendar: .current)
            timelineHourBuckets = TimelineDataBuilder.hourBuckets(from: sessions, calendar: .current)
        } catch {
            timelineSessions = []
            timelineSummary = Self.emptyTimelineSummary()
            timelineDayGroups = []
            timelineHourBuckets = []
            lastMessage = "Unable to load timeline data: \(error.localizedDescription)"
        }
    }

    private func refreshNavigationSnapshots(reloadUsageAnalytics shouldReloadUsageAnalytics: Bool, reloadTimeline shouldReloadTimeline: Bool) {
        displayedRows = makeDisplayedRows()
        appListRowCounts = Dictionary(
            uniqueKeysWithValues: AppListQuickFilter.allCases.map { filter in
                (filter, rows.filter { passesAppListQuickFilter($0, filter: filter) }.count)
            }
        )
        ensureSelectionMatchesDisplayedRows()
        refreshSelectedDailyRows()
        warningItems = buildWarningItems()

        if shouldReloadUsageAnalytics {
            reloadUsageAnalytics()
        }
        if shouldReloadTimeline {
            reloadTimelineSnapshots()
        }
    }

    private func refreshSelectedDailyRows() {
        guard let selectedAppID else {
            selectedDailyUsageRows = []
            return
        }
        selectedDailyUsageRows = dailyUsageRows.filter { $0.appID == selectedAppID }
    }

    func select(_ row: AppUsageRow) {
        selectedTimelineSession = nil
        selectedAppID = row.app.id
        refreshSelectedDailyRows()
        loadSelectedStorageItems()
    }

    func selectWarning(_ warning: AppWarningItem) {
        selectedTimelineSession = nil
        selectedWarningID = warning.id
        selectedAppID = warning.appID
        refreshSelectedDailyRows()
        loadSelectedStorageItems()
        lastMessage = "Selected warning: \(warning.title)"
    }

    func selectedWarning(for row: AppUsageRow?) -> AppWarningItem? {
        let warnings = warningItems
        if let selectedWarningID,
           let selected = warnings.first(where: { $0.id == selectedWarningID }) {
            return selected
        }
        if let row,
           let rowWarning = warnings.first(where: { $0.appID == row.app.id }) {
            return rowWarning
        }
        return warnings.first
    }

    func selectApp(id appID: String) {
        guard let row = rows.first(where: { $0.app.id == appID }) else { return }
        select(row)
    }

    func selectTimelineApp(appID: String) {
        selectedTimelineSession = nil
        selectedAppID = appID
        refreshSelectedDailyRows()
        loadSelectedStorageItems()
    }

    func selectTimelineSession(_ session: TimelineSession) {
        selectedTimelineSession = session
        selectedAppID = session.appID
        refreshSelectedDailyRows()
        loadSelectedStorageItems()
    }

    func setSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = key == .app || key == .location || key == .scanStatus
        }
    }

    func dailyUsageRowsForSelectedApp() -> [DailyUsageRow] {
        selectedDailyUsageRows
    }

    func dailyUsageRowsForCurrentPeriod() -> [DailyUsageRow] {
        dailyUsageRows
    }

    func usageSegmentsForCurrentPeriod() -> [UsageSegment] {
        do {
            return try dataStore.usageSegments(period: period, includeAll: includeAllBundles)
        } catch {
            return []
        }
    }

    func timelineSessionsForCurrentFilters() -> [TimelineSession] {
        timelineSessions
    }

    func timelineDayGroupsForCurrentFilters() -> [TimelineDayGroup] {
        timelineDayGroups
    }

    func timelineSummaryForCurrentFilters() -> TimelineSummary {
        timelineSummary
    }

    func timelineHourBucketsForCurrentFilters() -> [TimelineHourBucket] {
        timelineHourBuckets
    }

    func totalUsageSeconds(for period: ReportingPeriod) -> TimeInterval {
        do {
            return try dataStore.fetchRows(period: period, includeAll: includeAllBundles)
                .reduce(0) { $0 + $1.usageSeconds }
        } catch {
            return 0
        }
    }

    func revealSelectedInFinder() {
        guard let row = selectedRow else { return }
        revealInFinder(path: row.app.path)
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func preview(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func exportCurrentRows() {
        let csv = CSVExporter.appRowsCSV(rows: displayedRows)
        save(csv: csv, suggestedName: "App Monitor \(period.rawValue) Apps.csv")
    }

    func exportDailyUsage() {
        do {
            let csv = CSVExporter.dailyUsageCSV(rows: try dataStore.dailyUsageRows(period: period, includeAll: includeAllBundles))
            save(csv: csv, suggestedName: "App Monitor \(period.rawValue) Daily Usage.csv")
        } catch {
            lastMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func exportUsageSummary() {
        save(
            csv: CSVExporter.usageSummaryCSV(snapshot: usageAnalytics),
            suggestedName: "App Monitor \(period.rawValue) Usage Summary.csv"
        )
    }

    func exportUsageTrendBuckets() {
        save(
            csv: CSVExporter.trendBucketsCSV(buckets: usageAnalytics.trendBuckets),
            suggestedName: "App Monitor \(period.rawValue) Trend Buckets.csv"
        )
    }

    func exportTopApps() {
        save(
            csv: CSVExporter.topAppsCSV(topApps: usageAnalytics.topApps),
            suggestedName: "App Monitor \(period.rawValue) Top Apps.csv"
        )
    }

    func exportUsageHeatmap() {
        save(
            csv: CSVExporter.heatmapCSV(cells: usageAnalytics.heatmapCells),
            suggestedName: "App Monitor \(period.rawValue) Heatmap.csv"
        )
    }

    func exportTimelineSessions() {
        save(
            csv: CSVExporter.timelineSessionsCSV(rows: timelineSessions),
            suggestedName: "App Monitor \(period.rawValue) Timeline Sessions.csv"
        )
    }

    func copyToClipboard(_ value: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        lastMessage = "Copied \(label)"
    }

    func usageInsights() -> [String] {
        let snapshot = usageAnalytics
        let summary = snapshot.summary
        guard summary.totalSeconds > 0 else {
            return ["Usage insights will appear after App Monitor records more activity."]
        }

        var insights: [String] = []
        if let peakDay = summary.peakDay {
            insights.append("You used your Mac more on \(AppMonitorFormatting.day(peakDay)) than any other day this period.")
        }
        if let percent = summary.comparison.totalPercentChange {
            let direction = percent >= 0 ? "up" : "down"
            insights.append("Usage was \(direction) \(Self.percentFormatter.string(from: NSNumber(value: abs(percent))) ?? "0%") compared to the previous period.")
        }
        if let topApp = summary.mostUsedApp {
            insights.append("\(topApp.appName) accounted for \(Self.percentFormatter.string(from: NSNumber(value: topApp.percentOfTotal)) ?? "0%") of usage.")
        }
        if let busiest = snapshot.heatmapCells.max(by: { $0.seconds < $1.seconds }), busiest.seconds > 0 {
            insights.append("Your busiest time block was \(busiest.rowLabel) at \(Self.hourLabel(for: busiest.hourOfDay)).")
        }

        return Array(insights.prefix(4))
    }

    func focusSearch() {
        searchFocusToken = UUID()
    }

    func openWarningHelp(_ warning: AppWarningItem?) {
        let category = warning?.category ?? .configuration
        let urlString: String
        switch category {
        case .security:
            urlString = "https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac"
        case .performance:
            urlString = "https://support.apple.com/guide/activity-monitor/welcome/mac"
        case .storage:
            urlString = "https://support.apple.com/guide/mac-help/free-up-storage-space-mchl3f6a0fde/mac"
        case .compatibility:
            urlString = "https://support.apple.com/guide/mac-help/if-an-app-freezes-or-quits-unexpectedly-mchlp2579/mac"
        case .updates:
            urlString = "https://support.apple.com/guide/mac-help/get-macos-updates-mchlpx1065/mac"
        case .configuration:
            urlString = "https://support.apple.com/guide/mac-help/change-system-settings-mchlp1237/mac"
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func navigate(_ destination: DashboardDestination) {
        self.destination = destination
    }

    func showUpdates() {
        destination = .updates
        lastMessage = availableUpdateCount == 0 ? "No installed app updates loaded" : "Showing \(availableUpdateCount) installed app updates"
    }

    func showAppList(_ filter: AppListQuickFilter) {
        destination = .usageTable
        appListQuickFilter = filter
        selectedTimelineSession = nil
        ensureSelectionMatchesDisplayedRows()
        loadSelectedStorageItems()
        lastMessage = filter == .all ? "Showing all apps" : "Showing \(filter.rawValue)"
    }

    func showAllUsage() {
        sortKey = .usage
        sortAscending = false
        showAppList(.all)
    }

    func showStorageExplorer() {
        destination = .storage
    }

    func saveCurrentFilter() {
        let next = SavedAppFilter(name: "Filter \(savedFilters.count + 1)", state: filterState)
        savedFilters.append(next)
        persistSavedFilters()
        lastMessage = "Saved \(next.name)"
    }

    func applySavedFilter(_ filter: SavedAppFilter) {
        filterState = filter.state
        lastMessage = "Applied \(filter.name)"
    }

    func clearFilters() {
        filterState = AppFilterState()
    }

    func rowCount(for filter: AppListQuickFilter) -> Int {
        appListRowCounts[filter] ?? rows.filter { passesAppListQuickFilter($0, filter: filter) }.count
    }

    func approveCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        updateCleanupSuggestion(suggestion, state: .approved)
    }

    func setCleanupSuggestionQueued(_ suggestion: CleanupSuggestion, queued: Bool) {
        updateCleanupSuggestion(suggestion, state: queued ? .approved : .pending)
    }

    func toggleCleanupSuggestionQueued(_ suggestion: CleanupSuggestion) {
        setCleanupSuggestionQueued(suggestion, queued: suggestion.state != .approved)
    }

    func approveCleanupSuggestions(_ suggestions: [CleanupSuggestion]) {
        updateCleanupSuggestions(suggestions, state: .approved, actionTitle: "Cleanup Queued")
    }

    func clearApprovedCleanupSuggestions() {
        let approved = cleanupSuggestions.filter { $0.state == .approved }
        updateCleanupSuggestions(approved, state: .pending, actionTitle: "Cleanup Queue Cleared")
    }

    func rejectCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        updateCleanupSuggestion(suggestion, state: .rejected)
    }

    @discardableResult
    func quarantineCleanupSuggestion(_ suggestion: CleanupSuggestion) -> Bool {
        do {
            let destination = try quarantinePath(for: suggestion)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: URL(fileURLWithPath: suggestion.path), to: destination)
            try dataStore.updateCleanupSuggestion(id: suggestion.id, state: .quarantined, quarantinePath: destination.path)
            try dataStore.recordAction(title: "Quarantined Cleanup Candidate", detail: suggestion.path)
            loadInfrastructureState()
            lastMessage = "Moved \(URL(fileURLWithPath: suggestion.path).lastPathComponent) to quarantine"
            return true
        } catch {
            try? dataStore.updateCleanupSuggestion(id: suggestion.id, state: .failed, quarantinePath: suggestion.quarantinePath)
            loadInfrastructureState()
            lastMessage = "Quarantine failed: \(error.localizedDescription)"
            return false
        }
    }

    func restoreCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        guard let quarantinePath = suggestion.quarantinePath else {
            lastMessage = "No quarantine path recorded"
            return
        }

        do {
            let originalURL = URL(fileURLWithPath: suggestion.path)
            try FileManager.default.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: originalURL.path) {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.moveItem(at: URL(fileURLWithPath: quarantinePath), to: originalURL)
            try dataStore.updateCleanupSuggestion(id: suggestion.id, state: .restored, quarantinePath: nil)
            try dataStore.recordAction(title: "Restored Cleanup Candidate", detail: suggestion.path)
            loadInfrastructureState()
            lastMessage = "Restored \(originalURL.lastPathComponent)"
        } catch {
            lastMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func selectHistoryAction(id: String) {
        selectedHistoryActionID = id
    }

    func historyActionButtonTitle(title: String, detail: String) -> String {
        if restorableCleanupSuggestion(detail: detail) != nil {
            return "Restore"
        }
        if canRevertHistoryAction(title: title, detail: detail) {
            return "Revert Change"
        }
        return "Log Revert Request"
    }

    func historyActionCanApplyDirectly(title: String, detail: String) -> Bool {
        restorableCleanupSuggestion(detail: detail) != nil || canRevertHistoryAction(title: title, detail: detail)
    }

    func performHistoryRestoreOrRevert(title: String, detail: String) {
        if let suggestion = restorableCleanupSuggestion(detail: detail) {
            restoreCleanupSuggestion(suggestion)
            return
        }

        if revertHistoryAction(title: title, detail: detail) {
            return
        }

        logHistoryRevertRequest(title: title, detail: detail)
    }

    func logHistoryRevertRequest(title: String, detail: String) {
        do {
            try dataStore.recordAction(title: "Revert Requested", detail: "\(title): \(detail)")
            actionHistory = try dataStore.fetchActionHistory()
            lastMessage = "Logged revert request for \(title)"
        } catch {
            lastMessage = "Revert request failed: \(error.localizedDescription)"
        }
    }

    func runApprovedCleanup() async {
        guard !isRunningCleanup else { return }
        let approved = cleanupSuggestions.filter { $0.state == .approved }
        guard !approved.isEmpty else {
            lastMessage = "No approved cleanup candidates"
            return
        }

        isRunningCleanup = true
        cleanupProgress = OperationProgressSnapshot(
            title: "Running cleanup",
            detail: "Preparing approved cleanup...",
            completedUnitCount: 0,
            totalUnitCount: approved.count,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: 0
        )
        defer {
            cleanupProgress = .idle
            isRunningCleanup = false
        }

        var completedCount = 0
        var movedCount = 0
        var failedCount = 0
        var movedBytes: Int64 = 0

        for suggestion in approved {
            cleanupProgress = OperationProgressSnapshot(
                title: "Running cleanup",
                detail: "Moving \(URL(fileURLWithPath: suggestion.path).lastPathComponent) to quarantine",
                completedUnitCount: completedCount,
                totalUnitCount: approved.count,
                currentPath: suggestion.path,
                scannedFileCount: 0,
                scannedBytes: movedBytes
            )
            await Task.yield()

            if quarantineCleanupSuggestion(suggestion) {
                movedCount += 1
                movedBytes += suggestion.sizeBytes
            } else {
                failedCount += 1
            }

            completedCount += 1
            cleanupProgress = OperationProgressSnapshot(
                title: "Running cleanup",
                detail: "Processed \(completedCount) of \(approved.count) approved cleanup candidates",
                completedUnitCount: completedCount,
                totalUnitCount: approved.count,
                currentPath: suggestion.path,
                scannedFileCount: 0,
                scannedBytes: movedBytes
            )
            await Task.yield()
        }

        if failedCount > 0 {
            lastMessage = "Cleanup finished: \(movedCount) moved, \(failedCount) failed"
        } else {
            lastMessage = "Cleanup complete: moved \(movedCount) item\(movedCount == 1 ? "" : "s") to quarantine"
        }
    }

    func quarantineStorageItem(_ item: StorageScanItem) {
        let suggestion = CleanupSuggestion(
            id: "\(item.appID)|manual|\(item.path)",
            appID: item.appID,
            title: "Manual related-file quarantine",
            path: item.path,
            category: item.category,
            sizeBytes: item.sizeBytes,
            severity: item.sizeBytes >= 250_000_000 ? .medium : .low,
            rationale: "Manually selected from the related files list.",
            riskNotes: "Manual review item. Restore is available while it remains in quarantine.",
            state: .approved
        )
        try? dataStore.replaceCleanupSuggestions(for: item.appID, suggestions: [suggestion])
        quarantineCleanupSuggestion(suggestion)
    }

    func moveStorageItemToTrash(_ item: StorageScanItem) {
        guard confirmDestructiveAction(title: "Move File to Trash?", message: item.path) else { return }
        movePathToTrash(item.path, actionTitle: "Moved Related File to Trash")
    }

    func quarantineLargeFile(_ record: LargeFileRecord) {
        let item = StorageScanItem(
            id: record.id,
            appID: record.appID,
            category: record.category,
            path: record.path,
            sizeBytes: record.sizeBytes
        )
        quarantineStorageItem(item)
        updateLargeFile(record, state: .quarantined)
    }

    func ignoreLargeFile(_ record: LargeFileRecord) {
        updateLargeFile(record, state: .ignored)
    }

    func prepareSelectedAppUninstall() async {
        guard let row = selectedRow else { return }
        guard await promptIfAppIsRunning(row.app) else { return }

        isPreparingUninstall = true
        uninstallResults = []
        uninstallProgress = OperationProgressSnapshot(
            title: "Preparing uninstall",
            detail: "Scanning \(row.app.name) related paths...",
            completedUnitCount: 0,
            totalUnitCount: 1,
            currentPath: row.app.path,
            scannedFileCount: 0,
            scannedBytes: 0
        )
        lastMessage = "Preparing uninstall for \(row.app.name)..."

        do {
            let scanner = storageScanner
            let app = row.app
            let scanResult = await Task.detached(priority: .utility) {
                let items = scanner.scanStorage(for: app)
                let largeFiles = scanner.largeFiles(in: items)
                return (items: items, largeFiles: largeFiles)
            }.value
            try dataStore.replaceStorageItems(for: app.id, items: scanResult.items)
            try regenerateCleanupSuggestions(for: [app])
            try dataStore.replaceLargeFiles(scanResult.largeFiles)

            let plan = uninstallPlanner.plan(for: app, storageItems: scanResult.items)
            uninstallPlan = plan
            selectedUninstallItemIDs = plan.recommendedItemIDs
            reloadRows()
            loadInfrastructureState()
            loadSelectedStorageItems()
            lastMessage = plan.isProtected
                ? "Uninstall blocked: \(plan.protectionReason ?? "protected app")"
                : "Review uninstall plan for \(app.name)"
        } catch {
            lastMessage = "Unable to prepare uninstall: \(error.localizedDescription)"
        }

        uninstallProgress = .idle
        isPreparingUninstall = false
    }

    func closeUninstallPlan() {
        guard !isRunningUninstall else { return }
        uninstallPlan = nil
        selectedUninstallItemIDs = []
        uninstallResults = []
        uninstallProgress = .idle
    }

    func selectRecommendedUninstallItems() {
        selectedUninstallItemIDs = uninstallPlan?.recommendedItemIDs ?? []
    }

    func selectAllReviewableUninstallItems() {
        guard let uninstallPlan else { return }
        selectedUninstallItemIDs = Set(uninstallPlan.items.filter(canSelectUninstallItem).map(\.id))
    }

    func setUninstallItem(_ item: UninstallPlanItem, selected: Bool) {
        guard canSelectUninstallItem(item) else { return }
        if selected {
            selectedUninstallItemIDs.insert(item.id)
        } else {
            selectedUninstallItemIDs.remove(item.id)
        }
    }

    func canSelectUninstallItem(_ item: UninstallPlanItem) -> Bool {
        item.risk != .protected && item.coveredByParentID == nil
    }

    func uninstallResult(for itemID: String) -> UninstallItemResult? {
        uninstallResults.first { $0.itemID == itemID }
    }

    func executeSelectedAppUninstall() async {
        guard let plan = uninstallPlan, !isRunningUninstall else { return }
        guard !plan.isProtected else {
            lastMessage = "Uninstall blocked: \(plan.protectionReason ?? "protected app")"
            return
        }
        guard selectedUninstallItemIDs.contains(where: { id in
            plan.items.contains { $0.id == id && $0.role == .appBundle }
        }) else {
            lastMessage = "Select the app bundle before uninstalling"
            return
        }
        guard await promptIfAppIsRunning(plan.app) else { return }
        let selectedItems = plan.items.filter { selectedUninstallItemIDs.contains($0.id) && canSelectUninstallItem($0) }
        guard !selectedItems.isEmpty else {
            lastMessage = "No uninstall items selected"
            return
        }
        let confirmationMessage = """
        Move \(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") for \(plan.app.name) to Trash?

        Selected size: \(ByteCountFormatter.string(fromByteCount: selectedItems.reduce(0) { $0 + $1.sizeBytes }, countStyle: .file))
        """
        guard confirmDestructiveAction(title: "Uninstall & Clean Up?", message: confirmationMessage) else { return }

        isRunningUninstall = true
        uninstallResults = []
        let totalUnits = plan.items.count
        let summary = uninstallExecutor.execute(
            plan: plan,
            selectedItemIDs: selectedUninstallItemIDs
        ) { [weak self] completed, total, item, results in
            guard let self else { return }
            self.uninstallProgress = OperationProgressSnapshot(
                title: "Uninstalling",
                detail: "Processed \(URL(fileURLWithPath: item.path).lastPathComponent)",
                completedUnitCount: completed,
                totalUnitCount: total,
                currentPath: item.path,
                scannedFileCount: 0,
                scannedBytes: results.reduce(0) { $0 + ($1.status == .trashed ? $1.sizeBytes : 0) }
            )
            self.uninstallResults = results
        }
        let run = summary.run
        let results = summary.itemResults
        let failedCount = run.failedItemCount
        let trashedCount = run.trashedItemCount
        let didTrashBundle = results.contains { $0.role == .appBundle && $0.status == .trashed }

        do {
            try dataStore.recordUninstallRun(run, itemResults: results)
            try dataStore.recordAction(title: "Uninstall \(run.status.rawValue.capitalized)", detail: "\(plan.app.name): \(trashedCount) trashed, \(failedCount) failed")
            if didTrashBundle {
                var tags = tagsByAppID[plan.app.id] ?? []
                for tag in ["Archived", "Uninstalled"] where !tags.contains(tag) {
                    tags.append(tag)
                }
                try dataStore.setTags(tags, for: plan.app.id)
                try dataStore.setIgnored(true, appID: plan.app.id)
            }
            reloadRows()
            loadInfrastructureState()
            lastMessage = failedCount > 0
                ? "Uninstall finished with \(failedCount) failure\(failedCount == 1 ? "" : "s")"
                : "Uninstalled \(plan.app.name): moved \(trashedCount) item\(trashedCount == 1 ? "" : "s") to Trash"
        } catch {
            lastMessage = "Uninstall history save failed: \(error.localizedDescription)"
        }

        uninstallProgress = OperationProgressSnapshot(
            title: "Uninstall complete",
            detail: "\(trashedCount) trashed, \(failedCount) failed",
            completedUnitCount: totalUnits,
            totalUnitCount: totalUnits,
            currentPath: nil,
            scannedFileCount: 0,
            scannedBytes: results.reduce(0) { $0 + ($1.status == .trashed ? $1.sizeBytes : 0) }
        )
        isRunningUninstall = false
    }

    func archiveSelectedAppRecord() {
        guard let row = selectedRow else { return }
        do {
            var tags = tagsByAppID[row.app.id] ?? []
            if !tags.contains("Archived") {
                tags.append("Archived")
            }
            try dataStore.setTags(tags, for: row.app.id)
            try dataStore.setIgnored(true, appID: row.app.id)
            try dataStore.recordAction(title: "Archived App Record", detail: row.app.name)
            loadInfrastructureState()
            lastMessage = "Archived \(row.app.name)"
        } catch {
            lastMessage = "Archive failed: \(error.localizedDescription)"
        }
    }

    func tagSelectedApp(_ tag: String) {
        guard let row = selectedRow else { return }
        do {
            var tags = tagsByAppID[row.app.id] ?? []
            if !tags.contains(tag) {
                tags.append(tag)
            }
            try dataStore.setTags(tags, for: row.app.id)
            try dataStore.recordAction(title: "Tagged App", detail: "\(row.app.name): \(tag)")
            loadInfrastructureState()
            lastMessage = "Tagged \(row.app.name)"
        } catch {
            lastMessage = "Tag failed: \(error.localizedDescription)"
        }
    }

    func setSelectedAppIgnored(_ ignored: Bool) {
        guard let row = selectedRow else { return }
        do {
            try dataStore.setIgnored(ignored, appID: row.app.id)
            try dataStore.recordAction(title: ignored ? "Ignored App" : "Unignored App", detail: row.app.name)
            loadInfrastructureState()
            reloadRows()
            lastMessage = ignored ? "Ignored \(row.app.name)" : "Restored \(row.app.name)"
        } catch {
            lastMessage = "Ignore update failed: \(error.localizedDescription)"
        }
    }

    func appName(for appID: String) -> String {
        rows.first { $0.app.id == appID }?.app.name ?? "Unknown App"
    }

    func appRow(for appID: String) -> AppUsageRow? {
        rows.first { $0.app.id == appID }
    }

    func focusCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        focusedCleanupSuggestionID = suggestion.id
        selectedAppID = suggestion.appID
        selectedTimelineSession = nil
        refreshSelectedDailyRows()
        loadSelectedStorageItems()
    }

    func cleanupPreviewItems(for suggestion: CleanupSuggestion, limit: Int = 4) -> [CleanupPreviewItem] {
        let url = URL(fileURLWithPath: suggestion.path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: suggestion.path, isDirectory: &isDirectory) else {
            return [
                CleanupPreviewItem(
                    id: suggestion.path,
                    name: url.lastPathComponent.isEmpty ? suggestion.path : url.lastPathComponent,
                    path: suggestion.path,
                    sizeBytes: nil,
                    isDirectory: false
                )
            ]
        }

        guard isDirectory.boolValue,
              let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return [
                CleanupPreviewItem(
                    id: suggestion.path,
                    name: url.lastPathComponent.isEmpty ? suggestion.path : url.lastPathComponent,
                    path: suggestion.path,
                    sizeBytes: suggestion.sizeBytes,
                    isDirectory: false
                )
            ]
        }

        let previewItems = children.prefix(limit).map { child in
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
            let size = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize
            return CleanupPreviewItem(
                id: child.path,
                name: child.lastPathComponent,
                path: child.path,
                sizeBytes: size.map(Int64.init),
                isDirectory: values?.isDirectory == true
            )
        }

        if previewItems.isEmpty {
            return [
                CleanupPreviewItem(
                    id: suggestion.path,
                    name: url.lastPathComponent.isEmpty ? suggestion.path : url.lastPathComponent,
                    path: suggestion.path,
                    sizeBytes: suggestion.sizeBytes,
                    isDirectory: true
                )
            ]
        }

        return Array(previewItems)
    }

    func cleanupPreviewItemCount(for suggestion: CleanupSuggestion) -> Int? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: suggestion.path, isDirectory: &isDirectory) else {
            return nil
        }
        guard isDirectory.boolValue else { return 1 }
        return (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: suggestion.path),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).count) ?? 1
    }

    func rescanSelectedApp() async {
        guard let row = selectedRow else { return }
        do {
            let scanner = storageScanner
            let auditor = healthAuditor
            let items = await Task.detached(priority: .utility) {
                scanner.scanStorage(for: row.app)
            }.value
            try dataStore.replaceStorageItems(for: row.app.id, items: items)
            try regenerateCleanupSuggestions(for: [row.app])
            let large = scanner.largeFiles(in: items)
            try dataStore.replaceLargeFiles(large)
            let findings = await Task.detached(priority: .utility) {
                auditor.audit(app: row.app)
            }.value
            try dataStore.replaceHealthFindings(for: row.app.id, findings: findings)
            reloadRows()
            loadInfrastructureState()
            lastMessage = "Rescanned \(row.app.name)"
        } catch {
            lastMessage = "Rescan failed: \(error.localizedDescription)"
        }
    }

    func ownerText(for path: String) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.ownerAccountName] as? String ?? "Unknown owner"
    }

    func riskText(for item: StorageScanItem) -> String {
        cleanupAnalyzer.storageRisk(for: item).rawValue
    }

    func healthFindings(for appID: String) -> [AppHealthFinding] {
        healthFindingsByAppID[appID] ?? []
    }

    func worstHealthSeverity(for row: AppUsageRow) -> AppHealthSeverity? {
        let severities = healthFindings(for: row.app.id).map(\.severity)
        if severities.contains(.critical) { return .critical }
        if severities.contains(.warning) { return .warning }
        return severities.isEmpty ? nil : .info
    }

    func updateScanSchedule(enabled: Bool? = nil, intervalHours: Int? = nil) {
        if let enabled {
            scanSchedule.isEnabled = enabled
        }
        if let intervalHours {
            scanSchedule.intervalHours = intervalHours
        }
        if scanSchedule.isEnabled, scanSchedule.nextScanAt == nil {
            scanSchedule.nextScanAt = Date().addingTimeInterval(TimeInterval(scanSchedule.intervalHours * 3600))
        }
        if !scanSchedule.isEnabled {
            scanSchedule.nextScanAt = nil
        }
        persistScanSchedule()
        do {
            let state = scanSchedule.isEnabled ? "enabled" : "disabled"
            try dataStore.recordAction(
                title: "Updated Scan Schedule",
                detail: "Recurring scan \(state), every \(scanSchedule.intervalHours)h"
            )
            actionHistory = try dataStore.fetchActionHistory()
        } catch {
            lastMessage = "Schedule history failed: \(error.localizedDescription)"
        }
        startScheduler()
    }

    func refreshLoginItemStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            loginItemEnabled = status == .enabled
            loginItemStatus = String(describing: status)
        } else {
            loginItemEnabled = false
            loginItemStatus = "Unsupported"
        }
    }

    func setLoginItemEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            lastMessage = "Login items require macOS 13 or newer"
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginItemStatus()
            lastMessage = enabled ? "Login item enabled" : "Login item disabled"
        } catch {
            refreshLoginItemStatus()
            lastMessage = "Login item update failed: \(error.localizedDescription)"
        }
    }

    func setKeepRunningWhenClosed(_ enabled: Bool) {
        keepRunningWhenClosed = enabled
        AppLifecycleSettings.keepRunningWhenClosed = enabled
        if enabled {
            lastMessage = "Closing the dashboard will keep App Monitor in the menu bar"
        } else {
            NSApp.setActivationPolicy(.regular)
            lastMessage = "Dashboard close behavior restored"
        }
    }

    func setAppearancePreference(_ preference: AppAppearancePreference) {
        appearancePreference = preference
        lastMessage = "Appearance set to \(preference.settingsTitle)"
    }

    private func updateStorageScanProgress(
        appName: String,
        appIndex: Int,
        appCount: Int,
        progress: StorageScanProgress
    ) {
        storageScanProgress = OperationProgressSnapshot(
            title: "Scanning storage",
            detail: "\(progress.phase) - \(appName)",
            completedUnitCount: appIndex,
            totalUnitCount: appCount,
            currentPath: progress.currentPath,
            scannedFileCount: progress.scannedFileCount,
            scannedBytes: progress.scannedBytes
        )
    }

    private func loadSelectedStorageItems() {
        guard let selectedAppID else {
            selectedStorageItems = []
            return
        }

        selectedStorageItems = allStorageItems
            .filter { $0.appID == selectedAppID }
            .sorted {
                if $0.category.rawValue == $1.category.rawValue {
                    return $0.path < $1.path
                }
                return $0.category.rawValue < $1.category.rawValue
            }
    }

    private var usageAnalyticsIncludedAppIDs: Set<String>? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }

        return Set(rows.filter { row in
            row.app.name.lowercased().contains(query)
                || (row.app.bundleIdentifier?.lowercased().contains(query) ?? false)
                || row.app.path.lowercased().contains(query)
                || (tagsByAppID[row.app.id]?.contains { $0.lowercased().contains(query) } ?? false)
        }.map { $0.app.id })
    }

    private var timelineIncludedAppIDs: Set<String> {
        Set(displayedRows.map(\.app.id))
    }

    private func loadInfrastructureState() {
        do {
            let findings = try dataStore.fetchHealthFindings()
            healthFindingsByAppID = Dictionary(grouping: findings, by: \.appID)
            cleanupSuggestions = try dataStore.fetchCleanupSuggestions()
            reconcileCleanupFocus()
            largeFiles = try dataStore.fetchLargeFiles()
            allStorageItems = try dataStore.fetchAllStorageItems()
            rebuildStorageItemCaches()
            tagsByAppID = try dataStore.fetchTagsByApp()
            ignoredAppIDs = try dataStore.fetchIgnoredAppIDs()
            savedFilters = try dataStore.fetchSavedFilters()
            scanSchedule = try dataStore.fetchScanSchedule()
            updateSettings = try dataStore.fetchUpdateSettings()
            updateRecords = try dataStore.fetchAppUpdates()
            updateRuns = try dataStore.fetchUpdateRuns()
            updateItemResults = try dataStore.fetchUpdateItemResults()
            changeLogEntries = try dataStore.fetchChangeLogEntries()
            selectedUpdateIDs.formIntersection(Set(updateRecords.map(\.id)))
            actionHistory = try dataStore.fetchActionHistory()
            loadSelectedStorageItems()
            refreshNavigationSnapshots(reloadUsageAnalytics: true, reloadTimeline: true)
        } catch {
            lastMessage = "Unable to load infrastructure state: \(error.localizedDescription)"
        }
    }

    private func rebuildStorageItemCaches() {
        storageCategoriesByAppID = allStorageItems.reduce(into: [String: Set<StorageCategory>]()) { partial, item in
            guard item.sizeBytes > 0 else { return }
            partial[item.appID, default: []].insert(item.category)
        }
    }

    private func buildWarningItems() -> [AppWarningItem] {
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.app.id, $0) })
        var items: [AppWarningItem] = []

        for finding in healthFindingsByAppID.values.flatMap({ $0 }) {
            guard finding.severity == .warning || finding.severity == .critical,
                  let row = rowsByID[finding.appID] else { continue }
            items.append(healthWarningItem(for: finding, row: row))
        }

        for storageItem in allStorageItems where storageItem.warning != nil {
            guard let row = rowsByID[storageItem.appID],
                  let warning = storageItem.warning else { continue }
            items.append(storageWarningItem(for: storageItem, warning: warning, row: row))
        }

        for suggestion in cleanupSuggestions where warningStates.contains(suggestion.state) {
            guard let row = rowsByID[suggestion.appID] else { continue }
            items.append(cleanupWarningItem(for: suggestion, row: row))
        }

        for record in largeFiles where record.state == .needsReview {
            guard let row = rowsByID[record.appID] else { continue }
            items.append(largeFileWarningItem(for: record, row: row))
        }

        let appsWithStaleHealthWarning = Set(
            healthFindingsByAppID.values.flatMap { $0 }
                .filter { $0.title.localizedCaseInsensitiveContains("stale") }
                .map(\.appID)
        )

        for row in rows {
            if let unused = unusedAppWarningItem(for: row) {
                items.append(unused)
            }
            if !appsWithStaleHealthWarning.contains(row.app.id),
               let stale = staleAppWarningItem(for: row) {
                items.append(stale)
            }
        }

        var unique: [String: AppWarningItem] = [:]
        for item in items {
            unique[item.id] = item
        }

        return unique.values.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            if lhs.detectedAt != rhs.detectedAt {
                return lhs.detectedAt > rhs.detectedAt
            }
            let appComparison = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
            if appComparison != .orderedSame {
                return appComparison == .orderedAscending
            }
            return lhs.title < rhs.title
        }
    }

    private var warningStates: Set<CleanupSuggestionState> {
        [.pending, .approved, .quarantined, .failed]
    }

    private func healthWarningItem(for finding: AppHealthFinding, row: AppUsageRow) -> AppWarningItem {
        let category = healthCategory(for: finding)
        let severity = healthSeverity(for: finding)
        return AppWarningItem(
            id: "health:\(finding.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: finding.title,
            detail: finding.detail,
            recommendation: healthRecommendation(for: finding, category: category),
            severity: severity,
            category: category,
            source: finding.source,
            statusText: healthStatusText(for: finding),
            detectedAt: finding.checkedAt,
            details: [
                AppWarningDetail(title: "Source", value: finding.source),
                AppWarningDetail(title: "Detected", value: AppMonitorFormatting.shortDateTime(finding.checkedAt)),
                AppWarningDetail(title: "Type", value: finding.title)
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: row.app.name,
                    subtitle: "Main Application",
                    path: row.app.path
                )
            ]
        )
    }

    private func storageWarningItem(for item: StorageScanItem, warning: String, row: AppUsageRow) -> AppWarningItem {
        AppWarningItem(
            id: "storage:\(item.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: "\(item.category.rawValue) Scan Warning",
            detail: warning,
            recommendation: "Review the path before cleanup. If it belongs to this app and is safe to remove, move it to quarantine before deleting it permanently.",
            severity: item.sizeBytes >= 1_000_000_000 ? .high : .medium,
            category: .storage,
            source: "Storage Scan",
            statusText: AppMonitorFormatting.bytes(item.sizeBytes),
            sizeBytes: item.sizeBytes,
            detectedAt: item.scannedAt,
            details: [
                AppWarningDetail(title: "Category", value: item.category.rawValue),
                AppWarningDetail(title: "Size", value: AppMonitorFormatting.bytes(item.sizeBytes)),
                AppWarningDetail(title: "Detected", value: AppMonitorFormatting.shortDateTime(item.scannedAt)),
                AppWarningDetail(title: "Path", value: item.path)
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: URL(fileURLWithPath: item.path).lastPathComponent,
                    subtitle: item.category.rawValue,
                    path: item.path,
                    sizeBytes: item.sizeBytes
                )
            ]
        )
    }

    private func cleanupWarningItem(for suggestion: CleanupSuggestion, row: AppUsageRow) -> AppWarningItem {
        AppWarningItem(
            id: "cleanup:\(suggestion.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: cleanupWarningTitle(for: suggestion),
            detail: suggestion.rationale,
            recommendation: suggestion.riskNotes,
            severity: cleanupWarningSeverity(suggestion.severity),
            category: .storage,
            source: "Cleanup Analyzer",
            statusText: suggestion.state == .pending ? AppMonitorFormatting.bytes(suggestion.sizeBytes) : suggestion.state.rawValue.capitalized,
            sizeBytes: suggestion.sizeBytes,
            detectedAt: suggestion.updatedAt,
            details: [
                AppWarningDetail(title: "Category", value: suggestion.category.rawValue),
                AppWarningDetail(title: "State", value: suggestion.state.rawValue.capitalized),
                AppWarningDetail(title: "Size", value: AppMonitorFormatting.bytes(suggestion.sizeBytes)),
                AppWarningDetail(title: "Detected", value: AppMonitorFormatting.shortDateTime(suggestion.createdAt))
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: URL(fileURLWithPath: suggestion.path).lastPathComponent,
                    subtitle: suggestion.category.rawValue,
                    path: suggestion.path,
                    sizeBytes: suggestion.sizeBytes
                )
            ]
        )
    }

    private func largeFileWarningItem(for record: LargeFileRecord, row: AppUsageRow) -> AppWarningItem {
        AppWarningItem(
            id: "large-file:\(record.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: "Large File Review",
            detail: record.riskReason,
            recommendation: "Preview this file and confirm ownership before moving it to quarantine or Trash.",
            severity: record.sizeBytes >= 1_000_000_000 ? .high : .medium,
            category: .storage,
            source: "Large File Index",
            statusText: AppMonitorFormatting.bytes(record.sizeBytes),
            sizeBytes: record.sizeBytes,
            detectedAt: record.scannedAt,
            details: [
                AppWarningDetail(title: "Category", value: record.category.rawValue),
                AppWarningDetail(title: "Risk Score", value: "\(record.riskScore)"),
                AppWarningDetail(title: "Size", value: AppMonitorFormatting.bytes(record.sizeBytes)),
                AppWarningDetail(title: "Detected", value: AppMonitorFormatting.shortDateTime(record.scannedAt))
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: URL(fileURLWithPath: record.path).lastPathComponent,
                    subtitle: record.category.rawValue,
                    path: record.path,
                    sizeBytes: record.sizeBytes
                )
            ]
        )
    }

    private func unusedAppWarningItem(for row: AppUsageRow) -> AppWarningItem? {
        let lastSeen = row.lastSeen
        let daysUnused: Int
        if let lastSeen {
            daysUnused = Calendar.current.dateComponents([.day], from: lastSeen, to: Date()).day ?? 0
        } else {
            daysUnused = 9_999
        }

        guard daysUnused >= 90 || (lastSeen == nil && row.app.installedAt != nil) else { return nil }
        let title = lastSeen == nil ? "Never Opened" : "Old Login Item"
        let detail = lastSeen == nil
            ? "\(row.app.name) has no recorded local or imported activity."
            : "\(row.app.name) was last used \(daysUnused) days ago."
        return AppWarningItem(
            id: "usage:\(row.app.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: title,
            detail: detail,
            recommendation: "If this app is no longer needed, review its cleanup suggestions or archive the app record.",
            severity: row.totalSizeBytes >= 1_000_000_000 ? .medium : .low,
            category: .performance,
            source: "Usage Analytics",
            statusText: lastSeen == nil ? "Never" : "\(daysUnused)d",
            sizeBytes: row.totalSizeBytes > 0 ? row.totalSizeBytes : nil,
            detectedAt: lastSeen ?? row.app.lastSeen,
            details: [
                AppWarningDetail(title: "Last Opened", value: AppMonitorFormatting.shortDateTime(lastSeen)),
                AppWarningDetail(title: "Usage \(period.rawValue)", value: AppMonitorFormatting.duration(row.usageSeconds)),
                AppWarningDetail(title: "Storage", value: AppMonitorFormatting.bytes(row.totalSizeBytes))
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: row.app.name,
                    subtitle: "Application",
                    path: row.app.path,
                    sizeBytes: row.totalSizeBytes > 0 ? row.totalSizeBytes : nil
                )
            ]
        )
    }

    private func staleAppWarningItem(for row: AppUsageRow) -> AppWarningItem? {
        guard let bundleDate = row.app.bundleCreatedAt ?? row.app.installedAt else { return nil }
        let daysOld = Calendar.current.dateComponents([.day], from: bundleDate, to: Date()).day ?? 0
        guard daysOld >= 540 else { return nil }
        return AppWarningItem(
            id: "stale:\(row.app.id)",
            appID: row.app.id,
            appName: row.app.name,
            appPath: row.app.path,
            bundleIdentifier: row.app.bundleIdentifier,
            title: "Outdated Application",
            detail: "\(row.app.name) has not changed in roughly \(daysOld / 30) months.",
            recommendation: "Check for an available update or confirm this version is still compatible with your current macOS version.",
            severity: .medium,
            category: .updates,
            source: "Update Signal",
            statusText: "Update",
            sizeBytes: row.totalSizeBytes > 0 ? row.totalSizeBytes : nil,
            detectedAt: bundleDate,
            details: [
                AppWarningDetail(title: "Bundle Date", value: AppMonitorFormatting.day(bundleDate)),
                AppWarningDetail(title: "Version", value: row.app.version ?? "Unknown"),
                AppWarningDetail(title: "Path", value: row.app.path)
            ],
            affectedItems: [
                AppWarningAffectedItem(
                    title: row.app.name,
                    subtitle: row.app.version ?? "Unknown version",
                    path: row.app.path
                )
            ]
        )
    }

    private func healthCategory(for finding: AppHealthFinding) -> AppWarningCategory {
        let haystack = "\(finding.title) \(finding.source)".lowercased()
        if haystack.contains("code") || haystack.contains("sign") || haystack.contains("gatekeeper") || haystack.contains("writable") || haystack.contains("readable") {
            return .security
        }
        if haystack.contains("crash") {
            return .compatibility
        }
        if haystack.contains("stale") || haystack.contains("update") {
            return .updates
        }
        return .configuration
    }

    private func healthSeverity(for finding: AppHealthFinding) -> AppWarningSeverity {
        if finding.severity == .critical { return .critical }
        let title = finding.title.lowercased()
        if title.contains("gatekeeper") || title.contains("signature") || title.contains("writable") {
            return .high
        }
        if title.contains("stale") || title.contains("crash") {
            return .medium
        }
        return .low
    }

    private func healthRecommendation(for finding: AppHealthFinding, category: AppWarningCategory) -> String {
        let title = finding.title.lowercased()
        if title.contains("signature") || title.contains("gatekeeper") {
            return "Reinstall the app from a trusted source or contact the developer to resolve signing and notarization issues."
        }
        if title.contains("readable") {
            return "Grant App Monitor the needed permission or verify the bundle path is still valid."
        }
        if title.contains("writable") {
            return "Confirm the app was installed from a trusted source and repair permissions if this bundle should be protected."
        }
        if category == .updates {
            return "Check for an app update or confirm that this version is still supported."
        }
        if category == .compatibility {
            return "Review recent crash reports and update, reinstall, or remove the app if crashes continue."
        }
        return "Review the finding, rescan the app, and decide whether the app should be updated, quarantined, or archived."
    }

    private func healthStatusText(for finding: AppHealthFinding) -> String {
        if finding.title.localizedCaseInsensitiveContains("signature") {
            return "Invalid"
        }
        if finding.title.localizedCaseInsensitiveContains("gatekeeper") {
            return "Blocked"
        }
        if finding.title.localizedCaseInsensitiveContains("crash") {
            return "Crashes"
        }
        if finding.title.localizedCaseInsensitiveContains("stale") {
            return "Update"
        }
        return finding.severity == .critical ? "Critical" : "Review"
    }

    private func cleanupWarningSeverity(_ severity: CleanupSeverity) -> AppWarningSeverity {
        switch severity {
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }

    private func cleanupWarningTitle(for suggestion: CleanupSuggestion) -> String {
        switch suggestion.category {
        case .caches:
            return "Large Cache"
        case .logs, .diagnosticReports:
            return "Large Log Files"
        case .savedApplicationState:
            return "Saved State Cleanup"
        case .httpStorages, .webKit, .cookies:
            return "Web Data Review"
        case .applicationSupport:
            return "Application Support Review"
        case .extensions, .launchAgents, .applicationScripts:
            return "Extension Cleanup Review"
        case .bundle, .containers, .groupContainers, .preferences:
            return suggestion.title
        }
    }

    private func regenerateCleanupSuggestions(for apps: [MonitoredApp]) throws {
        let rowsByID = Dictionary(uniqueKeysWithValues: try dataStore.fetchRows(period: period, includeAll: includeAllBundles).map { ($0.app.id, $0) })
        for app in apps {
            guard let row = rowsByID[app.id] else { continue }
            let items = try dataStore.fetchStorageItems(appID: app.id)
            try dataStore.replaceCleanupSuggestions(for: app.id, suggestions: cleanupAnalyzer.suggestions(for: row, items: items))
        }
    }

    private func updateCleanupSuggestion(_ suggestion: CleanupSuggestion, state: CleanupSuggestionState) {
        do {
            try dataStore.updateCleanupSuggestion(id: suggestion.id, state: state, quarantinePath: suggestion.quarantinePath)
            try dataStore.recordAction(title: "Cleanup \(state.rawValue.capitalized)", detail: suggestion.path)
            loadInfrastructureState()
        } catch {
            lastMessage = "Cleanup update failed: \(error.localizedDescription)"
        }
    }

    private func updateCleanupSuggestions(_ suggestions: [CleanupSuggestion], state: CleanupSuggestionState, actionTitle: String) {
        guard !suggestions.isEmpty else { return }
        do {
            for suggestion in suggestions {
                try dataStore.updateCleanupSuggestion(id: suggestion.id, state: state, quarantinePath: suggestion.quarantinePath)
            }
            let bytes = suggestions.reduce(Int64(0)) { $0 + $1.sizeBytes }
            try dataStore.recordAction(title: actionTitle, detail: "\(suggestions.count) item\(suggestions.count == 1 ? "" : "s"), \(AppMonitorFormatting.bytes(bytes))")
            loadInfrastructureState()
            lastMessage = "\(actionTitle): \(suggestions.count) item\(suggestions.count == 1 ? "" : "s")"
        } catch {
            lastMessage = "Cleanup update failed: \(error.localizedDescription)"
        }
    }

    private func reconcileCleanupFocus() {
        let visibleIDs = Set(activeCleanupSuggestions.map(\.id))
        if let focusedCleanupSuggestionID, visibleIDs.contains(focusedCleanupSuggestionID) {
            return
        }
        focusedCleanupSuggestionID = activeCleanupSuggestions.sorted(by: cleanupSuggestionComparator).first?.id
    }

    private func restorableCleanupSuggestion(detail: String) -> CleanupSuggestion? {
        cleanupSuggestions.first { suggestion in
            suggestion.path == detail
                && suggestion.state == .quarantined
                && suggestion.quarantinePath != nil
        }
    }

    private func cleanupSuggestionForHistoryDetail(_ detail: String) -> CleanupSuggestion? {
        cleanupSuggestions.first { $0.path == detail }
    }

    private func canRevertHistoryAction(title: String, detail: String) -> Bool {
        if cleanupSuggestionForHistoryDetail(detail) != nil,
           title.hasPrefix("Cleanup "),
           !title.localizedCaseInsensitiveContains("restored") {
            return true
        }
        if title == "Tagged App" {
            return parsedTagHistoryDetail(detail) != nil
        }
        if title == "Ignored App" || title == "Unignored App" || title == "Archived App Record" {
            return appRow(named: detail) != nil
        }
        if title.hasPrefix("Large File "), largeFiles.contains(where: { $0.path == detail }) {
            return true
        }
        return false
    }

    private func revertHistoryAction(title: String, detail: String) -> Bool {
        do {
            if let suggestion = cleanupSuggestionForHistoryDetail(detail),
               title.hasPrefix("Cleanup "),
               !title.localizedCaseInsensitiveContains("restored") {
                try dataStore.updateCleanupSuggestion(id: suggestion.id, state: .pending, quarantinePath: suggestion.quarantinePath)
                try dataStore.recordAction(title: "Reverted Cleanup Change", detail: detail)
                loadInfrastructureState()
                lastMessage = "Reverted cleanup state"
                return true
            }

            if title == "Tagged App",
               let parsed = parsedTagHistoryDetail(detail),
               let row = appRow(named: parsed.appName) {
                var tags = tagsByAppID[row.app.id] ?? []
                tags.removeAll { $0 == parsed.tag }
                try dataStore.setTags(tags, for: row.app.id)
                try dataStore.recordAction(title: "Reverted Tag", detail: detail)
                loadInfrastructureState()
                lastMessage = "Removed tag \(parsed.tag)"
                return true
            }

            if title == "Ignored App", let row = appRow(named: detail) {
                try dataStore.setIgnored(false, appID: row.app.id)
                try dataStore.recordAction(title: "Reverted Ignore", detail: detail)
                loadInfrastructureState()
                reloadRows()
                lastMessage = "Restored \(row.app.name) to lists"
                return true
            }

            if title == "Unignored App", let row = appRow(named: detail) {
                try dataStore.setIgnored(true, appID: row.app.id)
                try dataStore.recordAction(title: "Reverted Unignore", detail: detail)
                loadInfrastructureState()
                reloadRows()
                lastMessage = "Ignored \(row.app.name) again"
                return true
            }

            if title == "Archived App Record", let row = appRow(named: detail) {
                var tags = tagsByAppID[row.app.id] ?? []
                tags.removeAll { $0 == "Archived" }
                try dataStore.setTags(tags, for: row.app.id)
                try dataStore.setIgnored(false, appID: row.app.id)
                try dataStore.recordAction(title: "Reverted Archive", detail: detail)
                loadInfrastructureState()
                reloadRows()
                lastMessage = "Unarchived \(row.app.name)"
                return true
            }

            if title.hasPrefix("Large File "),
               let record = largeFiles.first(where: { $0.path == detail }) {
                updateLargeFile(record, state: .needsReview)
                try dataStore.recordAction(title: "Reverted Large File Change", detail: detail)
                actionHistory = try dataStore.fetchActionHistory()
                lastMessage = "Returned large file to review"
                return true
            }
        } catch {
            lastMessage = "Revert failed: \(error.localizedDescription)"
            return false
        }

        return false
    }

    private func parsedTagHistoryDetail(_ detail: String) -> (appName: String, tag: String)? {
        guard let separator = detail.range(of: ": ") else { return nil }
        let appName = String(detail[..<separator.lowerBound])
        let tag = String(detail[separator.upperBound...])
        guard !appName.isEmpty, !tag.isEmpty else { return nil }
        return (appName, tag)
    }

    private func appRow(named name: String) -> AppUsageRow? {
        rows.first { $0.app.name == name }
    }

    private func passesCleanupSuggestionFilter(_ suggestion: CleanupSuggestion) -> Bool {
        passesCleanupSuggestionFilter(suggestion, filter: cleanupSuggestionFilter)
    }

    private func passesCleanupSuggestionFilter(_ suggestion: CleanupSuggestion, filter: CleanupSuggestionFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .caches:
            return [.caches, .httpStorages, .savedApplicationState, .webKit].contains(suggestion.category)
        case .unusedApps:
            guard let row = appRow(for: suggestion.appID) else { return true }
            guard let lastSeen = row.lastSeen else { return true }
            return lastSeen < Date().addingTimeInterval(-30 * 24 * 60 * 60)
        case .largeFiles:
            return suggestion.severity == .high || suggestion.sizeBytes >= 500_000_000
        case .downloads:
            return suggestion.path.localizedCaseInsensitiveContains("/Downloads/")
        case .logs:
            return suggestion.category == .logs || suggestion.category == .diagnosticReports
        case .other:
            return ![
                CleanupSuggestionFilter.caches,
                .unusedApps,
                .largeFiles,
                .downloads,
                .logs
            ].contains { filter in
                passesCleanupSuggestionFilter(suggestion, filter: filter)
            }
        }
    }

    private func cleanupSuggestionComparator(_ lhs: CleanupSuggestion, _ rhs: CleanupSuggestion) -> Bool {
        switch cleanupSuggestionSort {
        case .size:
            if lhs.sizeBytes == rhs.sizeBytes { return lhs.title < rhs.title }
            return lhs.sizeBytes > rhs.sizeBytes
        case .risk:
            let lhsRank = cleanupSeverityRank(lhs.severity)
            let rhsRank = cleanupSeverityRank(rhs.severity)
            if lhsRank == rhsRank { return lhs.sizeBytes > rhs.sizeBytes }
            return lhsRank > rhsRank
        case .app:
            let appCompare = appName(for: lhs.appID).localizedCaseInsensitiveCompare(appName(for: rhs.appID))
            if appCompare == .orderedSame { return lhs.sizeBytes > rhs.sizeBytes }
            return appCompare == .orderedAscending
        case .category:
            if lhs.category.rawValue == rhs.category.rawValue { return lhs.sizeBytes > rhs.sizeBytes }
            return lhs.category.rawValue < rhs.category.rawValue
        case .updated:
            if lhs.updatedAt == rhs.updatedAt { return lhs.sizeBytes > rhs.sizeBytes }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func cleanupSeverityRank(_ severity: CleanupSeverity) -> Int {
        switch severity {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    private func updateLargeFile(_ record: LargeFileRecord, state: LargeFileReviewState) {
        do {
            try dataStore.updateLargeFileState(id: record.id, state: state)
            try dataStore.recordAction(title: "Large File \(state.rawValue)", detail: record.path)
            loadInfrastructureState()
        } catch {
            lastMessage = "Large file update failed: \(error.localizedDescription)"
        }
    }

    private func makeUpdateProviders(settings: AppUpdateSettings) -> [any AppUpdateProvider] {
        var providers: [any AppUpdateProvider] = [
            MacAppStoreUpdateProvider(),
            HomebrewUpdateProvider(includeFormulae: settings.includeHomebrewFormulae)
        ]
        if settings.includeAppleSoftwareUpdates {
            providers.append(AppleSoftwareUpdateProvider())
        }
        if settings.includeDirectDownloadDetection {
            providers.append(DirectDownloadUpdateProvider())
        }
        return providers
    }

    private func updateProvider(for source: AppUpdateSource) -> any AppUpdateProvider {
        switch source {
        case .macAppStore:
            return MacAppStoreUpdateProvider()
        case .homebrewCask, .homebrewFormula:
            return HomebrewUpdateProvider(includeFormulae: true)
        case .appleSoftwareUpdate:
            return AppleSoftwareUpdateProvider()
        case .directDownload, .unknown:
            return DirectDownloadUpdateProvider()
        }
    }

    private func appsForUpdateChecks() throws -> [MonitoredApp] {
        var apps = try dataStore.fetchApps(includeAll: true)
        guard let currentApp = currentAppForUpdateDetection(),
              !apps.contains(where: { $0.id == currentApp.id || $0.path == currentApp.path }) else {
            return apps
        }
        apps.append(currentApp)
        return apps
    }

    private func currentAppForUpdateDetection() -> MonitoredApp? {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else { return nil }
        return inventoryScanner.app(at: bundleURL)
    }

    private func appMonitorAppcastURL() -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String else {
            return nil
        }
        return URL(string: value)
    }

    private func fetchAppMonitorUpdateItem(from url: URL) async throws -> SparkleAppcastItem {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        return try SparkleAppcastParser.latestItem(from: data)
    }

    private func appMonitorUpdateRecord(
        from item: SparkleAppcastItem,
        currentApp: MonitoredApp,
        appcastURL: URL,
        checkedAt: Date
    ) -> AppUpdateRecord {
        AppUpdateRecord(
            appID: currentApp.id,
            appName: "App Monitor",
            bundleIdentifier: currentApp.bundleIdentifier,
            appPath: currentApp.path,
            source: .directDownload,
            sourceIdentifier: appcastURL.absoluteString,
            currentVersion: currentApp.version,
            availableVersion: item.version,
            status: .available,
            checkedAt: checkedAt,
            installActionTitle: "Install App Monitor Update",
            installActionURL: item.url?.absoluteString,
            requiresAdmin: false,
            requiresRestart: true,
            canInstall: true,
            isAutoEligible: appMonitorAutomaticUpdatesEnabled,
            releaseNotesTitle: item.title,
            releaseNotesSummary: item.summary,
            releaseNotesURL: item.releaseNotesURL?.absoluteString,
            message: "Ready to install in place."
        )
    }

    nonisolated private static func prepareAppMonitorUpdateInstall(
        item: SparkleAppcastItem,
        currentBundleURL: URL
    ) async throws -> AppMonitorUpdateInstallPlan {
        guard let packageURL = item.url else {
            throw AppMonitorSelfUpdateError.missingPackageURL
        }

        let fileManager = FileManager.default
        let workDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("AppMonitorSelfUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectoryURL, withIntermediateDirectories: true)

        let (downloadedURL, _) = try await URLSession.shared.download(from: packageURL)
        let packageName = packageURL.lastPathComponent.isEmpty ? "AppMonitorUpdate" : packageURL.lastPathComponent
        let packageFileURL = workDirectoryURL.appendingPathComponent(packageName)
        try? fileManager.removeItem(at: packageFileURL)
        try fileManager.moveItem(at: downloadedURL, to: packageFileURL)

        if let expectedSHA256 = item.sha256?.trimmingCharacters(in: .whitespacesAndNewlines), !expectedSHA256.isEmpty {
            let actualSHA256 = try sha256Hex(for: packageFileURL)
            guard actualSHA256.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
                throw AppMonitorSelfUpdateError.checksumMismatch
            }
        }

        let extractedDirectoryURL = workDirectoryURL.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractedDirectoryURL, withIntermediateDirectories: true)
        let stagedAppURL = workDirectoryURL.appendingPathComponent("App Monitor.app", isDirectory: true)
        let packageExtension = packageFileURL.pathExtension.lowercased()

        switch packageExtension {
        case "zip":
            try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", packageFileURL.path, extractedDirectoryURL.path])
            let appURL = try findAppMonitorApp(in: extractedDirectoryURL)
            try copyAppBundle(from: appURL, to: stagedAppURL)
        case "dmg":
            let mountPointURL = workDirectoryURL.appendingPathComponent("mount", isDirectory: true)
            try fileManager.createDirectory(at: mountPointURL, withIntermediateDirectories: true)
            try runProcess("/usr/bin/hdiutil", arguments: ["attach", packageFileURL.path, "-nobrowse", "-readonly", "-mountpoint", mountPointURL.path])
            defer {
                try? runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPointURL.path, "-quiet"])
            }
            let appURL = try findAppMonitorApp(in: mountPointURL)
            try copyAppBundle(from: appURL, to: stagedAppURL)
        default:
            throw AppMonitorSelfUpdateError.unsupportedPackage(packageExtension.isEmpty ? "download" : packageExtension)
        }

        return AppMonitorUpdateInstallPlan(
            stagedAppURL: stagedAppURL,
            workDirectoryURL: workDirectoryURL,
            currentBundleURL: currentBundleURL
        )
    }

    nonisolated private static func copyAppBundle(from sourceURL: URL, to destinationURL: URL) throws {
        try? FileManager.default.removeItem(at: destinationURL)
        try runProcess("/usr/bin/ditto", arguments: [sourceURL.path, destinationURL.path])
    }

    nonisolated private static func findAppMonitorApp(in directoryURL: URL) throws -> URL {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppMonitorSelfUpdateError.appBundleNotFound
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            if url.lastPathComponent == "App Monitor.app" {
                return url
            }
        }
        throw AppMonitorSelfUpdateError.appBundleNotFound
    }

    nonisolated private static func sha256Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "AppMonitorSelfUpdate",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "\(executable) failed." : output]
            )
        }
    }

    private func launchAppMonitorUpdateInstaller(plan: AppMonitorUpdateInstallPlan) throws {
        let scriptURL = plan.workDirectoryURL.appendingPathComponent("install-app-monitor-update.sh")
        let currentPath = plan.currentBundleURL.path
        let stagedPath = plan.stagedAppURL.path
        let workPath = plan.workDirectoryURL.path
        let backupPath = "\(currentPath).previous-update"

        let quotedCurrentPath = Self.shellQuote(currentPath)
        let quotedStagedPath = Self.shellQuote(stagedPath)
        let quotedWorkPath = Self.shellQuote(workPath)
        let quotedBackupPath = Self.shellQuote(backupPath)
        let privilegedCommand = [
            "if [ -e \(quotedCurrentPath) ]; then /bin/rm -rf \(quotedBackupPath); /bin/mv \(quotedCurrentPath) \(quotedBackupPath); fi",
            "/usr/bin/ditto \(quotedStagedPath) \(quotedCurrentPath)",
            "/usr/bin/xattr -cr \(quotedCurrentPath) >/dev/null 2>&1 || true"
        ].joined(separator: "; ")
        let osascriptExpression = "do shell script \(Self.appleScriptString(privilegedCommand)) with administrator privileges"
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        #!/bin/zsh
        set -u

        CURRENT_APP=\(quotedCurrentPath)
        STAGED_APP=\(quotedStagedPath)
        WORK_DIR=\(quotedWorkPath)
        BACKUP_APP=\(quotedBackupPath)
        APP_PID=\(pid)

        replace_without_privileges() {
          /bin/rm -rf "$BACKUP_APP" || return 1
          if [ -e "$CURRENT_APP" ]; then
            /bin/mv "$CURRENT_APP" "$BACKUP_APP" || return 1
          fi
          /usr/bin/ditto "$STAGED_APP" "$CURRENT_APP" || return 1
          /usr/bin/xattr -cr "$CURRENT_APP" >/dev/null 2>&1 || true
          return 0
        }

        while /bin/kill -0 "$APP_PID" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done

        if replace_without_privileges; then
          /usr/bin/open "$CURRENT_APP"
          /bin/rm -rf "$BACKUP_APP" "$WORK_DIR"
          exit 0
        fi

        /usr/bin/osascript -e \(Self.shellQuote(osascriptExpression)) || exit 1
        /usr/bin/open "$CURRENT_APP"
        /bin/rm -rf "$BACKUP_APP" "$WORK_DIR"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        try process.run()
    }

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    nonisolated private static func appleScriptString(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func recordWithCurrentAutoEligibility(_ record: AppUpdateRecord) -> AppUpdateRecord {
        record
    }

    private func updateRecordComparator(_ lhs: AppUpdateRecord, _ rhs: AppUpdateRecord) -> Bool {
        if lhs.status.countsAsAvailable != rhs.status.countsAsAvailable {
            return lhs.status.countsAsAvailable && !rhs.status.countsAsAvailable
        }
        if lhs.isAutoEligible != rhs.isAutoEligible {
            return lhs.isAutoEligible && !rhs.isAutoEligible
        }
        let sourceCompare = lhs.source.displayName.localizedCaseInsensitiveCompare(rhs.source.displayName)
        if sourceCompare != .orderedSame {
            return sourceCompare == .orderedAscending
        }
        let nameCompare = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending
        }
        return lhs.sourceIdentifier < rhs.sourceIdentifier
    }

    private func app(for record: AppUpdateRecord) -> MonitoredApp? {
        if let appID = record.appID, let row = rows.first(where: { $0.app.id == appID }) {
            return row.app
        }
        if let appPath = record.appPath {
            return inventoryScanner.app(at: URL(fileURLWithPath: appPath))
        }
        return nil
    }

    private func isAppRunning(for record: AppUpdateRecord) -> Bool {
        NSWorkspace.shared.runningApplications.contains { running in
            if let bundleIdentifier = record.bundleIdentifier,
               running.bundleIdentifier == bundleIdentifier {
                return true
            }
            if let appPath = record.appPath {
                return running.bundleURL?.standardizedFileURL.path == URL(fileURLWithPath: appPath).standardizedFileURL.path
            }
            return false
        }
    }

    private func applyUpdateResult(_ result: UpdateItemResult) {
        guard let index = updateRecords.firstIndex(where: { $0.id == result.updateID }) else { return }
        updateRecords[index].status = result.status
        updateRecords[index].message = result.message
        updateRecords[index].checkedAt = result.completedAt
        updateRecords[index].isAutoEligible = false
    }

    private func changeLogEntries(
        from records: [AppUpdateRecord],
        runID: String?,
        results: [UpdateItemResult]
    ) -> [AppChangeLogEntry] {
        let resultsByUpdateID = Dictionary(uniqueKeysWithValues: results.map { ($0.updateID, $0) })
        return records.compactMap { record in
            if let result = resultsByUpdateID[record.id] {
                guard result.status == .updated || result.status == .needsRestart else { return nil }
                return AppChangeLogEntry.fromUpdateRecord(record, result: result, runID: runID, capturedAt: result.completedAt)
            }

            guard runID == nil else { return nil }
            guard record.status.countsAsAvailable else { return nil }
            guard record.currentVersion != nil || record.availableVersion != nil || record.releaseNotesSummary != nil || record.releaseNotesURL != nil else { return nil }
            return AppChangeLogEntry.fromUpdateRecord(record, capturedAt: record.checkedAt)
        }
    }

    private func promptIfAppIsRunningForUpdate(_ app: MonitoredApp) async -> Bool {
        guard let runningApp = runningApplication(for: app) else { return true }
        let alert = NSAlert()
        alert.messageText = "\(app.name) is running"
        alert.informativeText = "Quit the app before updating so the installer can replace the bundle cleanly."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit App")
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            runningApp.terminate()
            lastMessage = "Asked \(app.name) to quit"
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            lastMessage = "Update cancelled"
            return false
        }
    }

    private func promptIfAppIsRunning(_ app: MonitoredApp) async -> Bool {
        guard let runningApp = runningApplication(for: app) else { return true }
        let alert = NSAlert()
        alert.messageText = "\(app.name) is running"
        alert.informativeText = "Quit the app before uninstalling so related files are not recreated while cleanup runs."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit App")
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            runningApp.terminate()
            lastMessage = "Asked \(app.name) to quit"
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            lastMessage = "Uninstall cancelled"
            return false
        }
    }

    private func runningApplication(for app: MonitoredApp) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { running in
            if let bundleIdentifier = app.bundleIdentifier,
               running.bundleIdentifier == bundleIdentifier {
                return true
            }
            return running.bundleURL?.standardizedFileURL.path == URL(fileURLWithPath: app.path).standardizedFileURL.path
        }
    }

    private func uninstallResult(
        runID: String,
        item: UninstallPlanItem,
        status: UninstallItemResultStatus,
        message: String?
    ) -> UninstallItemResult {
        UninstallItemResult(
            runID: runID,
            itemID: item.id,
            appID: item.appID,
            path: item.path,
            category: item.category,
            role: item.role,
            sizeBytes: item.sizeBytes,
            risk: item.risk,
            status: status,
            message: message
        )
    }

    private func quarantinePath(for suggestion: CleanupSuggestion) throws -> URL {
        let root = dataStore.databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("Quarantine", isDirectory: true)
            .appendingPathComponent(suggestion.id.sanitizedPathComponent, isDirectory: true)
        let name = URL(fileURLWithPath: suggestion.path).lastPathComponent
        return root.appendingPathComponent(name.isEmpty ? "item" : name)
    }

    private func movePathToTrash(_ path: String, actionTitle: String) {
        do {
            var result: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &result)
            try dataStore.recordAction(title: actionTitle, detail: path)
            reloadRows()
            loadInfrastructureState()
            lastMessage = "Moved to Trash: \(URL(fileURLWithPath: path).lastPathComponent)"
        } catch {
            lastMessage = "Trash failed: \(error.localizedDescription)"
        }
    }

    private func confirmDestructiveAction(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func persistSavedFilters() {
        do {
            try dataStore.saveSavedFilters(savedFilters)
        } catch {
            lastMessage = "Saving filter failed: \(error.localizedDescription)"
        }
    }

    private func persistScanSchedule() {
        do {
            try dataStore.saveScanSchedule(scanSchedule)
        } catch {
            lastMessage = "Saving schedule failed: \(error.localizedDescription)"
        }
    }

    private func persistUpdateSettings() {
        do {
            try dataStore.saveUpdateSettings(updateSettings)
            updateRecords = updateRecords.map(recordWithCurrentAutoEligibility)
        } catch {
            lastMessage = "Saving update settings failed: \(error.localizedDescription)"
        }
    }

    private func nextAppMonitorUpdateCheckDate(from date: Date = Date()) -> Date {
        date.addingTimeInterval(TimeInterval(max(1, appMonitorUpdateCadenceHours) * 3600))
    }

    private func updateNextAppMonitorUpdateCheck(from date: Date = Date()) {
        appMonitorUpdateNextCheckAt = appMonitorUpdateChecksEnabled ? nextAppMonitorUpdateCheckDate(from: date) : nil
        persistAppMonitorUpdateNextCheckAt()
    }

    private func persistAppMonitorUpdateNextCheckAt() {
        if let appMonitorUpdateNextCheckAt {
            UserDefaults.standard.set(appMonitorUpdateNextCheckAt, forKey: Self.appMonitorUpdateNextCheckAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.appMonitorUpdateNextCheckAtKey)
        }
    }

    private func markScanCompleted() {
        scanSchedule.lastScanAt = Date()
        if scanSchedule.isEnabled {
            scanSchedule.nextScanAt = Date().addingTimeInterval(TimeInterval(scanSchedule.intervalHours * 3600))
        }
        persistScanSchedule()
    }

    private func startScheduler() {
        schedulerTimer?.invalidate()
        guard scanSchedule.isEnabled else { return }
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let nextScanAt = self.scanSchedule.nextScanAt, nextScanAt <= Date() else { return }
                await self.runFullScan()
            }
        }
    }

    private func startUpdateScheduler() {
        updateSchedulerTimer?.invalidate()
        guard updateSettings.scheduledChecksEnabled else { return }
        if updateSettings.nextCheckAt == nil {
            updateSettings.nextCheckAt = updateSettings.nextCheckDate()
            persistUpdateSettings()
        }
        updateSchedulerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let nextCheckAt = self.updateSettings.nextCheckAt,
                      nextCheckAt <= Date(),
                      !self.isCheckingUpdates,
                      !self.isRunningUpdates
                else {
                    return
                }
                await self.checkForUpdates(runAutomaticEligible: self.updateSettings.automaticUpdatesEnabled)
            }
        }
    }

    private func startAppMonitorUpdateScheduler() {
        appMonitorUpdateSchedulerTimer?.invalidate()
        guard appMonitorUpdateChecksEnabled else { return }
        if appMonitorUpdateNextCheckAt == nil {
            appMonitorUpdateNextCheckAt = nextAppMonitorUpdateCheckDate()
            persistAppMonitorUpdateNextCheckAt()
        }
        appMonitorUpdateSchedulerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let nextCheckAt = self.appMonitorUpdateNextCheckAt,
                      nextCheckAt <= Date(),
                      !self.isCheckingAppMonitorUpdate,
                      !self.isInstallingAppMonitorUpdate
                else {
                    return
                }
                await self.checkForAppMonitorUpdate(installIfAvailable: self.appMonitorAutomaticUpdatesEnabled)
            }
        }
    }

    private func passesInfrastructureFilters(_ row: AppUsageRow) -> Bool {
        if ignoredAppIDs.contains(row.app.id), !includeIgnoredApps {
            return false
        }
        if filterState.warningsOnly, row.warningCount == 0, worstHealthSeverity(for: row) != .warning, worstHealthSeverity(for: row) != .critical {
            return false
        }
        if filterState.cleanupOnly, !activeCleanupSuggestions.contains(where: { $0.appID == row.app.id }) {
            return false
        }
        if filterState.hideProtectedApps, uninstallPlanner.protectionReason(for: row.app) != nil {
            return false
        }
        if let category = filterState.category {
            let hasCategory = storageCategoriesByAppID[row.app.id]?.contains(category) ?? false
            if !hasCategory {
                return false
            }
        }
        if filterState.minimumStorageBytes > 0, row.totalSizeBytes < filterState.minimumStorageBytes {
            return false
        }

        switch filterState.dateRange {
        case .any:
            return true
        case .usedLast7Days:
            guard let lastSeen = row.lastSeen else { return false }
            return lastSeen >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
        case .unused30Days:
            guard let lastSeen = row.lastSeen else { return true }
            return lastSeen < Date().addingTimeInterval(-30 * 24 * 60 * 60)
        case .unused90Days:
            guard let lastSeen = row.lastSeen else { return true }
            return lastSeen < Date().addingTimeInterval(-90 * 24 * 60 * 60)
        }
    }

    private func passesAppListQuickFilter(_ row: AppUsageRow, filter: AppListQuickFilter? = nil) -> Bool {
        switch filter ?? appListQuickFilter {
        case .all:
            return true
        case .recentlyUsed:
            return row.usageSeconds > 0 || row.importedDaysInPeriod > 0
        case .neverUsed:
            return row.lastSeen == nil
        case .systemApps:
            return !row.app.isUserFacing
        }
    }

    private func ensureSelectionMatchesDisplayedRows() {
        let visibleRows = displayedRows
        if let selectedAppID, visibleRows.contains(where: { $0.app.id == selectedAppID }) {
            return
        }
        selectedAppID = visibleRows.first?.app.id
        selectedTimelineSession = nil
        refreshSelectedDailyRows()
    }

    private func loadTrackingStart() {
        do {
            if let stored = try dataStore.setting("tracking_started_at").flatMap(Double.init) {
                trackingStartedAt = Date(timeIntervalSince1970: stored)
                return
            }

            let start = Date()
            try dataStore.setSetting("tracking_started_at", value: String(start.timeIntervalSince1970))
            trackingStartedAt = start
        } catch {
            trackingStartedAt = nil
        }
    }

    private func save(csv: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                lastMessage = "Exported \(url.lastPathComponent)"
            } catch {
                lastMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func compare(_ lhs: AppUsageRow, _ rhs: AppUsageRow, by key: SortKey) -> ComparisonResult {
        switch key {
        case .app:
            return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name)
        case .usage:
            return compare(lhs.usageSeconds, rhs.usageSeconds)
        case .importedDays:
            return compare(lhs.importedDaysInPeriod, rhs.importedDaysInPeriod)
        case .importedUseCount:
            return compare(lhs.importedUseCount ?? -1, rhs.importedUseCount ?? -1)
        case .importedLastUsed:
            return compare(lhs.importedLastUsed ?? .distantPast, rhs.importedLastUsed ?? .distantPast)
        case .lastUsed:
            return compare(lhs.lastSeen ?? .distantPast, rhs.lastSeen ?? .distantPast)
        case .appSize:
            return compare(lhs.bundleSizeBytes, rhs.bundleSizeBytes)
        case .relatedSize:
            return compare(lhs.relatedSizeBytes, rhs.relatedSizeBytes)
        case .totalSize:
            return compare(lhs.totalSizeBytes, rhs.totalSizeBytes)
        case .location:
            return lhs.app.path.localizedCaseInsensitiveCompare(rhs.app.path)
        case .scanStatus:
            return lhs.scanStatus.localizedCaseInsensitiveCompare(rhs.scanStatus)
        }
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}

private extension String {
    var sanitizedPathComponent: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }

    var withTrailingSlash: String {
        hasSuffix("/") ? self : self + "/"
    }
}
