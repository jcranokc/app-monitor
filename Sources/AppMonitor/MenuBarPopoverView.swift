import AppKit
import AppMonitorCore
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var model: AppModel
    let openDashboardAction: () -> Void

    init(openDashboard: @escaping () -> Void = {}) {
        openDashboardAction = openDashboard
    }

    private let cardColumns = Array(
        repeating: GridItem(.flexible(minimum: 104), spacing: 10),
        count: 4
    )

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                header

                LazyVGrid(columns: cardColumns, spacing: 10) {
                    MetricCard(
                        title: "USED TODAY",
                        value: durationValue,
                        unit: nil,
                        subtitle: nil,
                        tint: MenuBarTheme.accent,
                        accessory: AnyView(MiniUsageBars(values: miniUsageValues))
                    )

                    MetricCard(
                        title: "STORAGE USED",
                        value: storageUsedParts.value,
                        unit: storageUsedParts.unit,
                        subtitle: "of \(storageTotalText)",
                        tint: MenuBarTheme.blue,
                        accessory: AnyView(
                            MiniProgressBar(
                                fraction: diskUsage.usedFraction,
                                tint: MenuBarTheme.blue
                            )
                        )
                    )

                    MetricCard(
                        title: "APPS",
                        value: "\(model.rows.count)",
                        unit: nil,
                        subtitle: "Installed",
                        tint: MenuBarTheme.green,
                        accessory: AnyView(EmptyView())
                    )

                    MetricCard(
                        title: "CLEANUP",
                        value: cleanupParts.value,
                        unit: cleanupParts.unit,
                        subtitle: "Available",
                        tint: MenuBarTheme.orange,
                        accessory: AnyView(EmptyView())
                    )
                }

                topAppsSection
                storageSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            actionRows

            footer
        }
        .frame(width: 540)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MenuBarTheme.popoverStroke, lineWidth: 1)
                )
                .shadow(color: MenuBarTheme.popoverShadow, radius: 24, y: 16)
        )
        .padding(1)
        .task {
            await model.bootstrap()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMonitorMark(size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("App Monitor")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MenuBarTheme.primaryText)
                Text("Your Mac at a glance")
                    .font(.system(size: 14))
                    .foregroundStyle(MenuBarTheme.secondaryText)
            }

            Spacer()

            Button {
                model.navigate(.settings)
                openDashboard()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MenuBarIconButtonStyle())
            .help("Open Settings")

            Button {
                Task { await model.runFullScan() }
            } label: {
                Image(systemName: model.isScanningStorage ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MenuBarIconButtonStyle())
            .disabled(model.isScanningStorage)
            .help(model.isScanningStorage ? "Storage scan is running" : "Refresh scan")
        }
    }

    private var topAppsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(
                title: "Top Apps Today",
                systemImage: "clock",
                actionTitle: "View All"
            ) {
                model.showAllUsage()
                openDashboard()
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(topRows) { row in
                    Button {
                        model.select(row)
                        model.showAllUsage()
                        openDashboard()
                    } label: {
                        TopAppRow(
                            row: row,
                            barFraction: topAppFraction(for: row),
                            durationText: topAppValueText(for: row)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if topRows.isEmpty {
                    EmptyPopoverState(
                        systemImage: "clock.badge.questionmark",
                        message: "Usage appears after App Monitor records app activity."
                    )
                    .padding(.vertical, 18)
                }
            }
        }
        .padding(12)
        .background(MenuBarTheme.sectionFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MenuBarTheme.hairline, lineWidth: 1)
        )
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Storage Breakdown",
                systemImage: nil,
                actionTitle: "View Storage"
            ) {
                model.navigate(.storage)
                openDashboard()
            }

            SegmentedStorageBar(segments: storageSegments, totalBytes: storageBarTotalBytes)

            HStack(alignment: .top, spacing: 12) {
                ForEach(storageSegments) { segment in
                    StorageLegendItem(segment: segment)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(MenuBarTheme.sectionFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MenuBarTheme.hairline, lineWidth: 1)
        )
    }

    private var actionRows: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.45)

            ActionSummaryRow(
                systemImage: "exclamationmark.triangle",
                title: "\(model.warningCount) Warning\(model.warningCount == 1 ? "" : "s")",
                detail: nil,
                tint: MenuBarTheme.warning
            ) {
                model.navigate(.warnings)
                openDashboard()
            }

            Divider().opacity(0.45)
                .padding(.leading, 50)

            ActionSummaryRow(
                systemImage: "leaf",
                title: "\(model.activeCleanupSuggestions.count) Cleanup Suggestion\(model.activeCleanupSuggestions.count == 1 ? "" : "s")",
                detail: cleanupDisplayText,
                tint: MenuBarTheme.green
            ) {
                model.navigate(.cleanup)
                openDashboard()
            }

            Divider().opacity(0.45)
        }
    }

    private var footer: some View {
        HStack {
            Text("Last scan: \(lastScanText)")
                .font(.system(size: 13))
                .foregroundStyle(MenuBarTheme.secondaryText)

            Spacer()

            Button {
                openDashboard()
            } label: {
                Text("Open App Monitor")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 164, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(MenuBarTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .help("Open the App Monitor dashboard")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        openDashboardAction()
    }

    private var topRows: [AppUsageRow] {
        let todayRows = model.todayUsageRows
        let source = todayRows.isEmpty ? model.rows : todayRows
        let rowsWithSignals = source.filter { topAppScore(for: $0) > 0 }
        let ranked = (rowsWithSignals.isEmpty ? source : rowsWithSignals).sorted { lhs, rhs in
            let lhsScore = topAppScore(for: lhs)
            let rhsScore = topAppScore(for: rhs)
            if lhsScore == rhsScore {
                return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
            }
            return lhsScore > rhsScore
        }
        return Array(ranked.prefix(5))
    }

    private var durationValue: String {
        compactDuration(model.todayUsageSeconds)
    }

    private var miniUsageValues: [Double] {
        let values = topRows.map { max(0.08, topAppFraction(for: $0)) }
        if values.isEmpty {
            return [0.22, 0.48, 0.34, 0.18, 0.2, 0.26, 0.16, 0.24, 0.42, 0.30]
        }
        return values + Array(repeating: 0.12, count: max(0, 10 - values.count))
    }

    private func topAppScore(for row: AppUsageRow) -> Double {
        let usage = max(0, row.usageSeconds)
        let importedSignal = Double(row.importedDaysInPeriod) * 180
        let sizeSignal = Double(max(0, row.totalSizeBytes)) / 1_000_000_000
        return max(usage, importedSignal, sizeSignal)
    }

    private func topAppFraction(for row: AppUsageRow) -> Double {
        let maxScore = max(topRows.map(topAppScore).max() ?? 1, 1)
        return min(1, max(0.08, topAppScore(for: row) / maxScore))
    }

    private func topAppValueText(for row: AppUsageRow) -> String {
        if row.usageSeconds >= 60 {
            return compactDuration(row.usageSeconds)
        }
        if row.importedDaysInPeriod > 0 {
            return "\(row.importedDaysInPeriod)d"
        }
        if row.totalSizeBytes > 0 {
            return compactBytes(row.totalSizeBytes)
        }
        return "<1m"
    }

    private var diskUsage: DiskUsage {
        DiskUsage.current(scannedFallbackBytes: model.scannedSizeBytes)
    }

    private var storageUsedParts: ByteParts {
        byteParts(diskUsage.usedBytes)
    }

    private var storageTotalText: String {
        compactBytes(diskUsage.totalBytes)
    }

    private var cleanupParts: ByteParts {
        byteParts(model.potentialSavingsBytes)
    }

    private var cleanupDisplayText: String {
        compactBytes(model.potentialSavingsBytes)
    }

    private var storageSegments: [StorageBreakdownSegment] {
        let apps = model.rows.reduce(0) { $0 + $1.bundleSizeBytes }
        let caches = bytes(for: [.caches, .httpStorages, .webKit, .cookies])
        let support = bytes(for: [.applicationSupport, .containers, .groupContainers, .preferences, .savedApplicationState])
        let tracked = max(0, model.allStorageItems.reduce(0) { $0 + $1.sizeBytes })
        let other = max(0, tracked - apps - caches - support)

        return [
            StorageBreakdownSegment(title: "Apps", bytes: apps, color: MenuBarTheme.accent),
            StorageBreakdownSegment(title: "Caches", bytes: caches, color: MenuBarTheme.blue),
            StorageBreakdownSegment(title: "Support Files", bytes: support, color: MenuBarTheme.green),
            StorageBreakdownSegment(title: "Other", bytes: other, color: MenuBarTheme.orange),
            StorageBreakdownSegment(title: "Free", bytes: diskUsage.freeBytes, color: MenuBarTheme.free)
        ]
    }

    private var storageBarTotalBytes: Int64 {
        max(diskUsage.totalBytes, storageSegments.reduce(0) { $0 + $1.bytes })
    }

    private func bytes(for categories: Set<StorageCategory>) -> Int64 {
        model.allStorageItems
            .filter { categories.contains($0.category) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    private var lastScanText: String {
        guard let date = model.scanSchedule.lastScanAt ?? model.rows.compactMap(\.scannedAt).max() else {
            return "Never"
        }
        if Calendar.current.isDateInToday(date) {
            return "Today, \(Self.timeFormatter.string(from: date))"
        }
        return Self.dateFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum MenuBarTheme {
    static let primaryText = Color.appMonitor(light: .init(0.065, 0.075, 0.11), dark: .init(0.92, 0.935, 0.965))
    static let secondaryText = Color.appMonitor(light: .init(0.33, 0.36, 0.45), dark: .init(0.66, 0.70, 0.78))
    static let mutedText = Color.appMonitor(light: .init(0.46, 0.49, 0.58), dark: .init(0.55, 0.59, 0.68))
    static let sectionFill = Color.appMonitor(light: .init(1, 1, 1, 0.48), dark: .init(0.13, 0.145, 0.18, 0.70))
    static let cardFill = Color.appMonitor(light: .init(1, 1, 1, 0.62), dark: .init(0.17, 0.182, 0.225, 0.78))
    static let iconButtonFill = Color.appMonitor(light: .init(1, 1, 1, 0.40), dark: .init(0.18, 0.194, 0.238, 0.84))
    static let iconButtonPressedFill = Color.appMonitor(light: .init(0, 0, 0, 0.10), dark: .init(1, 1, 1, 0.10))
    static let hairline = Color.appMonitor(light: .init(0, 0, 0, 0.075), dark: .init(1, 1, 1, 0.10))
    static let popoverStroke = Color.appMonitor(light: .init(1, 1, 1, 0.56), dark: .init(1, 1, 1, 0.12))
    static let popoverShadow = Color.appMonitor(light: .init(0, 0, 0, 0.20), dark: .init(0, 0, 0, 0.45))
    static let track = Color.appMonitor(light: .init(0.84, 0.86, 0.91, 0.74), dark: .init(1, 1, 1, 0.12))
    static let accent = Color.appMonitor(light: .init(0.40, 0.31, 0.90), dark: .init(0.64, 0.57, 1))
    static let blue = Color.appMonitor(light: .init(0.12, 0.50, 0.94), dark: .init(0.34, 0.66, 1))
    static let green = Color.appMonitor(light: .init(0.19, 0.65, 0.38), dark: .init(0.34, 0.82, 0.52))
    static let orange = Color.appMonitor(light: .init(0.93, 0.48, 0.03), dark: .init(1, 0.62, 0.22))
    static let warning = Color.appMonitor(light: .init(0.98, 0.63, 0.10), dark: .init(1, 0.72, 0.24))
    static let free = Color.appMonitor(light: .init(0.70, 0.72, 0.79), dark: .init(0.38, 0.42, 0.51))
}

private struct AppMonitorMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = AppBranding.logoImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.46, green: 0.36, blue: 0.96),
                                    Color(red: 0.34, green: 0.47, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: size * 0.52, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: MenuBarTheme.accent.opacity(0.25), radius: 5, y: 3)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String?
    let subtitle: String?
    let tint: Color
    let accessory: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MenuBarTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                if let unit {
                    Text(unit)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(MenuBarTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            accessory
                .frame(height: 24, alignment: .bottomLeading)
        }
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(12)
        .background(MenuBarTheme.cardFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MenuBarTheme.hairline, lineWidth: 1)
        )
    }
}

private struct MiniUsageBars: View {
    let values: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MenuBarTheme.accent)
                    .frame(width: 6, height: max(5, 26 * min(1, max(0.08, value))))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MiniProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MenuBarTheme.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 7)
        .frame(maxWidth: .infinity)
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String?
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MenuBarTheme.accent)
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MenuBarTheme.primaryText)
            Spacer()
            Button(actionTitle, action: action)
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundStyle(MenuBarTheme.accent)
        }
    }
}

