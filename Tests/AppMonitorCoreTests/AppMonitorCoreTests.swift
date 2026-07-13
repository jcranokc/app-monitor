import XCTest
@testable import AppMonitorCore

final class AppMonitorCoreTests: XCTestCase {
    func testNewInstallIsNotVerifiedInactiveBeforeObservationWindow() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let row = AppUsageRow(
            app: sampleApp(installedAt: now.addingTimeInterval(-2 * 86_400)),
            usageSeconds: 0,
            lastUsed: nil,
            bundleSizeBytes: 0,
            relatedSizeBytes: 0,
            warningCount: 0,
            scannedAt: nil,
            trackingStartedAt: now.addingTimeInterval(-90 * 86_400),
            verifiedInactivityDays: 30,
            activityEvaluatedAt: now
        )

        XCTAssertEqual(row.activityState, .noActivityRecorded)
    }

    func testTrackingRestartRequiresFreshObservationWindow() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let app = sampleApp(installedAt: now.addingTimeInterval(-365 * 86_400))
        let collecting = AppUsageRow(
            app: app,
            usageSeconds: 0,
            lastUsed: nil,
            bundleSizeBytes: 0,
            relatedSizeBytes: 0,
            warningCount: 0,
            scannedAt: nil,
            trackingStartedAt: now.addingTimeInterval(-1 * 86_400),
            verifiedInactivityDays: 30,
            activityEvaluatedAt: now
        )
        let verified = AppUsageRow(
            app: app,
            usageSeconds: 0,
            lastUsed: nil,
            bundleSizeBytes: 0,
            relatedSizeBytes: 0,
            warningCount: 0,
            scannedAt: nil,
            trackingStartedAt: now.addingTimeInterval(-31 * 86_400),
            verifiedInactivityDays: 30,
            activityEvaluatedAt: now
        )

        XCTAssertEqual(collecting.activityState, .noActivityRecorded)
        XCTAssertEqual(verified.activityState, .verifiedInactive)
    }

    func testMissingUsageDoesNotUnlockMediumRiskCleanupWithoutVerifiedRecentEvidence() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let app = sampleApp(installedAt: now.addingTimeInterval(-365 * 86_400))
        let row = AppUsageRow(
            app: app,
            usageSeconds: 0,
            lastUsed: nil,
            bundleSizeBytes: 0,
            relatedSizeBytes: 500_000_000,
            warningCount: 0,
            scannedAt: now,
            trackingStartedAt: now.addingTimeInterval(-1 * 86_400),
            verifiedInactivityDays: 30,
            activityEvaluatedAt: now
        )
        let item = StorageScanItem(
            appID: app.id,
            category: .applicationSupport,
            path: "/tmp/support",
            sizeBytes: 500_000_000,
            scannedAt: now
        )

        XCTAssertTrue(CleanupAnalyzer().suggestions(for: row, items: [item], now: now).isEmpty)
    }

    func testAdoptionCandidatesDoNotCountAsAvailableUpdates() {
        XCTAssertTrue(AppUpdateStatus.available.countsAsAvailable)
        XCTAssertTrue(AppUpdateStatus.manualAction.countsAsAvailable)
        XCTAssertFalse(AppUpdateStatus.adoptable.countsAsAvailable)
        XCTAssertTrue(AppUpdateStatus.adoptable.countsAsAdoptionCandidate)
        XCTAssertFalse(AppUpdateStatus.available.countsAsAdoptionCandidate)
    }
    func testAccessibilityIdentifiersAreStableAndUnique() {
        let identifiers = AppAccessibilityIdentifier.staticIdentifiers

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("app-monitor.") })
        XCTAssertEqual(AppAccessibilityIdentifier.appRow("com.example.Test App"), "app-monitor.apps.row.com-example-test-app")
        XCTAssertEqual(AppAccessibilityIdentifier.updateSelection("brew|cask"), "app-monitor.updates.selection.brew-cask")
    }

    func testPeriodTodayStartsAtLocalMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T15:30:00Z")!

        let interval = ReportingPeriod.today.interval(now: now, calendar: calendar)

        XCTAssertEqual(interval.start, ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z")!)
        XCTAssertEqual(interval.end, now)
    }

    func testRowsIncludeZeroUsageApps() throws {
        let store = try temporaryStore()
        let active = sampleApp(name: "Active App", bundleID: "com.example.active", path: "/Applications/Active.app")
        let idle = sampleApp(name: "Idle App", bundleID: "com.example.idle", path: "/Applications/Idle.app")
        try store.upsertApps([active, idle])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!
        try store.insertUsageSegment(UsageSegment(
            appID: active.id,
            bundleIdentifier: active.bundleIdentifier,
            appName: active.name,
            appPath: active.path,
            startedAt: now.addingTimeInterval(-120),
            endedAt: now.addingTimeInterval(-60)
        ))

        let rows = try store.fetchRows(period: .today, includeAll: false, now: now, calendar: calendar)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first { $0.app.id == active.id }?.usageSeconds, 60)
        XCTAssertEqual(rows.first { $0.app.id == idle.id }?.usageSeconds, 0)
    }

    func testUsageSegmentsAreClippedToSelectedPeriod() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T01:00:00Z")!
        let start = ISO8601DateFormatter().date(from: "2026-07-07T23:50:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-07-08T00:10:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: start,
            endedAt: end
        ))

        let row = try XCTUnwrap(store.fetchRows(period: .today, includeAll: false, now: now, calendar: calendar).first)
        XCTAssertEqual(row.usageSeconds, 600, accuracy: 0.1)
    }

    func testMonitoringHistoryCanBeSummarizedExportedPrunedAndDeleted() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])
        let oldStart = Date(timeIntervalSince1970: 1_700_000_000)
        let recentStart = Date(timeIntervalSince1970: 1_800_000_000)

        for start in [oldStart, recentStart] {
            try store.insertUsageSegment(UsageSegment(
                appID: app.id,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.name,
                appPath: app.path,
                startedAt: start,
                endedAt: start.addingTimeInterval(60)
            ))
        }
        try store.replaceImportedUsage([
            ImportedUsageHistory(
                appID: app.id,
                lastUsed: recentStart,
                useCount: 3,
                usedDays: [oldStart, recentStart],
                importedAt: recentStart
            )
        ])

        var summary = try store.monitoringHistorySummary()
        XCTAssertEqual(summary.eventCount, 2)
        XCTAssertEqual(summary.earliestEventAt, oldStart)
        XCTAssertEqual(summary.latestEventAt, recentStart.addingTimeInterval(60))
        XCTAssertEqual(summary.importedAppCount, 1)

        let csv = CSVExporter.monitoringHistoryCSV(segments: try store.fetchAllUsageSegments())
        XCTAssertTrue(csv.contains("App,Bundle Identifier,Start,End,Duration Seconds,Path"))
        XCTAssertTrue(csv.contains(app.name))

        XCTAssertEqual(try store.deleteMonitoringHistory(before: Date(timeIntervalSince1970: 1_750_000_000)), 1)
        summary = try store.monitoringHistorySummary()
        XCTAssertEqual(summary.eventCount, 1)
        XCTAssertEqual(summary.importedAppCount, 1)

        XCTAssertEqual(try store.deleteMonitoringHistory(), 1)
        summary = try store.monitoringHistorySummary()
        XCTAssertEqual(summary.eventCount, 0)
        XCTAssertEqual(summary.importedAppCount, 0)
    }

    func testTimelineSessionsSplitAtDayBoundariesAndClipToPeriod() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T01:00:00Z")!
        let start = ISO8601DateFormatter().date(from: "2026-07-07T23:50:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-07-08T00:10:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: start,
            endedAt: end
        ))

        let todaySessions = try store.timelineSessions(period: .today, includeAll: false, now: now, calendar: calendar)
        XCTAssertEqual(todaySessions.count, 1)
        XCTAssertEqual(todaySessions[0].startedAt, ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z")!)
        XCTAssertEqual(todaySessions[0].endedAt, end)
        XCTAssertEqual(todaySessions[0].durationSeconds, 600, accuracy: 0.1)
        XCTAssertTrue(todaySessions[0].isClipped)

        let weeklySessions = try store.timelineSessions(period: .week, includeAll: false, now: now, calendar: calendar)
        XCTAssertEqual(weeklySessions.count, 2)
        XCTAssertEqual(weeklySessions.map(\.durationSeconds).reduce(0, +), 1_200, accuracy: 0.1)
        XCTAssertTrue(weeklySessions.allSatisfy(\.isClipped))
    }

    func testTimelineSummaryDayGroupsAndDeltasUseClippedSessions() throws {
        let store = try temporaryStore()
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let editor = sampleApp(name: "Editor", bundleID: "com.example.editor", path: "/Applications/Editor.app")
        try store.upsertApps([app, editor])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T08:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T09:00:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T10:30:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: editor.id,
            bundleIdentifier: editor.bundleIdentifier,
            appName: editor.name,
            appPath: editor.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T11:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T11:15:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-07T08:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-07T08:30:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: editor.id,
            bundleIdentifier: editor.bundleIdentifier,
            appName: editor.name,
            appPath: editor.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-07T09:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-07T09:10:00Z")!
        ))

        let summary = try store.timelineSummary(period: .today, includeAll: false, now: now, calendar: calendar)
        let rowTotal = try store.fetchRows(period: .today, includeAll: false, now: now, calendar: calendar)
            .reduce(0) { $0 + $1.usageSeconds }
        XCTAssertEqual(summary.totalUsageSeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(summary.totalUsageSeconds, rowTotal, accuracy: 0.1)
        XCTAssertEqual(summary.dailyAverageSeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(summary.longestSession).durationSeconds, 3_600, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(summary.mostActiveDay).durationSeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(summary.sessionCount, 3)
        XCTAssertEqual(summary.totalUsageDelta.previousValue, 2_400, accuracy: 0.1)
        XCTAssertEqual(summary.sessionCountDelta.previousValue, 2, accuracy: 0.1)

        let groups = try store.timelineDayGroups(period: .today, includeAll: false, now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessionCount, 3)
        XCTAssertEqual(groups[0].activeAppCount, 2)
        XCTAssertEqual(groups[0].appLanes.first?.appID, app.id)
    }

    func testTimelineHourBucketsSplitSessionsAcrossHours() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T03:00:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T00:30:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T02:15:00Z")!
        ))

        let buckets = try store.timelineHourBuckets(period: .today, includeAll: false, now: now, calendar: calendar)

        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.map(\.totalDurationSeconds), [1_800, 3_600, 900])
        XCTAssertEqual(buckets.compactMap(\.topAppName), [app.name, app.name, app.name])
        XCTAssertEqual(buckets.map(\.sessionCount), [1, 1, 1])
    }

    func testUsageAnalyticsSummaryTopAppsAndPreviousPeriodComparison() throws {
        let store = try temporaryStore()
        let editor = sampleApp(name: "Editor", bundleID: "com.example.editor", path: "/Applications/Editor.app")
        let browser = sampleApp(name: "Browser", bundleID: "com.example.browser", path: "/Applications/Browser.app")
        try store.upsertApps([editor, browser])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: editor.id,
            bundleIdentifier: editor.bundleIdentifier,
            appName: editor.name,
            appPath: editor.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T08:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T09:00:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: browser.id,
            bundleIdentifier: browser.bundleIdentifier,
            appName: browser.name,
            appPath: browser.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T09:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T09:30:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: editor.id,
            bundleIdentifier: editor.bundleIdentifier,
            appName: editor.name,
            appPath: editor.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T10:15:00Z")!
        ))
        try store.insertUsageSegment(UsageSegment(
            appID: browser.id,
            bundleIdentifier: browser.bundleIdentifier,
            appName: browser.name,
            appPath: browser.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-07T20:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-07T20:30:00Z")!
        ))

        let snapshot = try store.usageAnalytics(period: .today, includeAll: false, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.summary.totalSeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(snapshot.summary.dailyAverageSeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(snapshot.summary.peakDay, ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z")!)
        XCTAssertEqual(snapshot.summary.peakDaySeconds, 6_300, accuracy: 0.1)
        XCTAssertEqual(snapshot.summary.sessionCount, 3)
        XCTAssertEqual(snapshot.summary.mostUsedApp?.appID, editor.id)
        XCTAssertEqual(snapshot.summary.mostUsedApp?.percentOfTotal ?? 0, 4_500 / 6_300, accuracy: 0.001)
        XCTAssertEqual(snapshot.summary.comparison.previousTotalSeconds, 1_800, accuracy: 0.1)
        XCTAssertEqual(snapshot.summary.comparison.totalPercentChange ?? 0, 2.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.summary.comparison.previousSessionCount, 1)
        XCTAssertTrue(CSVExporter.usageSummaryCSV(snapshot: snapshot).contains("Total Usage"))
        XCTAssertTrue(CSVExporter.topAppsCSV(topApps: snapshot.topApps).contains("Editor"))
    }

    func testUsageAnalyticsTrendBucketsSplitSegmentsAtMidnight() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-07T23:50:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T00:10:00Z")!
        ))

        let buckets = try store.usageTrendBuckets(
            period: .week,
            includeAll: false,
            grouping: .day,
            now: now,
            calendar: calendar
        )
        let nonEmpty = buckets.filter { $0.totalSeconds > 0 }

        XCTAssertEqual(nonEmpty.count, 2)
        XCTAssertEqual(nonEmpty.map(\.totalSeconds), [600, 600])
        XCTAssertEqual(nonEmpty.flatMap(\.stacks).map(\.appID), [app.id, app.id])
    }

    func testUsageAnalyticsTrendBucketsGroupTopFivePlusOther() throws {
        let store = try temporaryStore()
        var apps: [MonitoredApp] = []
        for index in 1...7 {
            apps.append(sampleApp(
                name: "App \(index)",
                bundleID: "com.example.app\(index)",
                path: "/Applications/App\(index).app"
            ))
        }
        try store.upsertApps(apps)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!
        let base = ISO8601DateFormatter().date(from: "2026-07-08T08:00:00Z")!

        for (offset, app) in apps.enumerated() {
            let seconds = TimeInterval((7 - offset) * 100)
            let start = base.addingTimeInterval(TimeInterval(offset * 1_000))
            try store.insertUsageSegment(UsageSegment(
                appID: app.id,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.name,
                appPath: app.path,
                startedAt: start,
                endedAt: start.addingTimeInterval(seconds)
            ))
        }

        let snapshot = try store.usageAnalytics(
            period: .today,
            includeAll: false,
            grouping: .day,
            now: now,
            calendar: calendar
        )
        let bucket = try XCTUnwrap(snapshot.trendBuckets.first { $0.totalSeconds > 0 })
        let other = try XCTUnwrap(bucket.stacks.first { $0.isOther })

        XCTAssertEqual(snapshot.topApps.count, 7)
        XCTAssertEqual(bucket.stacks.count, 6)
        XCTAssertEqual(other.seconds, 300, accuracy: 0.1)
        XCTAssertEqual(bucket.totalSeconds, snapshot.summary.totalSeconds, accuracy: 0.1)
    }

    func testUsageAnalyticsHeatmapSplitsSegmentsAcrossHourBuckets() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T03:00:00Z")!

        try store.insertUsageSegment(UsageSegment(
            appID: app.id,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            appPath: app.path,
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T00:30:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T02:15:00Z")!
        ))

        let cells = try store.usageHeatmapCells(period: .today, includeAll: false, now: now, calendar: calendar)
        let activeCells = cells.filter { $0.seconds > 0 }.sorted { $0.hourOfDay < $1.hourOfDay }

        XCTAssertEqual(activeCells.map(\.hourOfDay), [0, 1, 2])
        XCTAssertEqual(activeCells.map(\.seconds), [1_800, 3_600, 900])
        XCTAssertEqual(activeCells.map(\.sessionCount), [1, 1, 1])
        XCTAssertEqual(Set(activeCells.compactMap(\.topAppID)), [app.id])
        XCTAssertTrue(CSVExporter.heatmapCSV(cells: cells).contains("Session Count"))
    }

    func testStorageTotalsSeparateBundleAndRelatedFiles() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])
        try store.replaceStorageItems(for: app.id, items: [
            StorageScanItem(appID: app.id, category: .bundle, path: app.path, sizeBytes: 100),
            StorageScanItem(appID: app.id, category: .caches, path: "/tmp/cache", sizeBytes: 25),
            StorageScanItem(appID: app.id, category: .extensions, path: "/tmp/extensions", sizeBytes: 10),
            StorageScanItem(appID: app.id, category: .logs, path: "/tmp/log", sizeBytes: 5, warning: "partial")
        ])

        let row = try XCTUnwrap(store.fetchRows(period: .today, includeAll: false).first)

        XCTAssertEqual(row.bundleSizeBytes, 100)
        XCTAssertEqual(row.relatedSizeBytes, 40)
        XCTAssertEqual(row.totalSizeBytes, 140)
        XCTAssertEqual(row.warningCount, 1)
        XCTAssertEqual(row.scanStatus, "Warnings")
    }

    func testAppMetadataPersistsInstallDates() throws {
        let store = try temporaryStore()
        let installed = Date(timeIntervalSince1970: 1_700_000_000)
        let created = Date(timeIntervalSince1970: 1_690_000_000)
        let app = sampleApp(installedAt: installed, bundleCreatedAt: created)

        try store.upsertApps([app])

        let fetched = try XCTUnwrap(store.fetchApps(includeAll: false).first)
        XCTAssertEqual(fetched.installedAt, installed)
        XCTAssertEqual(fetched.bundleCreatedAt, created)
    }

    func testCleanupSuggestionStateSurvivesRefresh() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        let suggestion = CleanupSuggestion(
            id: "\(app.id)|Caches|/tmp/cache",
            appID: app.id,
            title: "Review cache",
            path: "/tmp/cache",
            category: .caches,
            sizeBytes: 100,
            severity: .low,
            rationale: "test",
            riskNotes: "test"
        )

        try store.replaceCleanupSuggestions(for: app.id, suggestions: [suggestion])
        try store.updateCleanupSuggestion(id: suggestion.id, state: .approved)
        try store.replaceCleanupSuggestions(for: app.id, suggestions: [suggestion])

        XCTAssertEqual(try store.fetchCleanupSuggestions().first?.state, .approved)
    }

    func testQuarantineReviewRequestSurvivesCleanupRefresh() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        let suggestion = CleanupSuggestion(
            id: "\(app.id)|large-file-review|/tmp/big.bin",
            appID: app.id,
            title: "Large file review",
            path: "/tmp/big.bin",
            category: .caches,
            sizeBytes: 500_000_000,
            severity: .medium,
            rationale: "test",
            riskNotes: "test",
            state: .reviewRequested
        )

        try store.saveCleanupSuggestion(suggestion)
        try store.replaceCleanupSuggestions(for: app.id, suggestions: [])

        XCTAssertEqual(try store.fetchCleanupSuggestions().first?.state, .reviewRequested)
    }

    func testLargeFileReviewStateSurvivesRefresh() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        let record = LargeFileRecord(
            id: "\(app.id)|/tmp/big.bin",
            appID: app.id,
            path: "/tmp/big.bin",
            category: .caches,
            sizeBytes: 500_000_000,
            riskScore: 35,
            riskReason: "test",
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.replaceLargeFiles([record])
        try store.updateLargeFileState(id: record.id, state: .ignored)
        try store.replaceLargeFiles([record])

        let stored = try store.fetchLargeFiles().first
        XCTAssertEqual(stored?.state, .ignored)
        XCTAssertEqual(stored?.modifiedAt?.timeIntervalSince1970, record.modifiedAt?.timeIntervalSince1970)
    }

    func testSavedFiltersAndScanSchedulePersist() throws {
        let store = try temporaryStore()
        let filter = SavedAppFilter(
            name: "Warnings",
            state: AppFilterState(
                warningsOnly: true,
                hideProtectedApps: true,
                category: .caches,
                minimumStorageBytes: 100,
                usageTime: .atLeast1Hour
            )
        )
        let schedule = AppScanSchedule(isEnabled: true, intervalHours: 12, nextScanAt: Date(timeIntervalSince1970: 1_800_000_000))

        try store.saveSavedFilters([filter])
        try store.saveScanSchedule(schedule)

        XCTAssertEqual(try store.fetchSavedFilters(), [filter])
        XCTAssertEqual(try store.fetchScanSchedule(), schedule)
    }

    func testAppFilterStateDecodesLegacySavedFilters() throws {
        let data = """
        {
          "warningsOnly": true,
          "cleanupOnly": false,
          "minimumStorageBytes": 100,
          "dateRange": "Any Date"
        }
        """.data(using: .utf8)!

        let filter = try JSONDecoder().decode(AppFilterState.self, from: data)

        XCTAssertTrue(filter.warningsOnly)
        XCTAssertFalse(filter.hideProtectedApps)
        XCTAssertEqual(filter.minimumStorageBytes, 100)
        XCTAssertEqual(filter.usageTime, .any)
    }

    func testStorageScannerBuildsLargeFileIndex() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorLargeFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("large.dat")
        try Data(repeating: 1, count: 2_000_000).write(to: file)
        let modifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: file.path)

        let item = StorageScanItem(
            appID: "app",
            category: .caches,
            path: directory.path,
            sizeBytes: 2_000_000
        )
        let records = StorageScanner().largeFiles(in: [item], thresholdBytes: 1_000_000)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.path, file.path)
        XCTAssertEqual(records.first?.category, .caches)
        XCTAssertEqual(records.first?.modifiedAt?.timeIntervalSince1970 ?? 0, modifiedAt.timeIntervalSince1970, accuracy: 1)
    }

    func testStorageScannerReportsLargeFileProgress() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorProgress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("large.dat")
        try Data(repeating: 1, count: 2_000_000).write(to: file)

        let item = StorageScanItem(
            appID: "app",
            category: .caches,
            path: directory.path,
            sizeBytes: 2_000_000
        )
        let recorder = ProgressRecorder()

        _ = StorageScanner().largeFiles(in: [item], thresholdBytes: 1_000_000) { progress in
            recorder.append(progress)
        }

        let snapshots = recorder.snapshots()
        XCTAssertFalse(snapshots.isEmpty)
        XCTAssertGreaterThan(snapshots.map(\.scannedFileCount).max() ?? 0, 0)
        XCTAssertGreaterThan(snapshots.map(\.scannedBytes).max() ?? 0, 0)
        XCTAssertTrue(snapshots.contains { $0.phase == "Indexing large files" })
    }

    func testImportedUsageHistoryCountsDaysInSelectedPeriod() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        try store.upsertApps([app])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!
        let july7 = ISO8601DateFormatter().date(from: "2026-07-07T00:00:00Z")!
        let july8 = ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z")!
        let june30 = ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z")!

        try store.replaceImportedUsage([
            ImportedUsageHistory(
                appID: app.id,
                lastUsed: now,
                useCount: 42,
                usedDays: [july7, july8, july8, june30],
                importedAt: now
            )
        ])

        let row = try XCTUnwrap(store.fetchRows(period: .week, includeAll: false, now: now, calendar: calendar).first)

        XCTAssertEqual(row.importedDaysInPeriod, 2)
        XCTAssertEqual(row.importedUseCount, 42)
        XCTAssertEqual(row.importedLastUsed, now)
        XCTAssertEqual(row.importedAt, now)
    }

    func testRelatedFileMatcherUsesBundleIdentifierAndAppNameTokens() {
        let app = sampleApp(name: "Google Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app")

        XCTAssertTrue(RelatedFileMatcher.matches(candidateName: "com.google.Chrome", app: app))
        XCTAssertTrue(RelatedFileMatcher.matches(candidateName: "Chrome", app: app))
        XCTAssertFalse(RelatedFileMatcher.matches(candidateName: "Safari", app: app))
        XCTAssertFalse(RelatedFileMatcher.matches(candidateName: "GoogleUpdater", app: app))
    }

    func testUninstallPlannerReviewsAllPathsButDefaultsHighRiskOff() {
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let items = [
            StorageScanItem(appID: app.id, category: .bundle, path: "/Applications/Sample.app", sizeBytes: 100),
            StorageScanItem(appID: app.id, category: .caches, path: "/Users/test/Library/Caches/com.example.sample", sizeBytes: 200),
            StorageScanItem(appID: app.id, category: .applicationSupport, path: "/Users/test/Library/Application Support/Sample", sizeBytes: 300),
            StorageScanItem(appID: app.id, category: .preferences, path: "/Users/test/Library/Preferences/com.example.sample.plist", sizeBytes: 400),
            StorageScanItem(appID: app.id, category: .containers, path: "/Users/test/Library/Containers/com.example.sample", sizeBytes: 500),
            StorageScanItem(appID: app.id, category: .extensions, path: "/Applications/Sample.app/Contents/PlugIns/Widget.appex", sizeBytes: 600)
        ]

        let plan = AppUninstallPlanner().plan(for: app, storageItems: items)

        XCTAssertFalse(plan.isProtected)
        XCTAssertEqual(plan.items.count, 6)
        XCTAssertEqual(plan.items.first { $0.category == .bundle }?.defaultSelected, true)
        XCTAssertEqual(plan.items.first { $0.category == .caches }?.defaultSelected, true)
        XCTAssertEqual(plan.items.first { $0.category == .applicationSupport }?.defaultSelected, true)
        XCTAssertEqual(plan.items.first { $0.category == .preferences }?.risk, .high)
        XCTAssertEqual(plan.items.first { $0.category == .preferences }?.defaultSelected, false)
        XCTAssertEqual(plan.items.first { $0.category == .containers }?.defaultSelected, false)
        XCTAssertNotNil(plan.items.first { $0.category == .extensions }?.coveredByParentID)
        XCTAssertEqual(plan.items.first { $0.category == .extensions }?.defaultSelected, false)
    }

    func testUninstallPlannerProtectsSystemAndAppleApps() {
        let app = sampleApp(name: "Safari", bundleID: "com.apple.Safari", path: "/System/Applications/Safari.app")
        let plan = AppUninstallPlanner().plan(for: app, storageItems: [
            StorageScanItem(appID: app.id, category: .bundle, path: app.path, sizeBytes: 100)
        ])

        XCTAssertTrue(plan.isProtected)
        XCTAssertEqual(plan.protectionReason, "System applications are protected.")
        XCTAssertTrue(plan.items.allSatisfy { $0.risk == .protected })
        XCTAssertTrue(plan.items.allSatisfy { !$0.defaultSelected })
    }

    func testUninstallExecutorTrashesParentAndMarksChildrenCovered() {
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let plan = AppUninstallPlanner().plan(for: app, storageItems: [
            StorageScanItem(appID: app.id, category: .bundle, path: app.path, sizeBytes: 100),
            StorageScanItem(appID: app.id, category: .extensions, path: "/Applications/Sample.app/Contents/PlugIns/Widget.appex", sizeBytes: 50)
        ])
        let trash = FakeTrashManager(existingPaths: Set(plan.items.map(\.path)))
        let executor = AppUninstallExecutor(trashManager: trash)

        let summary = executor.execute(plan: plan, selectedItemIDs: Set(plan.items.map(\.id)))

        XCTAssertEqual(summary.run.status, .completed)
        XCTAssertEqual(summary.itemResults.first { $0.role == .appBundle }?.status, .trashed)
        XCTAssertEqual(summary.itemResults.first { $0.category == .extensions }?.status, .coveredByParent)
        XCTAssertEqual(trash.trashedPaths, [app.path])
    }

    func testUninstallExecutorSkipsRelatedPathsWhenBundleTrashFails() {
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let plan = AppUninstallPlanner().plan(for: app, storageItems: [
            StorageScanItem(appID: app.id, category: .bundle, path: app.path, sizeBytes: 100),
            StorageScanItem(appID: app.id, category: .caches, path: "/Users/test/Library/Caches/com.example.sample", sizeBytes: 50)
        ])
        let trash = FakeTrashManager(
            existingPaths: Set(plan.items.map(\.path)),
            failingPaths: [app.path]
        )
        let executor = AppUninstallExecutor(trashManager: trash)

        let summary = executor.execute(plan: plan, selectedItemIDs: plan.recommendedItemIDs)

        XCTAssertEqual(summary.run.status, .failed)
        XCTAssertEqual(summary.itemResults.first { $0.role == .appBundle }?.status, .failed)
        XCTAssertEqual(summary.itemResults.first { $0.category == .caches }?.status, .skipped)
        XCTAssertEqual(trash.trashedPaths, [app.path])
    }

    func testUninstallRunPersistence() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        let run = UninstallRunRecord(
            appID: app.id,
            appName: app.name,
            appPath: app.path,
            bundleIdentifier: app.bundleIdentifier,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001),
            selectedItemCount: 1,
            trashedItemCount: 1,
            failedItemCount: 0,
            skippedItemCount: 0,
            selectedBytes: 100
        )
        let result = UninstallItemResult(
            runID: run.id,
            itemID: "item",
            appID: app.id,
            path: app.path,
            category: .bundle,
            role: .appBundle,
            sizeBytes: 100,
            risk: .medium,
            status: .trashed,
            message: "/Users/test/.Trash/Sample.app",
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        try store.recordUninstallRun(run, itemResults: [result])

        XCTAssertEqual(try store.fetchUninstallRuns(), [run])
        XCTAssertEqual(try store.fetchUninstallItemResults(runID: run.id), [result])
    }

    func testMacAppStoreOutdatedParserMatchesBundleID() {
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let checkedAt = Date(timeIntervalSince1970: 2_000)
        let json = """
        [
          {
            "appID": 123456,
            "bundleID": "com.example.sample",
            "title": "Sample App",
            "installedVersion": "1.0",
            "version": "2.0"
          }
        ]
        """

        let records = MacAppStoreUpdateProvider.parseOutdated(json: json, apps: [app], checkedAt: checkedAt)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].appID, app.id)
        XCTAssertEqual(records[0].source, .macAppStore)
        XCTAssertEqual(records[0].sourceIdentifier, "123456")
        XCTAssertEqual(records[0].currentVersion, "1.0")
        XCTAssertEqual(records[0].availableVersion, "2.0")
        XCTAssertEqual(records[0].status, .needsAdmin)
        XCTAssertTrue(records[0].requiresAdmin)
    }

    func testMacAppStoreOutdatedParserAllowsDuplicateBundleIDs() {
        let primary = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample.app")
        let duplicate = sampleApp(name: "Sample App Copy", bundleID: "com.example.sample", path: "/Volumes/Backup/Sample.app")
        let checkedAt = Date(timeIntervalSince1970: 2_025)
        let json = """
        [
          {
            "appID": 123456,
            "bundleID": "com.example.sample",
            "title": "Sample App",
            "installedVersion": "1.0",
            "version": "2.0"
          }
        ]
        """

        let records = MacAppStoreUpdateProvider.parseOutdated(json: json, apps: [primary, duplicate], checkedAt: checkedAt)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].appID, primary.id)
        XCTAssertEqual(records[0].appPath, primary.path)
        XCTAssertEqual(records[0].bundleIdentifier, "com.example.sample")
        XCTAssertEqual(records[0].availableVersion, "2.0")
    }

    func testMacAppStoreOutdatedParserReadsMasSevenSingleObjectOutput() {
        let app = sampleApp(
            name: "Did I Copy It?",
            bundleID: "com.underratedsoftware.didicopyit",
            path: "/Applications/Did I Copy It?.app"
        )
        let checkedAt = Date(timeIntervalSince1970: 2_050)
        let json = """
        Warning: Found a likely App Store app that is not indexed in Spotlight
        {"adamID":6784293008,"bundleID":"com.underratedsoftware.didicopyit","displayName":"Did I Copy It?.app","name":"Did I Copy It?","path":"/Applications/Did I Copy It?.app","version":"1.0.0","newVersion":"1.1.0"}
        """

        let records = MacAppStoreUpdateProvider.parseOutdated(json: json, apps: [app], checkedAt: checkedAt)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].appID, app.id)
        XCTAssertEqual(records[0].appName, "Did I Copy It?")
        XCTAssertEqual(records[0].bundleIdentifier, "com.underratedsoftware.didicopyit")
        XCTAssertEqual(records[0].sourceIdentifier, "6784293008")
        XCTAssertEqual(records[0].currentVersion, "1.0.0")
        XCTAssertEqual(records[0].availableVersion, "1.1.0")
        XCTAssertEqual(records[0].status, .needsAdmin)
    }

    func testHomebrewOutdatedParserIncludesCasksAndFormulae() {
        let app = sampleApp(name: "Sample App", bundleID: "com.example.sample", path: "/Applications/Sample App.app")
        let checkedAt = Date(timeIntervalSince1970: 2_100)
        let json = """
        {
          "formulae": [
            {
              "name": "sqlite",
              "installed_versions": ["3.45.0"],
              "current_version": "3.46.0"
            }
          ],
          "casks": [
            {
              "name": "sample-app",
              "installed_versions": ["1.0"],
              "current_version": "2.0"
            }
          ]
        }
        """

        let records = HomebrewUpdateProvider.parseOutdated(
            json: json,
            includeFormulae: true,
            apps: [app],
            checkedAt: checkedAt
        )

        XCTAssertEqual(records.count, 2)
        let cask = records.first { $0.source == .homebrewCask }
        XCTAssertEqual(cask?.appID, app.id)
        XCTAssertEqual(cask?.sourceIdentifier, "sample-app")
        XCTAssertEqual(cask?.availableVersion, "2.0")
        XCTAssertTrue(cask?.isAutoEligible == true)

        let formula = records.first { $0.source == .homebrewFormula }
        XCTAssertEqual(formula?.appName, "sqlite")
        XCTAssertEqual(formula?.currentVersion, "3.45.0")
        XCTAssertEqual(formula?.availableVersion, "3.46.0")
    }

    func testAppleSoftwareUpdateParserDetectsRestartRequirement() {
        let output = """
        Software Update Tool
        Finding available software
        Software Update found the following new or updated software:
        * Label: Safari17.5-17.5
            Title: Safari, Version: 17.5, Size: 100000K, Recommended: YES,
        * Label: macOS-15.5-24F74
            Title: macOS Sequoia 15.5, Version: 15.5, Size: 12000000K, Recommended: YES, Action: restart,
        """

        let records = AppleSoftwareUpdateProvider.parseList(output: output, checkedAt: Date(timeIntervalSince1970: 2_200))

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].appName, "Safari")
        XCTAssertEqual(records[0].status, .needsAdmin)
        XCTAssertFalse(records[0].requiresRestart)
        XCTAssertEqual(records[1].appName, "macOS Sequoia 15.5")
        XCTAssertEqual(records[1].status, .needsRestart)
        XCTAssertTrue(records[1].requiresRestart)
    }

    func testSparkleAppcastParserReadsLatestItem() throws {
        let xml = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 2.0</title>
              <description>Added faster scans and fixed crashes.</description>
              <sparkle:releaseNotesLink>https://example.com/releases/2.0</sparkle:releaseNotesLink>
              <enclosure url="https://example.com/Sample.zip" sparkle:shortVersionString="2.0" sparkle:version="200" sparkle:sha256="abcdef" />
            </item>
          </channel>
        </rss>
        """

        let item = try SparkleAppcastParser.latestItem(from: Data(xml.utf8))

        XCTAssertEqual(item.title, "Version 2.0")
        XCTAssertEqual(item.version, "2.0")
        XCTAssertEqual(item.url?.absoluteString, "https://example.com/Sample.zip")
        XCTAssertEqual(item.summary, "Added faster scans and fixed crashes.")
        XCTAssertEqual(item.releaseNotesURL?.absoluteString, "https://example.com/releases/2.0")
        XCTAssertEqual(item.sha256, "abcdef")
    }

    func testSparkleAppcastParserIgnoresDeltaEnclosures() throws {
        let xml = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>0.8.0</title>
              <sparkle:shortVersionString>0.8.0</sparkle:shortVersionString>
              <enclosure url="https://getdocky.com/releases/Docky-0.8.0.zip" />
              <sparkle:deltas>
                <enclosure url="https://getdocky.com/releases/Docky-0.8.0-from-0.6.2.delta" sparkle:deltaFrom="202606111009" />
              </sparkle:deltas>
            </item>
          </channel>
        </rss>
        """

        let item = try SparkleAppcastParser.latestItem(from: Data(xml.utf8))

        XCTAssertEqual(item.version, "0.8.0")
        XCTAssertEqual(item.url?.absoluteString, "https://getdocky.com/releases/Docky-0.8.0.zip")
    }

    func testGuidedUpdateURLPolicyRejectsUpdaterPayloads() {
        XCTAssertNil(GuidedUpdateURLPolicy.userFacingURL(from: "https://example.com/App.delta"))
        XCTAssertNil(GuidedUpdateURLPolicy.userFacingURL(from: "https://example.com/App.zip"))
        XCTAssertNil(GuidedUpdateURLPolicy.userFacingURL(from: "https://example.com/appcast.xml"))
        XCTAssertNil(GuidedUpdateURLPolicy.userFacingURL(from: "file:///tmp/App.dmg"))
        XCTAssertEqual(
            GuidedUpdateURLPolicy.userFacingURL(from: "https://example.com/releases/2.0")?.absoluteString,
            "https://example.com/releases/2.0"
        )
    }

    func testSparkleAppcastParserReadsChildVersionElements() throws {
        let xml = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>0.41.0</title>
              <sparkle:version>100</sparkle:version>
              <sparkle:shortVersionString>0.41.0</sparkle:shortVersionString>
              <enclosure url="https://example.com/CodexBar.zip" />
            </item>
          </channel>
        </rss>
        """

        let item = try SparkleAppcastParser.latestItem(from: Data(xml.utf8))

        XCTAssertEqual(item.version, "0.41.0")
        XCTAssertEqual(item.url?.absoluteString, "https://example.com/CodexBar.zip")
    }

    func testDirectDownloadProviderSkipsHomebrewManagedSparkleApps() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorTests-\(UUID().uuidString)", isDirectory: true)
        let appURL = rootURL.appendingPathComponent("AlDente.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let caskroomURL = rootURL.appendingPathComponent("Caskroom", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: caskroomURL.appendingPathComponent("aldente", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }

        NSDictionary(dictionary: [
            "SUFeedURL": "https://example.invalid/aldente-appcast.xml"
        ]).write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true)

        let app = sampleApp(
            name: "AlDente",
            bundleID: "com.apphousekitchen.aldente-pro",
            version: "1.38",
            path: appURL.path
        )
        let provider = DirectDownloadUpdateProvider(
            timeout: 0.01,
            homebrewCaskRoots: [caskroomURL.path]
        )

        let records = await provider.checkUpdates(apps: [app])

        XCTAssertTrue(records.isEmpty)
    }

    func testMetadataProviderMatchesHomebrewCaskMetadataForNonBrewApps() {
        let app = sampleApp(
            name: "Codex Test Replacer",
            bundleID: "com.example.codex-test-replacer",
            path: "/Applications/Codex Test Replacer.app"
        )
        let json = """
        [
          {
            "token": "codex-test-replacer",
            "name": ["Codex Test Replacer"],
            "version": "11.4.3",
            "url": "https://example.com/CodexTestReplacer-11.4.3.zip",
            "homepage": "https://example.com/",
            "desc": "Test update utility"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app], checkedAt: Date(timeIntervalSince1970: 2_450))

        XCTAssertEqual(records.count, 2)
        let homebrewRecord = records.first { $0.source == .homebrewCask }
        XCTAssertEqual(homebrewRecord?.appID, app.id)
        XCTAssertEqual(homebrewRecord?.sourceIdentifier, "replace:codex-test-replacer")
        XCTAssertEqual(homebrewRecord?.currentVersion, "1.0")
        XCTAssertEqual(homebrewRecord?.availableVersion, "11.4.3")
        XCTAssertEqual(homebrewRecord?.status, .adoptable)
        XCTAssertEqual(homebrewRecord?.installActionTitle, "Adopt with Homebrew")
        XCTAssertFalse(homebrewRecord?.isAutoEligible ?? true)

        let metadataRecord = records.first { $0.source == .metadata }
        XCTAssertEqual(metadataRecord?.appID, app.id)
        XCTAssertEqual(metadataRecord?.sourceIdentifier, "homebrew-cask:codex-test-replacer")
        XCTAssertEqual(metadataRecord?.currentVersion, "1.0")
        XCTAssertEqual(metadataRecord?.availableVersion, "11.4.3")
        XCTAssertEqual(metadataRecord?.status, .manualAction)
        XCTAssertTrue(metadataRecord?.canInstall ?? false)
    }

    func testMetadataProviderMarksHomebrewCaskAdoptableWithoutNewerVersion() {
        let app = sampleApp(
            name: "Codex Test Adoptable",
            bundleID: "com.example.codex-test-adoptable",
            version: "1.0",
            path: "/Applications/Codex Test Adoptable.app"
        )
        let json = """
        [
          {
            "token": "codex-test-adoptable",
            "name": ["Codex Test Adoptable"],
            "version": "1.0",
            "homepage": "https://example.com/"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].status, .adoptable)
        XCTAssertEqual(records[0].source, .homebrewCask)
        XCTAssertEqual(records[0].sourceIdentifier, "adopt:codex-test-adoptable")
        XCTAssertEqual(records[0].availableVersion, "1.0")
    }

    func testMetadataProviderSkipsHomebrewAdoptionWhenInstalledVersionIsNewer() {
        let app = sampleApp(
            name: "OneDrive",
            bundleID: "com.microsoft.OneDrive",
            version: "26.108.0607",
            path: "/Applications/OneDrive.app"
        )
        let json = """
        [
          {
            "token": "onedrive",
            "name": ["OneDrive"],
            "version": "26.106.0603.0003",
            "homepage": "https://www.microsoft.com/microsoft-365/onedrive/online-cloud-storage"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app])

        XCTAssertTrue(records.isEmpty)

        let staleRecord = AppUpdateRecord(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .homebrewCask,
            sourceIdentifier: "adopt:onedrive",
            currentVersion: app.version,
            availableVersion: "26.106.0603.0003",
            status: .adoptable,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )
        XCTAssertTrue(AppUpdateEligibility.isStaleHomebrewManagementRecord(staleRecord))
        XCTAssertFalse(
            AppUpdateEligibility.isBulkHomebrewActionable(
                record: staleRecord,
                settings: AppUpdateSettings(includeHomebrewFormulae: true)
            )
        )
    }

    func testMetadataProviderStillMarksSparkleAppsAdoptableWhenCaskIsNotNewer() throws {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Codex Test Sparkle Adopt.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        NSDictionary(dictionary: [
            "SUFeedURL": "https://apphousekitchen.com/aldente/aldenteproappcast.xml"
        ]).write(to: infoURL, atomically: true)

        let app = sampleApp(
            name: "Codex Test Sparkle Adopt",
            bundleID: "com.example.codex-test-sparkle-adopt",
            version: "1.38",
            path: appURL.path
        )
        let json = """
        [
          {
            "token": "codex-test-sparkle-adopt",
            "name": ["Codex Test Sparkle Adopt"],
            "version": "1.38",
            "homepage": "https://apphousekitchen.com/"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].status, .adoptable)
        XCTAssertEqual(records[0].source, .homebrewCask)
        XCTAssertEqual(records[0].sourceIdentifier, "adopt:codex-test-sparkle-adopt")
    }

    func testMetadataProviderMarksNewerSparkleCasksAdoptableWithReplaceCommand() throws {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Codex Test Sparkle Replace.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        NSDictionary(dictionary: [
            "SUFeedURL": "https://apphousekitchen.com/aldente/aldenteproappcast.xml"
        ]).write(to: infoURL, atomically: true)

        let app = sampleApp(
            name: "Codex Test Sparkle Replace",
            bundleID: "com.example.codex-test-sparkle-replace",
            version: "1.38",
            path: appURL.path
        )
        let json = """
        [
          {
            "token": "codex-test-sparkle-replace",
            "name": ["Codex Test Sparkle Replace"],
            "version": "1.39",
            "homepage": "https://apphousekitchen.com/"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].status, .adoptable)
        XCTAssertEqual(records[0].source, .homebrewCask)
        XCTAssertEqual(records[0].sourceIdentifier, "replace:codex-test-sparkle-replace")
        XCTAssertEqual(records[0].installActionTitle, "Adopt with Homebrew")
    }

    func testHomebrewProviderAdoptsCaskWithInstallAdoptCommand() async {
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(exitCode: 0, output: "sample-app adopted")
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample App.app",
            source: .homebrewCask,
            sourceIdentifier: "adopt:sample-app",
            currentVersion: "1.0",
            availableVersion: "1.0",
            status: .adoptable,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(result.message, "sample-app adopted")
        XCTAssertEqual(runner.calls.map(\.arguments), [
            ["update", "--auto-update"],
            ["install", "--cask", "--adopt", "sample-app"]
        ])
        XCTAssertNil(runner.calls[0].environment["SUDO_ASKPASS"])
        XCTAssertEqual(runner.calls[1].environment["SUDO_ASKPASS"], "/tmp/AppMonitorAskpass-Test")
        XCTAssertNotNil(runner.calls[1].environment["APP_MONITOR_ASKPASS_ATTEMPT_ID"])
        XCTAssertEqual(
            runner.calls[1].environment["APP_MONITOR_ASKPASS_CONTEXT"],
            "adopt Sample App as the sample-app Homebrew cask"
        )
        XCTAssertFalse(runner.calls[1].environment.keys.contains { $0.localizedCaseInsensitiveContains("password") })
    }

    func testHomebrewProviderReplacesCaskWithForceInstallCommand() async {
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(exitCode: 0, output: "codexbar installed")
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: "app",
            appName: "CodexBar",
            bundleIdentifier: "com.steipete.CodexBar",
            appPath: "/Applications/CodexBar.app",
            source: .homebrewCask,
            sourceIdentifier: "replace:codexbar",
            currentVersion: "0.37.2",
            availableVersion: "0.41.0",
            status: .adoptable,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(result.message, "codexbar installed")
        XCTAssertEqual(runner.calls.map(\.arguments), [
            ["update", "--auto-update"],
            ["install", "--cask", "--force", "codexbar"]
        ])
        XCTAssertNil(runner.calls[0].environment["SUDO_ASKPASS"])
        XCTAssertEqual(runner.calls[1].environment["SUDO_ASKPASS"], "/tmp/AppMonitorAskpass-Test")
        XCTAssertNotNil(runner.calls[1].environment["APP_MONITOR_ASKPASS_ATTEMPT_ID"])
        XCTAssertEqual(
            runner.calls[1].environment["APP_MONITOR_ASKPASS_CONTEXT"],
            "update CodexBar with the codexbar Homebrew cask"
        )
        XCTAssertFalse(runner.calls[1].environment.keys.contains { $0.localizedCaseInsensitiveContains("password") })
    }

    func testHomebrewProviderUsesSecureAskpassHelperForManagedUpdates() async {
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(exitCode: 0, output: "sample-app upgraded")
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample App.app",
            source: .homebrewCask,
            sourceIdentifier: "sample-app",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(runner.calls.map(\.arguments), [
            ["update", "--auto-update"],
            ["upgrade", "--cask", "sample-app", "--no-ask", "--greedy"]
        ])
        XCTAssertEqual(runner.calls[1].environment["SUDO_ASKPASS"], "/tmp/AppMonitorAskpass-Test")
        XCTAssertNotNil(runner.calls[1].environment["APP_MONITOR_ASKPASS_ATTEMPT_ID"])
        XCTAssertEqual(
            runner.calls[1].environment["APP_MONITOR_ASKPASS_CONTEXT"],
            "update Sample App with Homebrew"
        )
        XCTAssertFalse(runner.calls[1].environment.keys.contains { $0.localizedCaseInsensitiveContains("password") })
    }

    func testHomebrewProviderDoesNotUseGreedyForFormulaUpdates() async {
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(exitCode: 0, output: "sdl3 upgraded")
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: nil,
            appName: "sdl3",
            bundleIdentifier: nil,
            appPath: nil,
            source: .homebrewFormula,
            sourceIdentifier: "sdl3",
            currentVersion: "3.4.10",
            availableVersion: "3.4.12",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(runner.calls.map(\.arguments), [
            ["update", "--auto-update"],
            ["upgrade", "--formula", "sdl3", "--no-ask"]
        ])
        XCTAssertEqual(runner.calls[1].environment["SUDO_ASKPASS"], "/tmp/AppMonitorAskpass-Test")
    }

    func testHomebrewProviderCondensesUsageFailuresToTheErrorLine() async {
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(
                exitCode: 1,
                output: "Usage: brew upgrade [options]\nA very long help page.\nError: Formula update failed."
            )
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: nil,
            appName: "sdl3",
            bundleIdentifier: nil,
            appPath: nil,
            source: .homebrewFormula,
            sourceIdentifier: "sdl3",
            currentVersion: "3.4.10",
            availableVersion: "3.4.12",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.message, "Error: Formula update failed.")
    }

    func testHomebrewProviderRepairsMissingCaskArtifactWithReinstall() async {
        let missingArtifactOutput = "Error: cursor: It seems the App source '/Applications/Cursor.app' is not there."
        let runner = RecordingUpdateCommandRunner(results: [
            ShellCommandResult(exitCode: 0, output: ""),
            ShellCommandResult(exitCode: 1, output: missingArtifactOutput),
            ShellCommandResult(exitCode: 0, output: "cursor reinstalled")
        ])
        let provider = HomebrewUpdateProvider(
            brewPath: "/opt/homebrew/bin/brew",
            includeFormulae: true,
            commandRunner: runner,
            askpassHelperURL: URL(fileURLWithPath: "/tmp/AppMonitorAskpass-Test")
        )
        let record = AppUpdateRecord(
            appID: "cursor",
            appName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            appPath: "/Applications/Cursor.app",
            source: .homebrewCask,
            sourceIdentifier: "cursor",
            currentVersion: "3.8.24,cf80f4b937f3b9c48070d7085129a838ce7876a3",
            availableVersion: "3.10.20,23b9fb205fe595ea2be29da7214e19762d037fc3",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )

        let result = await provider.performUpdate(record: record, mode: .manual, runID: "run")

        XCTAssertEqual(result.status, .updated)
        XCTAssertTrue(result.message?.contains("Repaired the missing app artifact") == true)
        XCTAssertEqual(runner.calls.map(\.arguments), [
            ["update", "--auto-update"],
            ["upgrade", "--cask", "cursor", "--no-ask", "--greedy"],
            ["reinstall", "--cask", "--force", "cursor"]
        ])
        XCTAssertEqual(runner.calls[2].environment["SUDO_ASKPASS"], "/tmp/AppMonitorAskpass-Test")
        XCTAssertNotEqual(
            runner.calls[1].environment["APP_MONITOR_ASKPASS_ATTEMPT_ID"],
            runner.calls[2].environment["APP_MONITOR_ASKPASS_ATTEMPT_ID"]
        )
    }

    func testMetadataProviderDisplaysPrimaryCaskVersion() {
        let app = sampleApp(
            name: "Codex Test Primary Cask",
            bundleID: "com.example.codex-test-primary-cask",
            version: "1.15962.1",
            path: "/Applications/Codex Test Primary Cask.app"
        )
        let json = """
        [
          {
            "token": "codex-test-primary-cask",
            "name": ["Codex Test Primary Cask"],
            "version": "1.19367.0,1a5be1fbf83d1832486e03a667557c18f0a0ec7a",
            "homepage": "https://claude.ai/download"
          }
        ]
        """

        let records = MetadataUpdateProvider.parseCaskMetadata(json: Data(json.utf8), apps: [app])

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first { $0.source == .metadata }?.availableVersion, "1.19367.0")
        let homebrewRecord = records.first { $0.source == .homebrewCask }
        XCTAssertEqual(homebrewRecord?.availableVersion, "1.19367.0")
        XCTAssertEqual(homebrewRecord?.sourceIdentifier, "replace:codex-test-primary-cask")
        XCTAssertEqual(homebrewRecord?.status, .adoptable)
        XCTAssertEqual(homebrewRecord?.installActionTitle, "Adopt with Homebrew")
    }

    func testElectronLatestYAMLParserPrefersMacARMDownload() throws {
        let yaml = """
        version: 5.50.2
        files:
          - url: Validity DemandTools-x64.zip
            size: 358968011
          - url: Validity DemandTools-arm64.dmg
            size: 365304583
        path: Validity DemandTools-x64.zip
        releaseNotes: Fixed sync handling
        releaseDate: '2026-06-19T09:57:58.483Z'
        """

        let item = try XCTUnwrap(ElectronUpdateProvider.parseLatestYAML(
            data: Data(yaml.utf8),
            baseURL: URL(string: "https://dt.validity.com/")!
        ))

        XCTAssertEqual(item.version, "5.50.2")
        XCTAssertEqual(item.url?.absoluteString, "https://dt.validity.com/Validity%20DemandTools-arm64.dmg")
        XCTAssertEqual(item.releaseNotes, "Fixed sync handling")
    }

    func testChangeLogEntryBuildsFromUpdateRecordAndResult() {
        let record = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample.app",
            source: .directDownload,
            sourceIdentifier: "https://example.com/appcast.xml",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .manualAction,
            checkedAt: Date(timeIntervalSince1970: 2_000),
            installActionTitle: "Open Updater",
            installActionURL: "https://example.com/Sample.zip",
            canInstall: false,
            releaseNotesTitle: "Version 2.0",
            releaseNotesSummary: "Added faster scans.",
            releaseNotesURL: "https://example.com/releases/2.0"
        )
        let result = UpdateItemResult(
            id: "result",
            runID: "run",
            updateID: record.id,
            appID: "app",
            appName: "Sample App",
            source: .directDownload,
            sourceIdentifier: "https://example.com/appcast.xml",
            status: .updated,
            completedAt: Date(timeIntervalSince1970: 2_100)
        )

        let entry = AppChangeLogEntry.fromUpdateRecord(record, result: result)

        XCTAssertEqual(entry.appID, "app")
        XCTAssertEqual(entry.fromVersion, "1.0")
        XCTAssertEqual(entry.toVersion, "2.0")
        XCTAssertEqual(entry.title, "Version 2.0")
        XCTAssertEqual(entry.summary, "Added faster scans.")
        XCTAssertEqual(entry.releaseNotesURL, "https://example.com/releases/2.0")
        XCTAssertEqual(entry.updateRunID, "run")
        XCTAssertEqual(entry.updateResultID, "result")
    }

    func testUpdateEligibilityHonorsSafetyRules() {
        let settings = AppUpdateSettings(automaticUpdatesEnabled: true)
        let eligible = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample.app",
            source: .homebrewCask,
            sourceIdentifier: "sample-app",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            installActionTitle: "Update",
            canInstall: true,
            isAutoEligible: true
        )

        XCTAssertTrue(AppUpdateEligibility.isAutoEligible(record: eligible, isAppRunning: false, settings: settings))
        XCTAssertFalse(AppUpdateEligibility.isAutoEligible(record: eligible, isAppRunning: true, settings: settings))

        let needsAdmin = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample.app",
            source: .macAppStore,
            sourceIdentifier: "123",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .needsAdmin,
            installActionTitle: "Update",
            requiresAdmin: true,
            canInstall: true,
            isAutoEligible: false
        )
        XCTAssertFalse(AppUpdateEligibility.isAutoEligible(record: needsAdmin, isAppRunning: false, settings: settings))

        let direct = AppUpdateRecord(
            appID: "app",
            appName: "Sample App",
            bundleIdentifier: "com.example.sample",
            appPath: "/Applications/Sample.app",
            source: .directDownload,
            sourceIdentifier: "https://example.com/appcast.xml",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .manualAction,
            installActionTitle: "Open Updater",
            canInstall: false,
            isAutoEligible: false
        )
        XCTAssertFalse(AppUpdateEligibility.isAutoEligible(record: direct, isAppRunning: false, settings: settings))
    }

    func testBulkHomebrewEligibilityIncludesAdoptionsAndManagedUpdates() {
        let settings = AppUpdateSettings(
            automaticUpdatesEnabled: false,
            includeHomebrewFormulae: true
        )
        let adoptable = AppUpdateRecord(
            appID: "adoptable",
            appName: "Adoptable App",
            bundleIdentifier: "com.example.adoptable",
            appPath: "/Applications/Adoptable App.app",
            source: .homebrewCask,
            sourceIdentifier: "adopt:adoptable-app",
            currentVersion: "1.0",
            availableVersion: "1.0",
            status: .adoptable,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )
        let caskUpdate = AppUpdateRecord(
            appID: "cask",
            appName: "Managed App",
            bundleIdentifier: "com.example.managed",
            appPath: "/Applications/Managed App.app",
            source: .homebrewCask,
            sourceIdentifier: "managed-app",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )
        let formulaUpdate = AppUpdateRecord(
            appID: nil,
            appName: "managed-formula",
            bundleIdentifier: nil,
            appPath: nil,
            source: .homebrewFormula,
            sourceIdentifier: "managed-formula",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )

        XCTAssertTrue(AppUpdateEligibility.isBulkHomebrewActionable(record: adoptable, settings: settings))
        XCTAssertTrue(AppUpdateEligibility.isBulkHomebrewActionable(record: caskUpdate, settings: settings))
        XCTAssertTrue(AppUpdateEligibility.isBulkHomebrewActionable(record: formulaUpdate, settings: settings))
    }

    func testBulkHomebrewEligibilityExcludesManualAndDisabledRecords() {
        let settings = AppUpdateSettings(
            automaticUpdatesEnabled: false,
            includeHomebrewFormulae: false
        )
        let formulaUpdate = AppUpdateRecord(
            appID: nil,
            appName: "managed-formula",
            bundleIdentifier: nil,
            appPath: nil,
            source: .homebrewFormula,
            sourceIdentifier: "managed-formula",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            installActionTitle: "Update with Homebrew",
            canInstall: true,
            isAutoEligible: true
        )
        let directUpdate = AppUpdateRecord(
            appID: "direct",
            appName: "Direct App",
            bundleIdentifier: "com.example.direct",
            appPath: "/Applications/Direct App.app",
            source: .directDownload,
            sourceIdentifier: "https://example.com/appcast.xml",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .manualAction,
            installActionTitle: "Open Updater",
            canInstall: true,
            isAutoEligible: false
        )
        let failedAdoption = AppUpdateRecord(
            appID: "failed",
            appName: "Failed App",
            bundleIdentifier: "com.example.failed",
            appPath: "/Applications/Failed App.app",
            source: .homebrewCask,
            sourceIdentifier: "adopt:failed-app",
            currentVersion: "1.0",
            availableVersion: "1.0",
            status: .failed,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )

        XCTAssertFalse(AppUpdateEligibility.isBulkHomebrewActionable(record: formulaUpdate, settings: settings))
        XCTAssertFalse(AppUpdateEligibility.isBulkHomebrewActionable(record: directUpdate, settings: settings))
        XCTAssertFalse(AppUpdateEligibility.isBulkHomebrewActionable(record: failedAdoption, settings: settings))
    }

    func testMacAppStoreUpdateIsResolvedWhenInstalledVersionCatchesUp() {
        let record = AppUpdateRecord(
            appID: "app-store-app",
            appName: "Did I Copy It?",
            bundleIdentifier: "com.underratedsoftware.didicopyit",
            appPath: "/Applications/Did I Copy It?.app",
            source: .macAppStore,
            sourceIdentifier: "6784293008",
            currentVersion: "1.0.0",
            availableVersion: "1.1.0",
            status: .manualAction,
            installActionTitle: "Update from App Store",
            canInstall: true,
            isAutoEligible: false
        )

        XCTAssertFalse(AppUpdateEligibility.isResolvedByInstalledVersion(record, installedVersion: "1.0.0"))
        XCTAssertTrue(AppUpdateEligibility.isResolvedByInstalledVersion(record, installedVersion: "1.1"))
        XCTAssertTrue(AppUpdateEligibility.isResolvedByInstalledVersion(record, installedVersion: "1.2.0"))

        let sparkleRecord = AppUpdateRecord(
            appID: "docky",
            appName: "Docky",
            bundleIdentifier: "gt.quintero.Docky",
            appPath: "/Applications/Docky.app",
            source: .directDownload,
            sourceIdentifier: "https://getdocky.com/releases/appcast.xml",
            currentVersion: "0.6.2",
            availableVersion: "0.8.0",
            status: .manualAction,
            installActionTitle: "Open Updater",
            canInstall: true,
            isAutoEligible: false
        )
        XCTAssertFalse(AppUpdateEligibility.isResolvedByInstalledVersion(sparkleRecord, installedVersion: "0.7.0"))
        XCTAssertTrue(AppUpdateEligibility.isResolvedByInstalledVersion(sparkleRecord, installedVersion: "0.8.0"))

        let adoption = AppUpdateRecord(
            appID: "adoptable",
            appName: "Adoptable App",
            bundleIdentifier: "com.example.adoptable",
            appPath: "/Applications/Adoptable App.app",
            source: .homebrewCask,
            sourceIdentifier: "adopt:adoptable-app",
            currentVersion: "1.0",
            availableVersion: "1.0",
            status: .adoptable,
            installActionTitle: "Adopt with Homebrew",
            canInstall: true,
            isAutoEligible: false
        )
        XCTAssertFalse(AppUpdateEligibility.isResolvedByInstalledVersion(adoption, installedVersion: "1.0"))
    }

    func testUpdatePersistenceAndSettingsRoundTrip() throws {
        let store = try temporaryStore()
        let app = sampleApp()
        let record = AppUpdateRecord(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .homebrewCask,
            sourceIdentifier: "sample-app",
            currentVersion: "1.0",
            availableVersion: "2.0",
            status: .available,
            checkedAt: Date(timeIntervalSince1970: 2_300),
            installActionTitle: "Update with Homebrew",
            installActionURL: "https://formulae.brew.sh/cask/sample-app",
            canInstall: true,
            isAutoEligible: true,
            message: "Ready"
        )
        let settings = AppUpdateSettings(
            scheduledChecksEnabled: true,
            automaticUpdatesEnabled: true,
            cadenceHours: 12,
            includeHomebrewFormulae: false,
            includeAppleSoftwareUpdates: true,
            includeDirectDownloadDetection: false,
            lastCheckAt: Date(timeIntervalSince1970: 2_400),
            nextCheckAt: Date(timeIntervalSince1970: 2_500)
        )
        let run = UpdateRunRecord(
            mode: .manual,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 2_600),
            completedAt: Date(timeIntervalSince1970: 2_601),
            selectedItemCount: 1,
            updatedItemCount: 1,
            failedItemCount: 0,
            skippedItemCount: 0
        )
        let result = UpdateItemResult(
            runID: run.id,
            updateID: record.id,
            appID: app.id,
            appName: app.name,
            source: .homebrewCask,
            sourceIdentifier: "sample-app",
            status: .updated,
            message: "Updated",
            completedAt: Date(timeIntervalSince1970: 2_601)
        )
        let changeLog = AppChangeLogEntry(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .homebrewCask,
            sourceIdentifier: "sample-app",
            fromVersion: "1.0",
            toVersion: "2.0",
            title: "Sample App 1.0 -> 2.0",
            summary: "Updated with Homebrew.",
            releaseNotesURL: "https://formulae.brew.sh/cask/sample-app",
            updateRunID: run.id,
            updateResultID: result.id,
            capturedAt: Date(timeIntervalSince1970: 2_601)
        )

        try store.replaceAppUpdates([record])
        try store.saveUpdateSettings(settings)
        try store.recordUpdateRun(run, itemResults: [result])
        try store.upsertChangeLogEntries([changeLog])

        XCTAssertEqual(try store.fetchAppUpdates(), [record])
        XCTAssertEqual(try store.fetchUpdateSettings(), settings)
        XCTAssertEqual(try store.fetchUpdateRuns(), [run])
        XCTAssertEqual(try store.fetchUpdateItemResults(), [result])
        XCTAssertEqual(try store.fetchChangeLogEntries(), [changeLog])
        XCTAssertEqual(try store.fetchChangeLogEntries(appID: app.id), [changeLog])
    }

    func testCSVExportEscapesFields() {
        let app = sampleApp(name: "Comma, App", path: "/Applications/Comma.app")
        let row = AppUsageRow(
            app: app,
            usageSeconds: 65,
            lastUsed: nil,
            bundleSizeBytes: 10,
            relatedSizeBytes: 20,
            warningCount: 0,
            scannedAt: Date()
        )

        let csv = CSVExporter.appRowsCSV(rows: [row])

        XCTAssertTrue(csv.contains("\"Comma, App\""))
        XCTAssertTrue(csv.contains("65"))
        XCTAssertTrue(csv.contains("1m 5s"))
    }

    func testTimelineCSVExportIncludesSessionAuditFields() {
        let session = TimelineSession(
            id: "session",
            appID: "app",
            appName: "Comma, App",
            appPath: "/Applications/Comma.app",
            bundleIdentifier: "com.example.comma",
            startedAt: ISO8601DateFormatter().date(from: "2026-07-08T08:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-07-08T08:01:05Z")!,
            source: "Measured",
            isClipped: true
        )

        let csv = CSVExporter.timelineSessionsCSV(rows: [session])

        XCTAssertTrue(csv.contains("\"Comma, App\""))
        XCTAssertTrue(csv.contains("Duration Seconds"))
        XCTAssertTrue(csv.contains("65"))
        XCTAssertTrue(csv.contains("true"))
        XCTAssertTrue(csv.contains("/Applications/Comma.app"))
    }

    func testWarningTriagePersistsSnapshotDispositionAndHistory() throws {
        let store = try temporaryStore()
        let warning = AppWarningItem(
            id: "health|app-1|Code Signing|Code Signature Issue",
            appID: "app-1",
            appName: "Example",
            appPath: "/Applications/Example.app",
            bundleIdentifier: "com.example.app",
            title: "Code Signature Issue",
            detail: "codesign rejected the bundle",
            recommendation: "Reinstall from a trusted source.",
            severity: .critical,
            category: .security,
            source: "Code Signing"
        )

        try store.upsertWarningTriageRecord(
            warning: warning,
            disposition: .acknowledged,
            action: "Acknowledged",
            detail: "Reviewed by user"
        )
        try store.upsertWarningTriageRecord(
            warning: warning,
            disposition: .falsePositive,
            action: "False Positive",
            detail: "Known local development build"
        )

        let record = try XCTUnwrap(store.fetchWarningTriageRecords().first)
        XCTAssertEqual(record.warningID, warning.id)
        XCTAssertEqual(record.disposition, .falsePositive)
        XCTAssertEqual(record.snapshot, warning)

        let events = try store.fetchWarningTriageHistory()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.action, "False Positive")
        XCTAssertEqual(Set(events.map(\.warningID)), [warning.id])
    }

    func testWarningTriageEventDoesNotDuplicateRecord() throws {
        let store = try temporaryStore()
        let warning = AppWarningItem(
            id: "storage|app-1|Caches|/tmp/cache",
            appID: "app-1",
            appName: "Example",
            appPath: "/Applications/Example.app",
            bundleIdentifier: nil,
            title: "Cache Scan Warning",
            detail: "Unable to enumerate",
            recommendation: "Review the path.",
            severity: .medium,
            category: .storage,
            source: "Storage Scan"
        )

        try store.upsertWarningTriageRecord(
            warning: warning,
            disposition: .open,
            action: "Rechecked",
            detail: "Still present"
        )
        try store.recordWarningTriageEvent(
            warning: warning,
            action: "Verification Failed",
            detail: "Still present"
        )

        XCTAssertEqual(try store.fetchWarningTriageRecords().count, 1)
        XCTAssertEqual(try store.fetchWarningTriageHistory().count, 2)
    }

    private func temporaryStore() throws -> AppDataStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("test.sqlite")
        return try AppDataStore(databaseURL: url)
    }

    func testInventoryReconciliationPrefersInstalledAppOverDeveloperArtifact() {
        let installed = sampleApp(path: "/Applications/Sample.app")
        let buildArtifact = MonitoredApp(
            id: "com.example.sample|/Users/test/Library/Developer/Xcode/DerivedData/App/Build/Products/Debug/Sample.app",
            name: "Sample",
            bundleIdentifier: "com.example.sample",
            version: "1.0",
            path: "/Users/test/Library/Developer/Xcode/DerivedData/App/Build/Products/Debug/Sample.app",
            isUserFacing: false
        )

        let reconciled = AppInventoryScanner.reconcileInventory([buildArtifact, installed])

        XCTAssertEqual(reconciled, [installed])
    }

    func testInventoryReconciliationKeepsAppsWithoutBundleIdentifiersDistinctByPath() {
        let first = MonitoredApp(id: "one", name: "One", bundleIdentifier: nil, version: nil, path: "/Applications/One.app", isUserFacing: true)
        let second = MonitoredApp(id: "two", name: "Two", bundleIdentifier: nil, version: nil, path: "/Applications/Two.app", isUserFacing: true)

        XCTAssertEqual(AppInventoryScanner.reconcileInventory([first, second]).count, 2)
    }

    func testUnscannedStorageIsNotFormattedAsConfirmedZero() {
        let app = sampleApp()
        let unscanned = AppUsageRow(app: app, usageSeconds: 0, lastUsed: nil, bundleSizeBytes: 0, relatedSizeBytes: 0, warningCount: 0, scannedAt: nil)
        let scannedEmpty = AppUsageRow(app: app, usageSeconds: 0, lastUsed: nil, bundleSizeBytes: 0, relatedSizeBytes: 0, warningCount: 0, scannedAt: Date())

        XCTAssertNil(unscanned.scannedTotalSizeBytes)
        XCTAssertEqual(AppMonitorFormatting.bytes(unscanned.scannedTotalSizeBytes), "Not scanned")
        XCTAssertEqual(AppMonitorFormatting.bytes(scannedEmpty.scannedTotalSizeBytes), "0 KB")
    }

    private func sampleApp(
        name: String = "Sample App",
        bundleID: String = "com.example.sample",
        version: String = "1.0",
        path: String = "/Applications/Sample.app",
        installedAt: Date? = nil,
        bundleCreatedAt: Date? = nil
    ) -> MonitoredApp {
        MonitoredApp(
            id: "\(bundleID)|\(path)",
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            path: path,
            isUserFacing: true,
            installedAt: installedAt,
            bundleCreatedAt: bundleCreatedAt
        )
    }
}

