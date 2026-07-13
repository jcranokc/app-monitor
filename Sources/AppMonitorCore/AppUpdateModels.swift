import Foundation

public enum AppUpdateSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case macAppStore
    case homebrewCask
    case homebrewFormula
    case appleSoftwareUpdate
    case directDownload
    case metadata
    case electron
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .macAppStore:
            return "Mac App Store"
        case .homebrewCask:
            return "Homebrew Cask"
        case .homebrewFormula:
            return "Homebrew Formula"
        case .appleSoftwareUpdate:
            return "Apple Software Update"
        case .directDownload:
            return "Direct Download"
        case .metadata:
            return "Metadata"
        case .electron:
            return "Electron"
        case .unknown:
            return "Unknown"
        }
    }
}

public enum AppUpdateStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case upToDate
    case available
    case checking
    case updating
    case updated
    case failed
    case needsAdmin
    case needsRestart
    case manualAction
    case adoptable
    case providerUnavailable
    case skipped

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .upToDate:
            return "Up to Date"
        case .available:
            return "Available"
        case .checking:
            return "Checking"
        case .updating:
            return "Updating"
        case .updated:
            return "Updated"
        case .failed:
            return "Failed"
        case .needsAdmin:
            return "Needs Admin"
        case .needsRestart:
            return "Needs Restart"
        case .manualAction:
            return "Manual Action"
        case .adoptable:
            return "Adoptable"
        case .providerUnavailable:
            return "Provider Missing"
        case .skipped:
            return "Skipped"
        }
    }

    public var countsAsAvailable: Bool {
        switch self {
        case .available, .needsAdmin, .needsRestart, .manualAction:
            return true
        case .upToDate, .checking, .updating, .updated, .failed, .adoptable, .providerUnavailable, .skipped:
            return false
        }
    }

    public var countsAsAdoptionCandidate: Bool {
        self == .adoptable
    }
}

public enum UpdateRunMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case automatic

    public var id: String { rawValue }
}

public enum UpdateRunStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case completed
    case partial
    case failed
    case skipped

    public var id: String { rawValue }
}

public struct AppUpdateSettings: Hashable, Codable, Sendable {
    public var scheduledChecksEnabled: Bool
    public var automaticUpdatesEnabled: Bool
    public var cadenceHours: Int
    public var includeHomebrewFormulae: Bool
    public var includeAppleSoftwareUpdates: Bool
    public var includeDirectDownloadDetection: Bool
    public var lastCheckAt: Date?
    public var nextCheckAt: Date?

    public init(
        scheduledChecksEnabled: Bool = false,
        automaticUpdatesEnabled: Bool = false,
        cadenceHours: Int = 24,
        includeHomebrewFormulae: Bool = true,
        includeAppleSoftwareUpdates: Bool = true,
        includeDirectDownloadDetection: Bool = true,
        lastCheckAt: Date? = nil,
        nextCheckAt: Date? = nil
    ) {
        self.scheduledChecksEnabled = scheduledChecksEnabled
        self.automaticUpdatesEnabled = automaticUpdatesEnabled
        self.cadenceHours = cadenceHours
        self.includeHomebrewFormulae = includeHomebrewFormulae
        self.includeAppleSoftwareUpdates = includeAppleSoftwareUpdates
        self.includeDirectDownloadDetection = includeDirectDownloadDetection
        self.lastCheckAt = lastCheckAt
        self.nextCheckAt = nextCheckAt
    }

    public func nextCheckDate(from date: Date = Date()) -> Date {
        date.addingTimeInterval(TimeInterval(max(1, cadenceHours) * 3600))
    }
}

