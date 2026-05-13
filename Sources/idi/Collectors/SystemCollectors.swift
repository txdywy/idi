import AppKit
import Darwin
import Foundation
import IOKit.ps

struct SystemCollectors {
    private var previousCPU: host_cpu_load_info = host_cpu_load_info()
    private var previousCoreTicks: [CoreTickSample] = []
    private var previousNetwork: NetworkSample?
    private var previousDisk: DiskActivitySample?
    private let gpuCollector = GPUCollector()
    private let smcCollector = SMCCollector()
    private var processHistory = ProcessHistory()

    mutating func collect() -> [TelemetryModule] {
        let cpu = collectCPU()
        let memory = collectMemory()
        let network = collectNetwork()
        let disk = collectDisk()
        let battery = collectBattery()
        let gpu = collectGPU()
        let sensors = collectSensors()
        let weather = collectWeather()
        let time = collectTime()
        let apps = collectApps()
        return [cpu, memory, network, disk, battery, gpu, sensors, weather, time, apps]
    }

    private mutating func collectCPU() -> TelemetryModule {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return TelemetrySnapshot.mock.modules[0]
        }

        let previousTotal = previousCPU.cpu_ticks.0 + previousCPU.cpu_ticks.1 + previousCPU.cpu_ticks.2 + previousCPU.cpu_ticks.3
        let currentTotal = info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3
        let totalDelta = Double(max(currentTotal - previousTotal, 1))
        let idleDelta = Double(info.cpu_ticks.2 - previousCPU.cpu_ticks.2)
        previousCPU = info

        let usage = max(0, min(1, 1 - idleDelta / totalDelta))
        let loads = loadAverages()
        let uptime = ProcessInfo.processInfo.systemUptime
        let coreRows = collectCoreUsageRows()
        let rows = [
            DetailRow(label: "Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount) active", group: "Load", prominence: .primary),
            DetailRow(label: "Thermals", value: ProcessInfo.processInfo.thermalState.value, group: "Thermal", prominence: .primary),
            DetailRow(label: "Load avg", value: String(format: "%.2f  %.2f  %.2f", loads.0, loads.1, loads.2), group: "Load", prominence: .primary),
            DetailRow(label: "Uptime", value: formatDuration(uptime), group: "System")
        ] + coreRows