private final class RecordingUpdateCommandRunner: UpdateCommandRunning, @unchecked Sendable {
    struct Call: Equatable {
        let executable: String
        let arguments: [String]
        let environment: [String: String]
        let privileged: Bool
    }

    private var remainingResults: [ShellCommandResult]
    private(set) var calls: [Call] = []

    init(results: [ShellCommandResult]) {
        self.remainingResults = results
    }

    func run(_ executable: String, arguments: [String]) -> ShellCommandResult {
        calls.append(Call(executable: executable, arguments: arguments, environment: [:], privileged: false))
        return remainingResults.isEmpty ? ShellCommandResult(exitCode: 0, output: "") : remainingResults.removeFirst()
    }

    func run(_ executable: String, arguments: [String], environment: [String: String]) -> ShellCommandResult {
        calls.append(Call(executable: executable, arguments: arguments, environment: environment, privileged: false))
        return remainingResults.isEmpty ? ShellCommandResult(exitCode: 0, output: "") : remainingResults.removeFirst()
    }

    func runPrivileged(_ executable: String, arguments: [String]) -> ShellCommandResult {
        calls.append(Call(executable: executable, arguments: arguments, environment: [:], privileged: true))
        return remainingResults.isEmpty ? ShellCommandResult(exitCode: 0, output: "") : remainingResults.removeFirst()
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSnapshots: [StorageScanProgress] = []

    func append(_ snapshot: StorageScanProgress) {
        lock.lock()
        recordedSnapshots.append(snapshot)
        lock.unlock()
    }

    func snapshots() -> [StorageScanProgress] {
        lock.lock()
        let snapshots = recordedSnapshots
        lock.unlock()
        return snapshots
    }
}

private final class FakeTrashManager: UninstallTrashManaging {
    private let existingPaths: Set<String>
    private let failingPaths: Set<String>
    private(set) var trashedPaths: [String] = []

    init(existingPaths: Set<String>, failingPaths: Set<String> = []) {
        self.existingPaths = existingPaths
        self.failingPaths = failingPaths
    }

    func appMonitorFileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }

    func appMonitorTrashItem(at url: URL) throws -> URL? {
        let path = url.path
        trashedPaths.append(path)
        if failingPaths.contains(path) {
            throw NSError(domain: "FakeTrash", code: 1, userInfo: [NSLocalizedDescriptionKey: "Trash failed"])
        }
        return URL(fileURLWithPath: "/Users/test/.Trash").appendingPathComponent(url.lastPathComponent)
    }
}
