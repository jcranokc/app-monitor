import Foundation

public struct MonitoredApp: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let version: String?
    public let path: String
    public let isUserFacing: Bool
    public let installedAt: Date?
    public let bundleCreatedAt: Date?
    public let lastSeen: Date

    public init(
        id: String,
        name: String,
        bundleIdentifier: String?,
        version: String?,
        path: String,
        isUserFacing: Bool,
        installedAt: Date? = nil,
        bundleCreatedAt: Date? = nil,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.path = path
        self.isUserFacing = isUserFacing
        self.installedAt = installedAt
        self.bundleCreatedAt = bundleCreatedAt
        self.lastSeen = lastSeen
    }
}

public struct UsageSegment: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let bundleIdentifier: String?
    public let appName: String
    public let appPath: String
    public let startedAt: Date
    public let endedAt: Date

    public var durationSeconds: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    public init(
        id: String = UUID().uuidString,
        appID: String,
        bundleIdentifier: String?,
        appName: String,
        appPath: String,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.appID = appID
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.appPath = appPath
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public enum StorageCategory: String, CaseIterable, Codable, Identifiable {
    case bundle = "Bundle"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case preferences = "Preferences"
    case savedApplicationState = "Saved Application State"
    case httpStorages = "HTTPStorages"
    case logs = "Logs"
    case extensions = "Extensions"
    case launchAgents = "Launch Agents"
    case applicationScripts = "Application Scripts"
    case webKit = "WebKit"
    case cookies = "Cookies"
    case diagnosticReports = "Diagnostic Reports"

    public var id: String { rawValue }
}

public struct StorageScanItem: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let category: StorageCategory
    public let path: String
    public let sizeBytes: Int64
    public let warning: String?
    public let scannedAt: Date

    public init(
        id: String = UUID().uuidString,
        appID: String,
        category: StorageCategory,
        path: String,
        sizeBytes: Int64,
        warning: String? = nil,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.category = category
        self.path = path
        self.sizeBytes = sizeBytes
        self.warning = warning
        self.scannedAt = scannedAt
    }
}

public struct StorageScanProgress: Hashable, Sendable {
    public let phase: String
    public let currentPath: String
    public let scannedFileCount: Int
    public let scannedBytes: Int64

    public init(
        phase: String,
        currentPath: String,
        scannedFileCount: Int,
        scannedBytes: Int64
    ) {
        self.phase = phase
        self.currentPath = currentPath
        self.scannedFileCount = scannedFileCount
        self.scannedBytes = scannedBytes
    }
}

public struct ImportedUsageHistory: Hashable {
    public let appID: String
    public let lastUsed: Date?
    public let useCount: Int64?
    public let usedDays: [Date]
    public let importedAt: Date

    public init(
        appID: String,
        lastUsed: Date?,
        useCount: Int64?,
        usedDays: [Date],
        importedAt: Date = Date()
    ) {
        self.appID = appID
        self.lastUsed = lastUsed
        self.useCount = useCount
        self.usedDays = usedDays
        self.importedAt = importedAt
    }
}

public struct MonitoringHistorySummary: Hashable {
    public let eventCount: Int
    public let earliestEventAt: Date?
    public let latestEventAt: Date?
    public let importedAppCount: Int

    public init(
        eventCount: Int,
        earliestEventAt: Date?,
        latestEventAt: Date?,
        importedAppCount: Int
    ) {
        self.eventCount = eventCount
        self.earliestEventAt = earliestEventAt
        self.latestEventAt = latestEventAt
        self.importedAppCount = importedAppCount
    }
}

public struct ImportedUsageTotals: Hashable {
    public var lastUsed: Date?
    public var useCount: Int64?
    public var daysInPeriod: Int = 0
    public var importedAt: Date?

    public init(
        lastUsed: Date? = nil,
        useCount: Int64? = nil,
        daysInPeriod: Int = 0,
        importedAt: Date? = nil
    ) {
        self.lastUsed = lastUsed
        self.useCount = useCount
        self.daysInPeriod = daysInPeriod
        self.importedAt = importedAt
    }
}

public enum ReportingPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"

    public var id: String { rawValue }

    public func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let component: Calendar.Component
        switch self {
        case .today:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

        if let fullInterval = calendar.dateInterval(of: component, for: now) {
            return DateInterval(start: fullInterval.start, end: now)
        }

        let start = calendar.startOfDay(for: now)
        return DateInterval(start: start, end: now)
    }
}

