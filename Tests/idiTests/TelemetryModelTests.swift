import XCTest
@testable import idi

final class TelemetryModelTests: XCTestCase {
    func testSnapshotHealthStateUsesWorstModuleState() {
        let snapshot = TelemetrySnapshot(
            modules: [
                TelemetryModule(name: "CPU", symbol: "cpu", value: "20%", detail: "ok", accent: .blue, samples: [0.2], healthState: .normal, detailRows: []),
                TelemetryModule(name: "Memory", symbol: "memorychip", value: "91%", detail: "hot", accent: .purple, samples: [0.91], healthState: .critical, detailRows: [])
            ],
            updatedAt: Date()
        )

        XCTAssertEqual(snapshot.healthState, .critical)
    }

    @MainActor
    func testWeatherIsEnabledByDefault() {
        let suiteName = "idi.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = PreferencesModel(defaults: defaults)
        XCTAssertTrue(preferences.enabledModules.contains("Weather"))
        XCTAssertTrue(preferences.availableModules.contains("Weather"))
    }

    func testSystemCollectorsDoNotPublishWeatherPlaceholder() {
        var collectors = SystemCollectors()
        let modules = collectors.collect()

        XCTAssertFalse(modules.contains { $0.name == "Weather" && $0.value == "offline" })
        XCTAssertFalse(modules.contains { $0.name == "Weather" })
    }

    func testMenuBarSummaryUsesNetworkBatteryAndWeatherLines() {
        let snapshot = TelemetrySnapshot(
            modules: [
                TelemetryModule(name: "Network", symbol: "network", value: "4.2 MB/s", detail: "ok", accent: .green, samples: [0.2], healthState: .normal, detailRows: []),
                TelemetryModule(name: "Battery", symbol: "battery.75percent", value: "82%", detail: "ok", accent: .mint, samples: [0.18], healthState: .normal, detailRows: []),
                TelemetryModule(name: "Weather", symbol: "cloud.sun", value: "offline", detail: "Weather unavailable", accent: .cyan, samples: [0.44], healthState: .normal, detailRows: [])
            ],
            updatedAt: Date()
        )

        let text = MenuBarVitalsText(snapshot: snapshot, weatherEnabled: true)

        XCTAssertEqual(text.statusTitle, "⇅ 4.2 MB/s\n▰ 82%  ☼ --°")
        XCTAssertTrue(text.statusTitle.contains("\n"))
        XCTAssertEqual(text.menuTitle, "⇅ 4.2 MB/s\n▰ 82%  ☼ --°")
    }

    func testMenuBarModuleModeUsesOrderedModuleValues() {
        let modules = [
            TelemetryModule(name: "CPU", symbol: "cpu", value: "21%", detail: "ok", accent: .blue, samples: [0.21], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Memory", symbol: "memorychip", value: "11.4 GB", detail: "ok", accent: .purple, samples: [0.62], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Network", symbol: "network", value: "4.2 MB/s", detail: "ok", accent: .green, samples: [0.2], healthState: .normal, detailRows: []),
            TelemetryModule(name: "Battery", symbol: "battery.75percent", value: "82%", detail: "ok", accent: .mint, samples: [0.18], healthState: .normal, detailRows: [])
        ]
        let text = MenuBarVitalsText(snapshot: TelemetrySnapshot(modules: modules, updatedAt: Date()), weatherEnabled: false)

        XCTAssertEqual(text.moduleLines(orderedModules: [modules[3], modules[0], modules[2], modules[1]]).primary, "BAT 82%  CPU 21%")
        XCTAssertEqual(text.moduleLines(orderedModules: [modules[3], modules[0], modules[2], modules[1]]).secondary, "NET 4.2 MB/s  MEM 11.4 GB")
    }

    func testLocalTelemetryMergePreservesExistingWeather() {
        let previous = TelemetrySnapshot(
            modules: [
                TelemetryModule(name: "Disk", symbol: "internaldrive", value: "401 GB free", detail: "ok", accent: .orange, samples: [0.2], healthState: .normal, detailRows: []),
                TelemetryModule(name: "Weather", symbol: "sun.max", value: "26°C", detail: "Clear", accent: .cyan, samples: [0.72], healthState: .normal, detailRows: [])
            ],
            updatedAt: Date()
        )
        let localModules = [
            TelemetryModule(name: "Disk", symbol: "internaldrive", value: "399 GB free", detail: "ok", accent: .orange, samples: [0.21], healthState: .normal, detailRows: [])
        ]

        let merged = TelemetryModuleMerge.localModules(localModules, preservingAsyncModulesFrom: previous)

        XCTAssertEqual(merged.first { $0.name == "Disk" }?.value, "399 GB free")
        XCTAssertEqual(merged.first { $0.name == "Weather" }?.value, "26°C")
    }

