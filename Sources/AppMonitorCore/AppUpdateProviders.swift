import Foundation

public struct ShellCommandResult: Hashable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public protocol UpdateCommandRunning: Sendable {
    func run(_ executable: String, arguments: [String]) -> ShellCommandResult
    func runPrivileged(_ executable: String, arguments: [String]) -> ShellCommandResult
}

public struct ProcessUpdateCommandRunner: UpdateCommandRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String]) -> ShellCommandResult {
        runProcess(executable, arguments: arguments)
    }

    public func runPrivileged(_ executable: String, arguments: [String]) -> ShellCommandResult {
        let command = ([executable] + arguments).map(Self.shellQuote).joined(separator: " ")
        let script = "do shell script \(Self.appleScriptString(command)) with administrator privileges"
        return runProcess("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func runProcess(_ executable: String, arguments: [String]) -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let standardError = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let output: String
            if process.terminationStatus == 0 {
                output = standardOutput.isEmpty ? standardError : standardOutput
            } else {
                output = [standardOutput, standardError]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            }
            return ShellCommandResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return ShellCommandResult(exitCode: 127, output: error.localizedDescription)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptString(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

public protocol AppUpdateProvider: Sendable {
    var source: AppUpdateSource { get }
    func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord]
    func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult
}

public struct MacAppStoreUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .macAppStore
    private let masPath: String
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager

    public init(
        masPath: String = "/opt/homebrew/bin/mas",
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.masPath = masPath
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: masPath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: source, name: "Mac App Store", message: "mas is not installed or is not executable.")]
            }
            let result = commandRunner.run(masPath, arguments: ["outdated", "--json", "--inaccurate", "--check-min-os"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: source, name: "Mac App Store", message: result.output)]
            }
            return Self.parseOutdated(json: result.output, apps: apps, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            guard mode == .manual else {
                return skippedResult(record: record, runID: runID, message: "Mac App Store updates require explicit authorization.")
            }
            let arguments: [String]
            if let bundleIdentifier = record.bundleIdentifier {
                arguments = ["update", "--bundle", bundleIdentifier]
            } else {
                arguments = ["update", record.sourceIdentifier]
            }
            let result = commandRunner.runPrivileged(masPath, arguments: arguments)
            return itemResult(record: record, runID: runID, commandResult: result)
        }.value
    }

    public static func parseOutdated(json: String, apps: [MonitoredApp], checkedAt: Date = Date()) -> [AppUpdateRecord] {
        guard let objects = jsonObjectList(from: json) else {
            return []
        }
        let appsByBundleID = appLookupByBundleID(apps)

        return objects.compactMap { object in
            let bundleID = stringValue(
                object["bundleID"]
                    ?? object["bundleId"]
                    ?? object["bundleIdentifier"]
                    ?? object["bundle_id"]
            )
            let appStoreID = stringValue(
                object["appID"]
                    ?? object["appId"]
                    ?? object["adamID"]
                    ?? object["adamId"]
                    ?? object["id"]
            )
            let matchedApp = bundleID.flatMap { appsByBundleID[$0] }
            let name = stringValue(
                object["title"]
                    ?? object["name"]
                    ?? object["displayName"]
                    ?? object["displayNameWithExtensions"]
            ) ?? matchedApp?.name ?? "Mac App Store App"
            let explicitCurrentVersion = stringValue(
                object["installedVersion"]
                    ?? object["currentVersion"]
                    ?? object["installed"]
            )
            let masCurrentVersion = object["newVersion"] == nil ? nil : stringValue(object["version"])
            let currentVersion = explicitCurrentVersion
                ?? masCurrentVersion
                ?? matchedApp?.version
            let legacyAvailableVersion = explicitCurrentVersion == nil ? nil : stringValue(object["version"])
            let availableVersion = stringValue(
                object["newVersion"]
                    ?? object["latestVersion"]
                    ?? object["availableVersion"]
                    ?? object["available"]
            ) ?? legacyAvailableVersion
                ?? (explicitCurrentVersion == nil && masCurrentVersion == nil ? stringValue(object["version"]) : nil)
            let sourceIdentifier = appStoreID ?? bundleID ?? name
            return AppUpdateRecord(
                appID: matchedApp?.id,
                appName: name,
                bundleIdentifier: bundleID ?? matchedApp?.bundleIdentifier,
                appPath: matchedApp?.path,
                source: .macAppStore,
                sourceIdentifier: sourceIdentifier,
                currentVersion: currentVersion,
                availableVersion: availableVersion,
                status: .needsAdmin,
                checkedAt: checkedAt,
                installActionTitle: "Update from App Store",
                installActionURL: appStoreID.map { "macappstore://itunes.apple.com/app/id\($0)" },
                requiresAdmin: true,
                canInstall: true,
                isAutoEligible: false,
                message: "Requires App Store authorization."
            )
        }
    }
}

