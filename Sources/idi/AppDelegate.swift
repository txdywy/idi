import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var moduleStatusItems: [String: NSStatusItem] = [:]
    private lazy var popover = NSPopover()
    private lazy var telemetryStore = TelemetryStore()
    private lazy var preferences = PreferencesModel()
    private lazy var loginItemController = LoginItemController()
    private lazy var notificationController = NotificationController()
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        bindState()
        telemetryStore.start(preferences: preferences)
        updateStatusItems()
    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryStore.stop()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = sender as? NSStatusBarButton ?? statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showPreferences() {
        if let preferencesWindow {
            preferencesWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: PreferencesView()
                .environmentObject(preferences)
                .environmentObject(telemetryStore)
                .environmentObject(loginItemController)
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "idi Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func togglePause() {
        preferences.togglePause()
        telemetryStore.restartTimer()
        updateStatusItems()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                showPreferences: { [weak self] in self?.showPreferences() },
                togglePause: { [weak self] in self?.togglePause() },
                quit: { NSApp.terminate(nil) }
            )
            .environmentObject(telemetryStore)
            .environmentObject(preferences)
        )
    }

    private func bindState() {
        telemetryStore.$snapshot
            .sink { [weak self] snapshot in
                guard let self else { return }
                updateStatusItems()
                notificationController.handle(snapshot: snapshot, preferences: preferences)
            }
            .store(in: &cancellables)

        preferences.$enabledModules
            .sink { [weak self] _ in
                self?.updateStatusItems()
            }
            .store(in: &cancellables)

        preferences.$separateMenuBarModules
            .sink { [weak self] _ in
                self?.syncModuleStatusItems()
                self?.updateStatusItems()
            }
            .store(in: &cancellables)

        preferences.$menuBarDisplayStyle
            .sink { [weak self] _ in
                self?.updateStatusItems()
            }
            .store(in: &cancellables)

        preferences.$launchAtLogin
            .sink { [weak self] enabled in
                self?.loginItemController.apply(enabled: enabled)
            }
            .store(in: &cancellables)
    }

    private func syncModuleStatusItems() {
        let desired = preferences.separateMenuBarModules
        for module in desired where moduleStatusItems[module] == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            item.button?.target = self
            item.button?.action = #selector(togglePopover(_:))
            moduleStatusItems[module] = item
        }

        for module in moduleStatusItems.keys where !desired.contains(module) {
            if let item = moduleStatusItems[module] {
                NSStatusBar.system.removeStatusItem(item)
            }
            moduleStatusItems.removeValue(forKey: module)
        }
    }

    private func updateStatusItems() {
        syncModuleStatusItems()
        let statusPrefix = telemetryStore.snapshot.healthState.statusPrefix
        if preferences.isPaused {
            statusItem?.button?.title = "idi paused"
        } else if preferences.menuBarDisplayStyle == .modules {
            let modules = telemetryStore.visibleModules.prefix(3).map { "\($0.shortName) \($0.value)" }.joined(separator: "  ")
            statusItem?.button?.title = modules.isEmpty ? "\(statusPrefix) idi" : "\(statusPrefix) \(modules)"
        } else {
            statusItem?.button?.title = "\(statusPrefix) \(telemetryStore.statusTitle)"
        }

        for module in telemetryStore.snapshot.modules {
            guard let item = moduleStatusItems[module.name] else { continue }
            item.button?.title = "\(module.shortName) \(module.value)"
        }
    }
}

private extension TelemetryModule {
    var shortName: String {
        switch name {
        case "Memory":
            return "MEM"
        case "Network":
            return "NET"
        case "Battery":
            return "BAT"
        default:
            return name.uppercased()
        }
    }
}

private extension HealthState {
    var statusPrefix: String {
        switch self {
        case .normal:
            return "●"
        case .warning:
            return "▲"
        case .critical:
            return "■"
        }
    }
}