    @MainActor
    func testPreferencesPersistEnabledAndSeparateModules() {
        let suiteName = "idi.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = PreferencesModel(defaults: defaults)
        preferences.refreshInterval = 5.0
        preferences.density = .compact
        preferences.launchAtLogin = true
        preferences.notificationsEnabled = true
        preferences.menuBarDisplayStyle = .modules
        preferences.cpuWarningThreshold = 0.82
        preferences.memoryWarningThreshold = 0.83
        preferences.diskWarningThreshold = 0.9
        preferences.batteryLowThreshold = 0.18
        preferences.sensorHighThreshold = 0.88
        preferences.moveModule("Weather", direction: -1)
        preferences.toggleModule("Weather")
        preferences.toggleSeparateMenuBarModule("CPU")

        let restored = PreferencesModel(defaults: defaults)
        XCTAssertEqual(restored.refreshInterval, 5.0)
        XCTAssertEqual(restored.density, .compact)
        XCTAssertTrue(restored.launchAtLogin)
        XCTAssertTrue(restored.notificationsEnabled)
        XCTAssertEqual(restored.menuBarDisplayStyle, .modules)
        XCTAssertEqual(restored.cpuWarningThreshold, 0.82, accuracy: 0.001)
        XCTAssertEqual(restored.memoryWarningThreshold, 0.83, accuracy: 0.001)
        XCTAssertEqual(restored.diskWarningThreshold, 0.9, accuracy: 0.001)
        XCTAssertEqual(restored.batteryLowThreshold, 0.18, accuracy: 0.001)
        XCTAssertEqual(restored.sensorHighThreshold, 0.88, accuracy: 0.001)
        XCTAssertLessThan(restored.orderedIndex(for: "Weather"), restored.orderedIndex(for: "Time"))
        XCTAssertFalse(restored.enabledModules.contains("Weather"))
        XCTAssertTrue(restored.separateMenuBarModules.contains("CPU"))
        XCTAssertTrue(restored.enabledModules.contains("CPU"))
    }

    func testModuleLatestSampleFallsBackToZero() {
        let module = TelemetryModule(name: "GPU", symbol: "display", value: "available", detail: "safe", accent: .pink, samples: [], healthState: .normal, detailRows: [])
        XCTAssertEqual(module.latestSample, 0)
    }

    func testModuleIDIsStableName() {
        let module = TelemetryModule(name: "CPU", symbol: "cpu", value: "20%", detail: "ok", accent: .blue, samples: [0.2], healthState: .normal, detailRows: [])
        XCTAssertEqual(module.id, "CPU")
    }

    func testTelemetryHistorySummaryUsesWindow() {
        let now = Date()
        let summary = TelemetryHistorySummary(samples: [
            TelemetryHistorySample(date: now.addingTimeInterval(-400), value: 0.1, healthState: .normal),
            TelemetryHistorySample(date: now.addingTimeInterval(-20), value: 0.4, healthState: .normal),
            TelemetryHistorySample(date: now, value: 0.8, healthState: .warning)
        ], since: now.addingTimeInterval(-60))

        XCTAssertEqual(summary.windowSamples.count, 2)
        XCTAssertEqual(summary.min, 0.4, accuracy: 0.001)
        XCTAssertEqual(summary.peak, 0.8, accuracy: 0.001)
        XCTAssertEqual(summary.average, 0.6, accuracy: 0.001)
    }

    @MainActor
    func testBatteryLowThresholdUsesRemainingPercent() {
        let suiteName = "idi.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesModel(defaults: defaults)
        preferences.batteryLowThreshold = 0.2

        let lowBattery = TelemetryModule(name: "Battery", symbol: "battery.25percent", value: "10%", detail: "On battery", accent: .mint, samples: [0.9], healthState: .critical, detailRows: [])
        let healthyBattery = TelemetryModule(name: "Battery", symbol: "battery.75percent", value: "85%", detail: "On battery", accent: .mint, samples: [0.15], healthState: .normal, detailRows: [])

        XCTAssertTrue(NotificationController.exceedsThreshold(module: lowBattery, preferences: preferences))
        XCTAssertFalse(NotificationController.exceedsThreshold(module: healthyBattery, preferences: preferences))
    }

    func testSnapshotSummaryTextIncludesVisibleTelemetry() {
        let snapshot = TelemetrySnapshot(
            modules: [
                TelemetryModule(name: "CPU", symbol: "cpu", value: "20%", detail: "ok", accent: .blue, samples: [0.2], healthState: .normal, detailRows: []),
                TelemetryModule(name: "Network", symbol: "network", value: "4 MB/s", detail: "Private/local interfaces only", accent: .green, samples: [0.1], healthState: .warning, detailRows: [])
            ],
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let summary = snapshot.summaryText
        XCTAssertTrue(summary.contains("idi telemetry summary"))
        XCTAssertTrue(summary.contains("Health: Warning"))
        XCTAssertTrue(summary.contains("CPU CPU: 20% — ok [Normal]"))
        XCTAssertTrue(summary.contains("NET Network: 4 MB/s — Private/local interfaces only [Warning]"))
    }
}
