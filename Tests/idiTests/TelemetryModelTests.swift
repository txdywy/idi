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
    func testWeatherIsOptInByDefault() {
        let suiteName = "idi.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = PreferencesModel(defaults: defaults)
        XCTAssertFalse(preferences.enabledModules.contains("Weather"))
        XCTAssertTrue(preferences.availableModules.contains("Weather"))
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
        XCTAssertTrue(restored.enabledModules.contains("Weather"))
        XCTAssertTrue(restored.separateMenuBarModules.contains("CPU"))
        XCTAssertTrue(restored.enabledModules.contains("CPU"))
    }

    func testModuleLatestSampleFallsBackToZero() {
        let module = TelemetryModule(name: "GPU", symbol: "display", value: "available", detail: "safe", accent: .pink, samples: [], healthState: .normal, detailRows: [])
        XCTAssertEqual(module.latestSample, 0)
    }
}