private func appLookupByBundleID(_ apps: [MonitoredApp]) -> [String: MonitoredApp] {
    var lookup: [String: MonitoredApp] = [:]
    for app in apps {
        guard let bundleIdentifier = app.bundleIdentifier,
              lookup[bundleIdentifier] == nil else {
            continue
        }
        lookup[bundleIdentifier] = app
    }
    return lookup
}

private func hasExplicitSparkleFeed(app: MonitoredApp, fileManager: FileManager) -> Bool {
    let infoURL = URL(fileURLWithPath: app.path)
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("Info.plist")
    guard fileManager.fileExists(atPath: infoURL.path),
          let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
        return false
    }
    return info["SUFeedURL"] is String
}

private func isHomebrewCaskInstalled(token: String, fileManager: FileManager) -> Bool {
    fileManager.fileExists(atPath: "/opt/homebrew/Caskroom/\(token)")
        || fileManager.fileExists(atPath: "/usr/local/Caskroom/\(token)")
}

private func caskTokenCandidates(for app: MonitoredApp) -> [String] {
    var candidates: [String] = []

    func append(_ value: String?) {
        guard let value else { return }
        for candidate in tokenVariants(from: value) where !candidates.contains(candidate) {
            candidates.append(candidate)
        }
    }

    append(app.name)
    append(app.bundleIdentifier?.split(separator: ".").last.map(String.init))
    if let bundleIdentifier = app.bundleIdentifier {
        let components = bundleIdentifier.split(separator: ".").map(String.init)
        for size in stride(from: min(3, components.count), through: 1, by: -1) {
            append(components.suffix(size).joined(separator: "-"))
        }
    }
    append(URL(fileURLWithPath: app.path).deletingPathExtension().lastPathComponent)

    return Array(candidates.prefix(12))
}

private func tokenVariants(from value: String) -> [String] {
    let words = wordsForToken(value)
    guard !words.isEmpty else { return [] }

    var variants = [
        words.joined(separator: "-"),
        words.joined()
    ]

    if words.last == "app" {
        let withoutApp = words.dropLast()
        variants.append(withoutApp.joined(separator: "-"))
        variants.append(withoutApp.joined())
    }
    if words.last == "macos" || words.last == "mac" {
        let withoutPlatform = words.dropLast()
        variants.append(withoutPlatform.joined(separator: "-"))
        variants.append(withoutPlatform.joined())
    }

    var unique: [String] = []
    for variant in variants where !variant.isEmpty && !unique.contains(variant) {
        unique.append(variant)
    }
    return unique
}

private func wordsForToken(_ value: String) -> [String] {
    let expandedCamelCase = value.replacingOccurrences(
        of: "([a-z0-9])([A-Z])",
        with: "$1 $2",
        options: .regularExpression
    )
    return expandedCamelCase
        .lowercased()
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init)
}

