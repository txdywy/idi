import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    enum Density: String, CaseIterable, Identifiable {
        case compact = "Compact"
        case balanced = "Balanced"
        case detailed = "Detailed"

        var id: String { rawValue }
    }

    enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case modules = "Modules"

        var id: String { rawValue }
    }

    @Published var refreshInterval: TimeInterval {
        didSet { save() }
    }
    @Published var isPaused = false
    @Published var launchAtLogin: Bool {
        didSet { save() }
    }
    @Published var notificationsEnabled: Bool {
        didSet { save() }
    }
    @Published var density: Density {
        didSet { save() }
    }
    @Published var enabledModules: Set<String> {
        didSet { save() }
    }
    @Published var separateMenuBarModules: Set<String> {
        didSet { save() }
    }
    @Published var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet { save() }
    }
    @Published var cpuWarningThreshold: Double {
        didSet { save() }
    }
    @Published var memoryWarningThreshold: Double {
        didSet { save() }
    }
    @Published var diskWarningThreshold: Double {
        didSet { save() }
    }
    @Published var batteryLowThreshold: Double {
        didSet { save() }
    }
    @Published var sensorHighThreshold: Double {
        didSet { save() }
    }
    @Published var moduleOrder: [String] {
        didSet { save() }
    }

    let refreshIntervals: [TimeInterval] = [1.0, 2.0, 5.0]
    let availableModules = ["CPU", "Memory", "Network", "Disk", "Battery", "GPU", "Sensors", "Weather", "Time", "Apps"]

    private static let defaultEnabledModules = ["CPU", "Memory", "Network", "Disk", "Battery", "GPU", "Sensors", "Time", "Apps"]
    private static let defaultModuleOrder = ["Battery", "CPU", "Memory", "Disk", "Network", "GPU", "Sensors", "Apps", "Time", "Weather"]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 2.0
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        density = Density(rawValue: defaults.string(forKey: Keys.density) ?? "") ?? .balanced
        enabledModules = Set(defaults.stringArray(forKey: Keys.enabledModules) ?? Self.defaultEnabledModules)
        separateMenuBarModules = Set(defaults.stringArray(forKey: Keys.separateMenuBarModules) ?? [])
        menuBarDisplayStyle = MenuBarDisplayStyle(rawValue: defaults.string(forKey: Keys.menuBarDisplayStyle) ?? "") ?? .summary
        cpuWarningThreshold = defaults.object(forKey: Keys.cpuWarningThreshold) as? Double ?? 0.78
        memoryWarningThreshold = defaults.object(forKey: Keys.memoryWarningThreshold) as? Double ?? 0.78
        diskWarningThreshold = defaults.object(forKey: Keys.diskWarningThreshold) as? Double ?? 0.86
        batteryLowThreshold = defaults.object(forKey: Keys.batteryLowThreshold) as? Double ?? 0.2
        sensorHighThreshold = defaults.object(forKey: Keys.sensorHighThreshold) as? Double ?? 0.85
        let restoredOrder = defaults.stringArray(forKey: Keys.moduleOrder) ?? Self.defaultModuleOrder
        moduleOrder = Self.normalizedOrder(restoredOrder, availableModules: Self.defaultModuleOrder)
    }

    func orderedModules(_ modules: [TelemetryModule]) -> [TelemetryModule] {
        modules.sorted { orderedIndex(for: $0.name) < orderedIndex(for: $1.name) }
    }

    func orderedModuleNames(_ modules: some Sequence<String>) -> [String] {
        modules.sorted { orderedIndex(for: $0) < orderedIndex(for: $1) }
    }

    func moveModule(_ module: String, direction: Int) {
        guard let index = moduleOrder.firstIndex(of: module) else { return }
        let nextIndex = max(0, min(moduleOrder.count - 1, index + direction))
        guard nextIndex != index else { return }
        moduleOrder.swapAt(index, nextIndex)
    }

    func orderedIndex(for module: String) -> Int {
        moduleOrder.firstIndex(of: module) ?? Int.max
    }

    func togglePause() {
        isPaused.toggle()
    }

    func toggleModule(_ module: String) {
        if enabledModules.contains(module) {
            enabledModules.remove(module)
            separateMenuBarModules.remove(module)
        } else {
            enabledModules.insert(module)
        }
    }

    func toggleSeparateMenuBarModule(_ module: String) {
        if separateMenuBarModules.contains(module) {
            separateMenuBarModules.remove(module)
        } else {
            separateMenuBarModules.insert(module)
            enabledModules.insert(module)
        }
    }

    private func save() {
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(density.rawValue, forKey: Keys.density)
        defaults.set(Array(enabledModules).sorted(), forKey: Keys.enabledModules)
        defaults.set(Array(separateMenuBarModules).sorted(), forKey: Keys.separateMenuBarModules)
        defaults.set(menuBarDisplayStyle.rawValue, forKey: Keys.menuBarDisplayStyle)
        defaults.set(cpuWarningThreshold, forKey: Keys.cpuWarningThreshold)
        defaults.set(memoryWarningThreshold, forKey: Keys.memoryWarningThreshold)
        defaults.set(diskWarningThreshold, forKey: Keys.diskWarningThreshold)
        defaults.set(batteryLowThreshold, forKey: Keys.batteryLowThreshold)
        defaults.set(sensorHighThreshold, forKey: Keys.sensorHighThreshold)
        defaults.set(Self.normalizedOrder(moduleOrder, availableModules: availableModules), forKey: Keys.moduleOrder)
    }

    private static func normalizedOrder(_ order: [String], availableModules: [String]) -> [String] {
        let known = order.filter { availableModules.contains($0) }
        return known + availableModules.filter { !known.contains($0) }
    }
}

private enum Keys {
    static let refreshInterval = "refreshInterval"
    static let launchAtLogin = "launchAtLogin"
    static let notificationsEnabled = "notificationsEnabled"
    static let density = "density"
    static let enabledModules = "enabledModules"
    static let separateMenuBarModules = "separateMenuBarModules"
    static let menuBarDisplayStyle = "menuBarDisplayStyle"
    static let cpuWarningThreshold = "cpuWarningThreshold"
    static let memoryWarningThreshold = "memoryWarningThreshold"
    static let diskWarningThreshold = "diskWarningThreshold"
    static let batteryLowThreshold = "batteryLowThreshold"
    static let sensorHighThreshold = "sensorHighThreshold"
    static let moduleOrder = "moduleOrder"
}
