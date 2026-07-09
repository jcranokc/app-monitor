import AppKit
import AppMonitorCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 260, max: 260)
        } detail: {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    DashboardMainView()
                        .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)

                    Divider()
                        .opacity(0.55)

                    DashboardDetailPanel()
                        .frame(width: detailWidth(for: geometry.size.width))
                        .frame(maxHeight: .infinity)
                }
                .background(DashboardTheme.canvas)
            }
        }
        .sheet(item: $model.uninstallPlan) { plan in
            UninstallPlanSheet(plan: plan)
                .environmentObject(model)
        }
    }

    private func detailWidth(for width: CGFloat) -> CGFloat {
        min(360, max(320, width * 0.28))
    }
}

private enum DashboardTheme {
    static let canvas = Color.appMonitor(light: .init(0.985, 0.987, 0.992), dark: .init(0.055, 0.061, 0.075))
    static let sidebar = Color.appMonitor(light: .init(0.952, 0.962, 0.98), dark: .init(0.075, 0.084, 0.105))
    static let sidebarGlow = Color.appMonitor(light: .init(1, 1, 1, 0.72), dark: .init(0.105, 0.116, 0.145, 0.74))
    static let card = Color.appMonitor(light: .init(1, 1, 1, 0.94), dark: .init(0.115, 0.126, 0.158, 0.97))
    static let panel = Color.appMonitor(light: .init(1, 1, 1, 0.78), dark: .init(0.09, 0.101, 0.128, 0.9))
    static let control = Color.appMonitor(light: .init(1, 1, 1, 0.92), dark: .init(0.145, 0.157, 0.194, 0.96))
    static let controlPressed = Color.appMonitor(light: .init(0, 0, 0, 0.05), dark: .init(1, 1, 1, 0.08))
    static let subtleFill = Color.appMonitor(light: .init(0, 0, 0, 0.045), dark: .init(1, 1, 1, 0.065))
    static let track = Color.appMonitor(light: .init(0, 0, 0, 0.06), dark: .init(1, 1, 1, 0.105))
    static let trackStrong = Color.appMonitor(light: .init(0, 0, 0, 0.12), dark: .init(1, 1, 1, 0.16))
    static let cardStroke = Color.appMonitor(light: .init(0, 0, 0, 0.09), dark: .init(1, 1, 1, 0.10))
    static let softStroke = Color.appMonitor(light: .init(0, 0, 0, 0.06), dark: .init(1, 1, 1, 0.075))
    static let primaryText = Color.appMonitor(light: .init(0.055, 0.07, 0.105), dark: .init(0.91, 0.925, 0.965))
    static let secondaryText = Color.appMonitor(light: .init(0.39, 0.42, 0.49), dark: .init(0.62, 0.66, 0.74))
    static let accent = Color.appMonitor(light: .init(0.36, 0.25, 0.95), dark: .init(0.62, 0.54, 1))
    static let blue = Color.appMonitor(light: .init(0.21, 0.45, 0.92), dark: .init(0.36, 0.62, 1))
    static let green = Color.appMonitor(light: .init(0.2, 0.64, 0.36), dark: .init(0.35, 0.82, 0.52))
    static let orange = Color.appMonitor(light: .init(0.94, 0.55, 0.11), dark: .init(1, 0.63, 0.25))
    static let amber = Color.appMonitor(light: .init(0.70, 0.52, 0.14), dark: .init(0.95, 0.73, 0.26))
    static let red = Color.appMonitor(light: .init(0.86, 0.29, 0.21), dark: .init(1, 0.42, 0.36))
}

private struct AppMonitorLogoMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = AppBranding.logoImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "chart.bar.doc.horizontal")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(DashboardTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    AppMonitorLogoMark(size: 34)
                    Text("App Monitor")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                }
                .padding(.top, 14)

                Button {
                    model.navigate(.overview)
                } label: {
                    SidebarSelectionItem(title: "Overview", systemImage: "house", isSelected: model.destination == .overview)
                }
                .buttonStyle(.plain)

                SidebarGroup(title: "Applications") {
                    Button {
                        model.showAppList(.all)
                    } label: {
                        SidebarMetricItem(
                            title: "All Apps",
                            systemImage: "square.grid.2x2",
                            value: "\(model.rowCount(for: .all))",
                            isSelected: isAppListSelected(.all)
                        )
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.showAppList(.recentlyUsed)
                    } label: {
                        SidebarMetricItem(
                            title: "Recently Used",
                            systemImage: "clock",
                            value: "\(model.rowCount(for: .recentlyUsed))",
                            isSelected: isAppListSelected(.recentlyUsed)
                        )
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.showAppList(.neverUsed)
                    } label: {
                        SidebarMetricItem(
                            title: "Never Used",
                            systemImage: "clock.badge.questionmark",
                            value: "\(model.rowCount(for: .neverUsed))",
                            isSelected: isAppListSelected(.neverUsed)
                        )
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.showAppList(.systemApps)
                    } label: {
                        SidebarMetricItem(
                            title: "System Apps",
                            systemImage: "gearshape",
                            value: "\(model.rowCount(for: .systemApps))",
                            isSelected: isAppListSelected(.systemApps)
                        )
                    }
                    .buttonStyle(.plain)
                }

                SidebarGroup(title: "Storage") {
                    Button {
                        model.navigate(.storage)
                    } label: {
                        SidebarMetricItem(title: "Storage Overview", systemImage: "externaldrive", value: "", isSelected: model.destination == .storage)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.navigate(.largeFiles)
                    } label: {
                        SidebarMetricItem(title: "Large Files", systemImage: "folder", value: "\(largeFileCount)", isSelected: model.destination == .largeFiles)
                    }
                    .buttonStyle(.plain)
                }

                SidebarGroup(title: "Usage Analytics") {
                    Button {
                        model.navigate(.usageTrends)
                    } label: {
                        SidebarMetricItem(title: "Usage Trends", systemImage: "chart.xyaxis.line", value: "", isSelected: model.destination == .usageTrends)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.navigate(.activityTimeline)
                    } label: {
                        SidebarMetricItem(title: "Activity Timeline", systemImage: "point.3.connected.trianglepath.dotted", value: "", isSelected: model.destination == .activityTimeline)
                    }
                    .buttonStyle(.plain)
                }

                SidebarGroup(title: "") {
                    Button {
                        model.navigate(.warnings)
                    } label: {
                        SidebarMetricItem(title: "Warnings", systemImage: "exclamationmark.triangle", value: warningCountText, badgeColor: .orange.opacity(0.14), valueColor: DashboardTheme.orange, isSelected: model.destination == .warnings)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.showUpdates()
                    } label: {
                        SidebarMetricItem(title: "App Updates", systemImage: "arrow.down.circle", value: updateCountText, badgeColor: DashboardTheme.blue.opacity(0.13), valueColor: DashboardTheme.blue, isSelected: model.destination == .updates)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.navigate(.cleanup)
                    } label: {
                        SidebarMetricItem(title: "Cleanup Suggestions", systemImage: "shield.lefthalf.filled", value: compactBytes(potentialSavingsBytes), badgeColor: DashboardTheme.accent.opacity(0.12), valueColor: DashboardTheme.accent, isSelected: model.destination == .cleanup)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.navigate(.history)
                    } label: {
                        SidebarMetricItem(title: "History", systemImage: "clock.arrow.circlepath", value: "", isSelected: model.destination == .history)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.navigate(.settings)
                    } label: {
                        SidebarMetricItem(title: "Settings", systemImage: "gearshape", value: "", isSelected: model.destination == .settings)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 16)

                ScanStatusCard(lastScan: lastScanDate, nextScan: model.scanSchedule.nextScanAt)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [DashboardTheme.sidebar, DashboardTheme.sidebarGlow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var largeFileCount: Int {
        model.reviewLargeFileCount
    }

    private var warningCountText: String {
        let count = model.warningCount
        return count == 0 ? "" : "\(count)"
    }

    private var updateCountText: String {
        let count = model.availableUpdateCount
        return count == 0 ? "" : "\(count)"
    }

    private var potentialSavingsBytes: Int64 {
        model.potentialSavingsBytes
    }

    private var lastScanDate: Date? {
        model.scanSchedule.lastScanAt ?? model.rows.compactMap(\.scannedAt).max()
    }

    private func isAppListSelected(_ filter: AppModel.AppListQuickFilter) -> Bool {
        model.destination == .usageTable && model.appListQuickFilter == filter
    }
}

private struct DashboardMainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsCleanupNotice = false

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            DashboardToolbar(showsCleanupNotice: $showsCleanupNotice)

            ScrollView {
                Group {
                    if model.destination == .overview {
                        overviewContent
                    } else {
                        DashboardDestinationContent()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .id(model.destination)
        }
        .alert("Cleanup needs a cleanup engine", isPresented: $showsCleanupNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The dashboard can estimate possible savings from related files, but deletion, safety checks, permissions, and undo are not implemented yet.")
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Overview", subtitle: "Your Mac at a glance")
                .padding(.top, 6)

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryCard(
                    title: "Applications",
                    systemImage: "circle.hexagongrid",
                    value: "\(model.rows.count)",
                    unit: nil,
                    subtitle: "Installed",
                    footer: "\(recentlyDiscoveredCount) discovered this week",
                    footerSystemImage: "arrow.up.right",
                    tint: DashboardTheme.accent
                )

                SummaryCard(
                    title: "Used This Period",
                    systemImage: "clock",
                    value: "\(recentlyUsedCount)",
                    unit: nil,
                    subtitle: "Apps",
                    footer: "\(model.displayedRows.count) matching filters",
                    footerSystemImage: "arrow.down",
                    tint: DashboardTheme.blue
                )

                SummaryCard(
                    title: "Unused 30 Days",
                    systemImage: "sparkle.magnifyingglass",
                    value: "\(unusedCount)",
                    unit: nil,
                    subtitle: "Apps",
                    footer: "Review recommended",
                    footerSystemImage: "exclamationmark.triangle.fill",
                    tint: DashboardTheme.orange
                )

                SummaryCard(
                    title: "Storage Used",
                    systemImage: "shippingbox",
                    value: compactBytes(model.scannedSizeBytes),
                    unit: nil,
                    subtitle: "Total",
                    footer: "\(compactBytes(weeklyStorageDelta)) this week",
                    footerSystemImage: "arrow.up.right",
                    tint: DashboardTheme.accent
                )

                SummaryCard(
                    title: "Potential Savings",
                    systemImage: "leaf",
                    value: compactBytes(potentialSavingsBytes),
                    unit: nil,
                    subtitle: "Reviewed",
                    footer: "\(cleanupSuggestionCount) suggestions",
                    footerSystemImage: "checkmark.circle.fill",
                    tint: DashboardTheme.green,
                    isSoftGreen: true
                )
            }

            HStack(alignment: .top, spacing: 16) {
                RecentActivityCard()
                    .frame(maxWidth: .infinity)
                StorageBreakdownCard()
                    .frame(maxWidth: .infinity)
            }

            UsageTrendsCard()
        }
    }

    private var recentlyUsedCount: Int {
        model.rows.filter { $0.usageSeconds > 0 || $0.importedDaysInPeriod > 0 }.count
    }

    private var unusedCount: Int {
        model.rows.filter(isUnusedForThirtyDays).count
    }

    private var potentialSavingsBytes: Int64 {
        model.potentialSavingsBytes
    }

    private var cleanupSuggestionCount: Int {
        model.activeCleanupSuggestions.count
    }

    private var weeklyStorageDelta: Int64 {
        model.rows
            .filter { $0.scannedAt.map { Calendar.current.isDate($0, equalTo: Date(), toGranularity: .weekOfYear) } ?? false }
            .reduce(0) { $0 + $1.totalSizeBytes }
    }

    private var recentlyDiscoveredCount: Int {
        model.rows.filter { Calendar.current.isDate($0.app.lastSeen, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }
}

private struct DashboardDestinationContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.destination {
        case .overview:
            EmptyView()
        case .storage:
            StorageExplorerScreen()
        case .largeFiles:
            LargeFilesScreen()
        case .usageTable:
            UsageTableScreen()
        case .usageTrends:
            UsageTrendsWorkspace()
        case .activityTimeline:
            ActivityTimelineScreen()
        case .warnings:
            WarningsScreen()
        case .updates:
            UpdatesScreen()
        case .cleanup:
            CleanupCenterScreen()
        case .history:
            HistoryScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

private struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryText)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(DashboardTheme.secondaryText)
        }
    }
}

private struct UsageTableScreen: View {
    @EnvironmentObject private var model: AppModel
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeader {
                ScreenHeader(title: model.appListQuickFilter.tableTitle, subtitle: model.appListQuickFilter.tableSubtitle)
                    .padding(.top, 6)
            }