public enum UsageTrendGrouping: String, CaseIterable, Identifiable, Hashable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"

    public var id: String { rawValue }

    public static func defaultGrouping(for period: ReportingPeriod) -> UsageTrendGrouping {
        switch period {
        case .today, .week, .month:
            return .day
        case .year:
            return .month
        }
    }
}

public struct UsagePeriodComparison: Hashable {
    public let previousTotalSeconds: TimeInterval
    public let totalDeltaSeconds: TimeInterval
    public let totalPercentChange: Double?
    public let previousDailyAverageSeconds: TimeInterval
    public let dailyAverageDeltaSeconds: TimeInterval
    public let dailyAveragePercentChange: Double?
    public let previousSessionCount: Int
    public let sessionDelta: Int
    public let sessionPercentChange: Double?

    public var hasPreviousData: Bool {
        previousTotalSeconds > 0 || previousSessionCount > 0
    }

    public init(
        previousTotalSeconds: TimeInterval,
        totalDeltaSeconds: TimeInterval,
        totalPercentChange: Double?,
        previousDailyAverageSeconds: TimeInterval,
        dailyAverageDeltaSeconds: TimeInterval,
        dailyAveragePercentChange: Double?,
        previousSessionCount: Int,
        sessionDelta: Int,
        sessionPercentChange: Double?
    ) {
        self.previousTotalSeconds = previousTotalSeconds
        self.totalDeltaSeconds = totalDeltaSeconds
        self.totalPercentChange = totalPercentChange
        self.previousDailyAverageSeconds = previousDailyAverageSeconds
        self.dailyAverageDeltaSeconds = dailyAverageDeltaSeconds
        self.dailyAveragePercentChange = dailyAveragePercentChange
        self.previousSessionCount = previousSessionCount
        self.sessionDelta = sessionDelta
        self.sessionPercentChange = sessionPercentChange
    }
}

public struct UsageAnalyticsSummary: Hashable {
    public let totalSeconds: TimeInterval
    public let dailyAverageSeconds: TimeInterval
    public let peakDay: Date?
    public let peakDaySeconds: TimeInterval
    public let mostUsedApp: TopAppUsage?
    public let sessionCount: Int
    public let comparison: UsagePeriodComparison

    public init(
        totalSeconds: TimeInterval,
        dailyAverageSeconds: TimeInterval,
        peakDay: Date?,
        peakDaySeconds: TimeInterval,
        mostUsedApp: TopAppUsage?,
        sessionCount: Int,
        comparison: UsagePeriodComparison
    ) {
        self.totalSeconds = totalSeconds
        self.dailyAverageSeconds = dailyAverageSeconds
        self.peakDay = peakDay
        self.peakDaySeconds = peakDaySeconds
        self.mostUsedApp = mostUsedApp
        self.sessionCount = sessionCount
        self.comparison = comparison
    }
}

public struct UsageTrendBucket: Identifiable, Hashable {
    public let id: String
    public let start: Date
    public let end: Date
    public let stacks: [UsageStackSegment]
    public let totalSeconds: TimeInterval

    public init(
        id: String,
        start: Date,
        end: Date,
        stacks: [UsageStackSegment],
        totalSeconds: TimeInterval
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.stacks = stacks
        self.totalSeconds = totalSeconds
    }
}

public struct UsageStackSegment: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let seconds: TimeInterval
    public let percentOfBucket: Double
    public let isOther: Bool

    public init(
        id: String,
        appID: String,
        appName: String,
        appPath: String,
        seconds: TimeInterval,
        percentOfBucket: Double,
        isOther: Bool = false
    ) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.seconds = seconds
        self.percentOfBucket = percentOfBucket
        self.isOther = isOther
    }
}

public struct UsageHeatmapCell: Identifiable, Hashable {
    public let id: String
    public let rowStart: Date
    public let rowLabel: String
    public let hourOfDay: Int
    public let seconds: TimeInterval
    public let sessionCount: Int
    public let topAppID: String?
    public let topAppName: String?