public struct HomebrewUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .homebrewCask
    private let brewPath: String
    private let includeFormulae: Bool
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager

    public init(
        brewPath: String = "/opt/homebrew/bin/brew",
        includeFormulae: Bool,
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.brewPath = brewPath
        self.includeFormulae = includeFormulae
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: brewPath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: .homebrewCask, name: "Homebrew", message: "brew is not installed or is not executable.")]
            }
            _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
            let result = commandRunner.run(brewPath, arguments: ["outdated", "--json=v2", "--greedy"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: .homebrewCask, name: "Homebrew", message: result.output)]
            }
            return Self.parseOutdated(json: result.output, includeFormulae: includeFormulae, apps: apps, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            guard mode == .manual || AppUpdateEligibility.isAutoEligible(
                record: record,
                isAppRunning: false,
                settings: AppUpdateSettings(automaticUpdatesEnabled: true)
            ) else {
                return skippedResult(record: record, runID: runID, message: "Update is not eligible for automatic Homebrew install.")
            }
            _ = commandRunner.run(brewPath, arguments: ["update", "--auto-update"])
            let kindFlag = record.source == .homebrewFormula ? "--formula" : "--cask"
            let result = commandRunner.run(
                brewPath,
                arguments: ["upgrade", kindFlag, record.sourceIdentifier, "--no-ask", "--greedy"]
            )
            return itemResult(record: record, runID: runID, commandResult: result)
        }.value
    }

    public static func parseOutdated(
        json: String,
        includeFormulae: Bool,
        apps: [MonitoredApp],
        checkedAt: Date = Date()
    ) -> [AppUpdateRecord] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var records: [AppUpdateRecord] = []
        let appsByNormalizedName = Dictionary(grouping: apps, by: { normalizeName($0.name) })

        if let casks = root["casks"] as? [[String: Any]] {
            records += casks.map { object in
                brewRecord(
                    object: object,
                    source: .homebrewCask,
                    appsByNormalizedName: appsByNormalizedName,
                    checkedAt: checkedAt
                )
            }
        }

        if includeFormulae, let formulae = root["formulae"] as? [[String: Any]] {
            records += formulae.map { object in
                brewRecord(
                    object: object,
                    source: .homebrewFormula,
                    appsByNormalizedName: appsByNormalizedName,
                    checkedAt: checkedAt
                )
            }
        }

        return records
    }

    private static func brewRecord(
        object: [String: Any],
        source: AppUpdateSource,
        appsByNormalizedName: [String: [MonitoredApp]],
        checkedAt: Date
    ) -> AppUpdateRecord {
        let token = stringValue(object["name"] ?? object["token"]) ?? "unknown"
        let displayName = stringValue(object["full_name"] ?? object["name"] ?? object["token"]) ?? token
        let installedVersions = stringArrayValue(object["installed_versions"] ?? object["installedVersions"])
        let currentVersion = installedVersions.isEmpty ? stringValue(object["installed_version"]) : installedVersions.joined(separator: ", ")
        let availableVersion = stringValue(object["current_version"] ?? object["currentVersion"] ?? object["version"])
        let appNameKey = normalizeName(token.replacingOccurrences(of: "-", with: " "))
        let matchedApp = appsByNormalizedName[appNameKey]?.first
        return AppUpdateRecord(
            appID: matchedApp?.id,
            appName: matchedApp?.name ?? displayName,
            bundleIdentifier: matchedApp?.bundleIdentifier,
            appPath: matchedApp?.path,
            source: source,
            sourceIdentifier: token,
            currentVersion: currentVersion ?? matchedApp?.version,
            availableVersion: availableVersion,
            status: .available,
            checkedAt: checkedAt,
            installActionTitle: "Update with Homebrew",
            installActionURL: "https://formulae.brew.sh/\(source == .homebrewFormula ? "formula" : "cask")/\(token)",
            canInstall: true,
            isAutoEligible: true,
            releaseNotesTitle: "\(displayName) \(availableVersion ?? "update")",
            releaseNotesSummary: "Homebrew reports an update from \(currentVersion ?? "the installed version") to \(availableVersion ?? "the latest version").",
            releaseNotesURL: "https://formulae.brew.sh/\(source == .homebrewFormula ? "formula" : "cask")/\(token)",
            message: source == .homebrewFormula ? "Homebrew formula update available." : "Homebrew cask update available."
        )
    }
}