            DashboardCard {
                VStack(spacing: 0) {
                    UsageTableHeader()
                    Divider()
                    ForEach(Array(model.displayedRows.prefix(80))) { row in
                        Button {
                            model.select(row)
                        } label: {
                            UsageTableRow(row: row)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct UsageTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("App").frame(maxWidth: .infinity, alignment: .leading)
            Text("Usage").frame(width: 86, alignment: .trailing)
            Text("Last Used").frame(width: 112, alignment: .leading)
            Text("Storage").frame(width: 92, alignment: .trailing)
            Text("Status").frame(width: 88, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DashboardTheme.secondaryText)
        .padding(.vertical, 8)
    }
}

private struct UsageTableRow: View {
    let row: AppUsageRow

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                AppIcon(path: row.app.path, size: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.app.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(row.app.bundleIdentifier ?? row.app.path)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppMonitorFormatting.duration(row.usageSeconds))
                .font(.callout)
                .monospacedDigit()
                .frame(width: 86, alignment: .trailing)
            Text(AppMonitorFormatting.shortDateTime(row.lastSeen))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 112, alignment: .leading)
            Text(compactBytes(row.totalSizeBytes))
                .font(.callout)
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)
            Text(row.scanStatus)
                .font(.caption.weight(.medium))
                .foregroundStyle(row.warningCount > 0 ? DashboardTheme.orange : DashboardTheme.secondaryText)
                .frame(width: 88, alignment: .leading)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

private struct UnusedStoragePassUsageTrendsWorkspace: View {
    @EnvironmentObject private var model: AppModel

    private let metricColumns = [
        GridItem(.adaptive(minimum: 170), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                ScreenHeader(title: "Usage Trends", subtitle: "Usage summaries, top apps, and active-hour patterns")
                    .padding(.top, 6)
                Spacer()
                Menu {
                    ForEach(UsageTrendGrouping.allCases) { grouping in
                        Button {
                            model.usageTrendGrouping = grouping
                        } label: {
                            if model.usageTrendGrouping == grouping {
                                Label(grouping.rawValue, systemImage: "checkmark")
                            } else {
                                Text(grouping.rawValue)
                            }
                        }
                    }
                } label: {
                    ToolbarControl(title: model.usageTrendGrouping.rawValue, systemImage: nil, trailingSystemImage: "chevron.down", compact: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: metricColumns, spacing: 12) {
                AnalyticsMetricCard(
                    title: "Total Usage",
                    value: AppMonitorFormatting.duration(snapshot.summary.totalSeconds),
                    detail: analyticsDeltaText(snapshot.summary.comparison.totalPercentChange),
                    systemImage: "clock.fill",
                    tint: DashboardTheme.accent
                )
                AnalyticsMetricCard(
                    title: "Daily Average",
                    value: AppMonitorFormatting.duration(snapshot.summary.dailyAverageSeconds),
                    detail: analyticsDeltaText(snapshot.summary.comparison.dailyAveragePercentChange),
                    systemImage: "chart.bar.fill",
                    tint: DashboardTheme.blue
                )
                AnalyticsMetricCard(
                    title: "Peak Day",
                    value: snapshot.summary.peakDay.map(AppMonitorFormatting.day) ?? "No data",
                    detail: AppMonitorFormatting.duration(snapshot.summary.peakDaySeconds),
                    systemImage: "calendar.badge.clock",
                    tint: DashboardTheme.green
                )
                AnalyticsMetricCard(
                    title: "Sessions",
                    value: "\(snapshot.summary.sessionCount)",
                    detail: analyticsDeltaText(snapshot.summary.comparison.sessionPercentChange),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: DashboardTheme.orange
                )
            }

            DashboardCard {
                CardHeader(title: "Usage Over Time", subtitle: "\(snapshot.grouping.rawValue) stacked by top applications")
                if snapshot.trendBuckets.isEmpty {
                    EmptyCardState(systemImage: "chart.xyaxis.line", message: "Usage trends will appear after App Monitor records active windows.")
                        .frame(height: 190)
                } else {
                    UsageAnalyticsBucketChart(buckets: snapshot.trendBuckets)
                        .frame(height: 210)
                        .padding(.top, 12)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                UsageAnalyticsTopAppsCard(topApps: snapshot.topApps)
                    .frame(maxWidth: .infinity, minHeight: 280)
                UsageAnalyticsHeatmapCard(cells: snapshot.heatmapCells)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
    }

    private var snapshot: UsageAnalyticsSnapshot {
        model.usageAnalytics
    }
}

private struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
    }
}

private struct UsageAnalyticsBucketChart: View {
    let buckets: [UsageTrendBucket]

    var body: some View {
        GeometryReader { geometry in
            let maxSeconds = max(buckets.map(\.totalSeconds).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 8) {
                        VStack(spacing: 1) {
                            ForEach(bucket.stacks) { stack in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(stackColor(stack))
                                    .frame(height: stackHeight(stack, bucket: bucket, maxSeconds: maxSeconds, availableHeight: geometry.size.height - 28))
                            }
                            if bucket.stacks.isEmpty {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(DashboardTheme.track)
                                    .frame(height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: geometry.size.height - 28, alignment: .bottom)

                        Text(bucketLabel(bucket.start))
                            .font(.caption2)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stackHeight(_ stack: UsageStackSegment, bucket: UsageTrendBucket, maxSeconds: TimeInterval, availableHeight: CGFloat) -> CGFloat {
        guard bucket.totalSeconds > 0, maxSeconds > 0 else { return 0 }
        let bucketHeight = max(6, availableHeight * CGFloat(bucket.totalSeconds / maxSeconds))
        return max(4, bucketHeight * CGFloat(stack.percentOfBucket))
    }

    private func stackColor(_ stack: UsageStackSegment) -> Color {
        if stack.isOther { return Color.gray.opacity(0.72) }
        let colors = tileColors
        let index = abs(stack.appID.hashValue) % colors.count
        return colors[index]
    }

    private func bucketLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

private struct UsageAnalyticsTopAppsCard: View {
    @EnvironmentObject private var model: AppModel
    let topApps: [TopAppUsage]

    var body: some View {
        DashboardCard {
            CardHeader(title: "Top Apps", subtitle: "Highest measured usage")
            if topApps.isEmpty {
                EmptyCardState(systemImage: "app.badge", message: "Top apps will appear after usage is recorded.")
                    .frame(height: 210)
            } else {
                VStack(spacing: 13) {
                    ForEach(Array(topApps.prefix(7))) { app in
                        Button {
                            model.selectApp(id: app.appID)
                        } label: {
                            HStack(spacing: 10) {
                                AppIcon(path: app.appPath, size: 26)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.appName)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(DashboardTheme.track)
                                            Capsule()
                                                .fill(DashboardTheme.accent)
                                                .frame(width: max(5, geometry.size.width * CGFloat(app.percentOfTotal)))
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                Spacer()
                                Text(AppMonitorFormatting.duration(app.seconds))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .frame(width: 64, alignment: .trailing)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 14)
            }
        }
    }
}

private struct UsageAnalyticsHeatmapCard: View {
    let cells: [UsageHeatmapCell]

    var body: some View {
        DashboardCard {
            CardHeader(title: "Active Hours", subtitle: "Hourly usage heatmap")
            if rows.isEmpty {
                EmptyCardState(systemImage: "square.grid.3x3", message: "Hourly patterns will appear after usage is recorded.")
                    .frame(height: 210)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(rows.prefix(8), id: \.label) { row in
                        HStack(spacing: 5) {
                            Text(row.label)
                                .font(.caption2)
                                .foregroundStyle(DashboardTheme.secondaryText)
                                .frame(width: 48, alignment: .leading)
                            ForEach(row.cells) { cell in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(heatmapColor(for: cell))
                                    .frame(width: 10, height: 10)
                                    .help("\(row.label), \(cell.hourOfDay):00: \(AppMonitorFormatting.duration(cell.seconds))")
                            }
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var rows: [(label: String, cells: [UsageHeatmapCell])] {
        Dictionary(grouping: cells, by: \.rowLabel)
            .map { label, cells in
                (label, cells.sorted { $0.hourOfDay < $1.hourOfDay })
            }
            .sorted { lhs, rhs in
                (lhs.cells.first?.rowStart ?? .distantPast) < (rhs.cells.first?.rowStart ?? .distantPast)
            }
    }

    private func heatmapColor(for cell: UsageHeatmapCell) -> Color {
        guard maxSeconds > 0, cell.seconds > 0 else {
            return DashboardTheme.track
        }
        return DashboardTheme.accent.opacity(0.18 + 0.72 * min(1, cell.seconds / maxSeconds))
    }

    private var maxSeconds: TimeInterval {
        cells.map(\.seconds).max() ?? 0
    }
}

private struct StorageExplorerScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedCategory: StorageCategory?
    @State private var sortMode = StorageExplorerSort.size

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Storage Overview", subtitle: "See where your storage is being used and explore what's taking up space.")
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 12) {
                TotalStorageUsedCard(
                    scannedBytes: model.scannedSizeBytes,
                    volumeSnapshot: volumeSnapshot,
                    categoryTotals: categoryTotals
                )
                .frame(maxWidth: .infinity, minHeight: 126)

                LargestStorageCategoryCard(total: categoryTotals.first, totalBytes: totalTrackedBytes)
                    .frame(width: 310)
                    .frame(minHeight: 126)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                ForEach(categoryTotals) { total in
                    Button {
                        selectedCategory = selectedCategory == total.category ? nil : total.category
                    } label: {
                        StorageCategoryOverviewCard(
                            total: total,
                            totalBytes: totalTrackedBytes,
                            isSelected: selectedCategory == total.category
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                StorageDistributionCard(categoryTotals: categoryTotals, totalBytes: totalTrackedBytes)
                    .frame(maxWidth: .infinity, minHeight: 230)
                TopApplicationsByStorageCard(rows: topStorageRows)
                    .frame(width: 360)
                    .frame(minHeight: 230)
            }

            StorageExplorerTable(
                items: visibleStorageItems,
                maxItemBytes: maxVisibleItemBytes,
                selectedCategory: $selectedCategory,
                sortMode: $sortMode
            )
        }
    }

    private var storageItems: [StorageScanItem] {
        model.allStorageItems.sorted { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes { return lhs.path < rhs.path }
            return lhs.sizeBytes > rhs.sizeBytes
        }
    }

    private var visibleStorageItems: [StorageScanItem] {
        let filtered = storageItems.filter { item in
            guard let selectedCategory else { return true }
            return item.category == selectedCategory
        }

        switch sortMode {
        case .size:
            return filtered.sorted {
                if $0.sizeBytes == $1.sizeBytes { return $0.path < $1.path }
                return $0.sizeBytes > $1.sizeBytes
            }
        case .name:
            return filtered.sorted {
                URL(fileURLWithPath: $0.path).lastPathComponent.localizedCaseInsensitiveCompare(
                    URL(fileURLWithPath: $1.path).lastPathComponent
                ) == .orderedAscending
            }
        case .category:
            return filtered.sorted {
                if $0.category.rawValue == $1.category.rawValue { return $0.path < $1.path }
                return $0.category.rawValue < $1.category.rawValue
            }
        }
    }

    private var categoryTotals: [StorageCategoryTotal] {
        let grouped = Dictionary(grouping: storageItems, by: \.category)
        return StorageCategory.allCases.compactMap { category in
            let items = grouped[category] ?? []
            let bytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
            guard bytes > 0 else { return nil }
            return StorageCategoryTotal(category: category, bytes: bytes, itemCount: items.count)
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private var totalTrackedBytes: Int64 {
        categoryTotals.reduce(0) { $0 + $1.bytes }
    }

    private var maxVisibleItemBytes: Int64 {
        max(visibleStorageItems.map(\.sizeBytes).max() ?? 1, 1)
    }

    private var topStorageRows: [AppUsageRow] {
        Array(model.rows.filter { $0.totalSizeBytes > 0 }.sorted { $0.totalSizeBytes > $1.totalSizeBytes }.prefix(5))
    }

    private var volumeSnapshot: VolumeStorageSnapshot {
        VolumeStorageSnapshot.current()
    }
}

private struct LargeFilesScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Large Files", subtitle: "Standalone file index for path-level review")
                .padding(.top, 6)

            DashboardCard {
                VStack(alignment: .leading, spacing: 0) {
                    CardHeader(title: "Review Queue", subtitle: "\(model.reviewLargeFileCount) file\(model.reviewLargeFileCount == 1 ? "" : "s") need review")
                    if model.largeFiles.isEmpty {
                        EmptyCardState(systemImage: "folder", message: "Run Scan to build the large-file index.")
                            .frame(height: 160)
                    } else {
                        ForEach(model.largeFiles) { record in
                            Divider()
                            HStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .frame(width: 24)
                                    .foregroundStyle(DashboardTheme.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(URL(fileURLWithPath: record.path).lastPathComponent)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    Text("\(model.appName(for: record.appID)) · \(record.category.rawValue) · \(record.riskReason)")
                                        .font(.caption)
                                        .foregroundStyle(DashboardTheme.secondaryText)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(compactBytes(record.sizeBytes))
                                    .font(.callout)
                                    .monospacedDigit()
                                Text(record.state.rawValue)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(record.state == .needsReview ? DashboardTheme.orange : DashboardTheme.secondaryText)
                                    .frame(width: 82, alignment: .leading)
                                Menu {
                                    Button("Preview") { model.preview(path: record.path) }
                                    Button("Reveal in Finder") { model.revealInFinder(path: record.path) }
                                    Button("Move to Quarantine") { model.quarantineLargeFile(record) }
                                    Button("Ignore") { model.ignoreLargeFile(record) }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }
}

private enum ActivityTimelineMode: String, CaseIterable, Identifiable {
    case timeline = "Timeline"
    case list = "List"
    case heatmap = "Heatmap"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .timeline:
            return "point.3.connected.trianglepath.dotted"
        case .list:
            return "list.bullet.rectangle"
        case .heatmap:
            return "square.grid.3x3.fill"
        }
    }
}

private enum ActivityTimelineGrouping: String, CaseIterable, Identifiable {
    case day = "Day"
    case app = "App"
    case hour = "Hour"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .day:
            return "calendar"
        case .app:
            return "app"
        case .hour:
            return "clock"
        }
    }
}

private struct TimelineHourSelection: Equatable {
    let dayStart: Date
    let hourStart: Date
}

private struct ActivityTimelineScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: ActivityTimelineMode = .timeline
    @State private var grouping: ActivityTimelineGrouping = .day
    @State private var hourSelection: TimelineHourSelection?

    var body: some View {
        let summary = model.timelineSummary
        let allSessions = model.timelineSessions
        let sessions = filteredSessions(allSessions)
        let dayGroups = hourSelection == nil
            ? model.timelineDayGroups
            : TimelineDataBuilder.dayGroups(from: sessions, calendar: .current)
        let hourBuckets = hourSelection == nil
            ? model.timelineHourBuckets
            : TimelineDataBuilder.hourBuckets(from: sessions, calendar: .current)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 16) {
                ScreenHeader(title: "Activity Timeline", subtitle: "Detailed view of app usage sessions")
                    .padding(.top, 6)
                Spacer()
                Button {
                    model.exportTimelineSessions()
                } label: {
                    ToolbarControl(title: "Export", systemImage: "square.and.arrow.up", compact: true)
                }
                .buttonStyle(.plain)
            }

            TimelineSummaryGrid(summary: summary)

            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(ActivityTimelineMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Menu {
                    ForEach(ActivityTimelineGrouping.allCases) { option in
                        Button {
                            grouping = option
                        } label: {
                            if grouping == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Label(option.rawValue, systemImage: option.systemImage)
                            }
                        }
                    }
                } label: {
                    ToolbarControl(title: "Group by \(grouping.rawValue)", systemImage: "rectangle.3.group", trailingSystemImage: "chevron.down", compact: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                if let hourSelection {
                    Button {
                        self.hourSelection = nil
                    } label: {
                        ToolbarControl(title: hourFilterLabel(hourSelection), systemImage: "xmark.circle", compact: true)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            switch mode {
            case .timeline:
                TimelineModeContent(
                    grouping: grouping,
                    sessions: sessions,
                    dayGroups: dayGroups,
                    hourBuckets: hourBuckets
                ) { bucket in
                    hourSelection = TimelineHourSelection(dayStart: bucket.dayStart, hourStart: bucket.hourStart)
                    grouping = .hour
                }
            case .list:
                TimelineListMode(sessions: sessions)
            case .heatmap:
                TimelineHeatmapMode(buckets: model.timelineHourBuckets) { bucket in
                    hourSelection = TimelineHourSelection(dayStart: bucket.dayStart, hourStart: bucket.hourStart)
                    grouping = .hour
                    mode = .timeline
                }
            }
        }
    }

    private func filteredSessions(_ sessions: [TimelineSession]) -> [TimelineSession] {
        guard let hourSelection else { return sessions }
        guard let hourEnd = Calendar.current.date(byAdding: .hour, value: 1, to: hourSelection.hourStart) else {
            return sessions
        }

        return sessions.filter { session in
            Calendar.current.isDate(session.startedAt, inSameDayAs: hourSelection.dayStart)
                && session.endedAt > hourSelection.hourStart
                && session.startedAt < hourEnd
        }
    }

    private func hourFilterLabel(_ selection: TimelineHourSelection) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "ha"
        return "\(dayFormatter.string(from: selection.dayStart)) \(hourFormatter.string(from: selection.hourStart))"
    }
}

private struct TimelineSummaryGrid: View {
    let summary: TimelineSummary

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 100), spacing: 10), count: 5), spacing: 10) {
            TimelineMetricCard(
                title: "Total Usage",
                systemImage: "clock.fill",
                value: AppMonitorFormatting.duration(summary.totalUsageSeconds),
                subtitle: "\(summary.sessionCount) session\(summary.sessionCount == 1 ? "" : "s")",
                delta: summary.totalUsageDelta,
                tint: DashboardTheme.accent
            )
            TimelineMetricCard(
                title: "Daily Average",
                systemImage: "chart.bar.fill",
                value: AppMonitorFormatting.duration(summary.dailyAverageSeconds),
                subtitle: "Per represented day",
                delta: summary.dailyAverageDelta,
                tint: DashboardTheme.blue
            )
            TimelineMetricCard(
                title: "Longest Session",
                systemImage: "arrow.left.and.right",
                value: AppMonitorFormatting.duration(summary.longestSession?.durationSeconds ?? 0),
                subtitle: summary.longestSession?.appName ?? "No sessions",
                delta: summary.longestSessionDelta,
                tint: DashboardTheme.green
            )
            TimelineMetricCard(
                title: "Most Active Day",
                systemImage: "calendar",
                value: summary.mostActiveDay.map { timelineDayShort($0.dayStart) } ?? "None",
                subtitle: AppMonitorFormatting.duration(summary.mostActiveDay?.durationSeconds ?? 0),
                delta: summary.mostActiveDayDelta,
                tint: DashboardTheme.orange
            )
            TimelineMetricCard(
                title: "Total Sessions",
                systemImage: "rectangle.stack.fill",
                value: "\(summary.sessionCount)",
                subtitle: "After day splitting",
                delta: summary.sessionCountDelta,
                tint: DashboardTheme.red
            )
        }
    }
}

private struct TimelineMetricCard: View {
    let title: String
    let systemImage: String
    let value: String
    let subtitle: String
    let delta: TimelineMetricDelta
    let tint: Color

    var body: some View {
        let deltaDisplay = timelineDeltaDisplay(delta)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(minWidth: 72, alignment: .leading)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 5) {
                Image(systemName: deltaDisplay.systemImage)
                    .font(.caption2.weight(.semibold))
                Text(deltaDisplay.text)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(deltaDisplay.color)
        }
        .padding(13)
        .frame(minHeight: 126, alignment: .topLeading)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private struct TimelineModeContent: View {
    let grouping: ActivityTimelineGrouping
    let sessions: [TimelineSession]
    let dayGroups: [TimelineDayGroup]
    let hourBuckets: [TimelineHourBucket]
    let onHourBucketSelect: (TimelineHourBucket) -> Void

    @ViewBuilder
    var body: some View {
        if sessions.isEmpty {
            DashboardCard {
                EmptyCardState(systemImage: "point.3.connected.trianglepath.dotted", message: "Usage sessions will appear after App Monitor records active windows.")
                    .frame(height: 210)
            }
        } else {
            switch grouping {
            case .day:
                VStack(spacing: 14) {
                    ForEach(dayGroups) { group in
                        TimelineDayGroupCard(group: group)
                    }
                }
            case .app:
                TimelineAppGroupedContent(sessions: sessions)
            case .hour:
                TimelineHourGroupedContent(
                    buckets: hourBuckets,
                    sessions: sessions,
                    onBucketSelect: onHourBucketSelect
                )
            }
        }
    }
}

private struct TimelineAppSessionGroup: Identifiable {
    let id: String
    let appID: String
    let appName: String
    let appPath: String
    let bundleIdentifier: String?
    let dayLanes: [TimelineAppDayLane]
    let totalDurationSeconds: TimeInterval
    let sessionCount: Int
    let colorIndex: Int
}

private struct TimelineAppDayLane: Identifiable {
    let id: String
    let dayStart: Date
    let sessions: [TimelineSession]
    let totalDurationSeconds: TimeInterval
}

private struct TimelineAppGroupedContent: View {
    let sessions: [TimelineSession]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(appGroups) { group in
                TimelineAppGroupCard(group: group)
            }
        }
    }

    private var appGroups: [TimelineAppSessionGroup] {
        let sessionsByApp = Dictionary(grouping: sessions, by: \.appID)
        return sessionsByApp.compactMap { appID, appSessions -> TimelineAppSessionGroup? in
            let sortedAppSessions = appSessions.sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt { return lhs.id < rhs.id }
                return lhs.startedAt < rhs.startedAt
            }
            guard let first = sortedAppSessions.first else { return nil }

            let lanes = Dictionary(grouping: sortedAppSessions) { session in
                Calendar.current.startOfDay(for: session.startedAt)
            }
            .map { dayStart, daySessions in
                let sortedDaySessions = daySessions.sorted { lhs, rhs in
                    if lhs.startedAt == rhs.startedAt { return lhs.id < rhs.id }
                    return lhs.startedAt < rhs.startedAt
                }
                return TimelineAppDayLane(
                    id: "\(appID)|\(Int(dayStart.timeIntervalSince1970))",
                    dayStart: dayStart,
                    sessions: sortedDaySessions,
                    totalDurationSeconds: sortedDaySessions.reduce(0) { $0 + $1.durationSeconds }
                )
            }
            .sorted { lhs, rhs in
                if lhs.dayStart == rhs.dayStart { return lhs.id < rhs.id }
                return lhs.dayStart > rhs.dayStart
            }

            return TimelineAppSessionGroup(
                id: appID,
                appID: appID,
                appName: first.appName,
                appPath: first.appPath,
                bundleIdentifier: first.bundleIdentifier,
                dayLanes: lanes,
                totalDurationSeconds: sortedAppSessions.reduce(0) { $0 + $1.durationSeconds },
                sessionCount: sortedAppSessions.count,
                colorIndex: stableTimelineColorIndex(for: appID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalDurationSeconds == rhs.totalDurationSeconds {
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
            return lhs.totalDurationSeconds > rhs.totalDurationSeconds
        }
    }
}

private struct TimelineAppGroupCard: View {
    @EnvironmentObject private var model: AppModel
    let group: TimelineAppSessionGroup

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        model.selectTimelineApp(appID: group.appID)
                    } label: {
                        HStack(spacing: 10) {
                            AppIcon(path: group.appPath, size: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.appName)
                                    .font(.headline)
                                    .foregroundStyle(DashboardTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s") · \(group.dayLanes.count) day\(group.dayLanes.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(DashboardTheme.secondaryText)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(group.appPath)

                    Spacer()

                    Text(AppMonitorFormatting.duration(group.totalDurationSeconds))
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()
                }

                TimelineRuler()

                VStack(spacing: 8) {
                    ForEach(group.dayLanes) { lane in
                        TimelineAppDayLaneRow(group: group, lane: lane)
                    }
                }
            }
        }
    }
}

private struct TimelineAppDayLaneRow: View {
    @EnvironmentObject private var model: AppModel
    let group: TimelineAppSessionGroup
    let lane: TimelineAppDayLane

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.selectTimelineApp(appID: group.appID)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timelineDayTitle(lane.dayStart))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text("\(lane.sessions.count) session\(lane.sessions.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                }
                .frame(width: TimelineLayout.labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DashboardTheme.subtleFill)
                    TimelineGridLines()
                    ForEach(lane.sessions) { session in
                        TimelineSessionBar(
                            session: session,
                            dayStart: lane.dayStart,
                            color: timelineColor(for: group.colorIndex),
                            availableWidth: geometry.size.width
                        )
                    }
                }
            }
            .frame(height: TimelineLayout.laneHeight)

            Text(AppMonitorFormatting.duration(lane.totalDurationSeconds))
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: TimelineLayout.durationWidth, alignment: .trailing)
        }
    }
}

private struct TimelineHourGroupedContent: View {
    let buckets: [TimelineHourBucket]
    let sessions: [TimelineSession]
    let onBucketSelect: (TimelineHourBucket) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(days, id: \.self) { day in
                TimelineHourDayGroupCard(
                    day: day,
                    buckets: bucketsForDay(day),
                    sessions: sessionsForDay(day),
                    maxSeconds: maxSeconds,
                    onBucketSelect: onBucketSelect
                )
            }
        }
    }

    private var days: [Date] {
        Array(Set(buckets.map(\.dayStart))).sorted(by: >)
    }

    private var maxSeconds: TimeInterval {
        max(buckets.map(\.totalDurationSeconds).max() ?? 1, 1)
    }

    private func bucketsForDay(_ day: Date) -> [TimelineHourBucket] {
        buckets
            .filter { Calendar.current.isDate($0.dayStart, inSameDayAs: day) }
            .sorted { $0.hourStart < $1.hourStart }
    }

    private func sessionsForDay(_ day: Date) -> [TimelineSession] {
        sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
    }
}

private struct TimelineHourDayGroupCard: View {
    let day: Date
    let buckets: [TimelineHourBucket]
    let sessions: [TimelineSession]
    let maxSeconds: TimeInterval
    let onBucketSelect: (TimelineHourBucket) -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(timelineDayTitle(day))
                                .font(.headline)
                                .foregroundStyle(DashboardTheme.primaryText)
                            if Calendar.current.isDateInToday(day) {
                                Text("Today")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DashboardTheme.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(DashboardTheme.accent.opacity(0.11))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(buckets.count) active hour\(buckets.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                    }

                    Spacer()

                    Text(AppMonitorFormatting.duration(totalDurationSeconds))
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()
                }

                TimelineHourRuler()

                VStack(spacing: 8) {
                    ForEach(buckets) { bucket in
                        TimelineHourBucketRow(
                            bucket: bucket,
                            sessions: sessionsForBucket(bucket),
                            maxSeconds: maxSeconds,
                            onBucketSelect: onBucketSelect
                        )
                    }
                }
            }
        }
    }

    private var totalDurationSeconds: TimeInterval {
        buckets.reduce(0) { $0 + $1.totalDurationSeconds }
    }

    private func sessionsForBucket(_ bucket: TimelineHourBucket) -> [TimelineSession] {
        guard let hourEnd = Calendar.current.date(byAdding: .hour, value: 1, to: bucket.hourStart) else {
            return []
        }
        return sessions.filter { session in
            session.endedAt > bucket.hourStart && session.startedAt < hourEnd
        }
    }
}

private struct TimelineHourRuler: View {
    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: TimelineLayout.labelWidth)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    TimelineHourGridLines()
                    ForEach([0, 15, 30, 45, 60], id: \.self) { minute in
                        Text(minute == 60 ? "60m" : "\(minute)m")
                            .font(.caption2)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                            .frame(width: 34, alignment: minute == 60 ? .trailing : .leading)
                            .offset(x: hourRulerLabelX(minute, width: geometry.size.width))
                    }
                }
            }
            .frame(height: 22)

            Color.clear
                .frame(width: TimelineLayout.durationWidth)
        }
    }

    private func hourRulerLabelX(_ minute: Int, width: CGFloat) -> CGFloat {
        let ratio = CGFloat(minute) / 60
        return min(max(0, width * ratio - (minute == 60 ? 34 : 0)), max(0, width - 34))
    }
}

private struct TimelineHourBucketRow: View {
    let bucket: TimelineHourBucket
    let sessions: [TimelineSession]
    let maxSeconds: TimeInterval
    let onBucketSelect: (TimelineHourBucket) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onBucketSelect(bucket)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timelineTime(bucket.hourStart))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(bucket.topAppName ?? "\(bucket.sessionCount) session\(bucket.sessionCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: TimelineLayout.labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(heatmapBucketLabel(bucket))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DashboardTheme.subtleFill)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DashboardTheme.accent.opacity(0.08 + 0.16 * (bucket.totalDurationSeconds / maxSeconds)))
                    TimelineHourGridLines()
                    ForEach(sessions) { session in
                        TimelineHourSessionBar(
                            session: session,
                            hourStart: bucket.hourStart,
                            color: timelineColor(for: stableTimelineColorIndex(for: session.appID)),
                            availableWidth: geometry.size.width
                        )
                    }
                }
            }
            .frame(height: TimelineLayout.laneHeight)

            Text(AppMonitorFormatting.duration(bucket.totalDurationSeconds))
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: TimelineLayout.durationWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heatmapBucketLabel(bucket))
    }
}

private struct TimelineHourSessionBar: View {
    @EnvironmentObject private var model: AppModel
    let session: TimelineSession
    let hourStart: Date
    let color: Color
    let availableWidth: CGFloat

    var body: some View {
        Button {
            model.selectTimelineSession(session)
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)
                .overlay(alignment: .leading) {
                    if barWidth > 46 {
                        Text(session.appName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(width: barWidth, height: 20)
                .shadow(color: color.opacity(0.18), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .frame(width: max(barWidth, 14), height: 26, alignment: .leading)
        .offset(x: barX)
        .help(sessionAccessibilityLabel(session))
        .accessibilityLabel(sessionAccessibilityLabel(session))
    }

    private var hourEnd: Date {
        Calendar.current.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart.addingTimeInterval(3_600)
    }

    private var clippedStart: Date {
        max(session.startedAt, hourStart)
    }

    private var clippedEnd: Date {
        min(session.endedAt, hourEnd)
    }

    private var startRatio: CGFloat {
        CGFloat(max(0, min(1, clippedStart.timeIntervalSince(hourStart) / 3_600)))
    }

    private var widthRatio: CGFloat {
        CGFloat(max(0, min(1, clippedEnd.timeIntervalSince(clippedStart) / 3_600)))
    }

    private var barX: CGFloat {
        availableWidth * startRatio
    }

    private var barWidth: CGFloat {
        min(max(availableWidth * widthRatio, 5), max(5, availableWidth - barX))
    }
}

private struct TimelineHourGridLines: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ForEach(0...4, id: \.self) { index in
                    Rectangle()
                        .fill(index == 0 || index == 4 ? DashboardTheme.trackStrong : DashboardTheme.track)
                        .frame(width: index == 0 || index == 4 ? 1 : 0.5)
                        .offset(x: geometry.size.width * CGFloat(index) / 4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TimelineDayGroupCard: View {
    let group: TimelineDayGroup

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(timelineDayTitle(group.dayStart))
                                .font(.headline)
                                .foregroundStyle(DashboardTheme.primaryText)
                            if Calendar.current.isDateInToday(group.dayStart) {
                                Text("Today")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DashboardTheme.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(DashboardTheme.accent.opacity(0.11))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s") · \(group.activeAppCount) app\(group.activeAppCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                    }

                    Spacer()

                    Text(AppMonitorFormatting.duration(group.totalDurationSeconds))
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()
                }

                TimelineRuler()

                VStack(spacing: 8) {
                    ForEach(group.appLanes) { lane in
                        TimelineLaneRow(lane: lane, dayStart: group.dayStart)
                    }
                }
            }
        }
    }
}

private enum TimelineLayout {
    static let labelWidth: CGFloat = 174
    static let durationWidth: CGFloat = 78
    static let laneHeight: CGFloat = 30
}

private struct TimelineRuler: View {
    private let marks = [
        (0.0, "12 AM"),
        (0.25, "6 AM"),
        (0.5, "12 PM"),
        (0.75, "6 PM"),
        (1.0, "12 AM")
    ]

    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: TimelineLayout.labelWidth)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    TimelineGridLines()
                    ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                        Text(mark.1)
                            .font(.caption2)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                            .frame(width: 42, alignment: mark.0 == 1 ? .trailing : .leading)
                            .offset(x: rulerLabelX(mark.0, width: geometry.size.width))
                    }
                }
            }
            .frame(height: 22)

            Color.clear
                .frame(width: TimelineLayout.durationWidth)
        }
    }

    private func rulerLabelX(_ ratio: Double, width: CGFloat) -> CGFloat {
        min(max(0, width * CGFloat(ratio) - (ratio == 1 ? 42 : 0)), max(0, width - 42))
    }
}

private struct TimelineLaneRow: View {
    @EnvironmentObject private var model: AppModel
    let lane: TimelineAppLane
    let dayStart: Date

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.selectTimelineApp(appID: lane.appID)
            } label: {
                HStack(spacing: 9) {
                    AppIcon(path: lane.appPath, size: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lane.appName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DashboardTheme.primaryText)
                            .lineLimit(1)
                        Text(lane.bundleIdentifier ?? lane.appPath)
                            .font(.caption2)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(width: TimelineLayout.labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(lane.appPath)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DashboardTheme.subtleFill)
                    TimelineGridLines()
                    ForEach(lane.sessions) { session in
                        TimelineSessionBar(
                            session: session,
                            dayStart: dayStart,
                            color: timelineColor(for: lane.colorIndex),
                            availableWidth: geometry.size.width
                        )
                    }
                }
            }
            .frame(height: TimelineLayout.laneHeight)

            Text(AppMonitorFormatting.duration(lane.totalDurationSeconds))
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: TimelineLayout.durationWidth, alignment: .trailing)
        }
    }
}

private struct TimelineSessionBar: View {
    @EnvironmentObject private var model: AppModel
    let session: TimelineSession
    let dayStart: Date
    let color: Color
    let availableWidth: CGFloat