private struct TopAppRow: View {
    let row: AppUsageRow
    let barFraction: Double
    let durationText: String

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(path: row.app.path, size: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(row.app.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MenuBarTheme.primaryText)
                .lineLimit(1)
                .frame(width: 112, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MenuBarTheme.track.opacity(0.45))
                    Capsule()
                        .fill(MenuBarTheme.accent)
                        .frame(width: max(12, geometry.size.width * min(1, max(0.08, barFraction))))
                }
            }
            .frame(height: 5)

            Text(durationText)
                .font(.system(size: 13))
                .foregroundStyle(MenuBarTheme.secondaryText)
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
        .frame(height: 38)
        .contentShape(Rectangle())
    }
}

private struct SegmentedStorageBar: View {
    let segments: [StorageBreakdownSegment]
    let totalBytes: Int64

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(segments) { segment in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(segment.color)
                        .frame(width: width(for: segment, totalWidth: geometry.size.width))
                }
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func width(for segment: StorageBreakdownSegment, totalWidth: CGFloat) -> CGFloat {
        guard totalBytes > 0, segment.bytes > 0 else { return segment.title == "Free" ? totalWidth : 0 }
        return max(segment.title == "Free" ? 16 : 5, totalWidth * CGFloat(Double(segment.bytes) / Double(totalBytes)))
    }
}