public struct AppUpdateRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let appID: String?
    public let appName: String
    public let bundleIdentifier: String?
    public let appPath: String?
    public let source: AppUpdateSource
    public let sourceIdentifier: String
    public let currentVersion: String?
    public let availableVersion: String?
    public var status: AppUpdateStatus
    public var checkedAt: Date
    public let installActionTitle: String
    public let installActionURL: String?
    public let requiresAdmin: Bool
    public let requiresRestart: Bool
    public let canInstall: Bool
    public var isAutoEligible: Bool
    public let releaseNotesTitle: String?
    public let releaseNotesSummary: String?
    public let releaseNotesURL: String?
    public var message: String?

    public init(
        id: String? = nil,
        appID: String?,
        appName: String,
        bundleIdentifier: String?,
        appPath: String?,
        source: AppUpdateSource,
        sourceIdentifier: String,
        currentVersion: String?,
        availableVersion: String?,
        status: AppUpdateStatus,
        checkedAt: Date = Date(),
        installActionTitle: String,
        installActionURL: String? = nil,
        requiresAdmin: Bool = false,
        requiresRestart: Bool = false,
        canInstall: Bool = true,
        isAutoEligible: Bool = false,
        releaseNotesTitle: String? = nil,
        releaseNotesSummary: String? = nil,
        releaseNotesURL: String? = nil,
        message: String? = nil
    ) {
        self.id = id ?? Self.makeID(source: source, sourceIdentifier: sourceIdentifier, appID: appID)
        self.appID = appID
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.currentVersion = currentVersion
        self.availableVersion = availableVersion
        self.status = status
        self.checkedAt = checkedAt
        self.installActionTitle = installActionTitle
        self.installActionURL = installActionURL
        self.requiresAdmin = requiresAdmin
        self.requiresRestart = requiresRestart
        self.canInstall = canInstall
        self.isAutoEligible = isAutoEligible
        self.releaseNotesTitle = releaseNotesTitle
        self.releaseNotesSummary = releaseNotesSummary
        self.releaseNotesURL = releaseNotesURL
        self.message = message
    }

    public static func makeID(source: AppUpdateSource, sourceIdentifier: String, appID: String?) -> String {
        "\(source.rawValue)|\(sourceIdentifier.isEmpty ? appID ?? "unknown" : sourceIdentifier)"
    }
}

public struct AppChangeLogEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let appID: String?
    public let appName: String
    public let bundleIdentifier: String?
    public let appPath: String?
    public let source: AppUpdateSource
    public let sourceIdentifier: String
    public let fromVersion: String?
    public let toVersion: String?
    public let title: String
    public let summary: String
    public let releaseNotesURL: String?
    public let updateRunID: String?
    public let updateResultID: String?
    public let capturedAt: Date

    public init(
        id: String? = nil,
        appID: String?,
        appName: String,
        bundleIdentifier: String?,
        appPath: String?,
        source: AppUpdateSource,
        sourceIdentifier: String,
        fromVersion: String?,
        toVersion: String?,
        title: String,
        summary: String,
        releaseNotesURL: String? = nil,
        updateRunID: String? = nil,
        updateResultID: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id ?? Self.makeID(
            appID: appID,
            appName: appName,
            source: source,
            sourceIdentifier: sourceIdentifier,
            fromVersion: fromVersion,
            toVersion: toVersion
        )
        self.appID = appID
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.title = title
        self.summary = summary
        self.releaseNotesURL = releaseNotesURL
        self.updateRunID = updateRunID
        self.updateResultID = updateResultID
        self.capturedAt = capturedAt
    }

    public static func makeID(
        appID: String?,
        appName: String,
        source: AppUpdateSource,
        sourceIdentifier: String,
        fromVersion: String?,
        toVersion: String?
    ) -> String {
        [
            appID ?? appName,
            source.rawValue,
            sourceIdentifier,
            fromVersion ?? "unknown",
            toVersion ?? "unknown"
        ].joined(separator: "|")
    }

    public static func fromUpdateRecord(
        _ record: AppUpdateRecord,
        result: UpdateItemResult? = nil,
        runID: String? = nil,
        capturedAt: Date = Date()
    ) -> AppChangeLogEntry {
        let fromVersion = record.currentVersion
        let toVersion = record.availableVersion
        let versionText: String
        if let fromVersion, let toVersion {
            versionText = "\(fromVersion) -> \(toVersion)"
        } else if let toVersion {
            versionText = "Updated to \(toVersion)"
        } else {
            versionText = "Update recorded"
        }
        let title = record.releaseNotesTitle ?? "\(record.appName) \(versionText)"
        let summary = record.releaseNotesSummary
            ?? result?.message
            ?? record.message
            ?? "App Monitor recorded an update from \(record.source.displayName). Detailed release notes were not available from this provider."

        return AppChangeLogEntry(
            appID: record.appID,
            appName: record.appName,
            bundleIdentifier: record.bundleIdentifier,
            appPath: record.appPath,
            source: record.source,
            sourceIdentifier: record.sourceIdentifier,
            fromVersion: fromVersion,
            toVersion: toVersion,
            title: title,
            summary: summary,
            releaseNotesURL: record.releaseNotesURL ?? releaseNotesCandidateURL(record.installActionURL),
            updateRunID: runID ?? result?.runID,
            updateResultID: result?.id,
            capturedAt: capturedAt
        )
    }

    private static func releaseNotesCandidateURL(_ urlString: String?) -> String? {
        guard let urlString,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        let archiveExtensions: Set<String> = ["dmg", "pkg", "zip", "tbz", "tgz", "gz", "bz2", "xz"]
        return archiveExtensions.contains(url.pathExtension.lowercased()) ? nil : urlString
    }
}