    var body: some View {
        Button {
            model.selectTimelineSession(session)
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)
                .overlay(alignment: .leading) {
                    if barWidth > 56 {
                        Text(AppMonitorFormatting.duration(session.durationSeconds))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(width: barWidth, height: 20)
                .shadow(color: color.opacity(0.18), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .frame(width: max(barWidth, 14), height: 26, alignment: .leading)
        .offset(x: barX)
        .help(sessionAccessibilityLabel(session))
        .accessibilityLabel(sessionAccessibilityLabel(session))
    }

    private var dayDuration: TimeInterval {
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return 86_400 }
        return max(dayEnd.timeIntervalSince(dayStart), 1)
    }

    private var startRatio: CGFloat {
        CGFloat(max(0, min(1, session.startedAt.timeIntervalSince(dayStart) / dayDuration)))
    }

    private var widthRatio: CGFloat {
        CGFloat(max(0, min(1, session.durationSeconds / dayDuration)))
    }

    private var barX: CGFloat {
        availableWidth * startRatio
    }

    private var barWidth: CGFloat {
        min(max(availableWidth * widthRatio, 5), max(5, availableWidth - barX))
    }
}

private struct TimelineGridLines: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ForEach(0...24, id: \.self) { hour in
                    Rectangle()
                        .fill(hour % 6 == 0 ? DashboardTheme.trackStrong : DashboardTheme.subtleFill)
                        .frame(width: hour % 6 == 0 ? 1 : 0.5)
                        .offset(x: geometry.size.width * CGFloat(hour) / 24)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TimelineListMode: View {
    @EnvironmentObject private var model: AppModel
    let sessions: [TimelineSession]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "Session List", subtitle: "\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                    .padding(.bottom, 10)

                if sessions.isEmpty {
                    EmptyCardState(systemImage: "list.bullet.rectangle", message: "Usage sessions will appear after App Monitor records active windows.")
                        .frame(height: 180)
                } else {
                    TimelineListHeader()
                    Divider()
                    ForEach(Array(sessions.prefix(240))) { session in
                        TimelineListRow(session: session)
                        if session.id != sessions.prefix(240).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct TimelineListHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("App").frame(maxWidth: .infinity, alignment: .leading)
            Text("Start").frame(width: 92, alignment: .leading)
            Text("End").frame(width: 92, alignment: .leading)
            Text("Duration").frame(width: 82, alignment: .trailing)
            Text("Source").frame(width: 74, alignment: .leading)
            Text("Actions").frame(width: 78, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DashboardTheme.secondaryText)
        .padding(.vertical, 8)
    }
}

private struct TimelineListRow: View {
    @EnvironmentObject private var model: AppModel
    let session: TimelineSession

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                AppIcon(path: session.appPath, size: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.appName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DashboardTheme.primaryText)
                            .lineLimit(1)
                        if session.isClipped {
                            Image(systemName: "scissors")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DashboardTheme.orange)
                                .help("Session clipped at reporting period boundary")
                        }
                    }
                    Text(session.bundleIdentifier ?? session.appPath)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timelineTime(session.startedAt))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .monospacedDigit()
                .frame(width: 92, alignment: .leading)
            Text(timelineTime(session.endedAt))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .monospacedDigit()
                .frame(width: 92, alignment: .leading)
            Text(AppMonitorFormatting.duration(session.durationSeconds))
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: 82, alignment: .trailing)
            Text(session.source)
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 74, alignment: .leading)

            HStack(spacing: 6) {
                Button {
                    model.selectTimelineSession(session)
                } label: {
                    Image(systemName: "sidebar.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Show session details")

                Menu {
                    Button("Reveal App") { model.revealInFinder(path: session.appPath) }
                    Button("Copy Bundle ID") { model.copyToClipboard(session.bundleIdentifier ?? "", label: "bundle ID") }
                    Button("Export Timeline Sessions") { model.exportTimelineSessions() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectTimelineSession(session)
        }
        .help(sessionAccessibilityLabel(session))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionAccessibilityLabel(session))
        .accessibilityAddTraits(.isButton)
    }
}

private struct TimelineHeatmapMode: View {
    let buckets: [TimelineHourBucket]
    let onBucketSelect: (TimelineHourBucket) -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(title: "Hourly Heatmap", subtitle: "\(buckets.count) active hour bucket\(buckets.count == 1 ? "" : "s")")

                if buckets.isEmpty {
                    EmptyCardState(systemImage: "square.grid.3x3", message: "Usage sessions will appear after App Monitor records active windows.")
                        .frame(height: 190)
                } else {
                    VStack(spacing: 8) {
                        TimelineHeatmapHourHeader()
                        ForEach(days, id: \.self) { day in
                            TimelineHeatmapDayRow(
                                day: day,
                                buckets: bucketsForDay(day),
                                maxSeconds: maxSeconds,
                                onBucketSelect: onBucketSelect
                            )
                        }
                    }
                }
            }
        }
    }

    private var days: [Date] {
        Array(Set(buckets.map(\.dayStart))).sorted(by: >)
    }

    private var maxSeconds: TimeInterval {
        max(buckets.map(\.totalDurationSeconds).max() ?? 1, 1)
    }

    private func bucketsForDay(_ day: Date) -> [Int: TimelineHourBucket] {
        Dictionary(uniqueKeysWithValues: buckets.filter { Calendar.current.isDate($0.dayStart, inSameDayAs: day) }.map {
            (Calendar.current.component(.hour, from: $0.hourStart), $0)
        })
    }
}

