import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var preferences: PreferencesModel
    @EnvironmentObject private var telemetryStore: TelemetryStore
    @EnvironmentObject private var loginItemController: LoginItemController
    @State private var selectedSection: PreferenceSection = .monitoring

    private var modulesByDisplayOrder: [String] {
        preferences.orderedModuleNames(preferences.availableModules)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            HStack(spacing: 14) {
                sectionRail
                    .frame(width: 156)
                selectedPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(width: 740, height: 660)
        .background(IdiDesign.background())
        .tint(IdiDesign.cyan)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.title2.weight(.semibold))
                .foregroundStyle(IdiDesign.cyan)
                .frame(width: 46, height: 46)
                .background(IdiDesign.tile(cornerRadius: 15, accent: IdiDesign.cyan, active: true))

            VStack(alignment: .leading, spacing: 3) {
                Text("idi control center")
                    .font(IdiDesign.title(25, weight: .semibold))
                    .foregroundStyle(IdiDesign.ink)
                Text("Telemetry cadence, modules, pinned menu-bar instruments, and safety boundaries")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(IdiDesign.secondaryInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(telemetryStore.snapshot.healthState.rawValue.uppercased())
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(telemetryStore.snapshot.healthState.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(telemetryStore.snapshot.healthState.color.opacity(0.14), in: Capsule())
                Text("updated \(telemetryStore.snapshot.updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(IdiDesign.mono(.caption2))
                    .foregroundStyle(IdiDesign.tertiaryInk)
            }
        }
        .padding(14)
        .background(IdiDesign.panel(cornerRadius: 24))
    }

    private var sectionRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTROL RAIL")
                .font(.system(.caption2, design: .monospaced).weight(.black))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, 8)

            ForEach(PreferenceSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.symbol)
                            .frame(width: 18)
                        Text(section.rawValue)
                            .font(.caption.weight(.bold))
                        Spacer()
                    }
                    .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.68))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(IdiDesign.tile(cornerRadius: 13, accent: IdiDesign.cyan, active: selectedSection == section))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(selectedSection == section ? Color.cyan : .clear)
                            .frame(width: 3)
                            .padding(.vertical, 8)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Label("Local-first", systemImage: "lock.shield")
                    .foregroundStyle(.mint)
                    .font(.caption.weight(.bold))
                Text("No silent public IP lookup. Weather stays opt-in. Sensors stay read-only.")
                    .font(.caption2)
                    .foregroundStyle(IdiDesign.tertiaryInk)
            }
            .padding(10)
            .background(IdiDesign.tile(cornerRadius: 15, accent: .mint))
        }
        .padding(12)
        .background(IdiDesign.panel(cornerRadius: 22))
    }

    @ViewBuilder
    private var selectedPane: some View {
        switch selectedSection {
        case .monitoring:
            monitoringPane
        case .modules:
            modulesPane
        case .menuBar:
            menuBarPane
        case .alerts:
            alertsPane
        case .system:
            systemPane
        }
    }

    private var monitoringPane: some View {
        pane(title: "Monitoring", subtitle: "Sampling cadence and cockpit density") {
            PreferenceRow(title: "Refresh interval", detail: "Controls how often local collectors refresh.") {
                Picker("", selection: $preferences.refreshInterval) {
                    ForEach(preferences.refreshIntervals, id: \.self) { interval in
                        Text("\(Int(interval))s").tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: preferences.refreshInterval) { _ in telemetryStore.restartTimer() }
            }

            PreferenceRow(title: "Cockpit density", detail: "Changes row density across the popover and data tables.") {
                Picker("", selection: $preferences.density) {
                    ForEach(PreferencesModel.Density.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            PreferenceRow(title: "Sampler", detail: preferences.isPaused ? "Collection is paused." : "Collection is live.") {
                Button(preferences.isPaused ? "Resume" : "Pause") {
                    preferences.togglePause()
                    telemetryStore.restartTimer()
                }
                .buttonStyle(.borderedProminent)
            }

            metricStrip([
                ("Modules", "\(telemetryStore.visibleModules.count)"),
                ("Cadence", "\(Int(preferences.refreshInterval))s"),
                ("Rows", preferences.density.rawValue),
                ("Health", telemetryStore.snapshot.healthState.rawValue)
            ])
        }
    }

    private var modulesPane: some View {
        pane(title: "Popover modules", subtitle: "Choose which instruments appear in the cockpit rail") {
            VStack(spacing: 8) {
                ForEach(modulesByDisplayOrder, id: \.self) { module in
                    ModuleOrderRow(
                        module: module,
                        telemetry: telemetryStore.snapshot.modules.first(where: { $0.name == module }),
                        isOn: preferences.enabledModules.contains(module),
                        isFirst: modulesByDisplayOrder.first == module,
                        isLast: modulesByDisplayOrder.last == module,
                        toggle: { preferences.toggleModule(module) },
                        moveUp: { preferences.moveModule(module, direction: -1) },
                        moveDown: { preferences.moveModule(module, direction: 1) }
                    )
                }
            }

            HStack(spacing: 8) {
                Button("Core set") { setModules(["Battery", "CPU", "Memory", "Disk", "Network", "Sensors", "Apps"]) }
                Button("Enable all") { setModules(preferences.availableModules) }
                Button("Local only") { setModules(["Battery", "CPU", "Memory", "Disk", "Network", "GPU", "Sensors", "Time", "Apps"]) }
                Spacer()
            }
            .buttonStyle(.bordered)
        }
    }

    private var menuBarPane: some View {
        pane(title: "Menu bar instruments", subtitle: "Mirror the iStat-style pattern with original pinned status items") {
            PreferenceRow(title: "Primary item", detail: preferences.menuBarDisplayStyle == .summary ? "Two lines: network speed, battery, and weather." : "Two lines: the first four ordered module values.") {
                Picker("", selection: $preferences.menuBarDisplayStyle) {
                    ForEach(PreferencesModel.MenuBarDisplayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            Text("PINNED STATUS ITEMS")
                .font(.system(.caption2, design: .monospaced).weight(.black))
                .foregroundStyle(.cyan.opacity(0.9))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(modulesByDisplayOrder, id: \.self) { module in
                    PinnedTile(
                        module: module,
                        telemetry: telemetryStore.snapshot.modules.first(where: { $0.name == module }),
                        isOn: preferences.separateMenuBarModules.contains(module),
                        toggle: { preferences.toggleSeparateMenuBarModule(module) }
                    )
                }
            }
        }
    }

    private var alertsPane: some View {
        pane(title: "Alert thresholds", subtitle: "Simple global warning rules for core pressure signals") {
            Toggle("Warning notifications", isOn: $preferences.notificationsEnabled)
                .toggleStyle(.switch)
                .foregroundStyle(.white)

            ThresholdControl(title: "CPU high", value: $preferences.cpuWarningThreshold, range: 0.5...0.98, color: .blue)
            ThresholdControl(title: "Memory high", value: $preferences.memoryWarningThreshold, range: 0.5...0.98, color: .purple)
            ThresholdControl(title: "Disk high", value: $preferences.diskWarningThreshold, range: 0.5...0.98, color: .orange)
            ThresholdControl(title: "Battery low", value: $preferences.batteryLowThreshold, range: 0.05...0.5, color: .mint)
            ThresholdControl(title: "Sensor high", value: $preferences.sensorHighThreshold, range: 0.5...1.0, color: .yellow)
            Text("Rules are local thresholds only. idi does not run scripts, request control permissions, or write hardware state.")
                .font(.caption)
                .foregroundStyle(IdiDesign.tertiaryInk)
        }
    }

    private var systemPane: some View {
        pane(title: "System & privacy", subtitle: "Startup behavior and explicit hardware boundaries") {
            PreferenceRow(title: "Launch at login", detail: loginItemController.statusMessage) {
                Toggle("", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 10) {
                SafetyCard(symbol: "fan", title: "Fan safety", detail: "Fan control is read-only/disabled. idi never writes SMC fan values.", color: .yellow)
                SafetyCard(symbol: "network.badge.shield.half.filled", title: "Network privacy", detail: "Private interface data is local. Public IP is not queried silently.", color: .green)
                SafetyCard(symbol: "cloud.sun", title: "Weather opt-in", detail: "Weather contacts Open-Meteo only after the Weather module is enabled.", color: .cyan)
                SafetyCard(symbol: "doc.on.clipboard", title: "Copy Summary", detail: "The cockpit copy command writes only currently visible telemetry to the pasteboard.", color: .mint)
            }
        }
    }

    private func pane<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(IdiDesign.title(23, weight: .semibold))
                        .foregroundStyle(IdiDesign.ink)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(IdiDesign.secondaryInk)
                }
                content()
            }
            .padding(16)
        }
        .background(IdiDesign.panel(cornerRadius: 24))
    }

    private func metricStrip(_ metrics: [(String, String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(metrics, id: \.0) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.0.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.82))
                    Text(metric.1)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(IdiDesign.tile(cornerRadius: 13, accent: IdiDesign.cyan))
            }
        }
    }

    private func setModules(_ modules: [String]) {
        preferences.enabledModules = Set(modules)
        preferences.separateMenuBarModules = preferences.separateMenuBarModules.intersection(preferences.enabledModules)
    }

}

