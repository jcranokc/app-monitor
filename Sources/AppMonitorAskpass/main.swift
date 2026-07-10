import AppKit
import Darwin
import Foundation
import Security

private enum AskpassError: LocalizedError {
    case cancelled
    case emptyPassword
    case invalidKeychainData
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authorization was cancelled."
        case .emptyPassword:
            return "The password cannot be empty."
        case .invalidKeychainData:
            return "The saved Keychain credential is invalid."
        case let .keychain(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Keychain error \(status)."
        }
    }
}

private struct HomebrewCredentialStore {
    private let service: String
    private let account = NSUserName()

    init(service: String = "com.jacob.appmonitor.homebrew-administrator") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }

    func password() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AskpassError.keychain(status) }
        guard let data = item as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.isEmpty else {
            throw AskpassError.invalidKeychainData
        }
        return password
    }

    func save(password: String) throws {
        guard !password.isEmpty else { throw AskpassError.emptyPassword }
        let data = Data(password.utf8)
        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw AskpassError.keychain(updateStatus) }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = "App Monitor Homebrew administrator password"
        item[kSecAttrAccess as String] = try appOnlyAccess()
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw AskpassError.keychain(addStatus) }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AskpassError.keychain(status)
        }
    }

    private func appOnlyAccess() throws -> SecAccess {
        var access: SecAccess?
        let status = SecAccessCreate(
            "App Monitor Homebrew administrator password" as CFString,
            nil,
            &access
        )
        guard status == errSecSuccess, let access else {
            throw AskpassError.keychain(status)
        }
        return access
    }
}

private enum AppMonitorAskpass {
    private static let attemptEnvironmentKey = "APP_MONITOR_ASKPASS_ATTEMPT_ID"
    private static let contextEnvironmentKey = "APP_MONITOR_ASKPASS_CONTEXT"
    private static let markerLifetime: TimeInterval = 15 * 60

    static func run() -> Never {
        do {
            let store = HomebrewCredentialStore()
            switch CommandLine.arguments.dropFirst().first {
            case "--forget":
                try store.delete()
                try? removeAttemptMarkers()
                writeStandardOutput("forgotten\n")
            case "--status":
                writeStandardOutput(try store.password() == nil ? "missing\n" : "stored\n")
            case "--self-test":
                try runKeychainSelfTest()
                writeStandardOutput("passed\n")
            default:
                try providePassword(using: store)
            }
            exit(EXIT_SUCCESS)
        } catch AskpassError.cancelled {
            exit(EXIT_FAILURE)
        } catch {
            writeStandardError("App Monitor could not access its Homebrew credential: \(error.localizedDescription)\n")
            exit(EXIT_FAILURE)
        }
    }

    private static func runKeychainSelfTest() throws {
        let testStore = HomebrewCredentialStore(
            service: "com.jacob.appmonitor.homebrew-administrator.self-test.\(UUID().uuidString)"
        )
        let testValue = UUID().uuidString
        defer { try? testStore.delete() }
        try testStore.save(password: testValue)
        guard try testStore.password() == testValue else {
            throw AskpassError.invalidKeychainData
        }
    }

    private static func providePassword(using store: HomebrewCredentialStore) throws {
        let markerURL = try attemptMarkerURL()
        let isRetry = FileManager.default.fileExists(atPath: markerURL.path)
        if isRetry {
            try store.delete()
        }

        let password: String
        if let saved = try store.password() {
            password = saved
        } else {
            password = try promptForPassword()
            try store.save(password: password)
        }

        try Data().write(to: markerURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: markerURL.path)
        writeStandardOutput("\(password)\n")
    }

    private static func promptForPassword() throws -> String {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let alert = NSAlert()
        alert.messageText = "Administrator password required"
        let context = ProcessInfo.processInfo.environment[contextEnvironmentKey]
            ?? "complete the requested Homebrew changes"
        alert.informativeText = "App Monitor needs your macOS password to \(context). It will be saved in your Mac Keychain and reused for future Homebrew updates."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save and Continue")
        alert.addButton(withTitle: "Cancel")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        passwordField.placeholderString = "macOS password"
        alert.accessoryView = passwordField
        application.activate(ignoringOtherApps: true)

        while true {
            guard alert.runModal() == .alertFirstButtonReturn else {
                throw AskpassError.cancelled
            }
            let password = passwordField.stringValue
            if !password.isEmpty { return password }
            NSSound.beep()
        }
    }

    private static func attemptMarkerURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorAskpassAttempts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try removeExpiredAttemptMarkers(in: directory)

        let rawAttemptID = ProcessInfo.processInfo.environment[attemptEnvironmentKey]
            ?? "sudo-\(getppid())"
        let attemptID = rawAttemptID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return directory.appendingPathComponent(attemptID.isEmpty ? "sudo-\(getppid())" : attemptID)
    }

    private static func removeExpiredAttemptMarkers(in directory: URL) throws {
        let now = Date()
        for marker in try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            let values = try? marker.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modifiedAt = values?.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) > markerLifetime else {
                continue
            }
            try? FileManager.default.removeItem(at: marker)
        }
    }

    private static func removeAttemptMarkers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMonitorAskpassAttempts", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private static func writeStandardOutput(_ value: String) {
        FileHandle.standardOutput.write(Data(value.utf8))
    }

    private static func writeStandardError(_ value: String) {
        FileHandle.standardError.write(Data(value.utf8))
    }
}

AppMonitorAskpass.run()