public struct AppleSoftwareUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .appleSoftwareUpdate
    private let softwareUpdatePath: String
    private let commandRunner: any UpdateCommandRunning
    private let fileManager: FileManager

    public init(
        softwareUpdatePath: String = "/usr/sbin/softwareupdate",
        commandRunner: any UpdateCommandRunning = ProcessUpdateCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.softwareUpdatePath = softwareUpdatePath
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        await Task.detached(priority: .utility) {
            guard isExecutable(at: softwareUpdatePath, fileManager: fileManager) else {
                return [providerUnavailableRecord(source: source, name: "Apple Software Update", message: "softwareupdate is not available.")]
            }
            let result = commandRunner.run(softwareUpdatePath, arguments: ["--list", "--product-types", "macOS,Safari"])
            guard result.exitCode == 0 else {
                return [providerUnavailableRecord(source: source, name: "Apple Software Update", message: result.output)]
            }
            return Self.parseList(output: result.output, checkedAt: Date())
        }.value
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        await Task.detached(priority: .utility) {
            guard mode == .manual else {
                return skippedResult(record: record, runID: runID, message: "Apple software updates are held for manual confirmation.")
            }
            let result = commandRunner.runPrivileged(softwareUpdatePath, arguments: ["--install", record.sourceIdentifier])
            if result.exitCode == 0, record.requiresRestart {
                return UpdateItemResult(
                    runID: runID,
                    updateID: record.id,
                    appID: record.appID,
                    appName: record.appName,
                    source: record.source,
                    sourceIdentifier: record.sourceIdentifier,
                    status: .needsRestart,
                    message: result.output.isEmpty ? "Installed. Restart may be required." : result.output
                )
            }
            return itemResult(record: record, runID: runID, commandResult: result)
        }.value
    }

    public static func parseList(output: String, checkedAt: Date = Date()) -> [AppUpdateRecord] {
        let lines = output.components(separatedBy: .newlines)
        var records: [AppUpdateRecord] = []
        var currentLabel: String?
        var detailLines: [String] = []

        func flush() {
            guard let label = currentLabel else { return }
            let detail = detailLines.joined(separator: " ")
            let title = value(after: "Title:", in: detail, stoppingAt: ",") ?? label
            let version = value(after: "Version:", in: detail, stoppingAt: ",")
            let restart = detail.localizedCaseInsensitiveContains("restart")
            records.append(AppUpdateRecord(
                appID: nil,
                appName: title,
                bundleIdentifier: nil,
                appPath: nil,
                source: .appleSoftwareUpdate,
                sourceIdentifier: label,
                currentVersion: nil,
                availableVersion: version,
                status: restart ? .needsRestart : .needsAdmin,
                checkedAt: checkedAt,
                installActionTitle: "Install Apple Update",
                installActionURL: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension",
                requiresAdmin: true,
                requiresRestart: restart,
                canInstall: true,
                isAutoEligible: false,
                message: restart ? "Requires administrator approval and restart." : "Requires administrator approval."
            ))
            detailLines = []
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("* Label:") {
                flush()
                currentLabel = line.replacingOccurrences(of: "* Label:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentLabel != nil {
                detailLines.append(line)
            }
        }
        flush()

        return records
    }
}

