import AppKit
import AppMonitorCore
import SwiftUI

let appMonitorDashboardWindowID = "dashboard"

@main
struct AppMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("App Monitor", id: appMonitorDashboardWindowID) {
            DashboardView()
                .environmentObject(model)
                .preferredColorScheme(model.appearancePreference.colorScheme)
                .background(
                    MenuBarInstaller()
                        .environmentObject(model)
                )
                .background(DashboardWindowLifecycleInstaller())
                .frame(minWidth: 1180, minHeight: 720)
                .task {
                    await model.bootstrap()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.reconcileInstalledAppUpdates()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Inventory") {
                    Task { await model.refreshInventory() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Refresh Storage Scan") {
                    Task { await model.runFullScan() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Check for App Monitor Updates") {
                    Task { await model.checkForAppMonitorUpdate() }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Focus Search") {
                    model.focusSearch()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }

            CommandMenu("Navigate") {
                Button("Overview") { model.navigate(.overview) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("App Updates") { model.showUpdates(filter: .apps) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("All Apps") { model.showAppList(.all) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Warnings") { model.navigate(.warnings) }
                    .keyboardShortcut("4", modifiers: [.command])
                Button("Quarantine Review") { model.navigate(.cleanup) }
                    .keyboardShortcut("5", modifiers: [.command])
                Button("History") { model.navigate(.history) }
                    .keyboardShortcut("6", modifiers: [.command])
                Button("Settings") { model.navigate(.settings) }
                    .keyboardShortcut(",", modifiers: [.command])
                Divider()
                Button(model.isInspectorVisible ? "Hide Details" : "Show Details") {
                    model.isInspectorVisible.toggle()
                    AppAccessibility.announce(model.isInspectorVisible ? "Details shown" : "Details hidden")
                }
                .disabled(!model.hasInspectorContent)
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppAppearanceSettings.applyCurrentPreference()
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppBranding.appIconImage()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .appMonitorWillTerminate, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if AppLifecycleSettings.keepRunningWhenClosed {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                MenuBarController.shared.rebuildStatusItem()
            }
        }
        return false
    }
}

extension Notification.Name {
    static let appMonitorWillTerminate = Notification.Name("AppMonitorWillTerminate")
    static let appMonitorKeepRunningWhenClosedChanged = Notification.Name("AppMonitorKeepRunningWhenClosedChanged")
}
