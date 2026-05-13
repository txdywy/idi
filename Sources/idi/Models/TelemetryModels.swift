import Foundation

struct TelemetrySnapshot {
    var modules: [TelemetryModule]
    var updatedAt: Date

    var healthState: HealthState {
        if modules.contains(where: { $0.healthState == .critical }) {
            return .critical
        }
        if modules.contains(where: { $0.healthState == .warning }) {
            return .warning
        }
        return .normal
    }

    var summaryText: String {
        let updated = updatedAt.formatted(date: .abbreviated, time: .standard)
        let rows = modules
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { module in
                "\(module.shortCode) \(module.name): \(module.value) — \(module.detail) [\(module.healthState.rawValue)]"
            }
            .joined(separator: "\n")
        return "idi telemetry summary\nUpdated: \(updated)\nHealth: \(healthState.rawValue)\n\(rows)"
    }

    static let mock = TelemetrySnapshot(
        modules: [
            TelemetryModule(name: "CPU", symbol: "cpu", value: "24%", detail: "8 cores active", accent: .blue, samples: [0.18, 0.23, 0.21, 0.27, 0.24, 0.31, 0.28, 0.24], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Memory", symbol: "memorychip", value: "11.8 GB", detail: "68% used", accent: .purple, samples: [0.61, 0.64, 0.62, 0.67, 0.70, 0.69, 0.68, 0.71], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Network", symbol: "network", value: "42 MB/s", detail: "12 down / 3 up", accent: .green, samples: [0.12, 0.20, 0.18, 0.43, 0.31, 0.52, 0.47, 0.39], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Disk", symbol: "internaldrive", value: "74%", detail: "392 GB free", accent: .orange, samples: [0.72, 0.73, 0.75, 0.74, 0.76, 0.74, 0.73, 0.74], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Battery", symbol: "battery.75percent", value: "81%", detail: "4h 12m remaining", accent: .mint, samples: [0.86, 0.85, 0.84, 0.83, 0.83, 0.82, 0.81, 0.81], healthState: .normal, detailRows: [])
        ],
        updatedAt: Date()
    )
}

struct TelemetryModule: Identifiable {
    var id: String { name }
    var name: String
    var symbol: String
    var value: String
    var detail: String
    var accent: ModuleAccent
    var samples: [Double]
    var healthState: HealthState
    var detailRows: [DetailRow]

    var latestSample: Double {
        samples.last ?? 0
    }
}

struct DetailRow: Identifiable {
    let id = UUID()
    var label: String
    var value: String
    var group: String = "Overview"
    var prominence: DetailRowProminence = .normal
}

enum DetailRowProminence {
    case normal
    case primary
    case muted
}

enum HealthState: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

enum ModuleAccent {
    case blue
    case purple
    case green
    case orange
    case mint
    case pink
    case yellow
    case cyan
}

struct MenuBarVitalsText {
    var snapshot: TelemetrySnapshot
    var weatherEnabled: Bool

    var statusTitle: String {
        "\(primaryLine)\n\(secondaryLine)"
    }

    var menuTitle: String {
        statusTitle
    }

    var primaryLine: String {
        let network = moduleValue("Network") ?? "--/s"
        return "⇅ \(network)"
    }

    var secondaryLine: String {
        let battery = moduleValue("Battery") ?? "--"
        return "▰ \(battery)  ☼ \(weatherValue ?? "--°")"
    }

    func moduleLines(orderedModules: [TelemetryModule]) -> (primary: String, secondary: String) {
        let values = orderedModules.prefix(4).map { "\($0.shortCode) \($0.value)" }
        return (
            values.prefix(2).joined(separator: "  "),
            values.dropFirst(2).prefix(2).joined(separator: "  ")
        )
    }

    private var weatherValue: String? {
        guard weatherEnabled, let value = moduleValue("Weather"), value != "offline" else { return nil }
        return value
    }

    private func moduleValue(_ name: String) -> String? {
        snapshot.modules.first { $0.name == name }?.value
    }
}

struct TelemetryModuleMerge {
    static func localModules(_ modules: [TelemetryModule], preservingAsyncModulesFrom snapshot: TelemetrySnapshot) -> [TelemetryModule] {
        let localNames = Set(modules.map(\.name))
        let asyncModules = snapshot.modules.filter { $0.name == "Weather" && !localNames.contains($0.name) }
        return modules + asyncModules
    }
}

extension TelemetryModule {
    var shortCode: String {
        switch name {
        case "Battery": return "BAT"
        case "CPU": return "CPU"
        case "Memory": return "MEM"
        case "Disk": return "DSK"
        case "Network": return "NET"
        case "GPU": return "GPU"
        case "Sensors": return "SNS"
        case "Apps": return "APP"
        case "Time": return "CLK"
        case "Weather": return "WTH"
        default: return String(name.prefix(3)).uppercased()
        }
    }

    var displayOrder: Int {
        Self.displayOrder(for: name)
    }

    static func displayOrder(for name: String) -> Int {
        switch name {
        case "Battery": return 0
        case "CPU": return 1
        case "Memory": return 2
        case "Disk": return 3
        case "Network": return 4
        case "GPU": return 5
        case "Sensors": return 6
        case "Apps": return 7
        case "Time": return 8
        case "Weather": return 9
        default: return 99
        }
    }

    var summaryRows: [DetailRow] {
        let primary = detailRows.filter { $0.prominence == .primary }
        return Array((primary.isEmpty ? detailRows : primary).prefix(4))
    }

    var groupedDetailRows: [(String, [DetailRow])] {
        let groups = Dictionary(grouping: detailRows, by: { $0.group })
        let order = detailRows.map { $0.group }
        return groups.keys.sorted { lhs, rhs in
            (order.firstIndex(of: lhs) ?? Int.max) < (order.firstIndex(of: rhs) ?? Int.max)
        }.map { ($0, groups[$0] ?? []) }
    }
}
