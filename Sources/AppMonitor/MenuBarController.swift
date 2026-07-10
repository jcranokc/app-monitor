import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?
    private weak var model: AppModel?
    private var openDashboardAction: (() -> Void)?

    func rebuildStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover?.performClose(nil)
        popover = nil
        hostingController = nil

        if let model, let openDashboardAction {
            configure(model: model, openDashboard: openDashboardAction)
        }
    }

    func configure(model: AppModel, openDashboard: @escaping () -> Void) {
        self.model = model
        openDashboardAction = openDashboard

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                button.image = NSImage(
                    systemSymbolName: "waveform.path.ecg.rectangle",
                    accessibilityDescription: "App Monitor"
                )
                button.image?.isTemplate = true
                button.toolTip = "App Monitor"
            }
            statusItem = item
        }

        updateStatusItemInteraction()
        refreshPopoverContent()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            button.state = .off
            return
        }

        guard let popover = makePopoverIfNeeded() else { return }
        refreshPopoverContent()
        button.state = .on
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.state = .off
    }

    @objc private func openDashboardFromStatusMenu() {
        NSApp.setActivationPolicy(.regular)
        openDashboardAction?()
        DispatchQueue.main.async { [weak self] in
            self?.rebuildStatusItem()
        }
    }

    private func makePopoverIfNeeded() -> NSPopover? {
        if let popover {
            return popover
        }
        guard let model else { return nil }

        let controller = NSHostingController(rootView: rootView(for: model))
        controller.view.frame = NSRect(x: 0, y: 0, width: 542, height: 620)
        controller.view.appearance = model.appearancePreference.nsAppearance

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 542, height: 620)
        popover.contentViewController = controller
        popover.delegate = self

        hostingController = controller
        self.popover = popover
        return popover
    }

    private func refreshPopoverContent() {
        guard let model else { return }
        hostingController?.rootView = rootView(for: model)
        hostingController?.view.appearance = model.appearancePreference.nsAppearance
    }

    private func updateStatusItemInteraction() {
        guard let statusItem, let button = statusItem.button else { return }

        if NSApp.activationPolicy() == .accessory {
            statusItem.menu = nil
            button.action = #selector(openDashboardFromStatusMenu)
            button.target = self
            return
        }

        statusItem.menu = nil
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func rootView(for model: AppModel) -> AnyView {
        AnyView(
            MenuBarPopoverView { [weak self] in
                self?.popover?.performClose(nil)
                self?.statusItem?.button?.state = .off
                self?.openDashboardAction?()
            }
            .environmentObject(model)
            .preferredColorScheme(model.appearancePreference.colorScheme)
        )
    }
}

struct MenuBarInstaller: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear(perform: configure)
            .onChange(of: model.rows.count) {
                configure()
            }
            .onChange(of: model.warningCount) {
                configure()
            }
            .onChange(of: model.potentialSavingsBytes) {
                configure()
            }
            .onChange(of: model.appearancePreference) {
                configure()
            }
    }

    private func configure() {
        MenuBarController.shared.configure(model: model) {
            if !raiseExistingDashboardWindow() {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: appMonitorDashboardWindowID)
                DispatchQueue.main.async {
                    _ = raiseExistingDashboardWindow()
                    MenuBarController.shared.rebuildStatusItem()
                }
            }
        }
    }

    private func raiseExistingDashboardWindow() -> Bool {
        guard let dashboardWindow = NSApp.windows.first(where: { window in
            window.title == "App Monitor" && !(window is NSPanel)
        }) else {
            return false
        }

        NSApp.setActivationPolicy(.regular)
        if dashboardWindow.isMiniaturized {
            dashboardWindow.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            MenuBarController.shared.rebuildStatusItem()
        }
        return true
    }
}
