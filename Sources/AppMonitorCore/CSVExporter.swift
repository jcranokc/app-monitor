import Foundation

public enum CSVExporter {
    public static func monitoringHistoryCSV(segments: [UsageSegment]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [[
            "App", "Bundle Identifier", "Start", "End", "Duration Seconds", "Path"
        ].csvLine]

        for segment in segments {
            lines.append([
                segment.appName,
                segment.bundleIdentifier ?? "",
                iso.string(from: segment.startedAt),
                iso.string(from: segment.endedAt),
                String(Int(segment.durationSeconds.rounded())),
                segment.appPath
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func appRowsCSV(rows: [AppUsageRow]) -> String {
        var lines = [
            [
                "App",
                "Bundle Identifier",
                "Usage Seconds",
                "Usage",
                "Last Used",
                "Imported Days In Period",
                "Imported Use Count",
                "Imported Last Used",
                "Imported At",
                "App Size Bytes",
                "Related Files Size Bytes",
                "Total Size Bytes",
                "Location",
                "Scan Status"
            ].csvLine
        ]

        for row in rows {
            lines.append([
                row.app.name,
                row.app.bundleIdentifier ?? "",
                String(Int(row.usageSeconds.rounded())),
                AppMonitorFormatting.duration(row.usageSeconds),
                row.lastUsed.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                String(row.importedDaysInPeriod),
                row.importedUseCount.map(String.init) ?? "",
                row.importedLastUsed.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                row.importedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                String(row.bundleSizeBytes),
                String(row.relatedSizeBytes),
                String(row.totalSizeBytes),
                row.app.path,
                row.scanStatus
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func dailyUsageCSV(rows: [DailyUsageRow]) -> String {
        var lines = [["Date", "App", "Usage Seconds", "Usage"].csvLine]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        for row in rows {
            lines.append([
                iso.string(from: row.day),
                row.appName,
                String(Int(row.usageSeconds.rounded())),
                AppMonitorFormatting.duration(row.usageSeconds)
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func timelineSessionsCSV(rows: [TimelineSession]) -> String {
        var lines = [
            [
                "App",
                "Bundle Identifier",
                "Start",
                "End",
                "Duration Seconds",
                "Duration",
                "Source",
                "Clipped",
                "Path"
            ].csvLine
        ]
        let iso = ISO8601DateFormatter()

        for row in rows {
            lines.append([
                row.appName,
                row.bundleIdentifier ?? "",
                iso.string(from: row.startedAt),
                iso.string(from: row.endedAt),
                String(Int(row.durationSeconds.rounded())),
                AppMonitorFormatting.duration(row.durationSeconds),
                row.source,
                row.isClipped ? "true" : "false",
                row.appPath
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func usageSummaryCSV(snapshot: UsageAnalyticsSnapshot) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [["Metric", "Value", "Usage Seconds", "Comparison"].csvLine]
        let summary = snapshot.summary

        lines.append([
            "Total Usage",
            AppMonitorFormatting.duration(summary.totalSeconds),
            String(Int(summary.totalSeconds.rounded())),
            comparisonText(summary.comparison.totalPercentChange)
        ].csvLine)
        lines.append([
            "Daily Average",
            AppMonitorFormatting.duration(summary.dailyAverageSeconds),
            String(Int(summary.dailyAverageSeconds.rounded())),
            comparisonText(summary.comparison.dailyAveragePercentChange)
        ].csvLine)
        lines.append([
            "Peak Day",
            summary.peakDay.map { iso.string(from: $0) } ?? "",
            String(Int(summary.peakDaySeconds.rounded())),
            ""
        ].csvLine)
        lines.append([
            "Most Used App",
            summary.mostUsedApp?.appName ?? "",
            String(Int((summary.mostUsedApp?.seconds ?? 0).rounded())),
            percentageText(summary.mostUsedApp?.percentOfTotal)
        ].csvLine)
        lines.append([
            "Total Sessions",
            String(summary.sessionCount),
            "",
            comparisonText(summary.comparison.sessionPercentChange)
        ].csvLine)

        return lines.joined(separator: "\n") + "\n"
    }

    public static func trendBucketsCSV(buckets: [UsageTrendBucket]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [["Bucket Start", "Bucket End", "App", "Usage Seconds", "Usage", "Percent Of Bucket"].csvLine]

        for bucket in buckets {
            if bucket.stacks.isEmpty {
                lines.append([
                    iso.string(from: bucket.start),
                    iso.string(from: bucket.end),
                    "",
                    "0",
                    "0s",
                    "0"
                ].csvLine)
            } else {
                for stack in bucket.stacks {
                    lines.append([
                        iso.string(from: bucket.start),
                        iso.string(from: bucket.end),
                        stack.appName,
                        String(Int(stack.seconds.rounded())),
                        AppMonitorFormatting.duration(stack.seconds),
                        String(stack.percentOfBucket)
                    ].csvLine)
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func topAppsCSV(topApps: [TopAppUsage]) -> String {
        var lines = [["App", "App ID", "Usage Seconds", "Usage", "Percent Of Total", "Path"].csvLine]

        for app in topApps {
            lines.append([
                app.appName,
                app.appID,
                String(Int(app.seconds.rounded())),
                AppMonitorFormatting.duration(app.seconds),
                String(app.percentOfTotal),
                app.appPath
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func heatmapCSV(cells: [UsageHeatmapCell]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [["Row Start", "Row Label", "Hour", "Usage Seconds", "Usage", "Session Count", "Top App"].csvLine]

        for cell in cells {
            lines.append([
                iso.string(from: cell.rowStart),
                cell.rowLabel,
                String(cell.hourOfDay),
                String(Int(cell.seconds.rounded())),
                AppMonitorFormatting.duration(cell.seconds),
                String(cell.sessionCount),
                cell.topAppName ?? ""
            ].csvLine)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func comparisonText(_ percentChange: Double?) -> String {
        guard let percentChange else { return "No prior data" }
        return percentageText(percentChange)
    }

    private static func percentageText(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f%%", value * 100)
    }
}

private extension Array where Element == String {
    var csvLine: String {
        map { field in
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return field
        }.joined(separator: ",")
    }
}