        return module(
            name: "CPU",
            symbol: "cpu",
            latest: usage,
            value: "\(Int(usage * 100))%",
            detail: ProcessInfo.processInfo.thermalState.label,
            accent: .blue,
            detailRows: rows
        )
    }

    private func collectMemory() -> TelemetryModule {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let physical = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, physical > 0 else {
            return TelemetrySnapshot.mock.modules[1]
        }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let inactive = Double(stats.inactive_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let speculative = Double(stats.speculative_count) * pageSize
        let free = Double(stats.free_count) * pageSize
        let fileCache = inactive + speculative
        let used = active + wired + compressed
        let usage = max(0, min(1, used / physical))
        let usedGB = used / 1_073_741_824
        let totalGB = physical / 1_073_741_824
        let swap = swapUsage()

        return module(
            name: "Memory",
            symbol: "memorychip",
            latest: usage,
            value: String(format: "%.1f / %.0f GB", usedGB, totalGB),
            detail: usage > 0.78 ? "Pressure rising" : "Pressure stable",
            accent: .purple,
            detailRows: [
                DetailRow(label: "Active", value: formatBytes(active, style: .memory), group: "Pressure", prominence: .primary),
                DetailRow(label: "Wired", value: formatBytes(wired, style: .memory), group: "Pressure", prominence: .primary),
                DetailRow(label: "Compressed", value: formatBytes(compressed, style: .memory), group: "Pressure"),
                DetailRow(label: "Inactive", value: formatBytes(inactive, style: .memory), group: "Cache"),
                DetailRow(label: "Speculative", value: formatBytes(speculative, style: .memory), group: "Cache"),
                DetailRow(label: "Free", value: formatBytes(free, style: .memory), group: "Capacity", prominence: .primary),
                DetailRow(label: "File cache", value: formatBytes(fileCache, style: .memory), group: "Cache"),
                DetailRow(label: "Swap", value: swap, group: "Capacity")
            ]
        )
    }

    private mutating func collectNetwork() -> TelemetryModule {
        let sample = NetworkSample.current()
        defer { previousNetwork = sample }

        guard let previousNetwork else {
            let rows = sample.interfaces.map { interface in
                DetailRow(label: interface.name, value: "\(interface.ipv4 ?? "no IPv4") · sampling", group: "Interfaces")
            } + [DetailRow(label: "Connectivity", value: sample.isConnected ? "Local network active" : "No active interface", group: "Privacy", prominence: .primary)]
            return module(name: "Network", symbol: "network", latest: 0.05, value: "warming", detail: "Sampling interfaces", accent: .green, detailRows: rows)
        }

        let elapsed = max(sample.timestamp.timeIntervalSince(previousNetwork.timestamp), 0.1)
        var rows: [DetailRow] = []
        for interface in sample.interfaces {
            let previous = previousNetwork.interfaces.first { $0.name == interface.name }
            let rxRate = Double(interface.receivedBytes >= (previous?.receivedBytes ?? interface.receivedBytes) ? interface.receivedBytes - (previous?.receivedBytes ?? interface.receivedBytes) : 0) / elapsed
            let txRate = Double(interface.sentBytes >= (previous?.sentBytes ?? interface.sentBytes) ? interface.sentBytes - (previous?.sentBytes ?? interface.sentBytes) : 0) / elapsed
            rows.append(DetailRow(label: interface.name, value: "\(interface.ipv4 ?? "no IPv4") · ↓ \(formatBytes(rxRate, style: .file))/s · ↑ \(formatBytes(txRate, style: .file))/s", group: "Interfaces"))
        }

        let receivedDelta = sample.receivedBytes >= previousNetwork.receivedBytes
            ? sample.receivedBytes - previousNetwork.receivedBytes
            : 0
        let sentDelta = sample.sentBytes >= previousNetwork.sentBytes
            ? sample.sentBytes - previousNetwork.sentBytes
            : 0
        let rxRate = Double(receivedDelta) / elapsed
        let txRate = Double(sentDelta) / elapsed
        let totalRate = rxRate + txRate
        let latest = min(totalRate / 125_000_000, 1)
        rows.insert(DetailRow(label: "Aggregate", value: "↓ \(formatBytes(rxRate, style: .file))/s · ↑ \(formatBytes(txRate, style: .file))/s", group: "Throughput", prominence: .primary), at: 0)
        rows.append(DetailRow(label: "Connectivity", value: sample.isConnected ? "Private/local interfaces only" : "Offline or no active IPv4", group: "Privacy", prominence: .primary))
        rows.append(DetailRow(label: "Public IP", value: "Not queried silently", group: "Privacy", prominence: .primary))

        return module(
            name: "Network",
            symbol: "network",
            latest: latest,
            value: formatBytes(totalRate, style: .file) + "/s",
            detail: "↓ \(formatBytes(rxRate, style: .file))/s · ↑ \(formatBytes(txRate, style: .file))/s",
            accent: .green,
            detailRows: rows
        )
    }

    private mutating func collectDisk() -> TelemetryModule {
        let volumes = mountedLocalVolumes()
        let primary = volumes.first
        let available = Double(primary?.available ?? 0)
        let total = Double(primary?.total ?? 0)

        guard total > 0 else {
            return TelemetrySnapshot.mock.modules[3]
        }

        let activity = DiskActivitySample.current()
        let previous = previousDisk
        previousDisk = activity
        let elapsed = previous.map { max(activity.timestamp.timeIntervalSince($0.timestamp), 0.1) } ?? 1
        let readRate = previous.map { Double(activity.readBytes >= $0.readBytes ? activity.readBytes - $0.readBytes : 0) / elapsed } ?? 0
        let writeRate = previous.map { Double(activity.writeBytes >= $0.writeBytes ? activity.writeBytes - $0.writeBytes : 0) / elapsed } ?? 0
        let free = max(0, min(1, available / total))
        let volumeRows = volumes.prefix(4).map { volume in
            DetailRow(label: volume.name, value: "\(formatBytes(Double(volume.available), style: .file)) free of \(formatBytes(Double(volume.total), style: .file))", group: "Volumes")
        }

        return module(
            name: "Disk",
            symbol: "internaldrive",
            latest: 1 - free,
            value: formatBytes(available, style: .file) + " free",
            detail: "\(Int(free * 100))% available on \(primary?.name ?? "startup volume")",
            accent: .orange,
            detailRows: [
                DetailRow(label: "Read activity", value: previous == nil ? "sampling" : "\(formatBytes(readRate, style: .file))/s", group: "Activity", prominence: .primary),
                DetailRow(label: "Write activity", value: previous == nil ? "sampling" : "\(formatBytes(writeRate, style: .file))/s", group: "Activity", prominence: .primary)
            ] + volumeRows + [
                DetailRow(label: "SMART", value: "Requires supported hardware/privileges", group: "Safety", prominence: .muted)
            ]
        )
    }

    private func collectBattery() -> TelemetryModule {
        let adapter = adapterDetails()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return module(
                name: "Battery",
                symbol: "bolt.fill",
                latest: 0.5,
                value: "AC",
                detail: "No internal battery",
                accent: .mint,
                detailRows: [
                    DetailRow(label: "Power source", value: "External", group: "Power", prominence: .primary),
                    DetailRow(label: "Adapter", value: adapter, group: "Power")
                ]
            )
        }

        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = max(description[kIOPSMaxCapacityKey] as? Int ?? 1, 1)
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        let sourceState = description[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
        let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int ?? description[kIOPSTimeToFullChargeKey] as? Int ?? -1
        let percent = Double(current) / Double(max)
        let cycleCount = description["Cycle Count"] as? Int
        let health = (description[kIOPSBatteryHealthKey] as? String) ?? (description[kIOPSBatteryHealthConditionKey] as? String) ?? "Not exposed"

        return module(
            name: "Battery",
            symbol: charging ? "battery.100percent.bolt" : "battery.75percent",
            latest: 1 - percent,
            value: "\(Int(percent * 100))%",
            detail: charging ? "Charging" : sourceState,
            accent: .mint,
            detailRows: [
                DetailRow(label: "Charge", value: "\(current) / \(max)", group: "Battery", prominence: .primary),
                DetailRow(label: "Time remaining", value: formatPowerMinutes(timeRemaining), group: "Battery", prominence: .primary),
                DetailRow(label: "Cycle count", value: cycleCount.map(String.init) ?? "Not exposed", group: "Health"),
                DetailRow(label: "Condition", value: health, group: "Health", prominence: .primary),
                DetailRow(label: "Power source", value: sourceState, group: "Power"),
                DetailRow(label: "Adapter", value: adapter, group: "Power")
            ]
        )
    }

    private func collectGPU() -> TelemetryModule {
        gpuCollector.collect()
    }

    private func collectSensors() -> TelemetryModule {
        smcCollector.collect(thermalFallback: ProcessInfo.processInfo.thermalState)
    }

    private func collectWeather() -> TelemetryModule {
        module(
            name: "Weather",
            symbol: "cloud.sun",
            latest: 0.44,
            value: "offline",
            detail: "Configured location: Shanghai",
            accent: .cyan,
            detailRows: [
                DetailRow(label: "Provider", value: "Open-Meteo", group: "Privacy", prominence: .muted),
                DetailRow(label: "Location", value: "Shanghai (configured)", group: "Weather", prominence: .primary),
                DetailRow(label: "Privacy", value: "No current-location permission", group: "Privacy", prominence: .primary)
            ]
        )
    }

    private func collectTime() -> TelemetryModule {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let now = Date()
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let week = calendar.component(.weekOfYear, from: now)
        return module(
            name: "Time",
            symbol: "clock",
            latest: 0.5,
            value: formatter.string(from: now),
            detail: calendar.timeZone.identifier,
            accent: .blue,
            detailRows: [
                DetailRow(label: "Date", value: now.formatted(date: .complete, time: .omitted), group: "Local", prominence: .primary),
                DetailRow(label: "Week", value: "Week \(week) · day \(dayOfYear)", group: "Local"),
                DetailRow(label: "Time zone", value: calendar.timeZone.abbreviation() ?? "Local", group: "Local", prominence: .primary),
                DetailRow(label: "Shanghai", value: worldClock(identifier: "Asia/Shanghai"), group: "World"),
                DetailRow(label: "London", value: worldClock(identifier: "Europe/London"), group: "World"),
                DetailRow(label: "New York", value: worldClock(identifier: "America/New_York"), group: "World")
            ]
        )
    }

    private mutating func collectApps() -> TelemetryModule {
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let topRows = processHistory.update(with: processSamples())
        let foregroundRows = runningApps.prefix(4).map { app in
            DetailRow(label: "App: \(app.localizedName ?? "App")", value: app.isActive ? "Active" : "Running", group: "Foreground")
        }
        let count = runningApps.count
        return module(
            name: "Apps",
            symbol: "app.dashed",
            latest: min(Double(count) / 24, 1),
            value: "\(count) apps",
            detail: "Top CPU/MEM processes with recent samples",
            accent: .purple,
            detailRows: Array(topRows + foregroundRows)
        )
    }

    private mutating func collectCoreUsageRows() -> [DetailRow] {
        var processorInfo: processor_info_array_t?
        var processorCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &infoCount)
        guard result == KERN_SUCCESS, let processorInfo else { return [DetailRow(label: "Per-core", value: "Unavailable from Mach", group: "Per-core", prominence: .muted)] }
        defer {
            let byteCount = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        let cpuStateCount = Int(CPU_STATE_MAX)
        var rows: [DetailRow] = []
        var nextTicks: [CoreTickSample] = []
        for index in 0..<Int(processorCount) {
            let base = index * cpuStateCount
            let user = UInt32(processorInfo[base + Int(CPU_STATE_USER)])
            let system = UInt32(processorInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(processorInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(processorInfo[base + Int(CPU_STATE_NICE)])
            let tick = CoreTickSample(user: user, system: system, idle: idle, nice: nice)
            nextTicks.append(tick)

            let previous = previousCoreTicks.indices.contains(index) ? previousCoreTicks[index] : tick
            let totalDelta = Double(max(tick.total &- previous.total, 1))
            let idleDelta = Double(tick.idle &- previous.idle)
            let usage = max(0, min(1, 1 - idleDelta / totalDelta))
            rows.append(DetailRow(label: "Core \(index + 1)", value: "\(Int(usage * 100))%", group: "Per-core"))
        }
        previousCoreTicks = nextTicks
        return rows
    }

    private func loadAverages() -> (Double, Double, Double) {
        var values = [Double](repeating: 0, count: 3)
        if getloadavg(&values, 3) == 3 {
            return (values[0], values[1], values[2])
        }
        return (0, 0, 0)
    }

    private func swapUsage() -> String {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return "Unavailable" }
        return "\(formatBytes(Double(usage.xsu_used), style: .memory)) / \(formatBytes(Double(usage.xsu_total), style: .memory))"
    }

    private func mountedLocalVolumes() -> [VolumeSample] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeIsLocalKey, .volumeIsEjectableKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        let volumes = urls.compactMap { url -> VolumeSample? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsLocal == true,
                  values.volumeIsEjectable != true,
                  let total = values.volumeTotalCapacity,
                  total > 0 else { return nil }
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            return VolumeSample(name: values.volumeName ?? url.lastPathComponent, available: Int64(available), total: Int64(total))
        }
        if volumes.isEmpty {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let values = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            if let total = values?.volumeTotalCapacity, total > 0 {
                return [VolumeSample(name: values?.volumeName ?? "Startup", available: Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0), total: Int64(total))]
            }
        }
        return volumes
    }

    private func adapterDetails() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let description = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String? else {
            return "Not exposed"
        }
        return description
    }

    private func worldClock(identifier: String) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = TimeZone(identifier: identifier)
        return formatter.string(from: Date())
    }

    private func processSamples() -> [ProcessSample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid,pcpu,pmem,comm", "-r"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n")
            .dropFirst()
            .prefix(24)
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                guard parts.count == 4,
                      let pid = Int32(parts[0]),
                      let cpu = Double(parts[1]),
                      let memory = Double(parts[2]) else { return nil }
                let command = URL(fileURLWithPath: String(parts[3])).lastPathComponent
                return ProcessSample(pid: pid, name: command, cpu: cpu, memory: memory)
            }
    }

    private func module(name: String, symbol: String, latest: Double, value: String, detail: String, accent: ModuleAccent, detailRows: [DetailRow] = []) -> TelemetryModule {
        TelemetryModule(
            name: name,
            symbol: symbol,
            value: value,
            detail: detail,
            accent: accent,
            samples: Array(repeating: latest, count: 18),
            healthState: healthState(for: name, latest: latest),
            detailRows: detailRows
        )
    }

    private func healthState(for name: String, latest: Double) -> HealthState {
        switch name {
        case "CPU", "Memory":
            if latest > 0.9 { return .critical }
            if latest > 0.78 { return .warning }
            return .normal
        case "Disk":
            if latest > 0.94 { return .critical }
            if latest > 0.86 { return .warning }
            return .normal
        case "Battery":
            if latest > 0.9 { return .critical }
            if latest > 0.8 { return .warning }
            return .normal
        case "Network":
            if latest > 0.92 { return .warning }
            return .normal
        default:
            return .normal
        }
    }
}