    public init(
        id: String,
        rowStart: Date,
        rowLabel: String,
        hourOfDay: Int,
        seconds: TimeInterval,
        sessionCount: Int,
        topAppID: String?,
        topAppName: String?
    ) {
        self.id = id
        self.rowStart = rowStart
        self.rowLabel = rowLabel
        self.hourOfDay = hourOfDay
        self.seconds = seconds
        self.sessionCount = sessionCount
        self.topAppID = topAppID
        self.topAppName = topAppName
    }
}

public struct TopAppUsage: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let seconds: TimeInterval
    public let percentOfTotal: Double

    public init(
        appID: String,
        appName: String,
        appPath: String,
        seconds: TimeInterval,
        percentOfTotal: Double
    ) {
        self.id = appID
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.seconds = seconds
        self.percentOfTotal = percentOfTotal
    }
}

public struct UsageAnalyticsSnapshot: Hashable {
    public let interval: DateInterval
    public let grouping: UsageTrendGrouping
    public let summary: UsageAnalyticsSummary
    public let trendBuckets: [UsageTrendBucket]
    public let heatmapCells: [UsageHeatmapCell]
    public let topApps: [TopAppUsage]

    public init(
        interval: DateInterval,
        grouping: UsageTrendGrouping,
        summary: UsageAnalyticsSummary,
        trendBuckets: [UsageTrendBucket],
        heatmapCells: [UsageHeatmapCell],
        topApps: [TopAppUsage]
    ) {
        self.interval = interval
        self.grouping = grouping
        self.summary = summary
        self.trendBuckets = trendBuckets
        self.heatmapCells = heatmapCells
        self.topApps = topApps
    }

    public static func empty(
        period: ReportingPeriod = .week,
        grouping: UsageTrendGrouping = .day,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageAnalyticsSnapshot {
        let interval = period.interval(now: now, calendar: calendar)
        let comparison = UsagePeriodComparison(
            previousTotalSeconds: 0,
            totalDeltaSeconds: 0,
            totalPercentChange: nil,
            previousDailyAverageSeconds: 0,
            dailyAverageDeltaSeconds: 0,
            dailyAveragePercentChange: nil,
            previousSessionCount: 0,
            sessionDelta: 0,
            sessionPercentChange: nil
        )
        let summary = UsageAnalyticsSummary(
            totalSeconds: 0,
            dailyAverageSeconds: 0,
            peakDay: nil,
            peakDaySeconds: 0,
            mostUsedApp: nil,
            sessionCount: 0,
            comparison: comparison
        )
        return UsageAnalyticsSnapshot(
            interval: interval,
            grouping: grouping,
            summary: summary,
            trendBuckets: [],
            heatmapCells: [],
            topApps: []
        )
    }
}

public struct AppUsageRow: Identifiable, Hashable {
    public var id: String { app.id }

    public let app: MonitoredApp
    public let usageSeconds: TimeInterval
    public let lastUsed: Date?
    public let bundleSizeBytes: Int64
    public let relatedSizeBytes: Int64
    public let warningCount: Int
    public let scannedAt: Date?
    public let importedLastUsed: Date?
    public let importedUseCount: Int64?
    public let importedDaysInPeriod: Int
    public let importedAt: Date?
    public let trackingStartedAt: Date?
    public let verifiedInactivityDays: Int
    public let activityEvaluatedAt: Date

    public var totalSizeBytes: Int64 {
        bundleSizeBytes + relatedSizeBytes
    }

    /// Nil means storage has not been measured. A measured empty app is zero.
    public var scannedTotalSizeBytes: Int64? {
        scannedAt == nil ? nil : totalSizeBytes
    }

    public var lastSeen: Date? {
        lastUsed ?? importedLastUsed
    }

    public var activityState: AppActivityState {
        if lastSeen != nil { return .recorded }
        guard let trackingStartedAt else { return .coverageUnavailable }
        let observationStart = max(trackingStartedAt, app.installedAt ?? trackingStartedAt)
        let verifiedAt = Calendar.current.date(byAdding: .day, value: verifiedInactivityDays, to: observationStart)
            ?? observationStart.addingTimeInterval(TimeInterval(verifiedInactivityDays * 86_400))
        return activityEvaluatedAt >= verifiedAt ? .verifiedInactive : .noActivityRecorded
    }

    public var scanStatus: String {
        guard scannedAt != nil else { return "Not scanned" }
        return warningCount > 0 ? "Warnings" : "Scanned"
    }

