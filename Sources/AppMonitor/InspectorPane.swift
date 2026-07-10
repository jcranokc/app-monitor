import AppMonitorCore
import SwiftUI

struct InspectorPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let row = model.selectedRow {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(row)
                        UsageBars(rows: model.dailyUsageRowsForSelectedApp())
                        importedActivity(row)
                        updateSummary(row)
                        storageSummary(row)
                        storageItems
                    }
                    .padding(18)
                }
            } else {
                ContentUnavailableView("No App Selected", systemImage: "app.dashed", description: Text("Select an app to inspect usage and related files."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(_ row: AppUsageRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AppIcon(path: row.app.path, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.app.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(row.app.bundleIdentifier ?? "No bundle identifier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            DetailLine(title: "Version", value: row.app.version ?? "Unknown")
            DetailLine(title: "Usage", value: AppMonitorFormatting.duration(row.usageSeconds))
            DetailLine(title: "Last Used", value: AppMonitorFormatting.shortDateTime(row.lastUsed))
            DetailLine(title: "Imported Last Used", value: AppMonitorFormatting.shortDateTime(row.importedLastUsed))
            DetailLine(title: "Path", value: row.app.path)
            Button {
                Task { await model.prepareSelectedAppUninstall() }
            } label: {
                Label("Uninstall & Clean Up", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func importedActivity(_ row: AppUsageRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Imported Activity")
                .font(.headline)
            DetailLine(title: "Days In Selected Period", value: "\(row.importedDaysInPeriod)")
            DetailLine(title: "Historical Opens", value: row.importedUseCount.map(String.init) ?? "Unknown")
            DetailLine(title: "Last Imported", value: AppMonitorFormatting.shortDateTime(row.importedAt))
            Text("Imported from Spotlight metadata. These dates and counts are historical activity signals, not measured duration.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func updateSummary(_ row: AppUsageRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Updates")
                .font(.headline)
            if let record = model.selectedUpdateRecord {
                DetailLine(title: "Source", value: record.source.displayName)
                DetailLine(title: "Current", value: record.currentVersion ?? row.app.version ?? "Unknown")
                DetailLine(title: "Available", value: record.availableVersion ?? "Unknown")
                DetailLine(title: "Status", value: record.status.displayName)
                DetailLine(title: "Last Checked", value: AppMonitorFormatting.shortDateTime(record.checkedAt))
                if let result = model.selectedUpdateResult {
                    DetailLine(title: "Last Result", value: "\(result.status.displayName): \(result.message ?? "No details")")
                }
                Button {
                    Task { await model.updateRecord(record) }
                } label: {
                    Label(updateActionTitle(for: record), systemImage: updateActionIcon(for: record))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isCheckingUpdates || model.isRunningUpdates)
            } else {
                Text("No update record for this app. Run an update check to refresh provider data.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            if model.selectedChangeLogEntries.isEmpty {
                Text("No captured change logs yet.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Change Log")
                        .font(.subheadline.weight(.semibold))
                    ForEach(model.selectedChangeLogEntries.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(changeLogVersionText(entry))
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(AppMonitorFormatting.shortDateTime(entry.capturedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.title)
                                .font(.caption)
                                .lineLimit(2)
                            Text(entry.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func storageSummary(_ row: AppUsageRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage")
                .font(.headline)
            DetailLine(title: "App Bundle", value: AppMonitorFormatting.bytes(row.bundleSizeBytes))
            DetailLine(title: "Related Files", value: AppMonitorFormatting.bytes(row.relatedSizeBytes))
            DetailLine(title: "Total", value: AppMonitorFormatting.bytes(row.totalSizeBytes))
            DetailLine(title: "Status", value: row.scanStatus)
            if row.warningCount > 0 {
                Label("\(row.warningCount) scan warning\(row.warningCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
    }

    private var storageItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Related Paths")
                .font(.headline)
            if model.selectedStorageItems.isEmpty {
                Text("Run a storage scan to populate related app files.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(model.selectedStorageItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.category.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(AppMonitorFormatting.bytes(item.sizeBytes))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        Text(item.path)
                            .font(.caption)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .help(item.path)
                        if let warning = item.warning {
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(3)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func updateActionTitle(for record: AppUpdateRecord) -> String {
        if record.source == .macAppStore {
            return "Open App Store"
        }
        if record.status == .adoptable {
            return "Adopt with Homebrew"
        }
        return record.canInstall ? "Update App" : record.installActionTitle
    }

    private func updateActionIcon(for record: AppUpdateRecord) -> String {
        if record.source == .macAppStore {
            return "bag"
        }
        if record.status == .adoptable {
            return "shippingbox"
        }
        return record.canInstall ? "square.and.arrow.down" : "arrow.up.forward.app"
    }
}

private func changeLogVersionText(_ entry: AppChangeLogEntry) -> String {
    if let fromVersion = entry.fromVersion, let toVersion = entry.toVersion {
        return "\(fromVersion) -> \(toVersion)"
    }
    if let toVersion = entry.toVersion {
        return "Updated to \(toVersion)"
    }
    return entry.source.displayName
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

private struct UsageBars: View {
    let rows: [DailyUsageRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Usage")
                .font(.headline)

            if rows.isEmpty {
                Text("No usage recorded in this period.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                let maxUsage = max(rows.map(\.usageSeconds).max() ?? 1, 1)
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Text(AppMonitorFormatting.day(row.day))
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: max(4, geometry.size.width * row.usageSeconds / maxUsage))
                            }
                            .frame(height: 10)
                            Text(AppMonitorFormatting.duration(row.usageSeconds))
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 58, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