private struct TimelineHeatmapHourHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 74)
            ForEach(0..<24, id: \.self) { hour in
                Text(hour % 6 == 0 ? heatmapHourLabel(hour) : "")
                    .font(.caption2)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TimelineHeatmapDayRow: View {
    let day: Date
    let buckets: [Int: TimelineHourBucket]
    let maxSeconds: TimeInterval
    let onBucketSelect: (TimelineHourBucket) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(timelineDayShort(day))
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .frame(width: 74, alignment: .leading)

            ForEach(0..<24, id: \.self) { hour in
                if let bucket = buckets[hour] {
                    Button {
                        onBucketSelect(bucket)
                    } label: {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DashboardTheme.accent.opacity(0.16 + 0.78 * (bucket.totalDurationSeconds / maxSeconds)))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .help(heatmapBucketLabel(bucket))
                    .accessibilityLabel(heatmapBucketLabel(bucket))
                } else {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(DashboardTheme.subtleFill)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct LegacyWarningsScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Warnings", subtitle: "Storage warnings plus code-signing, Gatekeeper, crash, and update signals")
                .padding(.top, 6)

            DashboardCard {
                VStack(alignment: .leading, spacing: 0) {
                    CardHeader(title: "Health Findings", subtitle: "\(findings.count) warning\(findings.count == 1 ? "" : "s")")
                    if findings.isEmpty {
                        EmptyCardState(systemImage: "checkmark.seal", message: "Run Scan to audit app health. No warnings are currently stored.")
                            .frame(height: 180)
                    } else {
                        ForEach(findings) { finding in
                            Divider()
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: finding.severity == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(finding.severity == .critical ? DashboardTheme.red : DashboardTheme.orange)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(finding.title)
                                        .font(.callout.weight(.semibold))
                                    Text("\(model.appName(for: finding.appID)) · \(finding.source)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(DashboardTheme.secondaryText)
                                    Text(finding.detail)
                                        .font(.caption)
                                        .foregroundStyle(DashboardTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }

    private var findings: [AppHealthFinding] {
        model.healthFindingsByAppID.values
            .flatMap { $0 }
            .filter { $0.severity == .warning || $0.severity == .critical }
            .sorted { lhs, rhs in
                if lhs.severity == rhs.severity { return lhs.checkedAt > rhs.checkedAt }
                return lhs.severity == .critical
            }
    }
}

private struct WarningsScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedFilter: WarningCategoryFilter = .all
    @State private var sortMode: WarningSortMode = .severity
    @State private var expandedSeverities: Set<AppWarningSeverity> = []

    var body: some View {
        let warnings = visibleWarnings

        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Warnings", subtitle: "Potential issues that may impact performance, security, or storage.")
                .padding(.top, 6)

            LazyVGrid(columns: warningSummaryColumns, spacing: 12) {
                WarningMetricCard(
                    title: "Total Warnings",
                    value: "\(model.warningItems.count)",
                    subtitle: "Across \(Set(model.warningItems.map(\.appID)).count) apps",
                    tint: DashboardTheme.primaryText
                )
                ForEach(AppWarningSeverity.allCases) { severity in
                    WarningMetricCard(
                        title: severity.displayName,
                        value: "\(warningCount(for: severity))",
                        subtitle: warningMetricSubtitle(for: severity),
                        tint: warningSeverityColor(severity)
                    )
                }
            }

            HStack(spacing: 10) {
                ForEach(WarningCategoryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                        ensureSelection(in: visibleWarnings)
                    } label: {
                        WarningFilterChip(
                            title: filter.title,
                            count: warningCount(for: filter),
                            isSelected: selectedFilter == filter
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 12)

                Menu {
                    ForEach(WarningSortMode.allCases) { mode in
                        Button {
                            sortMode = mode
                            ensureSelection(in: visibleWarnings)
                        } label: {
                            if sortMode == mode {
                                Label(mode.rawValue, systemImage: "checkmark")
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                    }
                } label: {
                    ToolbarControl(title: "Sort by \(sortMode.rawValue)", systemImage: nil, trailingSystemImage: "chevron.down", compact: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            if warnings.isEmpty {
                DashboardCard {
                    EmptyCardState(systemImage: "checkmark.seal", message: emptyMessage)
                        .frame(height: 220)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(severityGroups(for: warnings), id: \.severity) { group in
                        WarningSeveritySection(
                            severity: group.severity,
                            warnings: group.warnings,
                            isExpanded: expandedSeverities.contains(group.severity)
                        ) {
                            toggleSeverityExpansion(group.severity)
                        }
                    }
                }
            }
        }
        .onAppear {
            ensureSelection(in: visibleWarnings)
        }
    }

    private var warningSummaryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 130), spacing: 12), count: 5)
    }

    private var visibleWarnings: [AppWarningItem] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = model.warningItems.filter { warning in
            guard selectedFilter.includes(warning) else { return false }
            guard !query.isEmpty else { return true }
            return warning.title.lowercased().contains(query)
                || warning.detail.lowercased().contains(query)
                || warning.appName.lowercased().contains(query)
                || warning.appPath.lowercased().contains(query)
                || warning.source.lowercased().contains(query)
                || warning.category.rawValue.lowercased().contains(query)
        }

        switch sortMode {
        case .severity:
            return filtered.sorted(by: severitySort)
        case .detected:
            return filtered.sorted {
                if $0.detectedAt == $1.detectedAt { return severitySort($0, $1) }
                return $0.detectedAt > $1.detectedAt
            }
        case .app:
            return filtered.sorted {
                let appComparison = $0.appName.localizedCaseInsensitiveCompare($1.appName)
                if appComparison == .orderedSame { return severitySort($0, $1) }
                return appComparison == .orderedAscending
            }
        case .size:
            return filtered.sorted {
                let lhsSize = $0.sizeBytes ?? -1
                let rhsSize = $1.sizeBytes ?? -1
                if lhsSize == rhsSize { return severitySort($0, $1) }
                return lhsSize > rhsSize
            }
        }
    }

    private var emptyMessage: String {
        if model.warningItems.isEmpty {
            return "Run Scan to audit app health, storage, cleanup candidates, and update signals."
        }
        return "No warnings match the current search or filter."
    }

    private func severityGroups(for warnings: [AppWarningItem]) -> [(severity: AppWarningSeverity, warnings: [AppWarningItem])] {
        AppWarningSeverity.allCases.compactMap { severity in
            let items = warnings.filter { $0.severity == severity }
            return items.isEmpty ? nil : (severity, items)
        }
    }

    private func severitySort(_ lhs: AppWarningItem, _ rhs: AppWarningItem) -> Bool {
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

    private func warningCount(for severity: AppWarningSeverity) -> Int {
        model.warningItems.filter { $0.severity == severity }.count
    }

    private func warningCount(for filter: WarningCategoryFilter) -> Int {
        model.warningItems.filter(filter.includes).count
    }

    private func warningMetricSubtitle(for severity: AppWarningSeverity) -> String {
        switch severity {
        case .critical:
            return "Requires attention"
        case .high:
            return "Should review"
        case .medium:
            return "Recommended"
        case .low:
            return "Informational"
        }
    }

    private func ensureSelection(in warnings: [AppWarningItem]) {
        guard let first = warnings.first else { return }
        if let selectedWarningID = model.selectedWarningID,
           let selected = warnings.first(where: { $0.id == selectedWarningID }) {
            if model.selectedAppID != selected.appID {
                model.selectWarning(selected)
            }
            return
        }
        model.selectWarning(first)
    }

    private func toggleSeverityExpansion(_ severity: AppWarningSeverity) {
        if expandedSeverities.contains(severity) {
            expandedSeverities.remove(severity)
        } else {
            expandedSeverities.insert(severity)
        }
    }
}

private enum WarningCategoryFilter: Hashable, Identifiable {
    case all
    case category(AppWarningCategory)

    static let allCases: [WarningCategoryFilter] = [.all] + AppWarningCategory.allCases.map { .category($0) }

    var id: String {
        switch self {
        case .all:
            return "All"
        case .category(let category):
            return category.rawValue
        }
    }

    var title: String { id }

    func includes(_ warning: AppWarningItem) -> Bool {
        switch self {
        case .all:
            return true
        case .category(let category):
            return warning.category == category
        }
    }
}

private enum WarningSortMode: String, CaseIterable, Identifiable {
    case severity = "Severity"
    case detected = "Detected"
    case app = "App"
    case size = "Size"

    var id: String { rawValue }
}

private struct WarningMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(14)
        .frame(minHeight: 94, alignment: .topLeading)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private struct WarningFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .lineLimit(1)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : DashboardTheme.accent)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(isSelected ? Color.white.opacity(0.22) : DashboardTheme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isSelected ? .white : DashboardTheme.primaryText)
        .padding(.horizontal, 14)
        .frame(height: 31)
        .background(isSelected ? DashboardTheme.accent : DashboardTheme.control)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? Color.clear : DashboardTheme.softStroke)
        )
    }
}

private struct WarningSeveritySection: View {
    @EnvironmentObject private var model: AppModel
    let severity: AppWarningSeverity
    let warnings: [AppWarningItem]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var visibleWarnings: [AppWarningItem] {
        isExpanded ? warnings : Array(warnings.prefix(defaultVisibleCount))
    }

    private var hiddenCount: Int {
        max(0, warnings.count - visibleWarnings.count)
    }

    private var defaultVisibleCount: Int {
        switch severity {
        case .critical:
            return 3
        case .high:
            return 4
        case .medium, .low:
            return 3
        }
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(severity.displayName)
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                    Text("\(warnings.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(warningSeverityColor(severity))
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(warningSeverityColor(severity).opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.bottom, 10)

                ForEach(visibleWarnings) { warning in
                    Divider()
                    Button {
                        model.selectWarning(warning)
                    } label: {
                        WarningListRow(
                            warning: warning,
                            isSelected: model.selectedWarningID == warning.id
                        )
                    }
                    .buttonStyle(.plain)
                }

                if hiddenCount > 0 || (isExpanded && warnings.count > defaultVisibleCount) {
                    Divider()
                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Text(isExpanded ? "Show less" : "Show \(hiddenCount) more")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct WarningListRow: View {
    let warning: AppWarningItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            WarningSeverityGlyph(severity: warning.severity)

            VStack(alignment: .leading, spacing: 3) {
                Text(warning.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(warning.detail)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(warning.appName)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 142, alignment: .leading)

            Text(warning.statusText ?? "--")
                .font(.caption.weight(.semibold))
                .foregroundStyle(warning.statusText == nil ? DashboardTheme.secondaryText : warningSeverityColor(warning.severity))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(DashboardTheme.secondaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isSelected ? DashboardTheme.accent.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct WarningSeverityGlyph: View {
    let severity: AppWarningSeverity

    var body: some View {
        Image(systemName: warningSeverityIcon(severity))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(warningSeverityColor(severity))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

private struct CleanupCenterScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsRunConfirmation = false

    var body: some View {
        let displayed = model.displayedCleanupSuggestions
        let recommended = displayed.filter { !isLowPriorityCleanup($0) }
        let lowPriority = displayed.filter(isLowPriorityCleanup)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 16) {
                ScreenHeader(title: "Cleanup Suggestions", subtitle: "Remove unnecessary files and free up space safely.")
                    .padding(.top, 6)
                Spacer()
            }

            CleanupSummaryCard(showsRunConfirmation: $showsRunConfirmation)

            HStack(spacing: 10) {
                CleanupFilterPills()
                Spacer()
                CleanupSortMenu()
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 0) {
                    if displayed.isEmpty {
                        EmptyCardState(systemImage: "shield.lefthalf.filled", message: model.activeCleanupSuggestions.isEmpty ? "Run Scan to generate cleanup suggestions from safe storage categories." : "No suggestions match this filter.")
                            .frame(height: 220)
                    } else {
                        CleanupSuggestionSection(title: "Recommended for Cleanup", suggestions: recommended)
                        if !lowPriority.isEmpty {
                            CleanupSuggestionSection(title: "Low Priority", suggestions: lowPriority)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .alert("Move approved items to quarantine?", isPresented: $showsRunConfirmation) {
            Button("Move to Quarantine") {
                Task { await model.runApprovedCleanup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(model.approvedCleanupCount) item\(model.approvedCleanupCount == 1 ? "" : "s") totaling \(compactBytes(model.approvedCleanupBytes)) will be moved to App Monitor quarantine so they can be restored later.")
        }
    }
}

private struct CleanupSummaryCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showsRunConfirmation: Bool

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Potential Space to Free")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DashboardTheme.secondaryText)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(compactBytes(model.potentialSavingsBytes))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(DashboardTheme.accent)
                                .monospacedDigit()
                                .minimumScaleFactor(0.72)
                            Text("\(model.activeCleanupSuggestions.count) item\(model.activeCleanupSuggestions.count == 1 ? "" : "s")")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DashboardTheme.secondaryText)
                        }
                    }

                    Spacer(minLength: 18)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(model.approvedCleanupCount) Items Approved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DashboardTheme.secondaryText)
                        Text(compactBytes(model.approvedCleanupBytes))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(DashboardTheme.primaryText)
                            .monospacedDigit()
                    }
                    .frame(width: 150, alignment: .leading)

                    Button {
                        showsRunConfirmation = true
                    } label: {
                        Text(model.isRunningCleanup ? "Running" : "Review & Clean")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(model.approvedCleanupCount == 0 ? DashboardTheme.secondaryText : DashboardTheme.accent)
                            .frame(width: 126, height: 44)
                            .background(model.approvedCleanupCount == 0 ? DashboardTheme.subtleFill : DashboardTheme.accent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.approvedCleanupCount == 0 || model.isRunningCleanup)
                }

                let segments = cleanupSummarySegments(for: model.activeCleanupSuggestions)
                CleanupStackedBar(segments: segments, totalBytes: model.potentialSavingsBytes)
                    .frame(height: 12)

                CleanupLegend(segments: segments)
            }
        }
    }
}

private struct CleanupStackedBar: View {
    let segments: [CleanupSummarySegment]
    let totalBytes: Int64

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                let visibleSegments = segments.filter { $0.bytes > 0 }
                if totalBytes <= 0 || visibleSegments.isEmpty {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DashboardTheme.track)
                        .frame(width: geometry.size.width)
                } else {
                    ForEach(visibleSegments) { segment in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(segment.color)
                            .frame(width: max(4, geometry.size.width * CGFloat(Double(segment.bytes) / Double(totalBytes))))
                    }
                }
            }
        }
    }
}

private struct CleanupLegend: View {
    let segments: [CleanupSummarySegment]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(segments) { segment in
                HStack(spacing: 7) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 9, height: 9)
                    Text(segment.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(compactBytes(segment.bytes))
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CleanupFilterPills: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppModel.CleanupSuggestionFilter.allCases) { filter in
                Button {
                    model.cleanupSuggestionFilter = filter
                    if let first = model.displayedCleanupSuggestions.first {
                        model.focusCleanupSuggestion(first)
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(model.cleanupSuggestionFilter == filter ? .white : DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(model.cleanupSuggestionFilter == filter ? DashboardTheme.accent : DashboardTheme.subtleFill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CleanupSortMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            ForEach(AppModel.CleanupSuggestionSort.allCases) { sort in
                Button {
                    model.cleanupSuggestionSort = sort
                } label: {
                    if model.cleanupSuggestionSort == sort {
                        Label("Sort by \(sort.rawValue)", systemImage: "checkmark")
                    } else {
                        Text("Sort by \(sort.rawValue)")
                    }
                }
            }
            Divider()
            Button("Approve Visible") {
                model.approveCleanupSuggestions(model.displayedCleanupSuggestions)
            }
            Button("Clear Approved") {
                model.clearApprovedCleanupSuggestions()
            }
        } label: {
            ToolbarControl(title: "Sort by \(model.cleanupSuggestionSort.rawValue)", systemImage: nil, trailingSystemImage: "chevron.down", compact: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}

private struct CleanupSuggestionSection: View {
    let title: String
    let suggestions: [CleanupSuggestion]

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 9)
                ForEach(suggestions) { suggestion in
                    CleanupSuggestionListRow(suggestion: suggestion)
                    if suggestion.id != suggestions.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.bottom, title == "Recommended for Cleanup" ? 16 : 0)
        }
    }
}

private struct CleanupSuggestionListRow: View {
    @EnvironmentObject private var model: AppModel
    let suggestion: CleanupSuggestion

    var body: some View {
        let row = model.appRow(for: suggestion.appID)
        let isFocused = model.focusedCleanupSuggestion?.id == suggestion.id
        let isQueued = suggestion.state == .approved

        HStack(alignment: .center, spacing: 12) {
            Button {
                model.toggleCleanupSuggestionQueued(suggestion)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isQueued ? DashboardTheme.accent : DashboardTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(isQueued ? DashboardTheme.accent : DashboardTheme.secondaryText.opacity(0.72), lineWidth: 1.4)
                        )
                        .frame(width: 15, height: 15)
                    if isQueued {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .help(isQueued ? "Remove from cleanup" : "Add to cleanup")

            CleanupSuggestionIcon(row: row, suggestion: suggestion, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(cleanupDisplayTitle(suggestion, appName: model.appName(for: suggestion.appID)))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    CleanupBadge(text: cleanupSeverityLabel(suggestion), color: cleanupSeverityColor(suggestion.severity))
                    if cleanupIsLowRisk(suggestion), suggestion.severity != .low {
                        CleanupBadge(text: "Safe", color: DashboardTheme.green)
                    }
                    if isQueued {
                        CleanupBadge(text: "Queued", color: DashboardTheme.accent)
                    }
                }
                Text(cleanupSubtitle(suggestion, row: row, appName: model.appName(for: suggestion.appID)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                Text(suggestion.rationale)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(compactBytes(suggestion.sizeBytes))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(itemCountText(model.cleanupPreviewItemCount(for: suggestion)))
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .trailing)

            Menu {
                Button("View Details") { model.focusCleanupSuggestion(suggestion) }
                Button(isQueued ? "Remove from Cleanup" : "Add to Cleanup") {
                    model.toggleCleanupSuggestionQueued(suggestion)
                }
                Divider()
                Button("Preview") { model.preview(path: suggestion.path) }
                Button("Reveal in Finder") { model.revealInFinder(path: suggestion.path) }
                Button("Reject") { model.rejectCleanupSuggestion(suggestion) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(isFocused ? DashboardTheme.accent.opacity(0.075) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            model.focusCleanupSuggestion(suggestion)
        }
        .help(suggestion.path)
    }

    private func itemCountText(_ count: Int?) -> String {
        guard let count else { return "1 item" }
        return "\(count) item\(count == 1 ? "" : "s")"
    }
}

private struct CleanupSuggestionIcon: View {
    let row: AppUsageRow?
    let suggestion: CleanupSuggestion
    let size: CGFloat

    var body: some View {
        Group {
            if let row {
                AppIcon(path: row.app.path, size: size)
            } else {
                Image(systemName: storageIcon(for: suggestion.category))
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(cleanupSeverityColor(suggestion.severity))
                    .frame(width: size, height: size)
            }
        }
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

private struct CleanupBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct DashboardDetailPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.destination == .history {
            HistoryDetailPanel()
        } else if model.destination == .cleanup {
            CleanupSuggestionDetailPanel()
        } else {
            AppDetailPanel()
        }
    }
}

private struct CleanupSuggestionDetailPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let suggestion = model.focusedCleanupSuggestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        CleanupInspectorHeader(suggestion: suggestion)
                        CleanupMetricStrip(suggestion: suggestion)
                        CleanupSizeSnapshotCard(suggestion: suggestion)
                        CleanupExplanationCard(suggestion: suggestion)
                        CleanupPreviewCard(suggestion: suggestion)
                    }
                    .padding(14)
                }

                Divider()

                VStack(spacing: 10) {
                    Button {
                        model.toggleCleanupSuggestionQueued(suggestion)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: suggestion.state == .approved ? "minus.circle" : "trash")
                            Text(suggestion.state == .approved ? "Remove from Cleanup" : "Add to Cleanup (\(compactBytes(suggestion.sizeBytes)))")
                        }
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(CleanupPrimaryFooterButtonStyle(isActive: suggestion.state != .approved))

                    Button {
                        model.revealInFinder(path: suggestion.path)
                    } label: {
                        Text("Reveal in Finder")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(DetailFooterButtonStyle())
                }
                .padding(14)
            } else {
                ContentUnavailableView("No Cleanup Suggestion", systemImage: "shield.lefthalf.filled", description: Text("Run a scan or choose a cleanup item to inspect what will be moved to quarantine."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DashboardTheme.panel)
    }
}

private struct CleanupInspectorHeader: View {
    @EnvironmentObject private var model: AppModel
    let suggestion: CleanupSuggestion

    var body: some View {
        CleanupInspectorCard {
            HStack(alignment: .top, spacing: 12) {
                CleanupSuggestionIcon(row: model.appRow(for: suggestion.appID), suggestion: suggestion, size: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(cleanupDisplayTitle(suggestion, appName: model.appName(for: suggestion.appID)))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(2)
                    Text("\(suggestion.category.rawValue) · \(model.appName(for: suggestion.appID))")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                    CleanupBadge(
                        text: cleanupIsLowRisk(suggestion) ? "Safe to Clean" : cleanupSeverityLabel(suggestion),
                        color: cleanupIsLowRisk(suggestion) ? DashboardTheme.green : cleanupSeverityColor(suggestion.severity)
                    )
                }

                Spacer(minLength: 4)

                Menu {
                    Button("Preview") { model.preview(path: suggestion.path) }
                    Button("Reveal in Finder") { model.revealInFinder(path: suggestion.path) }
                    Divider()
                    Button(suggestion.state == .approved ? "Remove from Cleanup" : "Add to Cleanup") {
                        model.toggleCleanupSuggestionQueued(suggestion)
                    }
                    Button("Reject") { model.rejectCleanupSuggestion(suggestion) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(DashboardTheme.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .menuStyle(.button)
            }
        }
    }
}

private struct CleanupMetricStrip: View {
    @EnvironmentObject private var model: AppModel
    let suggestion: CleanupSuggestion

    var body: some View {
        CleanupInspectorCard {
            HStack(spacing: 0) {
                CleanupMetric(title: "Size", value: compactBytes(suggestion.sizeBytes))
                Divider().frame(height: 46)
                CleanupMetric(title: "Items", value: cleanupItemCountText(model.cleanupPreviewItemCount(for: suggestion)))
                Divider().frame(height: 46)
                CleanupMetric(title: "Last Used", value: cleanupLastUsedText(model.appRow(for: suggestion.appID)))
            }
        }
    }
}

private struct CleanupMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DashboardTheme.secondaryText)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

private struct CleanupSizeSnapshotCard: View {
    let suggestion: CleanupSuggestion

    var body: some View {
        CleanupInspectorCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Size Over Time")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)

                GeometryReader { geometry in
                    let lineY = geometry.size.height * 0.46
                    ZStack {
                        VStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(DashboardTheme.subtleFill)
                                    .frame(height: 1)
                                Spacer()
                            }
                            Rectangle()
                                .fill(DashboardTheme.subtleFill)
                                .frame(height: 1)
                        }

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: lineY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: lineY))
                        }
                        .stroke(DashboardTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        Circle()
                            .fill(DashboardTheme.accent)
                            .frame(width: 8, height: 8)
                            .position(x: geometry.size.width - 4, y: lineY)
                    }
                }
                .frame(height: 72)

                HStack {
                    Text("Current scan only")
                    Spacer()
                    Text(compactBytes(suggestion.sizeBytes))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
            }
        }
    }
}

private struct CleanupExplanationCard: View {
    let suggestion: CleanupSuggestion

    var body: some View {
        CleanupInspectorCard {
            VStack(alignment: .leading, spacing: 9) {
                Text("What is this?")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                Text(suggestion.rationale)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(suggestion.riskNotes)
                    .font(.caption)
                    .foregroundStyle(cleanupSeverityColor(suggestion.severity))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CleanupPreviewCard: View {
    @EnvironmentObject private var model: AppModel
    let suggestion: CleanupSuggestion

    var body: some View {
        let items = model.cleanupPreviewItems(for: suggestion)
        CleanupInspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview of Items")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(DashboardTheme.blue)
                            .frame(width: 18)
                        Text(item.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DashboardTheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(item.sizeBytes.map(compactBytes) ?? "Folder")
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DashboardTheme.secondaryText.opacity(0.75))
                    }
                    .help(item.path)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct CleanupInspectorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private struct CleanupPrimaryFooterButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(isActive ? DashboardTheme.accent : DashboardTheme.secondaryText)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UpdatesScreen: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 170), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Installed App Updates", subtitle: "Mac App Store, Homebrew, Apple software, and direct-download update management")
                .padding(.top, 6)

            LazyVGrid(columns: columns, spacing: 12) {
                UpdateMetricCard(title: "Available", value: "\(model.availableUpdateCount)", systemImage: "arrow.down.circle", tint: DashboardTheme.blue, detail: "Detected updates")
                UpdateMetricCard(title: "Auto Eligible", value: "\(model.autoEligibleUpdateCount)", systemImage: "bolt.circle", tint: DashboardTheme.green, detail: "Safe automatic installs")
                UpdateMetricCard(title: "Manual", value: "\(model.manualUpdateCount)", systemImage: "hand.raised", tint: DashboardTheme.orange, detail: "Needs review")
                UpdateMetricCard(title: "Change Logs", value: "\(model.changeLogEntries.count)", systemImage: "text.page.badge.magnifyingglass", tint: DashboardTheme.accent, detail: "Captured over time")
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        CardHeader(title: "Update Queue", subtitle: "\(model.updateRecords.count) provider record\(model.updateRecords.count == 1 ? "" : "s")")
                        Spacer()
                        Button("Select Available") {
                            model.selectAllAvailableUpdates()
                        }
                        .disabled(model.updateRecords.isEmpty || model.isCheckingUpdates || model.isRunningUpdates)
                        Button("Clear") {
                            model.clearSelectedUpdates()
                        }
                        .disabled(model.selectedUpdateIDs.isEmpty)
                        Button {
                            Task { await model.checkForUpdates() }
                        } label: {
                            Label("Check Installed Apps", systemImage: "arrow.clockwise")
                        }
                        .disabled(model.isCheckingUpdates || model.isRunningUpdates)
                        Button {
                            Task { await model.updateSelectedRecords() }
                        } label: {
                            Label("Update Selected", systemImage: "square.and.arrow.down")
                        }
                        .disabled(!hasSelectedInstallableUpdates || model.isCheckingUpdates || model.isRunningUpdates)
                        Button {
                            Task { await model.updateAllEligibleRecords() }
                        } label: {
                            Label("Update All Eligible", systemImage: "bolt.fill")
                        }
                        .disabled(model.autoEligibleUpdateCount == 0 || model.isCheckingUpdates || model.isRunningUpdates)
                    }

                    if model.updateRecords.isEmpty {
                        EmptyCardState(systemImage: "arrow.down.circle", message: "Run an installed-app update check to populate available app and system updates.")
                            .frame(height: 220)
                    } else {
                        VStack(spacing: 0) {
                            UpdatesTableHeader()
                            Divider()
                            ForEach(model.updateRecords.prefix(120)) { record in
                                UpdatesTableRow(record: record)
                                Divider()
                            }
                        }
                    }
                }
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 0) {
                    CardHeader(title: "Change Log Timeline", subtitle: "Recent version changes and release notes")
                    if model.changeLogEntries.isEmpty {
                        EmptyCardState(systemImage: "text.page", message: "Change logs will appear after update checks find release notes or updates complete.")
                            .frame(height: 180)
                    } else {
                        ForEach(model.changeLogEntries.prefix(12)) { entry in
                            Divider()
                            ChangeLogTimelineRow(entry: entry)
                        }
                    }
                }
            }
        }
    }

    private var hasSelectedInstallableUpdates: Bool {
        model.selectedUpdateRecords.contains { $0.canInstall }
    }
}

private struct ChangeLogTimelineRow: View {
    @EnvironmentObject private var model: AppModel
    let entry: AppChangeLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: updateSourceIcon(entry.source))
                .foregroundStyle(DashboardTheme.blue)
                .frame(width: 24)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.appName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(versionTransition(entry))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(AppMonitorFormatting.shortDateTime(entry.capturedAt))
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
                Text(entry.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(entry.source.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DashboardTheme.blue)
                    if entry.releaseNotesURL != nil {
                        Button("Release Notes") {
                            model.openChangeLogReleaseNotes(entry)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2.weight(.semibold))
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct UpdateMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let detail: String

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct UpdatesTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("").frame(width: 24)
            Text("App").frame(maxWidth: .infinity, alignment: .leading)
            Text("Source").frame(width: 132, alignment: .leading)
            Text("Current").frame(width: 88, alignment: .leading)
            Text("Available").frame(width: 88, alignment: .leading)
            Text("Status").frame(width: 104, alignment: .leading)
            Text("Checked").frame(width: 112, alignment: .leading)
            Text("").frame(width: 82)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DashboardTheme.secondaryText)
        .padding(.vertical, 8)
    }
}

private struct UpdatesTableRow: View {
    @EnvironmentObject private var model: AppModel
    let record: AppUpdateRecord

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { model.selectedUpdateIDs.contains(record.id) },
                set: { model.setUpdateSelected(record, selected: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .frame(width: 24)
            .disabled(!record.canInstall)

            HStack(spacing: 10) {
                if let appPath = record.appPath {
                    AppIcon(path: appPath, size: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: updateSourceIcon(record.source))
                        .foregroundStyle(updateStatusColor(record.status))
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.appName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(record.message ?? record.bundleIdentifier ?? record.sourceIdentifier)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(record.source.displayName)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 132, alignment: .leading)
                .lineLimit(1)
            Text(record.currentVersion ?? "--")
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(record.availableVersion ?? "--")
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            UpdateStatusBadge(record: record)
                .frame(width: 104, alignment: .leading)
            Text(AppMonitorFormatting.shortDateTime(record.checkedAt))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 112, alignment: .leading)
            Button(record.canInstall ? "Source" : "Open") {
                model.openUpdateSource(record)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 82, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }
}

private struct UpdateStatusBadge: View {
    @EnvironmentObject private var model: AppModel
    let record: AppUpdateRecord

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .help(record.message ?? label)
    }

    private var label: String {
        if model.isUpdateAutoEligible(record) {
            return "Auto"
        }
        return record.status.displayName
    }

    private var color: Color {
        model.isUpdateAutoEligible(record) ? DashboardTheme.green : updateStatusColor(record.status)
    }
}

private struct HistoryScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let events = historyEvents
        let selectedID = model.selectedHistoryActionID ?? events.first?.id

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 16) {
                ScreenHeader(title: "History", subtitle: "Past scans, cleanup actions, restore points, and reversible changes.")
                    .padding(.top, 6)
                Spacer()
                Menu {
                    Button("Current Scan Baseline") {}
                    Button("Last 30 Days") {}
                    Button("Last 90 Days") {}
                } label: {
                    ToolbarControl(title: "30 Days", systemImage: "calendar", trailingSystemImage: "chevron.down", compact: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                Button {
                    if let event = events.first {
                        model.performHistoryRestoreOrRevert(title: event.title, detail: event.detail)
                    }
                } label: {
                    ToolbarControl(title: "Restore Latest", systemImage: "arrow.uturn.backward.circle", compact: true)
                }
                .buttonStyle(.plain)
                .disabled(events.isEmpty)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 130), spacing: 12), count: 4), spacing: 12) {
                HistoryMetricCard(title: "Space Reclaimed", value: compactBytes(reclaimedBytes), detail: "\(restorableCount) restore point\(restorableCount == 1 ? "" : "s")", systemImage: "externaldrive.badge.checkmark", tint: DashboardTheme.green)
                HistoryMetricCard(title: "Cleanups Run", value: "\(cleanupEventCount)", detail: "\(model.approvedCleanupCount) queued now", systemImage: "shield.checkered", tint: DashboardTheme.accent)
                HistoryMetricCard(title: "Reversible Changes", value: "\(directlyReversibleCount)", detail: "\(loggedRequestCount) logged request\(loggedRequestCount == 1 ? "" : "s")", systemImage: "arrow.counterclockwise.circle", tint: DashboardTheme.blue)
                HistoryMetricCard(title: "System Events", value: "\(events.count)", detail: lastEventText(events.first), systemImage: "clock.badge.checkmark", tint: DashboardTheme.orange)
            }

            HistoryStorageTimelineCard(points: storageTrendPoints, reclaimedBytes: reclaimedBytes, eventCount: events.count)

            DashboardCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        CardHeader(title: "Scan & Cleanup History", subtitle: "\(events.count) recorded event\(events.count == 1 ? "" : "s")")
                        Spacer()
                        Button {
                            model.logHistoryRevertRequest(title: "Snapshot Compare", detail: "Compare current scan with previous available state")
                        } label: {
                            ToolbarControl(title: "Compare Snapshots", systemImage: "rectangle.2.swap", compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 10)

                    if events.isEmpty {
                        EmptyCardState(systemImage: "clock.arrow.circlepath", message: "Actions will appear here after scans, cleanup approvals, quarantine moves, restores, tags, and settings changes.")
                            .frame(height: 190)
                    } else {
                        HistoryTableHeader()
                        ForEach(events) { event in
                            Divider()
                            Button {
                                model.selectHistoryAction(id: event.id)
                            } label: {
                                HistoryTableRow(event: event, isSelected: event.id == selectedID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var historyEvents: [HistoryDisplayEvent] {
        model.actionHistory.map { entry in
            makeHistoryEvent(date: entry.0, title: entry.1, detail: entry.2, model: model)
        }
    }

    private var reclaimedBytes: Int64 {
        model.cleanupSuggestions
            .filter { $0.state == .quarantined || $0.state == .restored }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    private var restorableCount: Int {
        model.cleanupSuggestions.filter { $0.state == .quarantined && $0.quarantinePath != nil }.count
    }

    private var cleanupEventCount: Int {
        historyEvents.filter { [.cleanup, .restore, .file].contains($0.kind) }.count
    }

    private var directlyReversibleCount: Int {
        historyEvents.filter { model.historyActionCanApplyDirectly(title: $0.title, detail: $0.detail) }.count
    }

    private var loggedRequestCount: Int {
        historyEvents.filter { $0.title == "Revert Requested" }.count
    }

    private var storageTrendPoints: [HistoryStoragePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let baseline = max(model.scannedSizeBytes, model.allStorageItems.reduce(0) { $0 + $1.sizeBytes })
        let impactByDay = Dictionary(grouping: historyEvents.filter { $0.impactBytes > 0 }) { event in
            calendar.startOfDay(for: event.date)
        }.mapValues { events in
            events.reduce(Int64(0)) { $0 + $1.impactBytes }
        }

        return (0..<12).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 11, to: today) else { return nil }
            let laterImpact = impactByDay
                .filter { $0.key > day }
                .reduce(Int64(0)) { $0 + $1.value }
            return HistoryStoragePoint(date: day, bytes: max(0, baseline + laterImpact))
        }
    }

    private func lastEventText(_ event: HistoryDisplayEvent?) -> String {
        guard let event else { return "No changes yet" }
        return event.relativeDateText
    }
}

private struct HistoryDetailPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let events = model.actionHistory.map { entry in
            makeHistoryEvent(date: entry.0, title: entry.1, detail: entry.2, model: model)
        }
        let selectedEvent = events.first { $0.id == model.selectedHistoryActionID } ?? events.first

        VStack(spacing: 0) {
            if let event = selectedEvent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HistoryInspectorHeader(event: event)
                        HistoryActionStatusCard(event: event)
                        HistoryActionContextCard(event: event)
                        HistoryTimelineMiniCard(events: Array(events.prefix(4)))
                        HistorySnapshotCard()
                    }
                    .padding(14)
                }

                Divider()

                VStack(spacing: 10) {
                    Button {
                        model.performHistoryRestoreOrRevert(title: event.title, detail: event.detail)
                    } label: {
                        Label(model.historyActionButtonTitle(title: event.title, detail: event.detail), systemImage: "arrow.counterclockwise.circle")
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(CleanupPrimaryFooterButtonStyle(isActive: model.historyActionCanApplyDirectly(title: event.title, detail: event.detail)))

                    HStack(spacing: 10) {
                        Button {
                            if let path = event.detailPathCandidate {
                                model.revealInFinder(path: path)
                            } else {
                                model.copyToClipboard(event.detail, label: "history detail")
                            }
                        } label: {
                            Text(event.detailPathCandidate == nil ? "Copy Detail" : "Reveal")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(DetailFooterButtonStyle())

                        Menu {
                            Button("Log Revert Request") {
                                model.logHistoryRevertRequest(title: event.title, detail: event.detail)
                            }
                            Button("Copy Details") {
                                model.copyToClipboard("\(event.title): \(event.detail)", label: "history details")
                            }
                            Button("Run New Scan") {
                                Task { await model.runFullScan() }
                            }
                        } label: {
                            HStack {
                                Text("More Actions")
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(DetailFooterButtonStyle())
                        .menuStyle(.button)
                    }
                }
                .padding(14)
            } else {
                ContentUnavailableView("No History Yet", systemImage: "clock.arrow.circlepath", description: Text("Run scans or review cleanup items to create restore points and reversible audit events."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DashboardTheme.panel)
    }
}

private struct HistoryDisplayEvent: Identifiable, Hashable {
    let id: String
    let date: Date
    let title: String
    let detail: String
    let kind: HistoryEventKind
    let result: HistoryEventResult
    let impactBytes: Int64

    var relativeDateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var dateText: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }

    var detailPathCandidate: String? {
        detail.hasPrefix("/") ? detail : nil
    }
}

private enum HistoryEventKind: Hashable {
    case cleanup
    case restore
    case scan
    case update
    case file
    case app
    case settings
    case other

    var label: String {
        switch self {
        case .cleanup: return "Cleanup"
        case .restore: return "Restore"
        case .scan: return "Scan"
        case .update: return "Update"
        case .file: return "File Change"
        case .app: return "App Change"
        case .settings: return "Settings"
        case .other: return "System"
        }
    }

    var systemImage: String {
        switch self {
        case .cleanup: return "shield.checkered"
        case .restore: return "arrow.uturn.backward.circle"
        case .scan: return "magnifyingglass.circle"
        case .update: return "arrow.down.circle"
        case .file: return "doc.badge.gearshape"
        case .app: return "app.badge"
        case .settings: return "gearshape"
        case .other: return "clock.arrow.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .cleanup: return DashboardTheme.accent
        case .restore: return DashboardTheme.green
        case .scan: return DashboardTheme.blue
        case .update: return DashboardTheme.blue
        case .file: return DashboardTheme.orange
        case .app: return DashboardTheme.accent
        case .settings: return DashboardTheme.secondaryText
        case .other: return DashboardTheme.secondaryText
        }
    }
}

private enum HistoryEventResult: Hashable {
    case completed
    case restored
    case pending
    case cancelled
    case failed

    var label: String {
        switch self {
        case .completed: return "Completed"
        case .restored: return "Restored"
        case .pending: return "Pending"
        case .cancelled: return "Cancelled"
        case .failed: return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .completed: return DashboardTheme.green
        case .restored: return DashboardTheme.green
        case .pending: return DashboardTheme.orange
        case .cancelled: return DashboardTheme.secondaryText
        case .failed: return DashboardTheme.red
        }
    }
}

private struct HistoryStoragePoint: Identifiable, Hashable {
    let date: Date
    let bytes: Int64

    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct HistoryMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(detail)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .frame(minHeight: 118, alignment: .topLeading)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private struct HistoryStorageTimelineCard: View {
    @EnvironmentObject private var model: AppModel
    let points: [HistoryStoragePoint]
    let reclaimedBytes: Int64
    let eventCount: Int

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    CardHeader(title: "Storage Over Time", subtitle: "Current scan baseline with known cleanup and restore deltas")
                    Spacer()
                    Picker("Range", selection: .constant("30D")) {
                        Text("7D").tag("7D")
                        Text("30D").tag("30D")
                        Text("90D").tag("90D")
                        Text("1Y").tag("1Y")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .labelsHidden()
                }

                HistoryStorageChart(points: points)
                    .frame(height: 206)

                HStack(spacing: 12) {
                    HistoryLegendItem(color: DashboardTheme.accent, title: "Tracked Apps", value: compactBytes(model.scannedSizeBytes))
                    HistoryLegendItem(color: DashboardTheme.green, title: "Reclaimed", value: compactBytes(reclaimedBytes))
                    HistoryLegendItem(color: DashboardTheme.blue, title: "Restorable", value: "\(model.cleanupSuggestions.filter { $0.state == .quarantined && $0.quarantinePath != nil }.count)")
                    HistoryLegendItem(color: Color.gray.opacity(0.72), title: "Events", value: "\(eventCount)")
                }
            }
        }
    }
}

private struct HistoryStorageChart: View {
    let points: [HistoryStoragePoint]

    var body: some View {
        GeometryReader { geometry in
            let maxBytes = max(points.map(\.bytes).max() ?? 1, 1)
            let minBytes: Int64 = 0
            let range = max(maxBytes, 1)
            let plottingRect = CGRect(x: 0, y: 12, width: geometry.size.width, height: geometry.size.height - 34)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(DashboardTheme.track)
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(DashboardTheme.track)
                        .frame(height: 1)
                }
                .padding(.bottom, 22)

                chartFill(in: plottingRect, minBytes: minBytes, range: range)
                    .fill(
                        LinearGradient(
                            colors: [DashboardTheme.accent.opacity(0.24), DashboardTheme.accent.opacity(0.035)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                chartLine(in: plottingRect, minBytes: minBytes, range: range)
                    .stroke(DashboardTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(points) { point in
                    Circle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 8, height: 8)
                        .position(pointPosition(point, in: plottingRect, minBytes: minBytes, range: range))
                        .help("\(historyShortDate(point.date)): \(compactBytes(point.bytes))")
                }

                HStack {
                    Text(historyShortDate(points.first?.date))
                    Spacer()
                    Text(historyShortDate(points.last?.date))
                }
                .font(.caption2)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func chartLine(in rect: CGRect, minBytes: Int64, range: Int64) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let position = pointPosition(point, in: rect, minBytes: minBytes, range: range)
                if index == 0 {
                    path.move(to: position)
                } else {
                    path.addLine(to: position)
                }
            }
        }
    }

    private func chartFill(in rect: CGRect, minBytes: Int64, range: Int64) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: pointPosition(first, in: rect, minBytes: minBytes, range: range).x, y: rect.maxY))
            for point in points {
                path.addLine(to: pointPosition(point, in: rect, minBytes: minBytes, range: range))
            }
            path.addLine(to: CGPoint(x: pointPosition(last, in: rect, minBytes: minBytes, range: range).x, y: rect.maxY))
            path.closeSubpath()
        }
    }

    private func pointPosition(_ point: HistoryStoragePoint, in rect: CGRect, minBytes: Int64, range: Int64) -> CGPoint {
        guard let first = points.first?.date.timeIntervalSince1970,
              let last = points.last?.date.timeIntervalSince1970,
              last > first
        else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        let xPercent = (point.date.timeIntervalSince1970 - first) / (last - first)
        let yPercent = Double(point.bytes - minBytes) / Double(range)
        return CGPoint(
            x: rect.minX + rect.width * CGFloat(xPercent),
            y: rect.maxY - rect.height * CGFloat(yPercent)
        )
    }
}