    public init(
        app: MonitoredApp,
        usageSeconds: TimeInterval,
        lastUsed: Date?,
        bundleSizeBytes: Int64,
        relatedSizeBytes: Int64,
        warningCount: Int,
        scannedAt: Date?,
        importedLastUsed: Date? = nil,
        importedUseCount: Int64? = nil,
        importedDaysInPeriod: Int = 0,
        importedAt: Date? = nil,
        trackingStartedAt: Date? = nil,
        verifiedInactivityDays: Int = 30,
        activityEvaluatedAt: Date = Date()
    ) {
        self.app = app
        self.usageSeconds = usageSeconds
        self.lastUsed = lastUsed
        self.bundleSizeBytes = bundleSizeBytes
        self.relatedSizeBytes = relatedSizeBytes
        self.warningCount = warningCount
        self.scannedAt = scannedAt
        self.importedLastUsed = importedLastUsed
        self.importedUseCount = importedUseCount
        self.importedDaysInPeriod = importedDaysInPeriod
        self.importedAt = importedAt
        self.trackingStartedAt = trackingStartedAt
        self.verifiedInactivityDays = verifiedInactivityDays
        self.activityEvaluatedAt = activityEvaluatedAt
    }
}

public enum ScanSnapshotPhase: Equatable, Sendable {
    case idle
    case refreshing(completed: Int, total: Int)
    case completed(Date)
    case failed(String)

    public var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    public var allowsSnapshotActions: Bool { !isRefreshing }
}

public struct CompletedAppScanSnapshot {
    public let storageItemsByAppID: [String: [StorageScanItem]]
    public let healthFindingsByAppID: [String: [AppHealthFinding]]
    public let cleanupSuggestionsByAppID: [String: [CleanupSuggestion]]
    public let largeFiles: [LargeFileRecord]

    public init(
        storageItemsByAppID: [String: [StorageScanItem]],
        healthFindingsByAppID: [String: [AppHealthFinding]],
        cleanupSuggestionsByAppID: [String: [CleanupSuggestion]],
        largeFiles: [LargeFileRecord]
    ) {
        self.storageItemsByAppID = storageItemsByAppID
        self.healthFindingsByAppID = healthFindingsByAppID
        self.cleanupSuggestionsByAppID = cleanupSuggestionsByAppID
        self.largeFiles = largeFiles
    }
}

public enum AppActivityState: String, Hashable, Codable {
    case recorded
    case noActivityRecorded
    case coverageUnavailable
    case verifiedInactive

    public var displayName: String {
        switch self {
        case .recorded: return "Activity recorded"
        case .noActivityRecorded: return "No activity recorded yet"
        case .coverageUnavailable: return "Activity history unavailable"
        case .verifiedInactive: return "Never used"
        }
    }
}

public struct DailyUsageRow: Identifiable, Hashable {
    public let id: String
    public let day: Date
    public let appID: String
    public let appName: String
    public let usageSeconds: TimeInterval

    public init(day: Date, appID: String, appName: String, usageSeconds: TimeInterval) {
        self.day = day
        self.appID = appID
        self.appName = appName
        self.usageSeconds = usageSeconds
        self.id = "\(appID)|\(day.timeIntervalSince1970)"
    }
}

public struct StorageTotals: Hashable {
    public var bundleSizeBytes: Int64 = 0
    public var relatedSizeBytes: Int64 = 0
    public var warningCount: Int = 0
    public var scannedAt: Date?
}

public enum AppHealthSeverity: String, Codable, CaseIterable, Identifiable {
    case info
    case warning
    case critical

    public var id: String { rawValue }
}

public struct AppHealthFinding: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let severity: AppHealthSeverity
    public let title: String
    public let detail: String
    public let source: String
    public let checkedAt: Date

    public init(
        id: String = UUID().uuidString,
        appID: String,
        severity: AppHealthSeverity,
        title: String,
        detail: String,
        source: String,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.severity = severity
        self.title = title
        self.detail = detail
        self.source = source
        self.checkedAt = checkedAt
    }
}

