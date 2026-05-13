import Foundation

@MainActor
final class TelemetryStore: ObservableObject {
    @Published private(set) var snapshot = TelemetrySnapshot.mock

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

        let timer = Timer(timeInterval: preferences.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
        return snapshot.modules.filter { preferences.enabledModules.contains($0.name) }
    }

    private func tick() {
        merge(collectedModules: collectors.collect())

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

        snapshot = TelemetrySnapshot(
            modules: modules.map { module in
                var next = module
                if let previous = previousModules[module.name] {
                    next.samples = Array((previous.samples + [module.latestSample]).suffix(36))
                }
                return next
            },
            updatedAt: Date()
        )
    }
}