private struct ProcessSample {
    var pid: Int32
    var name: String
    var cpu: Double
    var memory: Double
}

private struct ProcessHistory {
    private var samplesByPID: [Int32: [ProcessSample]] = [:]

    mutating func update(with samples: [ProcessSample]) -> [DetailRow] {
        let activePIDs = Set(samples.map(\.pid))
        samplesByPID = samplesByPID.filter { activePIDs.contains($0.key) }

        for sample in samples {
            let history = (samplesByPID[sample.pid] ?? []) + [sample]
            samplesByPID[sample.pid] = Array(history.suffix(12))
        }

        let topCPU = samples.sorted { $0.cpu > $1.cpu }.prefix(6).map { row(for: $0, section: "Top CPU") }
        let topMemory = samples.sorted { $0.memory > $1.memory }.prefix(6).map { row(for: $0, section: "Top MEM") }
        let recent = samples
            .sorted { averageCPU(for: $0) > averageCPU(for: $1) }
            .prefix(4)
            .map { row(for: $0, section: "Recent Avg/Peak") }
        return [
            DetailRow(label: "Table", value: "Fixed views: Top CPU, Top Memory, Recent Average/Peak", group: "Process", prominence: .muted),
            DetailRow(label: "Disk attribution", value: "Not available without elevated/private attribution", group: "Attribution", prominence: .muted),
            DetailRow(label: "Network attribution", value: "Not available without elevated/private attribution", group: "Attribution", prominence: .muted)
        ] + topCPU + topMemory + recent
    }