public enum AppWarningSeverity: String, Codable, CaseIterable, Identifiable, Comparable {
    case critical
    case high
    case medium
    case low

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .critical:
            return "Critical"
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }

    public var rank: Int {
        switch self {
        case .critical:
            return 4
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
        }
    }

    public static func < (lhs: AppWarningSeverity, rhs: AppWarningSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum AppWarningCategory: String, Codable, CaseIterable, Identifiable {
    case security = "Security"
    case performance = "Performance"
    case storage = "Storage"
    case compatibility = "Compatibility"
    case updates = "Updates"
    case configuration = "Configuration"

    public var id: String { rawValue }
}

public struct AppWarningDetail: Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let value: String

    public init(id: String = UUID().uuidString, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}

public struct AppWarningAffectedItem: Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let path: String?
    public let sizeBytes: Int64?

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        path: String? = nil,
        sizeBytes: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

public struct AppWarningItem: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let bundleIdentifier: String?
    public let title: String
    public let detail: String
    public let recommendation: String
    public let severity: AppWarningSeverity
    public let category: AppWarningCategory
    public let source: String
    public let statusText: String?
    public let sizeBytes: Int64?
    public let detectedAt: Date
    public let details: [AppWarningDetail]
    public let affectedItems: [AppWarningAffectedItem]

    public init(
        id: String,
        appID: String,
        appName: String,
        appPath: String,
        bundleIdentifier: String?,
        title: String,
        detail: String,
        recommendation: String,
        severity: AppWarningSeverity,
        category: AppWarningCategory,
        source: String,
        statusText: String? = nil,
        sizeBytes: Int64? = nil,
        detectedAt: Date = Date(),
        details: [AppWarningDetail] = [],
        affectedItems: [AppWarningAffectedItem] = []
    ) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.detail = detail
        self.recommendation = recommendation
        self.severity = severity
        self.category = category
        self.source = source
        self.statusText = statusText
        self.sizeBytes = sizeBytes
        self.detectedAt = detectedAt
        self.details = details
        self.affectedItems = affectedItems
    }
}

public enum AppWarningDisposition: String, Codable, CaseIterable, Identifiable {
    case open
    case acknowledged
    case ignored
    case falsePositive
    case verified

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .acknowledged: return "Acknowledged"
        case .ignored: return "Ignored"
        case .falsePositive: return "False Positive"
        case .verified: return "Verified"
        }
    }

    public var isSuppressed: Bool {
        self == .ignored || self == .falsePositive
    }
}

public struct AppWarningTriageRecord: Identifiable, Hashable, Codable {
    public var id: String { warningID }
    public let warningID: String
    public var disposition: AppWarningDisposition
    public var snapshot: AppWarningItem
    public let firstSeenAt: Date
    public var lastSeenAt: Date
    public var updatedAt: Date

    public init(
        warningID: String,
        disposition: AppWarningDisposition,
        snapshot: AppWarningItem,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.warningID = warningID
        self.disposition = disposition
        self.snapshot = snapshot
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.updatedAt = updatedAt
    }
}

public struct AppWarningTriageEvent: Identifiable, Hashable, Codable {
    public let id: String
    public let warningID: String
    public let action: String
    public let detail: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        warningID: String,
        action: String,
        detail: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.warningID = warningID
        self.action = action
        self.detail = detail
        self.createdAt = createdAt
    }
}

public enum CleanupSeverity: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    public var id: String { rawValue }
}

public enum CleanupSuggestionState: String, Codable, CaseIterable, Identifiable {
    case pending
    case reviewRequested
    case approved
    case quarantined
    case restored
    case rejected
    case failed

    public var id: String { rawValue }
}

public struct CleanupSuggestion: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let title: String
    public let path: String
    public let category: StorageCategory
    public let sizeBytes: Int64
    public let severity: CleanupSeverity
    public let rationale: String
    public let riskNotes: String
    public var state: CleanupSuggestionState
    public var quarantinePath: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        appID: String,
        title: String,
        path: String,
        category: StorageCategory,
        sizeBytes: Int64,
        severity: CleanupSeverity,
        rationale: String,
        riskNotes: String,
        state: CleanupSuggestionState = .pending,
        quarantinePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.title = title
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
        self.severity = severity
        self.rationale = rationale
        self.riskNotes = riskNotes
        self.state = state
        self.quarantinePath = quarantinePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum LargeFileReviewState: String, Codable, CaseIterable, Identifiable {
    case needsReview
    case queuedForQuarantine
    case ignored
    case quarantined
    case removed
    case failed

    public var id: String { rawValue }
}