private struct StorageLegendItem: View {
    let segment: StorageBreakdownSegment

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(segment.color)
                .frame(width: 9, height: 9)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.title)
                    .font(.system(size: 12))
                    .foregroundStyle(MenuBarTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(compactBytes(segment.bytes))
                    .font(.system(size: 12))
                    .foregroundStyle(MenuBarTheme.primaryText.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }
}

private struct ActionSummaryRow: View {
    let systemImage: String
    let title: String
    let detail: String?
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MenuBarTheme.primaryText)

                Spacer()

                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MenuBarTheme.orange)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MenuBarTheme.secondaryText)
            }
            .frame(height: 48)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyPopoverState: View {
    let systemImage: String
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(message)
        }
        .font(.system(size: 13))
        .foregroundStyle(MenuBarTheme.secondaryText)
        .frame(maxWidth: .infinity)
    }
}

private struct MenuBarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(MenuBarTheme.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? MenuBarTheme.iconButtonPressedFill : MenuBarTheme.iconButtonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MenuBarTheme.hairline, lineWidth: 1)
            )
    }
}

private struct StorageBreakdownSegment: Identifiable {
    let id = UUID()
    let title: String
    let bytes: Int64
    let color: Color
}

private struct DiskUsage {
    let usedBytes: Int64
    let freeBytes: Int64
    let totalBytes: Int64

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    static func current(scannedFallbackBytes: Int64) -> DiskUsage {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        let values = try? homeURL.resourceValues(forKeys: keys)
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let free = values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
            ?? 0

        if total > 0 {
            return DiskUsage(
                usedBytes: max(0, total - free),
                freeBytes: max(0, free),
                totalBytes: total
            )
        }

        return DiskUsage(
            usedBytes: scannedFallbackBytes,
            freeBytes: 0,
            totalBytes: max(scannedFallbackBytes, 1)
        )
    }
}

private struct ByteParts {
    let value: String
    let unit: String
}

private func byteParts(_ bytes: Int64) -> ByteParts {
    let text = compactBytes(bytes)
    let pieces = text.split(separator: " ", maxSplits: 1).map(String.init)
    if pieces.count == 2 {
        return ByteParts(value: pieces[0], unit: pieces[1])
    }
    return ByteParts(value: text, unit: "")
}

private func compactBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 KB" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.includesActualByteCount = false
    return formatter.string(fromByteCount: bytes)
}

private func compactDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    if minutes > 0 {
        return "\(minutes)m"
    }
    return "0m"
}