    private func row(for sample: ProcessSample, section: String) -> DetailRow {
        DetailRow(label: "\(section): \(sample.name)", value: String(format: "PID %d · CPU %.1f%% · MEM %.1f%% · avg %.1f%% · peak %.1f%%", sample.pid, sample.cpu, sample.memory, averageCPU(for: sample), peakCPU(for: sample)), group: section, prominence: section == "Top CPU" ? .primary : .normal)
    }

    private func averageCPU(for sample: ProcessSample) -> Double {
        let history = samplesByPID[sample.pid] ?? [sample]
        return history.map(\.cpu).reduce(0, +) / Double(max(history.count, 1))
    }

    private func peakCPU(for sample: ProcessSample) -> Double {
        let history = samplesByPID[sample.pid] ?? [sample]
        return history.map(\.cpu).max() ?? sample.cpu
    }
}

private struct CoreTickSample {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32

    var total: UInt32 { user &+ system &+ idle &+ nice }
}

private struct VolumeSample {
    var name: String
    var available: Int64
    var total: Int64
}

private struct DiskActivitySample {
    var readBytes: UInt64
    var writeBytes: UInt64
    var timestamp: Date

    static func current() -> DiskActivitySample {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-r", "-c", "IOBlockStorageDriver", "-k", "Statistics"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return DiskActivitySample(readBytes: 0, writeBytes: 0, timestamp: Date())
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return DiskActivitySample(readBytes: 0, writeBytes: 0, timestamp: Date())
        }