private struct HistoryLegendItem: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

private struct HistoryTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Date & Time")
                .frame(width: 116, alignment: .leading)
            Text("Type")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Result")
                .frame(width: 100, alignment: .leading)
            Text("Impact")
                .frame(width: 86, alignment: .trailing)
            Text("Actions")
                .frame(width: 118, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DashboardTheme.secondaryText)
        .padding(.vertical, 8)
    }
}

private struct HistoryTableRow: View {
    @EnvironmentObject private var model: AppModel
    let event: HistoryDisplayEvent
    let isSelected: Bool

    var body: some View {
        let directAction = model.historyActionCanApplyDirectly(title: event.title, detail: event.detail)
        let actionLabel = directAction ? "Revert" : "Request"

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.dateText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(event.relativeDateText)
                    .font(.caption2)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 116, alignment: .leading)

            HStack(spacing: 10) {
                HistoryIconBubble(kind: event.kind, size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(event.detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HistoryResultBadge(result: event.result)
                .frame(width: 100, alignment: .leading)

            Text(event.impactBytes > 0 ? compactBytes(event.impactBytes) : "--")
                .font(.caption.monospacedDigit())
                .foregroundStyle(event.impactBytes > 0 ? DashboardTheme.primaryText : DashboardTheme.secondaryText)
                .frame(width: 86, alignment: .trailing)

            HStack(spacing: 8) {
                Button {
                    model.performHistoryRestoreOrRevert(title: event.title, detail: event.detail)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: directAction ? "arrow.counterclockwise.circle" : "note.text.badge.plus")
                        Text(actionLabel)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(directAction ? DashboardTheme.accent : DashboardTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .frame(height: 26)
                    .background(directAction ? DashboardTheme.accent.opacity(0.07) : DashboardTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(model.historyActionButtonTitle(title: event.title, detail: event.detail))

                Menu {
                    Button(model.historyActionButtonTitle(title: event.title, detail: event.detail)) {
                        model.performHistoryRestoreOrRevert(title: event.title, detail: event.detail)
                    }
                    Button("Log Revert Request") {
                        model.logHistoryRevertRequest(title: event.title, detail: event.detail)
                    }
                    if let path = event.detailPathCandidate {
                        Divider()
                        Button("Reveal in Finder") {
                            model.revealInFinder(path: path)
                        }
                    }
                    Button("Copy Details") {
                        model.copyToClipboard("\(event.title): \(event.detail)", label: "history details")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .menuStyle(.button)
            }
            .frame(width: 118, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isSelected ? DashboardTheme.accent.opacity(0.075) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct HistoryIconBubble: View {
    let kind: HistoryEventKind
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.color)
            .frame(width: size, height: size)
            .background(kind.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.25), style: .continuous))
    }
}

private struct HistoryResultBadge: View {
    let result: HistoryEventResult

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(result.color)
                .frame(width: 6, height: 6)
            Text(result.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(result.color)
                .lineLimit(1)
        }
    }
}

private struct HistoryInspectorHeader: View {
    let event: HistoryDisplayEvent

    var body: some View {
        HistoryInspectorCard {
            HStack(alignment: .top, spacing: 12) {
                HistoryIconBubble(kind: event.kind, size: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.kind.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Text(event.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(2)
                    Text(event.dateText)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct HistoryActionStatusCard: View {
    @EnvironmentObject private var model: AppModel
    let event: HistoryDisplayEvent

    var body: some View {
        HistoryInspectorCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Restore Status")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                    Spacer()
                    HistoryResultBadge(result: event.result)
                }

                HStack(spacing: 8) {
                    HistoryStatusMetric(title: "Impact", value: event.impactBytes > 0 ? compactBytes(event.impactBytes) : "None")
                    HistoryStatusMetric(title: "Action", value: model.historyActionButtonTitle(title: event.title, detail: event.detail))
                }

                Text(statusCopy)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusCopy: String {
        if model.historyActionCanApplyDirectly(title: event.title, detail: event.detail) {
            return "This event has enough local state for App Monitor to apply a restore or revert safely."
        }
        return "This event is preserved as an audit trail. App Monitor will log a revert request instead of attempting an unsafe undo."
    }
}

private struct HistoryStatusMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DashboardTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DashboardTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct HistoryActionContextCard: View {
    let event: HistoryDisplayEvent

    var body: some View {
        HistoryInspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Change Detail")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(5)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Divider()
                HStack {
                    Text("Category")
                    Spacer()
                    Text(event.kind.label)
                }
                HStack {
                    Text("Recorded")
                    Spacer()
                    Text(event.relativeDateText)
                }
            }
            .font(.caption)
            .foregroundStyle(DashboardTheme.secondaryText)
        }
    }
}

private struct HistoryTimelineMiniCard: View {
    let events: [HistoryDisplayEvent]

    var body: some View {
        HistoryInspectorCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity Timeline")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)

                if events.isEmpty {
                    Text("No activity recorded yet.")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(event.kind.color)
                                        .frame(width: 10, height: 10)
                                    Rectangle()
                                        .fill(event.kind.color.opacity(0.24))
                                        .frame(width: 2, height: 34)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.dateText)
                                        .font(.caption2)
                                        .foregroundStyle(DashboardTheme.secondaryText)
                                    Text(event.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DashboardTheme.primaryText)
                                        .lineLimit(1)
                                    Text(event.detail)
                                        .font(.caption2)
                                        .foregroundStyle(DashboardTheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .help(event.detail)
                                }
                                Spacer()
                            }
                            .frame(minHeight: 46, alignment: .top)
                        }
                    }
                }
            }
        }
    }
}

private struct HistorySnapshotCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HistoryInspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Snapshots")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                Text("Compare the current scan baseline with future scans and restore-point events.")
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await model.runFullScan() }
                } label: {
                    Label("Create Snapshot", systemImage: "camera.metering.matrix")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(DetailFooterButtonStyle())
            }
        }
    }
}

private struct HistoryInspectorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(13)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

@MainActor
private func makeHistoryEvent(date: Date, title: String, detail: String, model: AppModel) -> HistoryDisplayEvent {
    let impact = model.cleanupSuggestions.first(where: { $0.path == detail })?.sizeBytes
        ?? model.largeFiles.first(where: { $0.path == detail })?.sizeBytes
        ?? 0
    return HistoryDisplayEvent(
        id: historyEventID(date: date, title: title, detail: detail),
        date: date,
        title: title,
        detail: detail,
        kind: historyKind(for: title),
        result: historyResult(for: title),
        impactBytes: impact
    )
}

private func historyEventID(date: Date, title: String, detail: String) -> String {
    "\(date.timeIntervalSince1970)|\(title)|\(detail)"
}

private func historyKind(for title: String) -> HistoryEventKind {
    let lower = title.lowercased()
    if lower.contains("restore") || lower.contains("revert") {
        return .restore
    }
    if lower.contains("cleanup") || lower.contains("quarantine") {
        return .cleanup
    }
    if lower.contains("scan") || lower.contains("import") {
        return .scan
    }
    if lower.contains("update") {
        return .update
    }
    if lower.contains("file") || lower.contains("trash") {
        return .file
    }
    if lower.contains("tag") || lower.contains("ignore") || lower.contains("archive") || lower.contains("uninstall") {
        return .app
    }
    if lower.contains("schedule") || lower.contains("setting") {
        return .settings
    }
    return .other
}

private func historyResult(for title: String) -> HistoryEventResult {
    let lower = title.lowercased()
    if lower.contains("failed") {
        return .failed
    }
    if lower.contains("cancel") {
        return .cancelled
    }
    if lower.contains("request") || lower.contains("queued") || lower.contains("pending") {
        return .pending
    }
    if lower.contains("restore") || lower.contains("revert") {
        return .restored
    }
    return .completed
}

private func historyShortDate(_ date: Date?) -> String {
    guard let date else { return "--" }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

private struct SettingsScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Settings", subtitle: "Appearance, background cadence, saved filters, and launch behavior")
                .padding(.top, 6)

            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    AppearanceSettingsSection()
                    Divider()
                    Toggle("Launch App Monitor at login", isOn: Binding(
                        get: { model.loginItemEnabled },
                        set: { model.setLoginItemEnabled($0) }
                    ))
                    Toggle("Keep running in menu bar when closed", isOn: Binding(
                        get: { model.keepRunningWhenClosed },
                        set: { model.setKeepRunningWhenClosed($0) }
                    ))
                    Text("Closing the dashboard hides the window and Dock icon while keeping the status icon available.")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Divider()
                    Toggle("Enable recurring full scan", isOn: Binding(
                        get: { model.scanSchedule.isEnabled },
                        set: { model.updateScanSchedule(enabled: $0) }
                    ))
                    Picker("Scan cadence", selection: Binding(
                        get: { model.scanSchedule.intervalHours },
                        set: { model.updateScanSchedule(intervalHours: $0) }
                    )) {
                        Text("Every 6 hours").tag(6)
                        Text("Every 12 hours").tag(12)
                        Text("Daily").tag(24)
                        Text("Weekly").tag(168)
                    }
                    .pickerStyle(.segmented)
                    DashboardDetailLine(title: "Next Scan", value: AppMonitorFormatting.shortDateTime(model.scanSchedule.nextScanAt))
                    DashboardDetailLine(title: "Login Item Status", value: model.loginItemStatus)
                    Toggle("Show ignored apps in tables", isOn: $model.includeIgnoredApps)
                    Divider()
                    SettingsSectionHeader(title: "App Monitor Updates", systemImage: "app.badge")
                    Toggle("Automatically check for App Monitor updates", isOn: Binding(
                        get: { model.appMonitorUpdateChecksEnabled },
                        set: { model.updateAppMonitorUpdateSchedule(enabled: $0) }
                    ))
                    Toggle("Automatically install App Monitor updates", isOn: Binding(
                        get: { model.appMonitorAutomaticUpdatesEnabled },
                        set: { model.updateAppMonitorAutomaticUpdates(enabled: $0) }
                    ))
                    Picker("App Monitor cadence", selection: Binding(
                        get: { model.appMonitorUpdateCadenceHours },
                        set: { model.updateAppMonitorUpdateSchedule(cadenceHours: $0) }
                    )) {
                        Text("Every 6 hours").tag(6)
                        Text("Every 12 hours").tag(12)
                        Text("Daily").tag(24)
                        Text("Weekly").tag(168)
                    }
                    .pickerStyle(.segmented)
                    HStack(alignment: .center, spacing: 12) {
                        DashboardDetailLine(title: "Last App Monitor Check", value: AppMonitorFormatting.shortDateTime(model.appMonitorUpdateLastCheckAt))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Task { await model.checkForAppMonitorUpdate() }
                        } label: {
                            Label(model.isCheckingAppMonitorUpdate ? "Checking" : "Check App Monitor", systemImage: "arrow.clockwise")
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isCheckingAppMonitorUpdate || model.isInstallingAppMonitorUpdate)
                    }
                    DashboardDetailLine(title: "Next App Monitor Check", value: AppMonitorFormatting.shortDateTime(model.appMonitorUpdateNextCheckAt))
                    DashboardDetailLine(title: "App Monitor Update Status", value: model.appMonitorUpdateMessage)
                    if model.appMonitorUpdateRecord != nil {
                        Button {
                            Task { await model.installAppMonitorUpdate() }
                        } label: {
                            Label(model.isInstallingAppMonitorUpdate ? "Installing App Monitor" : "Install App Monitor Update", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isInstallingAppMonitorUpdate || model.isCheckingAppMonitorUpdate)
                    }
                    Divider()
                    SettingsSectionHeader(title: "Installed App Update Discovery", systemImage: "square.stack.3d.up")
                    Toggle("Enable scheduled installed-app checks", isOn: Binding(
                        get: { model.updateSettings.scheduledChecksEnabled },
                        set: { model.updateUpdateSchedule(enabled: $0) }
                    ))
                    Toggle("Automatically install eligible app updates", isOn: Binding(
                        get: { model.updateSettings.automaticUpdatesEnabled },
                        set: { model.updateAutomaticUpdates(enabled: $0) }
                    ))
                    Picker("Installed app cadence", selection: Binding(
                        get: { model.updateSettings.cadenceHours },
                        set: { model.updateUpdateSchedule(cadenceHours: $0) }
                    )) {
                        Text("Every 6 hours").tag(6)
                        Text("Every 12 hours").tag(12)
                        Text("Daily").tag(24)
                        Text("Weekly").tag(168)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Include Homebrew formulae", isOn: Binding(
                        get: { model.updateSettings.includeHomebrewFormulae },
                        set: { model.updateUpdateSourceSettings(includeHomebrewFormulae: $0) }
                    ))
                    Toggle("Include macOS and Safari updates", isOn: Binding(
                        get: { model.updateSettings.includeAppleSoftwareUpdates },
                        set: { model.updateUpdateSourceSettings(includeAppleSoftwareUpdates: $0) }
                    ))
                    Toggle("Detect direct-download app updates", isOn: Binding(
                        get: { model.updateSettings.includeDirectDownloadDetection },
                        set: { model.updateUpdateSourceSettings(includeDirectDownloadDetection: $0) }
                    ))
                    HStack(alignment: .center, spacing: 12) {
                        DashboardDetailLine(title: "Last Installed App Check", value: AppMonitorFormatting.shortDateTime(model.updateSettings.lastCheckAt))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Task { await model.checkForUpdates() }
                        } label: {
                            Label(model.isCheckingUpdates ? "Checking" : "Check Installed Apps", systemImage: "arrow.clockwise")
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isCheckingUpdates || model.isRunningUpdates)
                    }
                    DashboardDetailLine(title: "Next Installed App Check", value: AppMonitorFormatting.shortDateTime(model.updateSettings.nextCheckAt))
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(DashboardTheme.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GitHub Repository")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DashboardTheme.primaryText)
                            Text("github.com/jcranokc/app-monitor")
                                .font(.caption)
                                .foregroundStyle(DashboardTheme.secondaryText)
                        }
                        Spacer()
                        Button {
                            model.openGitHubRepository()
                        } label: {
                            Label("Open GitHub", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(DashboardTheme.accent)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DashboardTheme.primaryText)
        }
    }
}

private struct AppearanceSettingsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(DashboardTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                    Text("Applies to the dashboard and menu bar menu")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
                Spacer()
            }

            Picker("Theme", selection: Binding(
                get: { model.appearancePreference },
                set: { model.setAppearancePreference($0) }
            )) {
                ForEach(AppAppearancePreference.allCases) { preference in
                    Text(preference.settingsTitle).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
        }
    }
}

private struct StoragePathReviewRow: View {
    @EnvironmentObject private var model: AppModel
    let item: StorageScanItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: storageIcon(for: item.category))
                .foregroundStyle(DashboardTheme.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(item.category.rawValue) · \(model.ownerText(for: item.path)) · Risk \(model.riskText(for: item))")
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(compactBytes(item.sizeBytes))
                .font(.callout)
                .monospacedDigit()
            Menu {
                Button("Preview") { model.preview(path: item.path) }
                Button("Reveal in Finder") { model.revealInFinder(path: item.path) }
                Button("Move to Quarantine") { model.quarantineStorageItem(item) }
                Button("Move to Trash") { model.moveStorageItemToTrash(item) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

private enum StorageExplorerSort: String, CaseIterable, Identifiable {
    case size = "Size"
    case name = "Name"
    case category = "Category"

    var id: String { rawValue }
}

private struct VolumeStorageSnapshot {
    let totalCapacityBytes: Int64?
    let availableBytes: Int64?

    static func current() -> VolumeStorageSnapshot {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let total = values?.volumeTotalCapacity.map(Int64.init)
        let available = values?.volumeAvailableCapacityForImportantUsage ?? values?.volumeAvailableCapacity.map(Int64.init)
        return VolumeStorageSnapshot(totalCapacityBytes: total, availableBytes: available)
    }
}

private struct TotalStorageUsedCard: View {
    let scannedBytes: Int64
    let volumeSnapshot: VolumeStorageSnapshot
    let categoryTotals: [StorageCategoryTotal]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Total Storage Used")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(compactBytes(scannedBytes))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()
                    if let totalCapacityBytes = volumeSnapshot.totalCapacityBytes {
                        Text("of \(compactBytes(totalCapacityBytes))")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .monospacedDigit()
                    }
                }

                CategorySegmentedStorageBar(
                    categoryTotals: categoryTotals,
                    usedBytes: scannedBytes,
                    capacityBytes: volumeSnapshot.totalCapacityBytes
                )
                .frame(height: 16)

                HStack {
                    Text(usedLabel)
                    Spacer()
                    Text(freeLabel)
                }
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .monospacedDigit()
            }
        }
    }

    private var usedLabel: String {
        guard let totalCapacityBytes = volumeSnapshot.totalCapacityBytes, totalCapacityBytes > 0 else {
            return "\(categoryTotals.count) categories tracked"
        }
        return "\(percentageString(scannedBytes, of: totalCapacityBytes)) used"
    }

    private var freeLabel: String {
        guard let availableBytes = volumeSnapshot.availableBytes else {
            return "\(categoryTotals.reduce(0) { $0 + $1.itemCount }) paths tracked"
        }
        return "\(compactBytes(availableBytes)) free"
    }
}

private struct CategorySegmentedStorageBar: View {
    let categoryTotals: [StorageCategoryTotal]
    let usedBytes: Int64
    let capacityBytes: Int64?