public struct LargeFileRecord: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let path: String
    public let category: StorageCategory
    public let sizeBytes: Int64
    public let riskScore: Int
    public let riskReason: String
    public let modifiedAt: Date?
    public var state: LargeFileReviewState
    public let scannedAt: Date

    public init(
        id: String,
        appID: String,
        path: String,
        category: StorageCategory,
        sizeBytes: Int64,
        riskScore: Int,
        riskReason: String,
        modifiedAt: Date? = nil,
        state: LargeFileReviewState = .needsReview,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
        self.riskScore = riskScore
        self.riskReason = riskReason
        self.modifiedAt = modifiedAt
        self.state = state
        self.scannedAt = scannedAt
    }
}

public enum UninstallPlanItemRole: String, Codable, CaseIterable, Identifiable {
    case appBundle
    case relatedPath

    public var id: String { rawValue }
}

public enum UninstallRiskLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case protected

    public var id: String { rawValue }
}

public struct UninstallPlanItem: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let role: UninstallPlanItemRole
    public let category: StorageCategory
    public let path: String
    public let sizeBytes: Int64
    public let warning: String?
    public let risk: UninstallRiskLevel
    public let defaultSelected: Bool
    public let coveredByParentID: String?
    public let rationale: String

    public init(
        id: String,
        appID: String,
        role: UninstallPlanItemRole,
        category: StorageCategory,
        path: String,
        sizeBytes: Int64,
        warning: String? = nil,
        risk: UninstallRiskLevel,
        defaultSelected: Bool,
        coveredByParentID: String? = nil,
        rationale: String
    ) {
        self.id = id
        self.appID = appID
        self.role = role
        self.category = category
        self.path = path
        self.sizeBytes = sizeBytes
        self.warning = warning
        self.risk = risk
        self.defaultSelected = defaultSelected
        self.coveredByParentID = coveredByParentID
        self.rationale = rationale
    }
}

public struct UninstallPlan: Identifiable, Hashable, Codable {
    public let id: String
    public let app: MonitoredApp
    public let items: [UninstallPlanItem]
    public let protectionReason: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        app: MonitoredApp,
        items: [UninstallPlanItem],
        protectionReason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.app = app
        self.items = items
        self.protectionReason = protectionReason
        self.createdAt = createdAt
    }

    public var isProtected: Bool {
        protectionReason != nil
    }

    public var recommendedItemIDs: Set<String> {
        Set(items.filter(\.defaultSelected).map(\.id))
    }

    public var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    public var recommendedBytes: Int64 {
        items.filter(\.defaultSelected).reduce(0) { $0 + $1.sizeBytes }
    }
}

public enum UninstallRunStatus: String, Codable, CaseIterable, Identifiable {
    case completed
    case partial
    case failed
    case cancelled

    public var id: String { rawValue }
}

public enum UninstallItemResultStatus: String, Codable, CaseIterable, Identifiable {
    case trashed
    case skipped
    case failed
    case coveredByParent
    case notSelected
    case missing

    public var id: String { rawValue }
}

public struct UninstallRunRecord: Identifiable, Hashable, Codable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let bundleIdentifier: String?
    public let status: UninstallRunStatus
    public let startedAt: Date
    public let completedAt: Date
    public let selectedItemCount: Int
    public let trashedItemCount: Int
    public let failedItemCount: Int
    public let skippedItemCount: Int
    public let selectedBytes: Int64
    public let message: String?

    public init(
        id: String = UUID().uuidString,
        appID: String,
        appName: String,
        appPath: String,
        bundleIdentifier: String?,
        status: UninstallRunStatus,
        startedAt: Date,
        completedAt: Date = Date(),
        selectedItemCount: Int,
        trashedItemCount: Int,
        failedItemCount: Int,
        skippedItemCount: Int,
        selectedBytes: Int64,
        message: String? = nil
    ) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.selectedItemCount = selectedItemCount
        self.trashedItemCount = trashedItemCount
        self.failedItemCount = failedItemCount
        self.skippedItemCount = skippedItemCount
        self.selectedBytes = selectedBytes
        self.message = message
    }
}

public struct UninstallItemResult: Identifiable, Hashable, Codable {
    public let id: String
    public let runID: String
    public let itemID: String
    public let appID: String
    public let path: String
    public let category: StorageCategory
    public let role: UninstallPlanItemRole
    public let sizeBytes: Int64
    public let risk: UninstallRiskLevel
    public let status: UninstallItemResultStatus
    public let message: String?
    public let completedAt: Date