public struct DirectDownloadUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .directDownload
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        var records: [AppUpdateRecord] = []
        for app in apps {
            guard let feedURL = sparkleFeedURL(for: app) else { continue }
            let checkedAt = Date()
            do {
                let latest = try await latestSparkleItem(from: feedURL)
                let hasUpdate = latest.version.map { version in
                    VersionComparator.isVersion(version, newerThan: app.version)
                } ?? false
                guard hasUpdate || latest.version == nil else { continue }
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .directDownload,
                    sourceIdentifier: feedURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: latest.version,
                    status: .manualAction,
                    checkedAt: checkedAt,
                    installActionTitle: "Open Updater",
                    installActionURL: latest.url?.absoluteString ?? feedURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: false,
                    isAutoEligible: false,
                    releaseNotesTitle: latest.title,
                    releaseNotesSummary: latest.summary,
                    releaseNotesURL: latest.releaseNotesURL?.absoluteString,
                    message: "Sparkle update feed detected. Open the app or vendor link to update."
                ))
            } catch {
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .directDownload,
                    sourceIdentifier: feedURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: nil,
                    status: .manualAction,
                    checkedAt: checkedAt,
                    installActionTitle: "Open Updater",
                    installActionURL: feedURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: false,
                    isAutoEligible: false,
                    releaseNotesTitle: "\(app.name) update feed",
                    releaseNotesSummary: "Sparkle feed detected, but App Monitor could not read the latest release notes.",
                    releaseNotesURL: feedURL.absoluteString,
                    message: "Sparkle feed detected, but App Monitor could not read the latest version: \(error.localizedDescription)"
                ))
            }
        }
        return records
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        skippedResult(record: record, runID: runID, message: "Direct-download apps require guided manual updates.")
    }

    private func sparkleFeedURL(for app: MonitoredApp) -> URL? {
        let infoURL = URL(fileURLWithPath: app.path)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
              let value = info["SUFeedURL"] as? String,
              let url = URL(string: value) else {
            return nil
        }
        return url
    }

    private func latestSparkleItem(from url: URL) async throws -> SparkleAppcastItem {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, _) = try await URLSession.shared.data(for: request)
        return try SparkleAppcastParser.latestItem(from: data)
    }
}

public struct MetadataUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .metadata
    private let caskAPIURL: URL
    private let timeout: TimeInterval

    public init(
        caskAPIURL: URL = URL(string: "https://formulae.brew.sh/api/cask.json")!,
        timeout: TimeInterval = 20
    ) {
        self.caskAPIURL = caskAPIURL
        self.timeout = timeout
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        do {
            var request = URLRequest(url: caskAPIURL)
            request.timeoutInterval = timeout
            let (data, _) = try await URLSession.shared.data(for: request)
            return Self.parseCaskMetadata(json: data, apps: apps, checkedAt: Date())
        } catch {
            return [providerUnavailableRecord(
                source: .metadata,
                name: "App Metadata",
                message: "Homebrew Cask metadata could not be loaded: \(error.localizedDescription)"
            )]
        }
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        skippedResult(record: record, runID: runID, message: "Metadata updates require a manual vendor update.")
    }

    public static func parseCaskMetadata(
        json data: Data,
        apps: [MonitoredApp],
        checkedAt: Date = Date(),
        fileManager: FileManager = .default
    ) -> [AppUpdateRecord] {
        guard let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let casksByToken = Dictionary(uniqueKeysWithValues: objects.compactMap { object -> (String, [String: Any])? in
            guard let token = stringValue(object["token"]) else { return nil }
            return (token, object)
        })

        var seenAppIDs: Set<String> = []
        var seenTokens: Set<String> = []
        var records: [AppUpdateRecord] = []

        for app in apps where app.isUserFacing {
            guard seenAppIDs.insert(app.id).inserted else { continue }
            guard !hasExplicitSparkleFeed(app: app, fileManager: fileManager) else { continue }

            for token in caskTokenCandidates(for: app) {
                guard seenTokens.insert(token).inserted,
                      !isHomebrewCaskInstalled(token: token, fileManager: fileManager),
                      let object = casksByToken[token],
                      let record = metadataRecord(object: object, app: app, checkedAt: checkedAt) else {
                    continue
                }
                records.append(record)
                break
            }
        }

        return records
    }

    private static func metadataRecord(
        object: [String: Any],
        app: MonitoredApp,
        checkedAt: Date
    ) -> AppUpdateRecord? {
        guard let token = stringValue(object["token"]) else { return nil }
        guard let rawVersion = stringValue(object["version"]) else { return nil }
        let version = displayVersion(fromCaskVersion: rawVersion)
        guard VersionComparator.isVersion(version, newerThan: app.version) else {
            return nil
        }

        let names = stringArrayValue(object["name"])
        let displayName = names.first ?? app.name
        let homepage = stringValue(object["homepage"])
        let url = stringValue(object["url"]) ?? homepage
        let description = stringValue(object["desc"])
        return AppUpdateRecord(
            appID: app.id,
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            source: .metadata,
            sourceIdentifier: "homebrew-cask:\(token)",
            currentVersion: app.version,
            availableVersion: version,
            status: .manualAction,
            checkedAt: checkedAt,
            installActionTitle: "Open Download",
            installActionURL: url,
            requiresAdmin: false,
            requiresRestart: false,
            canInstall: false,
            isAutoEligible: false,
            releaseNotesTitle: "\(displayName) \(version)",
            releaseNotesSummary: description ?? "Homebrew Cask metadata reports an update from \(app.version ?? "the installed version") to \(version).",
            releaseNotesURL: homepage,
            message: "Metadata reports an update. Open the vendor download to update."
        )
    }

    private static func displayVersion(fromCaskVersion version: String) -> String {
        version
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? version
    }
}

