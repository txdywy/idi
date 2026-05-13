import Foundation

@MainActor
final class TelemetryStore: ObservableObject {
    @Published private(set) var snapshot = TelemetrySnapshot.mock
    @Published private(set) var history: [String: [TelemetryHistorySample]] = [:]

    private var timer: Timer?
    private weak var preferences: PreferencesModel?
    private var collectors = SystemCollectors()
    private let weatherProvider = WeatherProvider()

    func start(preferences: PreferencesModel) {
        self.preferences = preferences
        tick()
        restartTimer()
    }

    func restartTimer() {
        stop()
        guard let preferences, !preferences.isPaused else { return }

        let timer = Timer(timeInterval: preferences.refreshInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer.tolerance = preferences.refreshInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        tick()
    }

    var statusTitle: String {
        guard let cpu = snapshot.modules.first(where: { $0.name == "CPU" }),
              let memory = snapshot.modules.first(where: { $0.name == "Memory" }) else {
            return "idi"
        }
        return "idi  \(cpu.value)  \(memory.value)"
    }

    var visibleModules: [TelemetryModule] {
        guard let preferences else { return snapshot.modules }
        return preferences.orderedModules(snapshot.modules.filter { preferences.enabledModules.contains($0.name) })
    }

    func historySummary(for module: String, window: TimeInterval = 300) -> TelemetryHistorySummary {
        TelemetryHistorySummary(samples: history[module] ?? [], since: Date().addingTimeInterval(-window))
    }

    private func tick() {
        merge(collectedModules: TelemetryModuleMerge.localModules(collectors.collect(), preservingAsyncModulesFrom: snapshot))

        guard preferences?.enabledModules.contains("Weather") == true else { return }

        Task {
            let weather = await weatherProvider.currentModule()
            await MainActor.run {
                merge(collectedModules: [weather], replacingOnly: true)
            }
        }
    }

    private func merge(collectedModules: [TelemetryModule], replacingOnly: Bool = false) {
        let previousModules = Dictionary(uniqueKeysWithValues: snapshot.modules.map { ($0.name, $0) })
        var modules = replacingOnly ? snapshot.modules : collectedModules

        if replacingOnly {
            for module in collectedModules {
                if let index = modules.firstIndex(where: { $0.name == module.name }) {
                    modules[index] = module
                } else {
                    modules.append(module)
                }
            }
        }

        let now = Date()
        let mergedModules = modules.map { module in
            var next = module
            if let previous = previousModules[module.name] {
                next.samples = Array((previous.samples + [module.latestSample]).suffix(36))
            }
            appendHistorySample(module: next, at: now)
            return next
        }
        snapshot = TelemetrySnapshot(
            modules: preferences?.orderedModules(mergedModules) ?? mergedModules,
            updatedAt: now
        )
    }

    private func appendHistorySample(module: TelemetryModule, at date: Date) {
        let next = (history[module.name] ?? []) + [TelemetryHistorySample(date: date, value: module.latestSample, healthState: module.healthState)]
        history[module.name] = Array(next.suffix(240))
    }
}

struct TelemetryHistorySample: Identifiable {
    let id = UUID()
    var date: Date
    var value: Double
    var healthState: HealthState
}

struct TelemetryHistorySummary {
    var samples: [TelemetryHistorySample]
    var since: Date

    var windowSamples: [TelemetryHistorySample] { samples.filter { $0.date >= since } }
    var values: [Double] { windowSamples.map(\.value) }
    var min: Double { values.min() ?? 0 }
    var peak: Double { values.sorted().last ?? 0 }
    var average: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    var latest: Double { values.last ?? 0 }
}