private enum PreferenceSection: String, CaseIterable, Identifiable {
    case monitoring = "Monitoring"
    case modules = "Modules"
    case menuBar = "Menu Bar"
    case alerts = "Alerts"
    case system = "System"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .monitoring: return "speedometer"
        case .modules: return "square.grid.2x2"
        case .menuBar: return "menubar.rectangle"
        case .alerts: return "bell.badge"
        case .system: return "gearshape"
        }
    }
}

private struct PreferenceRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))
            }
            Spacer(minLength: 12)
            control
        }
        .padding(12)
        .background(IdiDesign.tile(cornerRadius: 15))
    }
}

private struct ModuleOrderRow: View {
    let module: String
    let telemetry: TelemetryModule?
    let isOn: Bool
    let isFirst: Bool
    let isLast: Bool
    let toggle: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(action: toggle) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? .mint : .white.opacity(0.34))
            }
            .buttonStyle(.plain)
            Image(systemName: telemetry?.symbol ?? "circle.grid.2x2")
                .foregroundStyle((telemetry?.accent.color ?? .cyan).opacity(isOn ? 1 : 0.5))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(module)
                    .font(.caption.weight(.bold))
                Text(telemetry?.value ?? "standby")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(IdiDesign.tertiaryInk)
            }
            Spacer()
            Button("Up", action: moveUp).disabled(isFirst)
            Button("Down", action: moveDown).disabled(isLast)
        }
        .foregroundStyle(isOn ? .white : .white.opacity(0.58))
        .padding(10)
        .background((telemetry?.accent.color ?? .cyan).opacity(isOn ? 0.13 : 0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PinnedTile: View {
    let module: String
    let telemetry: TelemetryModule?
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(telemetry?.shortCode ?? String(module.prefix(3)).uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.black))
                        .foregroundStyle((telemetry?.accent.color ?? .cyan).opacity(0.9))
                    Spacer()
                    Image(systemName: isOn ? "pin.fill" : "pin")
                        .foregroundStyle(isOn ? .cyan : .white.opacity(0.38))
                }
                Text(module)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(telemetry?.value ?? "not sampled")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(isOn ? 0.085 : 0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isOn ? Color.cyan.opacity(0.28) : .white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ThresholdControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.14), in: Capsule())
            }
            Slider(value: $value, in: range, step: 0.01)
                .tint(color)
        }
        .padding(12)
        .background(IdiDesign.tile(cornerRadius: 15))
    }
}

private struct SafetyCard: View {
    let symbol: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer()
        }
        .padding(12)
        .background(IdiDesign.tile(cornerRadius: 15))
    }
}