public struct ElectronUpdateProvider: AppUpdateProvider, @unchecked Sendable {
    public let source: AppUpdateSource = .electron
    private let timeout: TimeInterval
    private let fileManager: FileManager

    public init(timeout: TimeInterval = 15, fileManager: FileManager = .default) {
        self.timeout = timeout
        self.fileManager = fileManager
    }

    public func checkUpdates(apps: [MonitoredApp]) async -> [AppUpdateRecord] {
        var records: [AppUpdateRecord] = []
        for app in apps where app.isUserFacing {
            guard let updateURL = electronLatestURL(for: app) else { continue }
            do {
                var request = URLRequest(url: updateURL)
                request.timeoutInterval = timeout
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let item = Self.parseLatestYAML(data: data, baseURL: updateURL.deletingLastPathComponent()),
                      VersionComparator.isVersion(item.version, newerThan: app.version) else {
                    continue
                }
                records.append(AppUpdateRecord(
                    appID: app.id,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.path,
                    source: .electron,
                    sourceIdentifier: updateURL.absoluteString,
                    currentVersion: app.version,
                    availableVersion: item.version,
                    status: .manualAction,
                    checkedAt: Date(),
                    installActionTitle: "Open Download",
                    installActionURL: item.url?.absoluteString ?? updateURL.absoluteString,
                    requiresAdmin: false,
                    requiresRestart: false,
                    canInstall: false,
                    isAutoEligible: false,
                    releaseNotesTitle: "\(app.name) \(item.version)",
                    releaseNotesSummary: item.releaseNotes?.nilIfEmpty ?? "Electron update metadata reports an update.",
                    releaseNotesURL: updateURL.absoluteString,
                    message: "Electron updater metadata reports an update. Open the vendor download to update."
                ))
            } catch {
                continue
            }
        }
        return records
    }

    public func performUpdate(record: AppUpdateRecord, mode: UpdateRunMode, runID: String) async -> UpdateItemResult {
        skippedResult(record: record, runID: runID, message: "Electron metadata updates require a manual vendor update.")
    }

    public static func parseLatestYAML(data: Data, baseURL: URL) -> ElectronLatestItem? {
        guard let text = String(data: data, encoding: .utf8),
              let version = yamlValue("version", in: text) else {
            return nil
        }
        let candidates = yamlURLCandidates(in: text)
        let selected = candidates.first { $0.localizedCaseInsensitiveContains("arm64.dmg") }
            ?? candidates.first { $0.localizedCaseInsensitiveContains(".dmg") }
            ?? candidates.first { $0.localizedCaseInsensitiveContains("arm64.zip") }
            ?? candidates.first
            ?? yamlValue("path", in: text)
        let url = selected.flatMap { electronDownloadURL(value: $0, baseURL: baseURL) }
        return ElectronLatestItem(
            version: version,
            url: url,
            releaseNotes: yamlValue("releaseNotes", in: text)
        )
    }