        let readBytes = sumIORegistryBytes(named: "Bytes (Read)", in: output)
        let writeBytes = sumIORegistryBytes(named: "Bytes (Write)", in: output)
        return DiskActivitySample(readBytes: readBytes, writeBytes: writeBytes, timestamp: Date())
    }
}

private func sumIORegistryBytes(named key: String, in output: String) -> UInt64 {
    let pattern = "\\\"\(key)\\\" = "
    return output.split(separator: "\n").reduce(UInt64(0)) { total, line in
        guard let range = line.range(of: pattern) else { return total }
        let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return total + (UInt64(suffix) ?? 0)
    }
}

private struct NetworkInterfaceSample {
    var name: String
    var ipv4: String?
    var receivedBytes: UInt64
    var sentBytes: UInt64
    var isUp: Bool
}

private struct NetworkSample {
    var interfaces: [NetworkInterfaceSample]
    var receivedBytes: UInt64
    var sentBytes: UInt64
    var timestamp: Date

    var isConnected: Bool {
        interfaces.contains { $0.isUp && $0.ipv4 != nil }
    }

    static func current() -> NetworkSample {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        var receivedByName: [String: UInt64] = [:]
        var sentByName: [String: UInt64] = [:]
        var ipv4ByName: [String: String] = [:]
        var flagsByName: [String: Int32] = [:]

        if getifaddrs(&addresses) == 0 {
            var pointer = addresses
            while pointer != nil {
                if let interface = pointer?.pointee,
                   let address = interface.ifa_addr {
                    let name = String(cString: interface.ifa_name)
                    flagsByName[name] = Int32(bitPattern: interface.ifa_flags)
                    if address.pointee.sa_family == UInt8(AF_LINK),
                       let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee,
                       !name.hasPrefix("lo") {
                        receivedByName[name] = UInt64(data.ifi_ibytes)
                        sentByName[name] = UInt64(data.ifi_obytes)
                    } else if address.pointee.sa_family == UInt8(AF_INET), !name.hasPrefix("lo") {
                        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        var addr = address.pointee
                        getnameinfo(&addr, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                        let ip = String(cString: host)
                        if ip.isPrivateIPv4 {
                            ipv4ByName[name] = ip
                        }
                    }
                }
                pointer = pointer?.pointee.ifa_next
            }
            freeifaddrs(addresses)
        }

        let names = Set(receivedByName.keys).union(ipv4ByName.keys).sorted()
        let interfaces = names.map { name in
            NetworkInterfaceSample(
                name: name,
                ipv4: ipv4ByName[name],
                receivedBytes: receivedByName[name] ?? 0,
                sentBytes: sentByName[name] ?? 0,
                isUp: (flagsByName[name] ?? 0) & IFF_UP != 0
            )
        }
        return NetworkSample(
            interfaces: interfaces,
            receivedBytes: interfaces.map(\.receivedBytes).reduce(0, +),
            sentBytes: interfaces.map(\.sentBytes).reduce(0, +),
            timestamp: Date()
        )
    }
}

private func formatBytes(_ bytes: Double, style: ByteCountFormatter.CountStyle) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(max(0, bytes)), countStyle: style)
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    let days = totalMinutes / 1_440
    let hours = (totalMinutes % 1_440) / 60
    let minutes = totalMinutes % 60
    if days > 0 { return "\(days)d \(hours)h" }
    if hours > 0 { return "\(hours)h \(minutes)m" }
    return "\(minutes)m"
}

private func formatPowerMinutes(_ minutes: Int) -> String {
    if minutes == -2 { return "Calculating" }
    if minutes < 0 { return "Not exposed" }
    return formatDuration(TimeInterval(minutes * 60))
}

private extension String {
    var isPrivateIPv4: Bool {
        let parts = split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 169 && parts[1] == 254 { return true }
        return false
    }
}

private extension ProcessInfo.ThermalState {
    var value: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }

    var label: String {
        switch self {
        case .nominal:
            return "Thermals nominal"
        case .fair:
            return "Thermals fair"
        case .serious:
            return "Thermals serious"
        case .critical:
            return "Thermals critical"
        @unknown default:
            return "Thermals unknown"
        }
    }
}
