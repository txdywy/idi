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
    let id = UUID()
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