    private func electronLatestURL(for app: MonitoredApp) -> URL? {
        let configURL = URL(fileURLWithPath: app.path)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("app-update.yml")
        guard fileManager.fileExists(atPath: configURL.path),
              let text = try? String(contentsOf: configURL, encoding: .utf8),
              yamlValue("provider", in: text) == "generic",
              let baseValue = yamlValue("url", in: text),
              !baseValue.localizedCaseInsensitiveContains("electron-vite"),
              let baseURL = URL(string: baseValue) else {
            return nil
        }
        return URL(string: "latest-mac.yml", relativeTo: baseURL)?.absoluteURL
    }
}

public struct ElectronLatestItem: Hashable, Sendable {
    public let version: String
    public let url: URL?
    public let releaseNotes: String?
}

public struct SparkleAppcastItem: Hashable {
    public let version: String?
    public let title: String?
    public let url: URL?
    public let summary: String?
    public let releaseNotesURL: URL?

    public init(version: String?, title: String?, url: URL?, summary: String? = nil, releaseNotesURL: URL? = nil) {
        self.version = version
        self.title = title
        self.url = url
        self.summary = summary
        self.releaseNotesURL = releaseNotesURL
    }
}

public enum SparkleAppcastParser {
    public static func latestItem(from data: Data) throws -> SparkleAppcastItem {
        let delegate = SparkleParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let item = delegate.items.first else {
            throw AppUpdateProviderError.parseFailed
        }
        return item
    }
}

public enum VersionComparator {
    public static func isVersion(_ candidate: String, newerThan current: String?) -> Bool {
        guard let current, !current.isEmpty else { return true }
        let candidateParts = numericParts(candidate)
        let currentParts = numericParts(current)
        if !candidateParts.isEmpty, !currentParts.isEmpty {
            let count = max(candidateParts.count, currentParts.count)
            for index in 0..<count {
                let lhs = index < candidateParts.count ? candidateParts[index] : 0
                let rhs = index < currentParts.count ? currentParts[index] : 0
                if lhs != rhs { return lhs > rhs }
            }
            return false
        }
        return candidate.localizedStandardCompare(current) == .orderedDescending
    }

    private static func numericParts(_ version: String) -> [Int] {
        version
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

public enum AppUpdateProviderError: Error, LocalizedError {
    case parseFailed

    public var errorDescription: String? {
        switch self {
        case .parseFailed:
            return "Could not parse update metadata."
        }
    }
}

private final class SparkleParserDelegate: NSObject, XMLParserDelegate {
    var items: [SparkleAppcastItem] = []
    private var isInsideItem = false
    private var currentElement = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentReleaseNotesURL: URL?
    private var currentVersion: String?
    private var currentURL: URL?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentSummary = ""
            currentReleaseNotesURL = nil
            currentVersion = nil
            currentURL = nil
        }
        guard isInsideItem else { return }
        if elementName == "enclosure" {
            currentVersion = attributeDict["sparkle:shortVersionString"]
                ?? attributeDict["sparkle:version"]
                ?? currentVersion
            currentURL = attributeDict["url"].flatMap(URL.init(string:))
            currentReleaseNotesURL = attributeDict["sparkle:releaseNotesLink"].flatMap(URL.init(string:))
                ?? currentReleaseNotesURL
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "description":
            currentSummary += string
        case "sparkle:shortVersionString", "shortVersionString":
            let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                currentVersion = value
            }
        case "sparkle:version", "version":
            let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, currentVersion == nil {
                currentVersion = value
            }
        case "sparkle:releaseNotesLink", "releaseNotesLink":
            currentReleaseNotesURL = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? currentReleaseNotesURL
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            items.append(SparkleAppcastItem(
                version: currentVersion,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                url: currentURL,
                summary: currentSummary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                releaseNotesURL: currentReleaseNotesURL
            ))
            isInsideItem = false
        }
        currentElement = ""
    }
}

private func isExecutable(at path: String, fileManager: FileManager) -> Bool {
    fileManager.isExecutableFile(atPath: path)
}

private func providerUnavailableRecord(source: AppUpdateSource, name: String, message: String) -> AppUpdateRecord {
    AppUpdateRecord(
        appID: nil,
        appName: name,
        bundleIdentifier: nil,
        appPath: nil,
        source: source,
        sourceIdentifier: "provider-\(source.rawValue)",
        currentVersion: nil,
        availableVersion: nil,
        status: .providerUnavailable,
        installActionTitle: "Open Source",
        canInstall: false,
        isAutoEligible: false,
        message: message
    )
}

