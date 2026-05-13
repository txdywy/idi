import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusContentView: NSView?
    private var statusTextStack: NSStackView?
    private var statusPrimaryLabel: NSTextField?
    private var statusSecondaryLabel: NSTextField?
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showPopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryStore.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    @objc private func togglePopover(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseDown {
            showQuickMenu(from: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(from: sender)
        }
    }

    private func showPopover(from sender: Any? = nil) {
        guard let button = sender as? NSStatusBarButton ?? statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showQuickMenu(from sender: Any? = nil) {
        guard let button = sender as? NSStatusBarButton ?? statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: MenuBarVitalsText(snapshot: telemetryStore.snapshot, weatherEnabled: preferences.enabledModules.contains("Weather")).menuTitle, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Cockpit", action: #selector(openCockpitFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: preferences.isPaused ? "Resume Sampling" : "Pause Sampling", action: #selector(togglePauseFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNowFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Copy Summary", action: #selector(copySummaryFromMenu), keyEquivalent: "c"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferencesFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit idi", action: #selector(quitFromMenu), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
    }

    @objc private func openCockpitFromMenu() { showPopover() }
    @objc private func togglePauseFromMenu() { togglePause() }
    @objc private func refreshNowFromMenu() { telemetryStore.refreshNow() }
    @objc private func copySummaryFromMenu() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(telemetryStore.snapshot.summaryText, forType: .string)
    }
    @objc private func showPreferencesFromMenu() { showPreferences() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }

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
        item.length = 156
        item.button?.image = nil
        item.button?.title = ""
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        statusItem = item
        configureStatusTextView()
    }

    private func configureStatusTextView() {
        guard let button = statusItem?.button else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView(image: makeStatusIcon())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.symbolConfiguration = .init(pointSize: 13, weight: .medium)

        let primary = statusLabel(size: 9.5, weight: .semibold)
        let secondary = statusLabel(size: 8.5, weight: .medium)
        let stack = NSStackView(views: [primary, secondary])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(icon)
        content.addSubview(stack)
        button.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
            content.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
            content.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            content.heightAnchor.constraint(equalToConstant: 22),
            icon.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            stack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])
        statusContentView = content
        statusTextStack = stack
        statusPrimaryLabel = primary
        statusSecondaryLabel = secondary
    }

    private func statusLabel(size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: size, weight: weight)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = popoverContentSize()
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

    private func popoverContentSize() -> NSSize {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        return NSSize(width: min(700, visibleFrame.width - 72), height: min(480, visibleFrame.height - 180))
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

        preferences.$moduleOrder
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
            item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
            moduleStatusItems[module] = item
        }

        for module in moduleStatusItems.keys where !desired.contains(module) {
            if let item = moduleStatusItems[module] {
                NSStatusBar.system.removeStatusItem(item)
            }
            moduleStatusItems.removeValue(forKey: module)
        }
    }

    private func menuBarVitalsTitle() -> String {
        MenuBarVitalsText(snapshot: telemetryStore.snapshot, weatherEnabled: preferences.enabledModules.contains("Weather")).statusTitle
    }

    private func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let outer = NSBezierPath()
        outer.move(to: NSPoint(x: 9, y: 16))
        outer.line(to: NSPoint(x: 15, y: 12.5))
        outer.line(to: NSPoint(x: 15, y: 5.5))
        outer.line(to: NSPoint(x: 9, y: 2))
        outer.line(to: NSPoint(x: 3, y: 5.5))
        outer.line(to: NSPoint(x: 3, y: 12.5))
        outer.close()
        outer.lineWidth = 1.8
        outer.stroke()

        NSBezierPath(ovalIn: NSRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8)).fill()

        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: 5.2, y: 9))
        pulse.line(to: NSPoint(x: 7.1, y: 9))
        pulse.line(to: NSPoint(x: 8.1, y: 11.6))
        pulse.line(to: NSPoint(x: 10.1, y: 6.2))
        pulse.line(to: NSPoint(x: 11.1, y: 9))
        pulse.line(to: NSPoint(x: 12.8, y: 9))
        pulse.lineWidth = 1.45
        pulse.lineCapStyle = .round
        pulse.lineJoinStyle = .round
        pulse.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func updateStatusItems() {
        syncModuleStatusItems()
        if preferences.isPaused {
            statusPrimaryLabel?.stringValue = "⏸ PAUSED"
            statusSecondaryLabel?.stringValue = "sampling off"
        } else {
            let text = MenuBarVitalsText(snapshot: telemetryStore.snapshot, weatherEnabled: preferences.enabledModules.contains("Weather"))
            if preferences.menuBarDisplayStyle == .modules {
                let lines = text.moduleLines(orderedModules: preferences.orderedModules(telemetryStore.snapshot.modules))
                statusPrimaryLabel?.stringValue = lines.primary
                statusSecondaryLabel?.stringValue = lines.secondary
            } else {
                statusPrimaryLabel?.stringValue = text.primaryLine
                statusSecondaryLabel?.stringValue = text.secondaryLine
            }
        }
        statusItem?.button?.title = ""

        for module in preferences.orderedModules(telemetryStore.snapshot.modules) {
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
