import Foundation
import Metal

struct GPUCollector {
    func collect() -> TelemetryModule {
        let devices = MTLCopyAllDevices()
        guard let device = devices.first ?? MTLCreateSystemDefaultDevice() else {
            return TelemetryModule(
                name: "GPU",
                symbol: "display",
                value: "unavailable",
                detail: "No Metal device exposed",
                accent: .pink,
                samples: Array(repeating: 0.1, count: 18),
                healthState: .normal,
                detailRows: [
                    DetailRow(label: "Metal", value: "Unavailable", group: "Device", prominence: .muted),
                    DetailRow(label: "Utilization", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
                    DetailRow(label: "Memory used", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
                    DetailRow(label: "Frequency", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
                    DetailRow(label: "Temperature", value: "See Sensors module when SMC exposes it", group: "Public API limits", prominence: .muted),
                    DetailRow(label: "Power", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted)
                ]
            )
        }

        let recommendedMB = device.recommendedMaxWorkingSetSize / 1_048_576
        var rows = [
            DetailRow(label: "Device", value: device.name, group: "Device", prominence: .primary),
            DetailRow(label: "Metal devices", value: devices.map(\.name).joined(separator: ", "), group: "Device"),
            DetailRow(label: "Unified memory", value: device.hasUnifiedMemory ? "Yes" : "No", group: "Memory", prominence: .primary),
            DetailRow(label: "Recommended workset", value: "\(recommendedMB) MB", group: "Memory", prominence: .primary),
            DetailRow(label: "Low power", value: device.isLowPower ? "Yes" : "No", group: "Device"),
            DetailRow(label: "Removable", value: device.isRemovable ? "Yes" : "No", group: "Device"),
            DetailRow(label: "Headless", value: device.isHeadless ? "Yes" : "No", group: "Device"),
            DetailRow(label: "Utilization", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
            DetailRow(label: "Memory used", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
            DetailRow(label: "Frequency", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted),
            DetailRow(label: "Temperature", value: "See Sensors module when SMC exposes it", group: "Public API limits", prominence: .muted),
            DetailRow(label: "Power", value: "Not exposed by public Metal API", group: "Public API limits", prominence: .muted)
        ]
        if #available(macOS 13.0, *) {
            let location: String
            switch device.location {
            case .builtIn:
                location = "Built-in"
            case .slot:
                location = "Slot"
            case .external:
                location = "External"
            case .unspecified:
                location = "Unspecified"
            @unknown default:
                location = "Unknown"
            }
            rows.insert(DetailRow(label: "Location", value: location, group: "Device"), at: 6)
        }

        return TelemetryModule(
            name: "GPU",
            symbol: "display",
            value: device.name,
            detail: "Metal public fields; private counters marked unavailable",
            accent: .pink,
            samples: Array(repeating: device.hasUnifiedMemory ? 0.42 : 0.58, count: 18),
            healthState: .normal,
            detailRows: rows
        )
    }
}