private func skippedResult(record: AppUpdateRecord, runID: String, message: String) -> UpdateItemResult {
    UpdateItemResult(
        runID: runID,
        updateID: record.id,
        appID: record.appID,
        appName: record.appName,
        source: record.source,
        sourceIdentifier: record.sourceIdentifier,
        status: .skipped,
        message: message
    )
}

private func itemResult(record: AppUpdateRecord, runID: String, commandResult: ShellCommandResult) -> UpdateItemResult {
    UpdateItemResult(
        runID: runID,
        updateID: record.id,
        appID: record.appID,
        appName: record.appName,
        source: record.source,
        sourceIdentifier: record.sourceIdentifier,
        status: commandResult.exitCode == 0 ? .updated : .failed,
        message: commandResult.output.isEmpty ? nil : commandResult.output
    )
}

private func stringValue(_ value: Any?) -> String? {
    switch value {
    case let value as String:
        return value
    case let value as Int:
        return String(value)
    case let value as Int64:
        return String(value)
    case let value as Double:
        return String(value)
    default:
        return nil
    }
}

private func stringArrayValue(_ value: Any?) -> [String] {
    if let values = value as? [String] {
        return values
    }
    if let values = value as? [Any] {
        return values.compactMap(stringValue)
    }
    return stringValue(value).map { [$0] } ?? []
}

private func jsonObjectList(from output: String) -> [[String: Any]]? {
    for candidate in jsonPayloadCandidates(from: output) {
        guard let data = candidate.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data),
              let objects = objectList(from: root) else {
            continue
        }
        return objects
    }

    let lineObjects = output
        .split(separator: "\n")
        .compactMap { line -> [String: Any]? in
            guard let data = line.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    return lineObjects.isEmpty ? nil : lineObjects
}

private func jsonPayloadCandidates(from output: String) -> [String] {
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var candidates = [trimmed]
    if let start = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }) {
        let closer: Character = trimmed[start] == "{" ? "}" : "]"
        if let end = trimmed.lastIndex(of: closer) {
            let payload = String(trimmed[start...end])
            if payload != trimmed {
                candidates.append(payload)
            }
        }
    }
    return candidates
}

private func objectList(from root: Any) -> [[String: Any]]? {
    if let objects = root as? [[String: Any]] {
        return objects
    }
    guard let object = root as? [String: Any] else {
        return nil
    }
    for key in ["apps", "items", "updates", "outdated"] {
        if let objects = object[key] as? [[String: Any]] {
            return objects
        }
    }
    return [object]
}

private func yamlValue(_ key: String, in text: String) -> String? {
    for rawLine in text.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("\(key):") else { continue }
        let value = String(line.dropFirst(key.count + 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return unquotedYAMLValue(value).nilIfEmpty
    }
    return nil
}

private func yamlURLCandidates(in text: String) -> [String] {
    text.components(separatedBy: .newlines).compactMap { rawLine in
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("- url:") {
            return unquotedYAMLValue(String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if line.hasPrefix("url:") {
            return unquotedYAMLValue(String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

private func electronDownloadURL(value: String, baseURL: URL) -> URL? {
    if let url = URL(string: value, relativeTo: baseURL)?.absoluteURL {
        return url
    }
    let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    return encoded.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
}

private func unquotedYAMLValue(_ value: String) -> String {
    var value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
    } else if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
    }
    return value
}

private func normalizeName(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: ".app", with: "")
        .filter { $0.isLetter || $0.isNumber }
}

private func value(after marker: String, in text: String, stoppingAt stop: Character) -> String? {
    guard let markerRange = text.range(of: marker, options: .caseInsensitive) else { return nil }
    let tail = text[markerRange.upperBound...]
    let value = tail.split(separator: stop, maxSplits: 1, omittingEmptySubsequences: false).first
    return value.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
