import Foundation

/// Stable identifiers used by VoiceOver QA and automated UI tests.
public enum AppAccessibilityIdentifier {
    public static let sidebarOverview = "app-monitor.sidebar.overview"
    public static let sidebarUpdates = "app-monitor.sidebar.updates"
    public static let sidebarAllApps = "app-monitor.sidebar.all-apps"
    public static let sidebarWarnings = "app-monitor.sidebar.warnings"
    public static let sidebarQuarantine = "app-monitor.sidebar.quarantine"
    public static let sidebarHistory = "app-monitor.sidebar.history"
    public static let sidebarSettings = "app-monitor.sidebar.settings"
    public static let sidebarUpdateSourcesDisclosure = "app-monitor.sidebar.update-sources-disclosure"
    public static let appTableOptions = "app-monitor.apps.table-options"
    public static let updatesSelectAvailable = "app-monitor.updates.select-available"
    public static let updatesClearSelection = "app-monitor.updates.clear-selection"
    public static let updatesCheck = "app-monitor.updates.check"
    public static let updatesRunSelected = "app-monitor.updates.run-selected"
    public static let updatesAdoptAll = "app-monitor.updates.adopt-all"
    public static let quarantineFilters = "app-monitor.quarantine.filters"
    public static let quarantineSort = "app-monitor.quarantine.sort"
    public static let historyTable = "app-monitor.history.table"
    public static let settingsScreen = "app-monitor.settings.screen"
    public static let inspectorToggle = "app-monitor.inspector.toggle"

    public static let staticIdentifiers: [String] = [
        sidebarOverview,
        sidebarUpdates,
        sidebarAllApps,
        sidebarWarnings,
        sidebarQuarantine,
        sidebarHistory,
        sidebarSettings,
        sidebarUpdateSourcesDisclosure,
        appTableOptions,
        updatesSelectAvailable,
        updatesClearSelection,
        updatesCheck,
        updatesRunSelected,
        updatesAdoptAll,
        quarantineFilters,
        quarantineSort,
        historyTable,
        settingsScreen,
        inspectorToggle
    ]

    public static func sidebar(_ destination: String) -> String {
        "app-monitor.sidebar.\(component(destination))"
    }

    public static func appRow(_ id: String) -> String {
        "app-monitor.apps.row.\(component(id))"
    }

    public static func updateRow(_ id: String) -> String {
        "app-monitor.updates.row.\(component(id))"
    }

    public static func updateSelection(_ id: String) -> String {
        "app-monitor.updates.selection.\(component(id))"
    }

    public static func quarantineRow(_ id: String) -> String {
        "app-monitor.quarantine.row.\(component(id))"
    }

    public static func quarantineSelection(_ id: String) -> String {
        "app-monitor.quarantine.selection.\(component(id))"
    }

    public static func warningRow(_ id: String) -> String {
        "app-monitor.warnings.row.\(component(id))"
    }

    public static func historyRow(_ id: String) -> String {
        "app-monitor.history.row.\(component(id))"
    }

    public static func chart(_ name: String) -> String {
        "app-monitor.chart.\(component(name))"
    }

    public static func setting(_ name: String) -> String {
        "app-monitor.settings.\(component(name))"
    }

    private static func component(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0).lowercased() : "-" }
            .joined()
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