    var body: some View {
        GeometryReader { geometry in
            let denominator = max(capacityBytes ?? max(usedBytes, 1), 1)
            let visibleTotals = categoryTotals.prefix(8)
            let coloredWidth = min(geometry.size.width, geometry.size.width * CGFloat(Double(usedBytes) / Double(denominator)))

            HStack(spacing: 1) {
                ForEach(Array(visibleTotals)) { total in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(total.color)
                        .frame(width: segmentWidth(total.bytes, totalUsed: max(usedBytes, 1), availableWidth: coloredWidth))
                }

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(DashboardTheme.track)
                    .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func segmentWidth(_ bytes: Int64, totalUsed: Int64, availableWidth: CGFloat) -> CGFloat {
        guard totalUsed > 0 else { return 0 }
        return max(2, availableWidth * CGFloat(Double(bytes) / Double(totalUsed)))
    }
}

private struct LargestStorageCategoryCard: View {
    let total: StorageCategoryTotal?
    let totalBytes: Int64

    var body: some View {
        DashboardCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Largest Category")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Text(total?.title ?? "No Storage Data")
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(total.map { compactBytes($0.bytes) } ?? "Run Scan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()
                    Text(total.map { "\(percentageString($0.bytes, of: totalBytes)) of tracked storage" } ?? "Storage categories will appear after scanning.")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: total?.icon ?? "folder")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(total?.color ?? DashboardTheme.accent)
                    .frame(width: 58, height: 58)
                    .background((total?.color ?? DashboardTheme.accent).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct StorageCategoryOverviewCard: View {
    let total: StorageCategoryTotal
    let totalBytes: Int64
    let isSelected: Bool

    var body: some View {
        DashboardCard {
            HStack(spacing: 14) {
                Image(systemName: total.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(total.color)
                    .frame(width: 42, height: 42)
                    .background(total.color.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(total.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DashboardTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(isSelected ? total.color : DashboardTheme.secondaryText)
                    }

                    Text(compactBytes(total.bytes))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .monospacedDigit()

                    Text("\(total.itemCount) path\(total.itemCount == 1 ? "" : "s") / \(percentageString(total.bytes, of: totalBytes))")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? total.color.opacity(0.6) : Color.clear, lineWidth: 2)
        )
    }
}

private struct StorageDistributionCard: View {
    let categoryTotals: [StorageCategoryTotal]
    let totalBytes: Int64

    var body: some View {
        DashboardCard {
            CardHeader(title: "Storage Distribution", subtitle: "Visual breakdown of storage by category")
            if categoryTotals.isEmpty {
                EmptyCardState(systemImage: "rectangle.3.group", message: "Run Scan to populate category distribution.")
                    .frame(height: 170)
            } else {
                StorageCategoryTreemap(categoryTotals: categoryTotals, totalBytes: totalBytes)
                    .frame(height: 178)
                    .padding(.top, 12)
            }
        }
    }
}

private struct StorageCategoryTreemap: View {
    let categoryTotals: [StorageCategoryTotal]
    let totalBytes: Int64

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    categoryTile(at: 0)
                        .frame(width: geometry.size.width * 0.42)
                    categoryTile(at: 1)
                }
                .frame(height: geometry.size.height * 0.58)

                HStack(spacing: 4) {
                    categoryTile(at: 2)
                        .frame(width: geometry.size.width * 0.32)
                    categoryTile(at: 3)
                    categoryTile(at: 4)
                        .frame(width: geometry.size.width * 0.2)
                }
                .frame(height: geometry.size.height * 0.42)
            }
        }
    }

    @ViewBuilder
    private func categoryTile(at index: Int) -> some View {
        if categoryTotals.indices.contains(index) {
            let total = categoryTotals[index]
            VStack(alignment: .leading, spacing: 5) {
                Text(total.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(compactBytes(total.bytes))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                Text(percentageString(total.bytes, of: totalBytes))
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [total.color.opacity(0.8), total.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(DashboardTheme.track)
        }
    }
}

private struct TopApplicationsByStorageCard: View {
    @EnvironmentObject private var model: AppModel
    let rows: [AppUsageRow]

    var body: some View {
        DashboardCard {
            HStack {
                CardHeader(title: "Top Applications by Storage", subtitle: "\(rows.count) largest tracked apps")
                Spacer()
                Button("View All") {
                    model.showAllUsage()
                    model.sortKey = .totalSize
                    model.sortAscending = false
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardTheme.accent)
            }

            if rows.isEmpty {
                EmptyCardState(systemImage: "app.badge", message: "Run Scan to rank applications by total storage.")
                    .frame(height: 160)
            } else {
                VStack(spacing: 13) {
                    ForEach(rows) { row in
                        Button {
                            model.select(row)
                        } label: {
                            TopStorageAppRow(row: row, maxBytes: maxBytes)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var maxBytes: Int64 {
        max(rows.map(\.totalSizeBytes).max() ?? 1, 1)
    }
}

private struct TopStorageAppRow: View {
    let row: AppUsageRow
    let maxBytes: Int64

    var body: some View {
        HStack(spacing: 10) {
            AppIcon(path: row.app.path, size: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(row.app.name)
                .font(.callout.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .frame(width: 118, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DashboardTheme.track)
                    Capsule()
                        .fill(DashboardTheme.accent)
                        .frame(width: max(6, geometry.size.width * CGFloat(Double(row.totalSizeBytes) / Double(maxBytes))))
                }
            }
            .frame(height: 6)

            Text(compactBytes(row.totalSizeBytes))
                .font(.caption)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: 66, alignment: .trailing)
        }
    }
}

private struct StorageExplorerTable: View {
    let items: [StorageScanItem]
    let maxItemBytes: Int64
    @Binding var selectedCategory: StorageCategory?
    @Binding var sortMode: StorageExplorerSort

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    CardHeader(title: "Storage Explorer", subtitle: "Browse and manage large folders and files")
                    Spacer()
                    Menu {
                        ForEach(StorageExplorerSort.allCases) { mode in
                            Button {
                                sortMode = mode
                            } label: {
                                if sortMode == mode {
                                    Label(mode.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(mode.rawValue)
                                }
                            }
                        }
                    } label: {
                        ToolbarControl(title: "Sort by \(sortMode.rawValue)", systemImage: nil, trailingSystemImage: "chevron.down", compact: true)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    StorageCrumb(title: NSUserName(), systemImage: "person.crop.circle")
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                    StorageCrumb(title: "Library", systemImage: "folder")
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Menu {
                        Button("All Categories") {
                            selectedCategory = nil
                        }
                        ForEach(StorageCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                if selectedCategory == category {
                                    Label(storageTitle(for: category), systemImage: "checkmark")
                                } else {
                                    Text(storageTitle(for: category))
                                }
                            }
                        }
                    } label: {
                        StorageCrumb(title: selectedCategory.map(storageTitle(for:)) ?? "All Categories", systemImage: "externaldrive")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    Spacer()
                }

                VStack(spacing: 0) {
                    StorageExplorerHeaderRow()
                    Divider()
                    if items.isEmpty {
                        EmptyCardState(systemImage: "folder.badge.questionmark", message: "Run Scan or clear the category filter to see storage paths.")
                            .frame(height: 150)
                    } else {
                        ForEach(Array(items.prefix(90))) { item in
                            StorageExplorerPathRow(item: item, maxBytes: maxItemBytes)
                            if item.id != items.prefix(90).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct StorageCrumb: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(DashboardTheme.primaryText)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

private struct StorageExplorerHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 86, alignment: .trailing)
            Text("Category").frame(width: 118, alignment: .leading)
            Text("Last Scanned").frame(width: 118, alignment: .leading)
            Text("Size").frame(width: 118, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DashboardTheme.secondaryText)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

private struct StorageExplorerPathRow: View {
    @EnvironmentObject private var model: AppModel
    let item: StorageScanItem
    let maxBytes: Int64

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: itemIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.category == .bundle ? DashboardTheme.accent : DashboardTheme.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(parentPath)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(compactBytes(item.sizeBytes))
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: 86, alignment: .trailing)

            Text(storageTitle(for: item.category))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 118, alignment: .leading)

            Text(AppMonitorFormatting.tableDateTime(item.scannedAt))
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .frame(width: 118, alignment: .leading)

            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DashboardTheme.track)
                        Capsule()
                            .fill(DashboardTheme.accent)
                            .frame(width: max(5, geometry.size.width * CGFloat(Double(item.sizeBytes) / Double(maxBytes))))
                    }
                }
                .frame(height: 7)

                Menu {
                    Button("Preview") { model.preview(path: item.path) }
                    Button("Reveal in Finder") { model.revealInFinder(path: item.path) }
                    Button("Move to Quarantine") { model.quarantineStorageItem(item) }
                    Button("Move to Trash") { model.moveStorageItemToTrash(item) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .frame(width: 26, height: 26)
                        .background(DashboardTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(DashboardTheme.softStroke)
                        )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .help(item.path)
    }

    private var displayName: String {
        let name = URL(fileURLWithPath: item.path).lastPathComponent
        return name.isEmpty ? item.path : name
    }

    private var parentPath: String {
        URL(fileURLWithPath: item.path).deletingLastPathComponent().path
    }

    private var itemIcon: String {
        item.category == .bundle ? "app.fill" : "folder.fill"
    }
}

private struct StorageCategoryTotal: Identifiable {
    let category: StorageCategory
    let bytes: Int64
    let itemCount: Int

    var id: StorageCategory { category }

    var title: String {
        storageTitle(for: category)
    }

    var color: Color {
        storageColor(for: category)
    }

    var icon: String {
        storageIcon(for: category)
    }
}

private struct DashboardDetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardTheme.secondaryText)
            Text(value)
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .textSelection(.enabled)
        }
    }
}

private struct DashboardToolbar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showsCleanupNotice: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                SearchField(text: $model.searchText, focusToken: model.searchFocusToken)
                    .frame(width: 285)

                Spacer()

                Menu {
                    if model.destination == .cleanup {
                        Button {} label: {
                            Label("This Mac", systemImage: "checkmark")
                        }
                    } else {
                        ForEach(ReportingPeriod.allCases) { period in
                            Button {
                                model.period = period
                            } label: {
                                if model.period == period {
                                    Label(period.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(period.rawValue)
                                }
                            }
                        }
                    }
                } label: {
                    ToolbarControl(
                        title: model.destination == .cleanup ? "This Mac" : model.period.rawValue,
                        systemImage: model.destination == .cleanup ? "desktopcomputer" : "calendar",
                        trailingSystemImage: "chevron.down"
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                Menu {
                    Toggle("Show all bundles", isOn: $model.includeAllBundles)
                    Toggle("Show ignored apps", isOn: $model.includeIgnoredApps)
                    Toggle("Warnings only", isOn: $model.filterState.warningsOnly)
                    Toggle("Cleanup candidates only", isOn: $model.filterState.cleanupOnly)
                    Toggle("Hide protected apps", isOn: $model.filterState.hideProtectedApps)
                    Divider()
                    Menu("Storage category") {
                        Button("Any Category") {
                            model.filterState.category = nil
                        }
                        ForEach(StorageCategory.allCases) { category in
                            Button {
                                model.filterState.category = category
                            } label: {
                                if model.filterState.category == category {
                                    Label(category.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(category.rawValue)
                                }
                            }
                        }
                    }
                    Menu("Storage threshold") {
                        Button("Any Size") { model.filterState.minimumStorageBytes = 0 }
                        Button("100 MB+") { model.filterState.minimumStorageBytes = 100_000_000 }
                        Button("500 MB+") { model.filterState.minimumStorageBytes = 500_000_000 }
                        Button("1 GB+") { model.filterState.minimumStorageBytes = 1_000_000_000 }
                    }
                    Menu("Date range") {
                        ForEach(AppDateRangeFilter.allCases) { range in
                            Button {
                                model.filterState.dateRange = range
                            } label: {
                                if model.filterState.dateRange == range {
                                    Label(range.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(range.rawValue)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Save Current Filter") {
                        model.saveCurrentFilter()
                    }
                    if !model.savedFilters.isEmpty {
                        Menu("Saved Filters") {
                            ForEach(model.savedFilters) { filter in
                                Button(filter.name) {
                                    model.applySavedFilter(filter)
                                }
                            }
                        }
                    }
                    Button("Clear Filters") {
                        model.clearFilters()
                    }
                    Divider()
                    Button("Sort by usage") {
                        model.sortKey = .usage
                        model.sortAscending = false
                    }
                    Button("Sort by storage") {
                        model.sortKey = .totalSize
                        model.sortAscending = false
                    }
                    Button("Sort by name") {
                        model.sortKey = .app
                        model.sortAscending = true
                    }
                } label: {
                    ToolbarControl(title: "Filter", systemImage: "line.3.horizontal.decrease")
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                if model.destination != .cleanup {
                    Menu {
                        Button("Summary CSV") {
                            model.exportUsageSummary()
                        }
                        Button("Trend Buckets CSV") {
                            model.exportUsageTrendBuckets()
                        }
                        Button("Top Apps CSV") {
                            model.exportTopApps()
                        }
                        Button("Heatmap CSV") {
                            model.exportUsageHeatmap()
                        }
                        Divider()
                        Button("Current App Table CSV") {
                            model.exportCurrentRows()
                        }
                    } label: {
                        ToolbarControl(title: "Export", systemImage: "square.and.arrow.down")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await model.runFullScan() }
                } label: {
                    ToolbarControl(title: model.isScanningStorage ? "Scanning" : "Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.isScanningStorage)

                Button {
                    Task { await model.checkForUpdates() }
                } label: {
                    ToolbarControl(title: model.isCheckingUpdates ? "Checking" : "App Updates", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .disabled(model.isCheckingUpdates || model.isRunningUpdates)

                Button {
                    if model.destination == .cleanup {
                        Task { await model.runFullScan() }
                    } else {
                        model.navigate(.cleanup)
                    }
                } label: {
                    ToolbarControl(
                        title: model.destination == .cleanup ? "Rescan" : "Cleanup",
                        systemImage: model.destination == .cleanup ? "arrow.clockwise" : "sparkles",
                        isProminent: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.destination == .cleanup && model.isScanningStorage)
            }

            if model.isScanningStorage {
                OperationProgressStrip(progress: visibleScanProgress, tint: DashboardTheme.accent)
            }

            if model.isRunningCleanup {
                OperationProgressStrip(progress: visibleCleanupProgress, tint: DashboardTheme.green)
            }

            if model.isCheckingUpdates || model.isRunningUpdates {
                OperationProgressStrip(progress: visibleUpdateProgress, tint: DashboardTheme.blue)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(DashboardTheme.canvas)
    }

    private var visibleScanProgress: OperationProgressSnapshot {
        guard model.storageScanProgress.isVisible else {
            return OperationProgressSnapshot(
                title: "Scanning storage",
                detail: "Scanning apps and related files...",
                completedUnitCount: 0,
                totalUnitCount: max(model.rows.count, 1),
                currentPath: nil,
                scannedFileCount: 0,
                scannedBytes: 0
            )
        }
        return model.storageScanProgress
    }

    private var visibleCleanupProgress: OperationProgressSnapshot {
        guard model.cleanupProgress.isVisible else {
            return OperationProgressSnapshot(
                title: "Running cleanup",
                detail: "Moving approved items to quarantine...",
                completedUnitCount: 0,
                totalUnitCount: max(model.approvedCleanupCount, 1),
                currentPath: nil,
                scannedFileCount: 0,
                scannedBytes: 0
            )
        }
        return model.cleanupProgress
    }

    private var visibleUpdateProgress: OperationProgressSnapshot {
        guard model.updateProgress.isVisible else {
            return OperationProgressSnapshot(
                title: model.isCheckingUpdates ? "Checking installed app updates" : "Running installed app updates",
                detail: model.isCheckingUpdates ? "Checking installed app providers..." : "Installing selected app updates...",
                completedUnitCount: 0,
                totalUnitCount: max(model.updateRecords.count, 1),
                currentPath: nil,
                scannedFileCount: 0,
                scannedBytes: 0
            )
        }
        return model.updateProgress
    }
}

private struct RecentActivityCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DashboardCard {
            CardHeader(title: "Recent Activity", subtitle: "By total usage time")

            if activityRows.isEmpty {
                EmptyCardState(systemImage: "clock", message: "Usage will appear after App Monitor records active windows.")
                    .frame(height: 198)
            } else {
                VStack(spacing: 12) {
                    ForEach(activityRows) { row in
                        Button {
                            model.select(row)
                        } label: {
                            ActivityRow(row: row, maxUsage: maxUsage)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 12)

            Button {
                model.showAllUsage()
            } label: {
                CardFooterButton(title: "View All Usage", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 365)
    }

    private var activityRows: [AppUsageRow] {
        Array(model.displayedRows
            .filter { $0.usageSeconds > 0 || $0.importedDaysInPeriod > 0 }
            .sorted { $0.usageSeconds > $1.usageSeconds }
            .prefix(5))
    }

    private var maxUsage: TimeInterval {
        max(activityRows.map(\.usageSeconds).max() ?? 1, 1)
    }
}

private struct StorageBreakdownCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DashboardCard {
            CardHeader(title: "Storage Breakdown", subtitle: "By size on disk")

            if storageRows.isEmpty {
                EmptyCardState(systemImage: "externaldrive.badge.questionmark", message: "Run a storage scan to populate app and related file sizes.")
                    .frame(height: 240)
            } else {
                StorageTreemap(rows: storageRows)
                    .frame(height: 260)
                    .padding(.top, 8)
            }

            Spacer(minLength: 12)

            Button {
                model.showStorageExplorer()
            } label: {
                CardFooterButton(title: "View Storage", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 365)
    }

    private var storageRows: [AppUsageRow] {
        Array(model.rows
            .filter { $0.totalSizeBytes > 0 }
            .sorted { $0.totalSizeBytes > $1.totalSizeBytes }
            .prefix(7))
    }
}

private struct UsageTrendsCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DashboardCard {
            HStack(alignment: .top, spacing: 16) {
                CardHeader(title: "Usage Trends", subtitle: "Usage over the selected period")
                Spacer(minLength: 12)
                HStack(spacing: 26) {
                    TrendMetric(title: "Total", value: AppMonitorFormatting.duration(model.usageAnalytics.summary.totalSeconds))
                    TrendMetric(title: "Daily Avg", value: AppMonitorFormatting.duration(model.usageAnalytics.summary.dailyAverageSeconds))
                    TrendMetric(title: "Sessions", value: "\(model.usageAnalytics.summary.sessionCount)")
                    TrendMetric(title: "Top App", value: model.usageAnalytics.summary.mostUsedApp?.appName ?? "No data")
                }
            }

            UsageStackedTrendChart(
                buckets: Array(model.usageAnalytics.trendBuckets.suffix(7)),
                mode: .stacked,
                compact: true
            )
                .frame(height: 170)
                .padding(.top, 8)
        }
    }
}

private struct UsageTrendsWorkspace: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Usage Trends", subtitle: "Understand how you use your Mac over time.")
                .padding(.top, 6)

            UsageSummaryMetricGrid(snapshot: model.usageAnalytics)
            UsageOverTimeCard()
            UsageHeatmapCard()
        }
    }
}

private struct UsageSummaryMetricGrid: View {
    let snapshot: UsageAnalyticsSnapshot

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            UsageMetricSummaryCard(
                title: "Total Usage",
                systemImage: "clock.fill",
                value: AppMonitorFormatting.duration(snapshot.summary.totalSeconds),
                detail: "\(snapshot.summary.sessionCount) sessions",
                comparison: usageComparisonText(snapshot.summary.comparison.totalPercentChange),
                tint: DashboardTheme.accent
            )
            UsageMetricSummaryCard(
                title: "Daily Average",
                systemImage: "calendar",
                value: AppMonitorFormatting.duration(snapshot.summary.dailyAverageSeconds),
                detail: "Across active days",
                comparison: usageComparisonText(snapshot.summary.comparison.dailyAveragePercentChange),
                tint: DashboardTheme.blue
            )
            UsageMetricSummaryCard(
                title: "Peak Day",
                systemImage: "chart.bar.fill",
                value: snapshot.summary.peakDay.map(AppMonitorFormatting.day) ?? "No data",
                detail: AppMonitorFormatting.duration(snapshot.summary.peakDaySeconds),
                comparison: snapshot.summary.totalSeconds > 0 ? "Highest day" : "No usage recorded",
                tint: DashboardTheme.orange
            )
            UsageMetricSummaryCard(
                title: "Most Used App",
                systemImage: "app.fill",
                value: snapshot.summary.mostUsedApp?.appName ?? "No data",
                detail: AppMonitorFormatting.duration(snapshot.summary.mostUsedApp?.seconds ?? 0),
                comparison: snapshot.summary.mostUsedApp.map { usagePercentText($0.percentOfTotal) + " of usage" } ?? "No usage recorded",
                tint: DashboardTheme.green
            )
            UsageMetricSummaryCard(
                title: "Total Sessions",
                systemImage: "point.3.connected.trianglepath.dotted",
                value: "\(snapshot.summary.sessionCount)",
                detail: "Foreground intervals",
                comparison: usageComparisonText(snapshot.summary.comparison.sessionPercentChange),
                tint: Color(red: 0.42, green: 0.38, blue: 0.72)
            )
        }
    }
}

private struct UsageMetricSummaryCard: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String
    let comparison: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }

            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(detail)
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(comparison)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(minHeight: 145, alignment: .topLeading)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private enum UsageChartMode: String, CaseIterable, Identifiable {
    case stacked = "Stacked"
    case total = "Total"

    var id: String { rawValue }
}

private struct UsageOverTimeCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: UsageChartMode = .stacked

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    CardHeader(title: "Usage Over Time", subtitle: "\(model.period.rawValue) grouped \(model.usageTrendGrouping.rawValue.lowercased())")
                    Spacer()
                    Picker("Chart mode", selection: $mode) {
                        ForEach(UsageChartMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)

                    Picker("Grouping", selection: $model.usageTrendGrouping) {
                        ForEach(UsageTrendGrouping.allCases) { grouping in
                            Text(grouping.rawValue).tag(grouping)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 122)
                }

                if model.usageAnalytics.summary.totalSeconds <= 0 {
                    EmptyCardState(systemImage: "chart.xyaxis.line", message: "No usage recorded for this period.")
                        .frame(height: 210)
                } else {
                    UsageStackedTrendChart(
                        buckets: model.usageAnalytics.trendBuckets,
                        mode: mode,
                        compact: false
                    )
                    .frame(height: 250)

                    UsageStackLegend(topApps: Array(model.usageAnalytics.topApps.prefix(5)), buckets: model.usageAnalytics.trendBuckets)
                }
            }
        }
    }
}

private struct UsageStackedTrendChart: View {
    @EnvironmentObject private var model: AppModel
    let buckets: [UsageTrendBucket]
    let mode: UsageChartMode
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            let maxTotal = max(buckets.map(\.totalSeconds).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: compact ? 7 : 10) {
                ForEach(buckets) { bucket in
                    VStack(spacing: compact ? 5 : 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DashboardTheme.subtleFill)

                            if mode == .total {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DashboardTheme.accent)
                                    .frame(height: barHeight(for: bucket.totalSeconds, maxTotal: maxTotal, availableHeight: geometry.size.height - labelHeight))
                                    .help(usageBucketTooltip(bucket: bucket, grouping: model.usageAnalytics.grouping))
                            } else {
                                VStack(spacing: 1) {
                                    Spacer(minLength: 0)
                                    ForEach(bucket.stacks.reversed()) { segment in
                                        Button {
                                            if !segment.isOther {
                                                model.selectApp(id: segment.appID)
                                            }
                                        } label: {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(usageColor(for: segment.appID, isOther: segment.isOther))
                                                .frame(height: barHeight(for: segment.seconds, maxTotal: maxTotal, availableHeight: geometry.size.height - labelHeight))
                                        }
                                        .buttonStyle(.plain)
                                        .help(usageSegmentTooltip(bucket: bucket, segment: segment, grouping: model.usageAnalytics.grouping))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height - labelHeight)

                        if !compact {
                            Text(usageBucketLabel(bucket.start, grouping: model.usageAnalytics.grouping))
                                .font(.caption2)
                                .foregroundStyle(DashboardTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityLabel("Usage over time chart")
    }

    private var labelHeight: CGFloat {
        compact ? 0 : 24
    }

    private func barHeight(for seconds: TimeInterval, maxTotal: TimeInterval, availableHeight: CGFloat) -> CGFloat {
        guard seconds > 0 else { return 0 }
        return max(2, availableHeight * CGFloat(seconds / maxTotal))
    }
}

private struct UsageStackLegend: View {
    let topApps: [TopAppUsage]
    let buckets: [UsageTrendBucket]

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(topApps) { app in
                HStack(spacing: 7) {
                    Circle()
                        .fill(usageColor(for: app.appID))
                        .frame(width: 9, height: 9)
                    Text(app.appName)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(usagePercentText(app.percentOfTotal))
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .monospacedDigit()
                }
            }

            if includesOther {
                HStack(spacing: 7) {
                    Circle()
                        .fill(usageColor(for: "__other__", isOther: true))
                        .frame(width: 9, height: 9)
                    Text("Other")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.primaryText)
                    Text("Grouped")
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
            }
        }
    }

    private var includesOther: Bool {
        buckets.flatMap(\.stacks).contains { $0.isOther }
    }
}

private struct UsageHeatmapCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(title: "Usage Heatmap", subtitle: "Time-of-day density")

                if model.usageAnalytics.summary.totalSeconds <= 0 {
                    EmptyCardState(systemImage: "square.grid.3x3", message: "No usage recorded for this period.")
                        .frame(height: 190)
                } else {
                    UsageHeatmapGrid(cells: model.usageAnalytics.heatmapCells)
                        .frame(minHeight: heatmapHeight)
                }
            }
        }
    }

    private var heatmapHeight: CGFloat {
        let rowCount = Set(model.usageAnalytics.heatmapCells.map(\.rowLabel)).count
        return CGFloat(max(7, rowCount)) * 18 + 38
    }
}

private struct UsageHeatmapGrid: View {
    let cells: [UsageHeatmapCell]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Color.clear
                    .frame(width: 54, height: 13)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 6 == 0 ? "\(hour)" : "")
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(rows, id: \.id) { row in
                HStack(spacing: 3) {
                    Text(row.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(1)
                        .frame(width: 54, alignment: .trailing)

                    ForEach(row.cells) { cell in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(heatmapColor(for: cell.seconds, maxSeconds: maxSeconds))
                            .frame(maxWidth: .infinity)
                            .frame(height: 12)
                            .help(heatmapTooltip(cell))
                            .accessibilityLabel("\(cell.rowLabel) \(cell.hourOfDay):00 \(AppMonitorFormatting.duration(cell.seconds))")
                    }
                }
            }
        }
    }

    private var rows: [HeatmapDisplayRow] {
        let grouped = Dictionary(grouping: cells) { cell in
            "\(cell.rowStart.timeIntervalSince1970)|\(cell.rowLabel)"
        }

        return grouped.map { key, cells in
            let sorted = cells.sorted { $0.hourOfDay < $1.hourOfDay }
            return HeatmapDisplayRow(
                id: key,
                label: sorted.first?.rowLabel ?? "",
                rowStart: sorted.first?.rowStart ?? .distantPast,
                cells: sorted
            )
        }
        .sorted { $0.rowStart < $1.rowStart }
    }

    private var maxSeconds: TimeInterval {
        max(cells.map(\.seconds).max() ?? 1, 1)
    }
}

private struct HeatmapDisplayRow {
    let id: String
    let label: String
    let rowStart: Date
    let cells: [UsageHeatmapCell]
}

private func unusedStoragePassUsageComparisonText(_ percentChange: Double?) -> String {
    guard let percentChange else { return "No prior data" }
    let sign = percentChange >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.0f", abs(percentChange) * 100))% vs previous"
}

private func unusedStoragePassUsagePercentText(_ percent: Double) -> String {
    if percent > 0, percent < 0.01 {
        return "<1%"
    }
    return "\(String(format: "%.0f", percent * 100))%"
}

private func unusedStoragePassUsageColor(for appID: String, isOther: Bool = false) -> Color {
    if isOther { return Color.gray.opacity(0.72) }
    var hash = 0
    for scalar in appID.unicodeScalars {
        hash = abs((hash &* 31) &+ Int(scalar.value))
    }
    return tileColors[hash % tileColors.count]
}

private func unusedStoragePassUsageBucketLabel(_ date: Date, grouping: UsageTrendGrouping) -> String {
    let formatter = DateFormatter()
    switch grouping {
    case .day:
        formatter.dateFormat = "EEE"
    case .week:
        formatter.dateFormat = "MMM d"
    case .month:
        formatter.dateFormat = "MMM"
    }
    return formatter.string(from: date)
}

private func unusedStoragePassUsageBucketTooltip(bucket: UsageTrendBucket) -> String {
    "\(unusedStoragePassUsageBucketLabel(bucket.start, grouping: .day)): \(AppMonitorFormatting.duration(bucket.totalSeconds))"
}

private func unusedStoragePassUsageSegmentTooltip(bucket: UsageTrendBucket, segment: UsageStackSegment) -> String {
    "\(segment.appName): \(AppMonitorFormatting.duration(segment.seconds)) in \(unusedStoragePassUsageBucketLabel(bucket.start, grouping: .day))"
}

private func unusedStoragePassHeatmapColor(for seconds: TimeInterval, maxSeconds: TimeInterval) -> Color {
    guard maxSeconds > 0, seconds > 0 else {
        return DashboardTheme.track
    }
    return DashboardTheme.accent.opacity(0.16 + 0.76 * min(1, seconds / maxSeconds))
}

private func unusedStoragePassHeatmapTooltip(_ cell: UsageHeatmapCell) -> String {
    let topApp = cell.topAppName.map { " / \($0)" } ?? ""
    return "\(cell.rowLabel) \(cell.hourOfDay):00: \(AppMonitorFormatting.duration(cell.seconds))\(topApp)"
}

private struct AppDetailPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsCleanupNotice = false

    var body: some View {
        VStack(spacing: 0) {
            if let row = model.selectedRow {
                if model.destination == .warnings {
                    let warning = model.selectedWarning(for: row)
                    let warningRow = warning.flatMap { model.appRow(for: $0.appID) } ?? row
                    ScrollView {
                        WarningInspectorPanel(row: warningRow, warning: warning)
                            .padding(18)
                    }

                    Divider()

                    WarningInspectorFooter(row: warningRow, warning: warning)
                        .padding(18)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if let session = model.selectedTimelineSession {
                                TimelineSessionDetailCard(session: session)
                            }
                            DetailHeader(row: row)
                            DetailQuickStats(row: row)
                            DetailMiniUsageChart(rows: selectedDailyRows)
                            TopAppsThisPeriodSection()
                            UsageInsightsSection()
                            DetailStorageSection(row: row)
                            RelatedFilesSection(row: row)
                        }
                        .padding(18)
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Button {
                            model.revealSelectedInFinder()
                        } label: {
                            Text("Reveal in Finder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DetailFooterButtonStyle())

                        Menu {
                            Button("Rescan Selected App") {
                                Task { await model.rescanSelectedApp() }
                            }
                            Button("Tag: Needs Review") {
                                model.tagSelectedApp("Needs Review")
                            }
                            Button("Tag: Keep") {
                                model.tagSelectedApp("Keep")
                            }
                            Button("Ignore App") {
                                model.setSelectedAppIgnored(true)
                            }
                            Button("Archive App Record") {
                                model.archiveSelectedAppRecord()
                            }
                            Divider()
                            Button("Uninstall & Clean Up...") {
                                Task { await model.prepareSelectedAppUninstall() }
                            }
                            Divider()
                            Button("Export Current Table") {
                                model.exportCurrentRows()
                            }
                            Button("Import Activity") {
                                Task { await model.refreshImportedActivity() }
                            }
                            Button("Refresh Inventory") {
                                Task { await model.refreshInventory() }
                            }
                            Button("Cleanup Suggestions") {
                                model.navigate(.cleanup)
                            }
                        } label: {
                            HStack {
                                Text("More Actions")
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DetailFooterButtonStyle())
                        .menuStyle(.button)
                    }
                    .padding(18)
                }
            } else {
                ContentUnavailableView("No App Selected", systemImage: "app.dashed", description: Text("Scan or search for an app to inspect usage and related files."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DashboardTheme.panel)
        .alert("Cleanup needs a cleanup engine", isPresented: $showsCleanupNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This UI can point at related files, but it cannot safely delete or restore files yet.")
        }
    }

    private var selectedDailyRows: [DailyUsageRow] {
        model.dailyUsageRowsForSelectedApp()
    }
}

private struct TimelineSessionDetailCard: View {
    @EnvironmentObject private var model: AppModel
    let session: TimelineSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(DashboardTheme.accent.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Text(session.appName)
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text("\(timelineDateTime(session.startedAt)) - \(timelineTime(session.endedAt))")
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                DetailStatBox(title: "Duration", value: AppMonitorFormatting.duration(session.durationSeconds))
                DetailStatBox(title: "Source", value: session.source)
                DetailStatBox(title: "Clipped", value: session.isClipped ? "Yes" : "No")
            }

            HStack(spacing: 8) {
                Button {
                    model.revealInFinder(path: session.appPath)
                } label: {
                    Label("Reveal", systemImage: "finder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DetailFooterButtonStyle())

                Button {
                    model.copyToClipboard(session.bundleIdentifier ?? session.appPath, label: session.bundleIdentifier == nil ? "path" : "bundle ID")
                } label: {
                    Label("Copy ID", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DetailFooterButtonStyle())
            }
        }
        .padding(14)
        .background(DashboardTheme.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.accent.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionAccessibilityLabel(session))
    }
}

private struct WarningInspectorPanel: View {
    let row: AppUsageRow
    let warning: AppWarningItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailHeader(row: row)
            DetailQuickStats(row: row)

            if let warning {
                WarningInspectorSummary(warning: warning)
                WarningDetailBlock(title: "What's Wrong", text: warning.detail)
                WarningDetailBlock(title: "Recommendation", text: warning.recommendation)
                WarningDetailsList(warning: warning)
                WarningAffectedItemsList(warning: warning)
            } else {
                EmptyCardState(systemImage: "checkmark.seal", message: "Select a warning to inspect severity, affected paths, and recommended actions.")
                    .frame(height: 180)
            }
        }
    }
}

private struct WarningInspectorSummary: View {
    let warning: AppWarningItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                WarningSeverityGlyph(severity: warning.severity)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Severity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.secondaryText)
                    Text(warning.severity.displayName)
                        .font(.headline)
                        .foregroundStyle(DashboardTheme.primaryText)
                }
                Spacer()
                Text(warning.category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(warningSeverityColor(warning.severity))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(warningSeverityColor(warning.severity).opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(warning.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(2)
                Text(warning.source)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(warningSeverityColor(warning.severity).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(warningSeverityColor(warning.severity).opacity(0.18))
        )
    }
}

private struct WarningDetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DashboardTheme.primaryText)
            Text(text)
                .font(.callout)
                .foregroundStyle(DashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct WarningDetailsList: View {
    let warning: AppWarningItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Details", trailing: "")
            VStack(spacing: 11) {
                ForEach(warning.details) { detail in
                    HStack(alignment: .top, spacing: 12) {
                        Text(detail.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .frame(width: 92, alignment: .leading)
                        Text(detail.value)
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.primaryText)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .background(DashboardTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.softStroke)
            )
        }
    }
}

private struct WarningAffectedItemsList: View {
    @EnvironmentObject private var model: AppModel
    let warning: AppWarningItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Affected Items", trailing: "\(affectedItems.count)")
            VStack(spacing: 0) {
                ForEach(affectedItems) { item in
                    Button {
                        if let path = item.path {
                            model.revealInFinder(path: path)
                        }
                    } label: {
                        WarningAffectedItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .disabled(item.path == nil)

                    if item.id != affectedItems.last?.id {
                        Divider()
                            .padding(.leading, 34)
                    }
                }
            }
            .background(DashboardTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.softStroke)
            )
        }
    }

    private var affectedItems: [AppWarningAffectedItem] {
        if warning.affectedItems.isEmpty {
            return [
                AppWarningAffectedItem(
                    title: warning.appName,
                    subtitle: "Application",
                    path: warning.appPath,
                    sizeBytes: warning.sizeBytes
                )
            ]
        }
        return warning.affectedItems
    }
}

private struct WarningAffectedItemRow: View {
    let item: AppWarningAffectedItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.path?.hasSuffix(".app") == true ? "app.fill" : "folder.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Affected Item" : item.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.sizeBytes.map(AppMonitorFormatting.bytes) ?? "--")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardTheme.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

private struct WarningInspectorFooter: View {
    @EnvironmentObject private var model: AppModel
    let row: AppUsageRow
    let warning: AppWarningItem?

    var body: some View {
        VStack(spacing: 12) {
            Button {
                model.openWarningHelp(warning)
            } label: {
                Text("Learn More")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(DashboardTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                model.revealInFinder(path: warning?.appPath ?? row.app.path)
            } label: {
                Text("Reveal in Finder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DetailFooterButtonStyle())
        }
    }
}

private struct DetailHeader: View {
    @EnvironmentObject private var model: AppModel
    let row: AppUsageRow

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppIcon(path: row.app.path, size: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(row.app.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(row.app.path)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.app.path)
                StatusPill(status: healthStatus)
                    .padding(.top, 2)
            }

            Spacer()

            Menu {
                Button("Reveal in Finder") {
                    model.revealInFinder(path: row.app.path)
                }
                Button("Export Current Table") {
                    model.exportCurrentRows()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(DashboardTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(DashboardTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DashboardTheme.softStroke)
                    )
            }
            .buttonStyle(.plain)
            .menuStyle(.button)
        }
    }

    private var healthStatus: AppHealthStatus {
        if let severity = model.worstHealthSeverity(for: row) {
            switch severity {
            case .critical:
                return .critical
            case .warning:
                return .warning
            case .info:
                break
            }
        }
        if row.warningCount > 0 {
            return .warning
        }
        if row.scannedAt == nil {
            return .needsScan
        }
        return .healthy
    }
}

private struct DetailQuickStats: View {
    @EnvironmentObject private var model: AppModel
    let row: AppUsageRow

    var body: some View {
        HStack(spacing: 12) {
            DetailStatBox(title: "Usage \(model.period.shortDashboardLabel)", value: AppMonitorFormatting.duration(row.usageSeconds))
            DetailStatBox(title: "Last Opened", value: AppMonitorFormatting.shortDateTime(row.lastSeen))
            DetailStatBox(title: "Installed", value: row.app.installedAt.map(AppMonitorFormatting.day) ?? "Unknown")
        }
    }
}

private struct DetailStorageSection: View {
    @EnvironmentObject private var model: AppModel
    let row: AppUsageRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Storage", trailing: compactBytes(row.totalSizeBytes))

            if summaries.isEmpty {
                EmptyCardState(systemImage: "internaldrive", message: "Storage details appear after a scan.")
                    .frame(height: 92)
            } else {
                VStack(spacing: 12) {
                    ForEach(summaries) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.title)
                                .font(.callout)
                                .foregroundStyle(DashboardTheme.primaryText)
                            Spacer()
                            Text(compactBytes(item.bytes))
                                .font(.callout)
                                .foregroundStyle(DashboardTheme.primaryText)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var summaries: [StorageSummaryItem] {
        storageSummaries(row: row, items: model.selectedStorageItems)
    }
}

private struct DetailMiniUsageChart: View {
    @EnvironmentObject private var model: AppModel
    let rows: [DailyUsageRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Usage \(model.period.shortDashboardLabel)", trailing: maxValueLabel)

            UsageTrendChart(days: chartDays, showsAxis: false)
                .frame(height: 100)
        }
    }

    private var chartDays: [TrendDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rows, by: { calendar.startOfDay(for: $0.day) })
            .mapValues { rows in rows.reduce(0) { $0 + $1.usageSeconds } }
        let days = grouped.map { day, seconds in TrendDay(day: day, seconds: seconds) }
            .sorted { $0.day < $1.day }
        return Array(days.suffix(14))
    }

    private var maxValueLabel: String {
        AppMonitorFormatting.duration(chartDays.map(\.seconds).max() ?? 0)
    }
}

private struct TopAppsThisPeriodSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top Apps This Period", trailing: "\(model.usageAnalytics.topApps.count)")

            if model.usageAnalytics.topApps.isEmpty {
                EmptyCardState(systemImage: "app.dashed", message: "No usage recorded for this period.")
                    .frame(height: 96)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.usageAnalytics.topApps.prefix(5))) { app in
                        Button {
                            model.selectApp(id: app.appID)
                        } label: {
                            TopAppUsageRow(app: app)
                        }
                        .buttonStyle(.plain)

                        if app.id != model.usageAnalytics.topApps.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .background(DashboardTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DashboardTheme.softStroke)
                )
            }
        }
    }
}

private struct TopAppUsageRow: View {
    let app: TopAppUsage

    var body: some View {
        HStack(spacing: 10) {
            AppIcon(path: app.appPath, size: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.appName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text(usagePercentText(app.percentOfTotal))
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
            }
            Spacer()
            Text(AppMonitorFormatting.duration(app.seconds))
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
        }
        .padding(10)
        .contentShape(Rectangle())
        .help("\(usagePercentText(app.percentOfTotal)) of usage")
    }
}

private struct UsageInsightsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Insights", trailing: "")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.usageInsights(), id: \.self) { insight in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DashboardTheme.accent)
                            .frame(width: 16)
                        Text(insight)
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .background(DashboardTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.softStroke)
            )
        }
    }
}

