import Foundation
import IOKit

struct SMCCollector {
    func collect(thermalFallback: ProcessInfo.ThermalState) -> TelemetryModule {
        let snapshot = readSnapshot()
        let rows = snapshot.rows.isEmpty
            ? [
                DetailRow(label: "Thermal state", value: thermalFallback.value, group: "Thermal", prominence: .primary),
                DetailRow(label: "AppleSMC", value: snapshot.status, group: "Safety", prominence: .muted)
            ]
            : snapshot.rows

        return TelemetryModule(
            name: "Sensors",
            symbol: "thermometer.medium",
            value: snapshot.primaryValue ?? thermalFallback.value,
            detail: snapshot.status,
            accent: .yellow,
            samples: Array(repeating: snapshot.sample ?? thermalFallback.sample, count: 18),
            healthState: thermalFallback == .critical ? .critical : thermalFallback == .serious ? .warning : .normal,
            detailRows: rows
        )
    }

    private func readSnapshot() -> Snapshot {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            return Snapshot(status: "AppleSMC unavailable", primaryValue: nil, sample: nil, rows: [])
        }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let openResult = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard openResult == KERN_SUCCESS else {
            return Snapshot(status: "AppleSMC open denied", primaryValue: nil, sample: nil, rows: [])
        }
        defer { IOServiceClose(connection) }

        let temperatureKeys: [(String, String)] = [
            ("TC0P", "CPU proximity"), ("TC0E", "CPU efficiency"), ("TC0F", "CPU fan"),
            ("TC0D", "CPU diode"), ("TC0H", "CPU heatsink"), ("TC0T", "CPU package"),
            ("TG0P", "GPU proximity"), ("TG0D", "GPU diode"), ("TG0H", "GPU heatsink"),
            ("TB0T", "Battery"), ("TB1T", "Battery 2"), ("TB2T", "Battery 3"),
            ("TN0D", "Enclosure north"), ("TM0P", "Memory proximity"), ("Ts0P", "Palm rest")
        ]
        let fanKeys: [(String, String)] = [
            ("F0Ac", "Fan 0 actual"), ("F0Mn", "Fan 0 minimum"), ("F0Mx", "Fan 0 maximum"),
            ("F1Ac", "Fan 1 actual"), ("F1Mn", "Fan 1 minimum"), ("F1Mx", "Fan 1 maximum")
        ]
        var rows = [DetailRow(label: "Fan control", value: "Read-only / disabled for safety", group: "Safety", prominence: .primary)]
        var primary: Double?

        for (key, label) in temperatureKeys {
            if let value = readNumeric(key: key, connection: connection) {
                if primary == nil { primary = value }
                rows.append(DetailRow(label: label, value: String(format: "%.1f°C · %@", value, key), group: "Temperatures", prominence: primary == nil ? .primary : .normal))
            }
        }

        for (key, label) in fanKeys {
            if let value = readNumeric(key: key, connection: connection) {
                rows.append(DetailRow(label: label, value: "\(Int(value)) rpm · \(key)", group: "Fans"))
            }
        }

        if rows.count == 1 {
            return Snapshot(status: "AppleSMC keys unsupported", primaryValue: nil, sample: nil, rows: rows)
        }

        let sample = min(max((primary ?? 40) / 100, 0), 1)
        return Snapshot(
            status: "AppleSMC read-only",
            primaryValue: primary.map { String(format: "%.1f°C", $0) },
            sample: sample,
            rows: rows
        )
    }

    private func readNumeric(key: String, connection: io_connect_t) -> Double? {
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = key.smcKey
        input.data8 = SMCCommand.readKeyInfo.rawValue

        guard call(connection: connection, input: &input, output: &output) else { return nil }
        let dataSize = output.keyInfo.dataSize
        let dataType = output.keyInfo.dataType

        input = SMCKeyData()
        input.key = key.smcKey
        input.keyInfo.dataSize = dataSize
        input.keyInfo.dataType = dataType
        input.data8 = SMCCommand.readBytes.rawValue

        guard call(connection: connection, input: &input, output: &output) else { return nil }

        if dataType == "sp78".smcKey {
            let bytes = output.bytes.tuple
            let integer = Int8(bitPattern: bytes.0)
            let fraction = Double(bytes.1) / 256.0
            return Double(integer) + fraction
        }

        if dataType == "fpe2".smcKey {
            let bytes = output.bytes.tuple
            let raw = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            return Double(raw) / 4.0
        }

        return nil
    }

    private func call(connection: io_connect_t, input: inout SMCKeyData, output: inout SMCKeyData) -> Bool {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let result = withUnsafeMutablePointer(to: &input) { inputPointer in
            inputPointer.withMemoryRebound(to: UInt8.self, capacity: inputSize) { inputBytes in
                withUnsafeMutablePointer(to: &output) { outputPointer in
                    outputPointer.withMemoryRebound(to: UInt8.self, capacity: outputSize) { outputBytes in
                        IOConnectCallStructMethod(connection, 2, inputBytes, inputSize, outputBytes, &outputSize)
                    }
                }
            }
        }
        return result == KERN_SUCCESS
    }
}

private struct Snapshot {
    var status: String
    var primaryValue: String?
    var sample: Double?
    var rows: [DetailRow]
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case readKeyInfo = 9
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = SMCBytes()
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCBytes {
    var _0: UInt8 = 0
    var _1: UInt8 = 0
    var _2: UInt8 = 0
    var _3: UInt8 = 0
    var _4: UInt8 = 0
    var _5: UInt8 = 0
    var _6: UInt8 = 0
    var _7: UInt8 = 0
    var _8: UInt8 = 0
    var _9: UInt8 = 0
    var _10: UInt8 = 0
    var _11: UInt8 = 0
    var _12: UInt8 = 0
    var _13: UInt8 = 0
    var _14: UInt8 = 0
    var _15: UInt8 = 0
    var _16: UInt8 = 0
    var _17: UInt8 = 0
    var _18: UInt8 = 0
    var _19: UInt8 = 0
    var _20: UInt8 = 0
    var _21: UInt8 = 0
    var _22: UInt8 = 0
    var _23: UInt8 = 0
    var _24: UInt8 = 0
    var _25: UInt8 = 0
    var _26: UInt8 = 0
    var _27: UInt8 = 0
    var _28: UInt8 = 0
    var _29: UInt8 = 0
    var _30: UInt8 = 0
    var _31: UInt8 = 0

    var tuple: (UInt8, UInt8) { (_0, _1) }
}

private extension String {
    var smcKey: UInt32 {
        utf8.reduce(UInt32(0)) { result, byte in
            (result << 8) + UInt32(byte)
        }
    }
}

private extension ProcessInfo.ThermalState {
    var sample: Double {
        switch self {
        case .nominal: return 0.2
        case .fair: return 0.45
        case .serious: return 0.78
        case .critical: return 0.96
        @unknown default: return 0.5
        }
    }

    var value: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