    public init(
        id: String = UUID().uuidString,
        runID: String,
        itemID: String,
        appID: String,
        path: String,
        category: StorageCategory,
        role: UninstallPlanItemRole,
        sizeBytes: Int64,
        risk: UninstallRiskLevel,
        status: UninstallItemResultStatus,
        message: String? = nil,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.runID = runID
        self.itemID = itemID
        self.appID = appID
        self.path = path
        self.category = category
        self.role = role
        self.sizeBytes = sizeBytes
        self.risk = risk
        self.status = status
        self.message = message
        self.completedAt = completedAt
    }
}

public struct UninstallExecutionSummary: Hashable, Codable {
    public let run: UninstallRunRecord
    public let itemResults: [UninstallItemResult]

    public init(run: UninstallRunRecord, itemResults: [UninstallItemResult]) {
        self.run = run
        self.itemResults = itemResults
    }
}

public enum StorageRiskLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public enum AppDateRangeFilter: String, Codable, CaseIterable, Identifiable {
    case any = "Any Date"
    case usedLast7Days = "Used Last 7 Days"
    case unused30Days = "Unused 30 Days"
    case unused90Days = "Unused 90 Days"

    public var id: String { rawValue }
}

public enum AppUsageTimeFilter: String, Codable, CaseIterable, Identifiable {
    case any = "Any Usage"
    case none = "No Tracked Time"
    case atLeast15Minutes = "15 min+"
    case atLeast1Hour = "1 hr+"
    case atLeast4Hours = "4 hr+"
    case atLeast8Hours = "8 hr+"

    public var id: String { rawValue }
}

public struct AppFilterState: Codable, Hashable {
    public var warningsOnly: Bool
    public var cleanupOnly: Bool
    public var hideProtectedApps: Bool
    public var category: StorageCategory?
    public var minimumStorageBytes: Int64
    public var usageTime: AppUsageTimeFilter
    public var dateRange: AppDateRangeFilter

    public init(
        warningsOnly: Bool = false,
        cleanupOnly: Bool = false,
        hideProtectedApps: Bool = false,
        category: StorageCategory? = nil,
        minimumStorageBytes: Int64 = 0,
        usageTime: AppUsageTimeFilter = .any,
        dateRange: AppDateRangeFilter = .any
    ) {
        self.warningsOnly = warningsOnly
        self.cleanupOnly = cleanupOnly
        self.hideProtectedApps = hideProtectedApps
        self.category = category
        self.minimumStorageBytes = minimumStorageBytes
        self.usageTime = usageTime
        self.dateRange = dateRange
    }

    private enum CodingKeys: String, CodingKey {
        case warningsOnly
        case cleanupOnly
        case hideProtectedApps
        case category
        case minimumStorageBytes
        case usageTime
        case dateRange
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        warningsOnly = try container.decodeIfPresent(Bool.self, forKey: .warningsOnly) ?? false
        cleanupOnly = try container.decodeIfPresent(Bool.self, forKey: .cleanupOnly) ?? false
        hideProtectedApps = try container.decodeIfPresent(Bool.self, forKey: .hideProtectedApps) ?? false
        category = try container.decodeIfPresent(StorageCategory.self, forKey: .category)
        minimumStorageBytes = try container.decodeIfPresent(Int64.self, forKey: .minimumStorageBytes) ?? 0
        usageTime = try container.decodeIfPresent(AppUsageTimeFilter.self, forKey: .usageTime) ?? .any
        dateRange = try container.decodeIfPresent(AppDateRangeFilter.self, forKey: .dateRange) ?? .any
    }
}

public struct SavedAppFilter: Identifiable, Hashable, Codable {
    public let id: String
    public var name: String
    public var state: AppFilterState
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        state: AppFilterState,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.createdAt = createdAt
    }
}

public struct AppScanSchedule: Hashable, Codable {
    public var isEnabled: Bool
    public var intervalHours: Int
    public var nextScanAt: Date?
    public var lastScanAt: Date?

    public init(
        isEnabled: Bool = false,
        intervalHours: Int = 24,
        nextScanAt: Date? = nil,
        lastScanAt: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.intervalHours = intervalHours
        self.nextScanAt = nextScanAt
        self.lastScanAt = lastScanAt
    }
}