private struct RelatedFilesSection: View {
    @EnvironmentObject private var model: AppModel
    let row: AppUsageRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Files")
                .font(.headline)
                .foregroundStyle(DashboardTheme.primaryText)

            if model.selectedStorageItems.isEmpty {
                EmptyCardState(systemImage: "folder", message: "Run Scan to find related support, cache, log, and container paths.")
                    .frame(height: 118)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.selectedStorageItems.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(5))) { item in
                        Button {
                            model.revealInFinder(path: item.path)
                        } label: {
                            RelatedFileRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Preview") { model.preview(path: item.path) }
                            Button("Reveal in Finder") { model.revealInFinder(path: item.path) }
                            Button("Move to Quarantine") { model.quarantineStorageItem(item) }
                            Button("Move to Trash") { model.moveStorageItemToTrash(item) }
                        }

                        if item.id != model.selectedStorageItems.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 34)
                        }
                    }
                }
                .background(DashboardTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DashboardTheme.softStroke)
                )
            }
        }
    }
}

private struct UninstallPlanSheet: View {
    @EnvironmentObject private var model: AppModel
    let plan: UninstallPlan

    private var currentPlan: UninstallPlan {
        model.uninstallPlan ?? plan
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    AppIcon(path: currentPlan.app.path, size: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentPlan.app.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DashboardTheme.primaryText)
                        Text(currentPlan.app.bundleIdentifier ?? currentPlan.app.path)
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(compactBytes(model.selectedUninstallBytes))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(DashboardTheme.primaryText)
                        Text("\(model.selectedUninstallCount) selected")
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                    }
                }

                if let protectionReason = currentPlan.protectionReason {
                    Label(protectionReason, systemImage: "lock.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.red)
                }

                if model.uninstallProgress.isVisible {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: model.uninstallProgress.fraction ?? 0)
                        Text(model.uninstallProgress.detail)
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(categoryGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(storageTitle(for: group.category), systemImage: storageIcon(for: group.category))
                                    .font(.headline)
                                    .foregroundStyle(DashboardTheme.primaryText)
                                Spacer()
                                Text(compactBytes(group.items.reduce(0) { $0 + $1.sizeBytes }))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DashboardTheme.secondaryText)
                            }

                            VStack(spacing: 0) {
                                ForEach(group.items) { item in
                                    UninstallPlanItemRow(item: item)
                                    if item.id != group.items.last?.id {
                                        Divider()
                                            .padding(.leading, 42)
                                    }
                                }
                            }
                            .background(DashboardTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(DashboardTheme.softStroke)
                            )
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    model.selectRecommendedUninstallItems()
                } label: {
                    Label("Recommended", systemImage: "checkmark.shield")
                }
                .disabled(model.isRunningUninstall || currentPlan.isProtected)

                Button {
                    model.selectAllReviewableUninstallItems()
                } label: {
                    Label("Select All", systemImage: "checklist")
                }
                .disabled(model.isRunningUninstall || currentPlan.isProtected)

                Spacer()

                Button {
                    model.closeUninstallPlan()
                } label: {
                    Label(model.uninstallResults.isEmpty ? "Cancel" : "Close", systemImage: "xmark")
                }
                .disabled(model.isRunningUninstall)

                Button(role: .destructive) {
                    Task { await model.executeSelectedAppUninstall() }
                } label: {
                    Label(model.isRunningUninstall ? "Trashing" : "Trash Selected", systemImage: "trash")
                }
                .disabled(model.isRunningUninstall || currentPlan.isProtected || model.selectedUninstallCount == 0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 760, height: 640)
    }

    private var categoryGroups: [UninstallCategoryGroup] {
        let grouped = Dictionary(grouping: currentPlan.items, by: \.category)
        return grouped.map { category, items in
            UninstallCategoryGroup(
                category: category,
                items: items.sorted { lhs, rhs in
                    if lhs.role != rhs.role { return lhs.role == .appBundle }
                    if lhs.risk != rhs.risk { return riskRank(lhs.risk) < riskRank(rhs.risk) }
                    return lhs.path < rhs.path
                }
            )
        }
        .sorted { lhs, rhs in
            if lhs.category == .bundle { return true }
            if rhs.category == .bundle { return false }
            return lhs.category.rawValue < rhs.category.rawValue
        }
    }
}

private struct UninstallCategoryGroup: Identifiable {
    let category: StorageCategory
    let items: [UninstallPlanItem]

    var id: StorageCategory { category }
}

private struct UninstallPlanItemRow: View {
    @EnvironmentObject private var model: AppModel
    let item: UninstallPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { model.selectedUninstallItemIDs.contains(item.id) },
                set: { model.setUninstallItem(item, selected: $0) }
            ))
            .labelsHidden()
            .disabled(!model.canSelectUninstallItem(item) || model.isRunningUninstall)
            .frame(width: 24)

            Image(systemName: item.role == .appBundle ? "app.fill" : storageIcon(for: item.category))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(riskColor(item.risk))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .lineLimit(1)
                    Text(riskLabel(item.risk))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(riskColor(item.risk))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(riskColor(item.risk).opacity(0.1))
                        .clipShape(Capsule())
                    if let result = model.uninstallResult(for: item.id) {
                        Text(resultLabel(result.status))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(resultColor(result.status))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(resultColor(result.status).opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(compactBytes(item.sizeBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DashboardTheme.secondaryText)
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.path)

                if let warning = item.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.orange)
                        .lineLimit(2)
                } else if let result = model.uninstallResult(for: item.id), let message = result.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .lineLimit(2)
                } else if item.coveredByParentID != nil {
                    Text(item.rationale)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.secondaryText)
                }
            }

            VStack(spacing: 6) {
                Button {
                    model.preview(path: item.path)
                } label: {
                    Image(systemName: "eye")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Preview")

                Button {
                    model.revealInFinder(path: item.path)
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(10)
    }

    private var displayName: String {
        let name = URL(fileURLWithPath: item.path).lastPathComponent
        return name.isEmpty ? item.path : name
    }
}

private struct SummaryCard: View {
    let title: String
    let systemImage: String
    let value: String
    let unit: String?
    let subtitle: String
    let footer: String
    let footerSystemImage: String
    let tint: Color
    var isSoftGreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(DashboardTheme.primaryText)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    if let unit {
                        Text(unit)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DashboardTheme.primaryText)
                    }
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(DashboardTheme.secondaryText)
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: footerSystemImage)
                    .font(.caption)
                Text(footer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption)
            .foregroundStyle(tint)
        }
        .padding(16)
        .frame(minHeight: 174, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSoftGreen ? Color.green.opacity(0.06) : DashboardTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSoftGreen ? DashboardTheme.green.opacity(0.17) : DashboardTheme.cardStroke)
        )
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardTheme.cardStroke)
        )
    }
}

private struct CardHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DashboardTheme.primaryText)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(DashboardTheme.secondaryText)
        }
    }
}

private struct ActivityRow: View {
    let row: AppUsageRow
    let maxUsage: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(path: row.app.path, size: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(row.app.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DashboardTheme.track)
                        Capsule()
                            .fill(DashboardTheme.accent)
                            .frame(width: max(8, geometry.size.width * row.usageSeconds / maxUsage))
                    }
                }
                .frame(height: 5)
            }

            Text(AppMonitorFormatting.duration(row.usageSeconds))
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }
}

private struct StorageTreemap: View {
    @EnvironmentObject private var model: AppModel
    let rows: [AppUsageRow]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    tile(at: 0)
                        .frame(width: geometry.size.width * 0.5)
                    tile(at: 1)
                }
                .frame(height: geometry.size.height * 0.52)

                HStack(spacing: 4) {
                    tile(at: 2)
                    tile(at: 3)
                    tile(at: 4)
                }
                .frame(height: geometry.size.height * 0.23)

                HStack(spacing: 4) {
                    tile(at: 5)
                    tile(at: 6)
                    otherTile
                }
                .frame(height: geometry.size.height * 0.25)
            }
        }
    }

    @ViewBuilder
    private func tile(at index: Int) -> some View {
        if rows.indices.contains(index) {
            Button {
                model.select(rows[index])
            } label: {
                StorageTile(row: rows[index], color: tileColors[index % tileColors.count])
            }
            .buttonStyle(.plain)
        }
    }

    private var otherTile: some View {
        let remaining = rows.dropFirst(7).reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        let value = remaining > 0 ? remaining : rows.dropFirst(5).reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        return StorageTile(title: "Other", subtitle: compactBytes(value), color: .gray)
    }
}

private struct StorageTile: View {
    let title: String
    let subtitle: String
    let color: Color

    init(row: AppUsageRow, color: Color) {
        title = row.app.name
        subtitle = compactBytes(row.totalSizeBytes)
        self.color = color
    }

    init(title: String, subtitle: String, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [color.opacity(0.78), color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TrendDay: Identifiable {
    let day: Date
    let seconds: TimeInterval

    var id: Date { day }
}

private struct UsageTrendChart: View {
    let days: [TrendDay]
    var showsAxis = true

    var body: some View {
        VStack(spacing: 8) {
            if showsAxis {
                HStack {
                    Text(maxLabel)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Divider().opacity(0.45)
                        Spacer()
                        Divider().opacity(0.35)
                        Spacer()
                        Divider().opacity(0.35)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(days) { day in
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(DashboardTheme.accent)
                                    .frame(height: barHeight(for: day, availableHeight: geometry.size.height - 26))
                                    .shadow(color: DashboardTheme.accent.opacity(0.2), radius: 6, y: 4)
                                Text(dayLabel(day.day))
                                    .font(.caption)
                                    .foregroundStyle(DashboardTheme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(height: 16)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
    }

    private var maxSeconds: TimeInterval {
        max(days.map(\.seconds).max() ?? 1, 1)
    }

    private var maxLabel: String {
        AppMonitorFormatting.duration(maxSeconds)
    }

    private func barHeight(for day: TrendDay, availableHeight: CGFloat) -> CGFloat {
        guard day.seconds > 0 else { return 4 }
        return max(8, availableHeight * day.seconds / maxSeconds)
    }

    private func dayLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day)
    }
}

private struct DetailStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .padding(.horizontal, 8)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

private struct SectionHeader: View {
    let title: String
    let trailing: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(DashboardTheme.primaryText)
            Spacer()
            Text(trailing)
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
        }
    }
}

private struct RelatedFileRow: View {
    @EnvironmentObject private var model: AppModel
    let item: StorageScanItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.rawValue)
                    .font(.callout)
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Text("\(model.ownerText(for: item.path)) · Risk \(model.riskText(for: item))")
                    .font(.caption2)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(compactBytes(item.sizeBytes))
                .font(.callout)
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .help(item.path)
    }
}

private struct SearchField: View {
    @Binding var text: String
    let focusToken: UUID
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.secondaryText)
            TextField("Search apps...", text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($isFocused)
            Text("⌘K")
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText.opacity(0.8))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(DashboardTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
        .onChange(of: focusToken) {
            isFocused = true
        }
    }
}

private struct ToolbarControl: View {
    let title: String
    let systemImage: String?
    var trailingSystemImage: String?
    var isProminent = false
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.caption)
            }
        }
        .foregroundStyle(isProminent ? .white : DashboardTheme.primaryText)
        .padding(.horizontal, compact ? 12 : 16)
        .frame(height: compact ? 32 : 34)
        .background(isProminent ? DashboardTheme.accent : DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isProminent ? Color.clear : DashboardTheme.softStroke)
        )
    }
}