public struct UpdateRunRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let mode: UpdateRunMode
    public let status: UpdateRunStatus
    public let startedAt: Date
    public let completedAt: Date
    public let selectedItemCount: Int
    public let updatedItemCount: Int
    public let failedItemCount: Int
    public let skippedItemCount: Int
    public let message: String?

    public init(
        id: String = UUID().uuidString,
        mode: UpdateRunMode,
        status: UpdateRunStatus,
        startedAt: Date,
        completedAt: Date = Date(),
        selectedItemCount: Int,
        updatedItemCount: Int,
        failedItemCount: Int,
        skippedItemCount: Int,
        message: String? = nil
    ) {
        self.id = id
        self.mode = mode
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.selectedItemCount = selectedItemCount
        self.updatedItemCount = updatedItemCount
        self.failedItemCount = failedItemCount
        self.skippedItemCount = skippedItemCount
        self.message = message
    }
}

public struct UpdateItemResult: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let runID: String
    public let updateID: String
    public let appID: String?
    public let appName: String
    public let source: AppUpdateSource
    public let sourceIdentifier: String
    public let status: AppUpdateStatus
    public let message: String?
    public let completedAt: Date

    public init(
        id: String = UUID().uuidString,
        runID: String,
        updateID: String,
        appID: String?,
        appName: String,
        source: AppUpdateSource,
        sourceIdentifier: String,
        status: AppUpdateStatus,
        message: String? = nil,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.runID = runID
        self.updateID = updateID
        self.appID = appID
        self.appName = appName
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.status = status
        self.message = message
        self.completedAt = completedAt
    }
}

public struct AppUpdateEligibility {
    public static func isResolvedByInstalledVersion(
        _ record: AppUpdateRecord,
        installedVersion: String?
    ) -> Bool {
        switch record.source {
        case .macAppStore, .directDownload, .metadata, .electron:
            break
        case .homebrewCask, .homebrewFormula, .appleSoftwareUpdate, .unknown:
            return false
        }
        guard let installedVersion,
              !installedVersion.isEmpty,
              let availableVersion = record.availableVersion,
              !availableVersion.isEmpty else {
            return false
        }
        return VersionComparator.isVersion(installedVersion, atLeast: availableVersion)
    }

    public static func isStaleHomebrewManagementRecord(_ record: AppUpdateRecord) -> Bool {
        guard record.source == .homebrewCask,
              record.sourceIdentifier.hasPrefix("adopt:") || record.sourceIdentifier.hasPrefix("replace:"),
              let currentVersion = record.currentVersion,
              let availableVersion = record.availableVersion else {
            return false
        }
        return VersionComparator.isVersion(currentVersion, newerThan: availableVersion)
    }

    public static func isBulkHomebrewActionable(
        record: AppUpdateRecord,
        settings: AppUpdateSettings
    ) -> Bool {
        guard record.canInstall else { return false }
        guard record.status == .available || record.status == .adoptable else { return false }
        guard !record.requiresAdmin, !record.requiresRestart else { return false }
        guard !isStaleHomebrewManagementRecord(record) else { return false }

        switch record.source {
        case .homebrewCask:
            return true
        case .homebrewFormula:
            return record.status == .available && settings.includeHomebrewFormulae
        case .macAppStore, .appleSoftwareUpdate, .directDownload, .metadata, .electron, .unknown:
            return false
        }
    }

    public static func isAutoEligible(
        record: AppUpdateRecord,
        isAppRunning: Bool,
        settings: AppUpdateSettings
    ) -> Bool {
        guard settings.automaticUpdatesEnabled else { return false }
        guard record.status == .available else { return false }
        guard record.canInstall, record.isAutoEligible else { return false }
        guard !record.requiresAdmin, !record.requiresRestart else { return false }
        guard !isAppRunning else { return false }
        switch record.source {
        case .homebrewCask:
            return true
        case .homebrewFormula:
            return settings.includeHomebrewFormulae
        case .macAppStore, .appleSoftwareUpdate, .directDownload, .metadata, .electron, .unknown:
            return false
        }
    }
}