private struct OperationProgressStrip: View {
    let progress: OperationProgressSnapshot
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(progress.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                if !progress.unitText.isEmpty {
                    Text(progress.unitText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .monospacedDigit()
                }
                Text(progress.percentText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(tint)
            }

            HStack(spacing: 10) {
                Text(progress.detail)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let currentPath = progress.currentPath, !currentPath.isEmpty {
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundStyle(DashboardTheme.secondaryText.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                if !progress.metricsText.isEmpty {
                    Text(progress.metricsText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DashboardTheme.secondaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18))
        )
    }
}

private struct CardFooterButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            Text(title)
            Image(systemName: systemImage)
                .font(.caption)
            Spacer()
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(DashboardTheme.primaryText)
        .frame(height: 34)
        .background(DashboardTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }
}

private struct TrendMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DashboardTheme.secondaryText)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(DashboardTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private enum AppHealthStatus {
    case healthy
    case warning
    case critical
    case needsScan

    var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warnings"
        case .critical: return "Critical"
        case .needsScan: return "Needs Scan"
        }
    }

    var color: Color {
        switch self {
        case .healthy: return DashboardTheme.green
        case .warning: return DashboardTheme.orange
        case .critical: return DashboardTheme.red
        case .needsScan: return DashboardTheme.secondaryText
        }
    }
}

private struct StatusPill: View {
    let status: AppHealthStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.14))
            .clipShape(Capsule())
    }
}

private func warningSeverityColor(_ severity: AppWarningSeverity) -> Color {
    switch severity {
    case .critical:
        return DashboardTheme.red
    case .high:
        return DashboardTheme.orange
    case .medium:
        return Color(red: 0.9, green: 0.66, blue: 0.08)
    case .low:
        return DashboardTheme.blue
    }
}

private func warningSeverityIcon(_ severity: AppWarningSeverity) -> String {
    switch severity {
    case .critical:
        return "exclamationmark"
    case .high:
        return "exclamationmark.triangle.fill"
    case .medium:
        return "lock.fill"
    case .low:
        return "info"
    }
}

private struct DetailFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(DashboardTheme.primaryText)
            .frame(height: 36)
            .background(configuration.isPressed ? DashboardTheme.controlPressed : DashboardTheme.control)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.softStroke)
            )
    }
}

private struct EmptyCardState: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DashboardTheme.secondaryText.opacity(0.72))
            Text(message)
                .font(.callout)
                .foregroundStyle(DashboardTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WindowDots: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 0.95, green: 0.28, blue: 0.24))
            Circle().fill(Color(red: 0.95, green: 0.72, blue: 0.18))
            Circle().fill(Color(red: 0.25, green: 0.72, blue: 0.32))
        }
        .frame(width: 58, height: 12)
    }
}

private struct SidebarSelectionItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.callout.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(isSelected ? DashboardTheme.accent : DashboardTheme.primaryText)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .contentShape(Rectangle())
        .background(isSelected ? DashboardTheme.accent.opacity(0.13) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SidebarGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardTheme.secondaryText)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 4) {
                content
            }
        }
    }
}

private struct SidebarMetricItem: View {
    let title: String
    let systemImage: String
    let value: String
    var badgeColor = Color.clear
    var valueColor = DashboardTheme.secondaryText
    var isSelected = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? DashboardTheme.accent : DashboardTheme.secondaryText)
                .frame(width: 18)
            Text(title)
                .font(.callout)
                .foregroundStyle(isSelected ? DashboardTheme.accent : DashboardTheme.primaryText)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .padding(.horizontal, badgeColor == .clear ? 0 : 8)
                    .padding(.vertical, badgeColor == .clear ? 0 : 3)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .contentShape(Rectangle())
        .background(isSelected ? DashboardTheme.accent.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct ScanStatusCard: View {
    let lastScan: Date?
    let nextScan: Date?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(DashboardTheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Last scan: \(lastScanText)")
                Text("Next scan: \(nextScanText)")
            }
            .font(.caption)
            .foregroundStyle(DashboardTheme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DashboardTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(DashboardTheme.softStroke)
        )
    }

    private var lastScanText: String {
        guard let lastScan else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastScan)
    }

    private var nextScanText: String {
        guard let nextScan else { return "Not scheduled" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: nextScan)
    }
}

private struct StorageSummaryItem: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let color: Color
}

private let timelinePalette: [Color] = [
    DashboardTheme.accent,
    DashboardTheme.blue,
    DashboardTheme.green,
    DashboardTheme.orange,
    DashboardTheme.red,
    Color(red: 0.16, green: 0.68, blue: 0.62),
    Color(red: 0.54, green: 0.36, blue: 0.88),
    Color(red: 0.86, green: 0.32, blue: 0.58),
    Color(red: 0.22, green: 0.56, blue: 0.76),
    Color(red: 0.56, green: 0.61, blue: 0.18),
    Color(red: 0.7, green: 0.4, blue: 0.18),
    Color(red: 0.34, green: 0.45, blue: 0.78)
]

private let tileColors: [Color] = [
    DashboardTheme.accent,
    DashboardTheme.blue,
    DashboardTheme.green,
    Color(red: 0.93, green: 0.62, blue: 0.09),
    DashboardTheme.red,
    Color(red: 0.37, green: 0.29, blue: 0.86),
    Color(red: 0.25, green: 0.54, blue: 0.68)
]

private func compactBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 KB" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.includesActualByteCount = false
    return formatter.string(fromByteCount: bytes)
}

private func timelineColor(for index: Int) -> Color {
    timelinePalette[index % max(timelinePalette.count, 1)]
}

private func stableTimelineColorIndex(for key: String) -> Int {
    var hash: UInt64 = 1_469_598_103_934_665_603
    for scalar in key.unicodeScalars {
        hash ^= UInt64(scalar.value)
        hash = hash &* 1_099_511_628_211
    }
    return Int(hash % UInt64(max(timelinePalette.count, 1)))
}

private func timelineDeltaDisplay(_ delta: TimelineMetricDelta) -> (text: String, systemImage: String, color: Color) {
    guard delta.hasPriorData else {
        return ("No prior data", "minus", DashboardTheme.secondaryText)
    }

    let isPositive = delta.absoluteDelta >= 0
    let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
    let color = isPositive ? DashboardTheme.blue : DashboardTheme.orange

    if let percent = delta.percentDelta {
        let value = abs(percent * 100)
        return ("\(isPositive ? "+" : "-")\(String(format: "%.0f", value))% vs prior", icon, color)
    }

    switch delta.kind {
    case .duration:
        return ("\(isPositive ? "+" : "-")\(AppMonitorFormatting.duration(abs(delta.absoluteDelta)))", icon, color)
    case .count:
        return ("\(isPositive ? "+" : "-")\(Int(abs(delta.absoluteDelta.rounded())))", icon, color)
    }
}

private func timelineDayTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
}

private func timelineDayShort(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE M/d"
    return formatter.string(from: date)
}

private func timelineTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

private func timelineDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d h:mm a"
    return formatter.string(from: date)
}

private func sessionAccessibilityLabel(_ session: TimelineSession) -> String {
    let clipped = session.isClipped ? " Session clipped at reporting period boundary." : ""
    return "\(session.appName), \(timelineDateTime(session.startedAt)) to \(timelineTime(session.endedAt)), \(AppMonitorFormatting.duration(session.durationSeconds)).\(clipped)"
}

private func heatmapHourLabel(_ hour: Int) -> String {
    switch hour {
    case 0:
        return "0"
    case 6:
        return "6"
    case 12:
        return "12"
    case 18:
        return "18"
    default:
        return ""
    }
}

private func heatmapBucketLabel(_ bucket: TimelineHourBucket) -> String {
    let topApp = bucket.topAppName ?? "No top app"
    return "\(timelineDayTitle(bucket.dayStart)), \(timelineTime(bucket.hourStart)), \(AppMonitorFormatting.duration(bucket.totalDurationSeconds)), \(topApp)"
}

private func percentageString(_ bytes: Int64, of totalBytes: Int64) -> String {
    guard totalBytes > 0 else { return "0%" }
    let percent = Double(bytes) / Double(totalBytes) * 100
    if percent < 0.1, bytes > 0 {
        return "<0.1%"
    }
    return "\(String(format: "%.1f", percent))%"
}

private func analyticsDeltaText(_ percentChange: Double?) -> String {
    guard let percentChange else { return "No prior data" }
    let sign = percentChange >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.0f", abs(percentChange) * 100))% vs previous"
}

private func storageTitle(for category: StorageCategory) -> String {
    switch category {
    case .bundle:
        return "Applications"
    case .applicationSupport:
        return "Application Support"
    case .caches:
        return "Caches"
    case .containers:
        return "Containers"
    case .groupContainers:
        return "Group Containers"
    case .preferences:
        return "Preferences"
    case .savedApplicationState:
        return "Saved State"
    case .httpStorages:
        return "HTTPStorages"
    case .logs:
        return "Logs"
    case .extensions:
        return "Extensions"
    case .launchAgents:
        return "Launch Agents"
    case .applicationScripts:
        return "Application Scripts"
    case .webKit:
        return "WebKit"
    case .cookies:
        return "Cookies"
    case .diagnosticReports:
        return "Diagnostic Reports"
    }
}

private func storageColor(for category: StorageCategory) -> Color {
    switch category {
    case .bundle:
        return DashboardTheme.blue
    case .applicationSupport:
        return DashboardTheme.accent
    case .caches:
        return DashboardTheme.green
    case .containers:
        return Color(red: 0.18, green: 0.74, blue: 0.64)
    case .groupContainers:
        return Color(red: 0.33, green: 0.48, blue: 0.9)
    case .preferences:
        return Color(red: 0.95, green: 0.73, blue: 0.18)
    case .savedApplicationState:
        return Color(red: 0.24, green: 0.6, blue: 0.68)
    case .httpStorages:
        return Color(red: 0.36, green: 0.29, blue: 0.88)
    case .logs:
        return DashboardTheme.red
    case .extensions:
        return DashboardTheme.orange
    case .launchAgents:
        return Color(red: 0.66, green: 0.39, blue: 0.88)
    case .applicationScripts:
        return Color(red: 0.19, green: 0.56, blue: 0.8)
    case .webKit:
        return Color(red: 0.17, green: 0.66, blue: 0.58)
    case .cookies:
        return Color(red: 0.76, green: 0.49, blue: 0.21)
    case .diagnosticReports:
        return Color(red: 0.88, green: 0.32, blue: 0.42)
    }
}

private func storageIcon(for category: StorageCategory) -> String {
    switch category {
    case .bundle:
        return "app"
    case .applicationSupport:
        return "shippingbox"
    case .caches:
        return "bolt.horizontal"
    case .containers, .groupContainers:
        return "tray.full"
    case .preferences:
        return "slider.horizontal.3"
    case .savedApplicationState:
        return "rectangle.stack"
    case .httpStorages:
        return "network"
    case .logs:
        return "doc.text"
    case .extensions:
        return "puzzlepiece.extension"
    case .launchAgents:
        return "paperplane"
    case .applicationScripts:
        return "applescript"
    case .webKit:
        return "safari"
    case .cookies:
        return "seal"
    case .diagnosticReports:
        return "waveform.path.ecg"
    }
}

private func riskRank(_ risk: UninstallRiskLevel) -> Int {
    switch risk {
    case .low:
        return 0
    case .medium:
        return 1
    case .high:
        return 2
    case .protected:
        return 3
    }
}

private func riskLabel(_ risk: UninstallRiskLevel) -> String {
    switch risk {
    case .low:
        return "Low"
    case .medium:
        return "Medium"
    case .high:
        return "High"
    case .protected:
        return "Protected"
    }
}

private func riskColor(_ risk: UninstallRiskLevel) -> Color {
    switch risk {
    case .low:
        return DashboardTheme.green
    case .medium:
        return DashboardTheme.orange
    case .high, .protected:
        return DashboardTheme.red
    }
}

private func resultLabel(_ status: UninstallItemResultStatus) -> String {
    switch status {
    case .trashed:
        return "Trashed"
    case .skipped:
        return "Skipped"
    case .failed:
        return "Failed"
    case .coveredByParent:
        return "Covered"
    case .notSelected:
        return "Not Selected"
    case .missing:
        return "Missing"
    }
}

private func resultColor(_ status: UninstallItemResultStatus) -> Color {
    switch status {
    case .trashed:
        return DashboardTheme.green
    case .coveredByParent, .notSelected, .missing, .skipped:
        return DashboardTheme.secondaryText
    case .failed:
        return DashboardTheme.red
    }
}

private func updateSourceIcon(_ source: AppUpdateSource) -> String {
    switch source {
    case .macAppStore:
        return "bag"
    case .homebrewCask, .homebrewFormula:
        return "terminal"
    case .appleSoftwareUpdate:
        return "apple.logo"
    case .directDownload:
        return "arrow.down.app"
    case .unknown:
        return "questionmark.app"
    }
}

private func updateStatusColor(_ status: AppUpdateStatus) -> Color {
    switch status {
    case .available:
        return DashboardTheme.blue
    case .updated, .upToDate:
        return DashboardTheme.green
    case .needsAdmin, .needsRestart, .manualAction:
        return DashboardTheme.orange
    case .failed:
        return DashboardTheme.red
    case .providerUnavailable, .skipped:
        return DashboardTheme.secondaryText
    case .checking, .updating:
        return DashboardTheme.accent
    }
}

private func versionTransition(_ entry: AppChangeLogEntry) -> String {
    if let fromVersion = entry.fromVersion, let toVersion = entry.toVersion {
        return "\(fromVersion) -> \(toVersion)"
    }
    if let toVersion = entry.toVersion {
        return "to \(toVersion)"
    }
    if let fromVersion = entry.fromVersion {
        return "from \(fromVersion)"
    }
    return entry.source.displayName
}

private func historyEntryID(_ entry: (Date, String, String)) -> String {
    "\(entry.0.timeIntervalSince1970)|\(entry.1)|\(entry.2)"
}

private struct CleanupSummarySegment: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let color: Color
}

private func cleanupSummarySegments(for suggestions: [CleanupSuggestion]) -> [CleanupSummarySegment] {
    var totals: [String: Int64] = [:]
    for suggestion in suggestions {
        totals[cleanupSummaryGroup(for: suggestion).title, default: 0] += suggestion.sizeBytes
    }

    let fixedSegments = [
        cleanupSegment(title: "Caches", bytes: totals["Caches"] ?? 0, color: DashboardTheme.accent),
        cleanupSegment(title: "Unused Apps", bytes: totals["Unused Apps"] ?? 0, color: DashboardTheme.blue),
        cleanupSegment(title: "Large & Old Files", bytes: totals["Large & Old Files"] ?? 0, color: DashboardTheme.green),
        cleanupSegment(title: "Downloads", bytes: totals["Downloads"] ?? 0, color: DashboardTheme.orange),
        cleanupSegment(title: "Logs", bytes: totals["Logs"] ?? 0, color: DashboardTheme.amber)
    ]

    let otherBytes = totals["Other"] ?? 0
    if otherBytes > 0 {
        return fixedSegments + [cleanupSegment(title: "Other", bytes: otherBytes, color: Color.gray.opacity(0.72))]
    }
    return fixedSegments
}

private func cleanupSegment(title: String, bytes: Int64, color: Color) -> CleanupSummarySegment {
    CleanupSummarySegment(id: title, title: title, bytes: bytes, color: color)
}

private func cleanupSummaryGroup(for suggestion: CleanupSuggestion) -> (title: String, color: Color) {
    if suggestion.path.localizedCaseInsensitiveContains("/Downloads/") {
        return ("Downloads", DashboardTheme.orange)
    }

    if suggestion.rationale.localizedCaseInsensitiveContains("not been used in at least 30 days") {
        return ("Unused Apps", DashboardTheme.blue)
    }

    switch suggestion.category {
    case .caches, .httpStorages, .savedApplicationState, .webKit:
        return ("Caches", DashboardTheme.accent)
    case .logs, .diagnosticReports:
        return ("Logs", DashboardTheme.amber)
    case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .cookies:
        if suggestion.sizeBytes >= 500_000_000 || suggestion.severity == .high {
            return ("Large & Old Files", DashboardTheme.green)
        }
        return ("Other", Color.gray.opacity(0.72))
    case .bundle, .containers, .groupContainers, .preferences:
        return ("Other", Color.gray.opacity(0.72))
    }
}

private func isLowPriorityCleanup(_ suggestion: CleanupSuggestion) -> Bool {
    suggestion.severity == .low && suggestion.sizeBytes < 500_000_000 && suggestion.state != .approved
}

private func cleanupDisplayTitle(_ suggestion: CleanupSuggestion, appName: String) -> String {
    if !suggestion.title.hasPrefix("Review ") {
        return suggestion.title
    }

    switch suggestion.category {
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

private func cleanupSubtitle(_ suggestion: CleanupSuggestion, row: AppUsageRow?, appName: String) -> String {
    let lastComponent = URL(fileURLWithPath: suggestion.path).lastPathComponent
    let pathLabel = lastComponent.isEmpty ? suggestion.path : lastComponent
    return "\(suggestion.category.rawValue) / \(appName) / \(cleanupLastUsedText(row)) / \(pathLabel)"
}

private func cleanupLastUsedText(_ row: AppUsageRow?) -> String {
    guard let lastSeen = row?.lastSeen else { return "Never used" }
    let days = Calendar.current.dateComponents([.day], from: lastSeen, to: Date()).day ?? 0
    if days <= 0 { return "Today" }
    if days == 1 { return "1 day ago" }
    if days < 30 { return "\(days) days ago" }
    return AppMonitorFormatting.day(lastSeen)
}

private func cleanupItemCountText(_ count: Int?) -> String {
    guard let count else { return "1 item" }
    return "\(count) item\(count == 1 ? "" : "s")"
}

private func cleanupSeverityLabel(_ suggestion: CleanupSuggestion) -> String {
    switch suggestion.severity {
    case .low:
        return "Safe"
    case .medium:
        return "Medium"
    case .high:
        return "Large"
    }
}

private func cleanupSeverityColor(_ severity: CleanupSeverity) -> Color {
    switch severity {
    case .low:
        return DashboardTheme.green
    case .medium:
        return DashboardTheme.orange
    case .high:
        return DashboardTheme.accent
    }
}

private func cleanupIsLowRisk(_ suggestion: CleanupSuggestion) -> Bool {
    switch suggestion.category {
    case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
        return true
    case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies, .bundle, .containers, .groupContainers, .preferences:
        return false
    }
}

private func isUnusedForThirtyDays(_ row: AppUsageRow) -> Bool {
    guard let lastSeen = row.lastSeen else { return true }
    return lastSeen < Date().addingTimeInterval(-30 * 24 * 60 * 60)
}

private func storageSummaries(row: AppUsageRow, items: [StorageScanItem]) -> [StorageSummaryItem] {
    guard row.totalSizeBytes > 0 || !items.isEmpty else { return [] }

    var totals: [String: Int64] = [:]

    if row.bundleSizeBytes > 0 {
        totals["App Bundle", default: 0] += row.bundleSizeBytes
    }

    for item in items {
        let title = item.category == .bundle ? "App Bundle" : item.category.rawValue
        if item.category != .bundle || row.bundleSizeBytes == 0 {
            totals[title, default: 0] += item.sizeBytes
        }
    }

    let colorByTitle: [String: Color] = [
        "App Bundle": DashboardTheme.accent,
        "Caches": DashboardTheme.blue,
        "Application Support": Color(red: 0.34, green: 0.69, blue: 0.55),
        "Containers": Color(red: 0.47, green: 0.38, blue: 0.78),
        "Group Containers": Color(red: 0.41, green: 0.55, blue: 0.82),
        "Preferences": DashboardTheme.orange,
        "Saved Application State": Color(red: 0.24, green: 0.6, blue: 0.68),
        "HTTPStorages": DashboardTheme.blue.opacity(0.8),
        "Logs": DashboardTheme.orange,
        "Extensions": DashboardTheme.green
    ]

    return totals
        .map { title, bytes in StorageSummaryItem(id: title, title: title, bytes: bytes, color: colorByTitle[title] ?? .gray) }
        .filter { $0.bytes > 0 }
        .sorted { $0.bytes > $1.bytes }
}

private func usageColor(for appID: String, isOther: Bool = false) -> Color {
    if isOther {
        return Color(red: 0.58, green: 0.6, blue: 0.66)
    }

    let palette: [Color] = [
        DashboardTheme.accent,
        DashboardTheme.blue,
        DashboardTheme.green,
        DashboardTheme.orange,
        Color(red: 0.78, green: 0.31, blue: 0.58),
        Color(red: 0.18, green: 0.58, blue: 0.66),
        Color(red: 0.54, green: 0.42, blue: 0.82),
        Color(red: 0.72, green: 0.45, blue: 0.22)
    ]

    let hash = appID.unicodeScalars.reduce(UInt64(1469598103934665603)) { partial, scalar in
        (partial ^ UInt64(scalar.value)) &* 1099511628211
    }
    return palette[Int(hash % UInt64(palette.count))]
}

private func heatmapColor(for seconds: TimeInterval, maxSeconds: TimeInterval) -> Color {
    guard seconds > 0 else {
        return DashboardTheme.accent.opacity(0.07)
    }
    let intensity = min(1, max(0.08, seconds / max(maxSeconds, 1)))
    return DashboardTheme.accent.opacity(0.12 + 0.68 * intensity)
}

private func usageComparisonText(_ percentChange: Double?) -> String {
    guard let percentChange else { return "No prior data" }
    return "\(usageSignedPercentText(percentChange)) vs previous period"
}

private func usagePercentText(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

private func usageSignedPercentText(_ value: Double) -> String {
    let percent = Int((value * 100).rounded())
    return percent > 0 ? "+\(percent)%" : "\(percent)%"
}

private func usageBucketLabel(_ date: Date, grouping: UsageTrendGrouping) -> String {
    let formatter = DateFormatter()
    switch grouping {
    case .day:
        formatter.setLocalizedDateFormatFromTemplate("M/d")
    case .week:
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
    case .month:
        formatter.setLocalizedDateFormatFromTemplate("MMM")
    }
    return formatter.string(from: date)
}

private func usageBucketTooltip(bucket: UsageTrendBucket, grouping: UsageTrendGrouping) -> String {
    "\(usageBucketLabel(bucket.start, grouping: grouping)): \(AppMonitorFormatting.duration(bucket.totalSeconds))"
}

private func usageSegmentTooltip(bucket: UsageTrendBucket, segment: UsageStackSegment, grouping: UsageTrendGrouping) -> String {
    let share = usagePercentText(segment.percentOfBucket)
    return "\(usageBucketLabel(bucket.start, grouping: grouping)) \(segment.appName): \(AppMonitorFormatting.duration(segment.seconds)), \(share)"
}

private func heatmapTooltip(_ cell: UsageHeatmapCell) -> String {
    let topApp = cell.topAppName.map { ", top app: \($0)" } ?? ""
    return "\(cell.rowLabel) \(cell.hourOfDay):00: \(AppMonitorFormatting.duration(cell.seconds)), \(cell.sessionCount) sessions\(topApp)"
}

private extension ReportingPeriod {
    var shortDashboardLabel: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .year:
            return "This Year"
        }
    }
}
