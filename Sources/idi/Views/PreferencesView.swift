import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var preferences: PreferencesModel
    @EnvironmentObject private var telemetryStore: TelemetryStore
    @EnvironmentObject private var loginItemController: LoginItemController

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("idi cockpit safety", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .foregroundStyle(.cyan)
                    Text("The menu-bar cockpit stays local-first: no SMC writes, no fan-control writes, no silent public IP lookup, and Weather fetches only when its module is enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Monitoring") {
                Picker("Refresh interval", selection: $preferences.refreshInterval) {
                    ForEach(preferences.refreshIntervals, id: \.self) { interval in
                        Text("\(Int(interval)) seconds").tag(interval)
                    }
                }
                .onChange(of: preferences.refreshInterval) { _ in
                    telemetryStore.restartTimer()
                }

                Picker("Density", selection: $preferences.density) {
                    ForEach(PreferencesModel.Density.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }

                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                Text(loginItemController.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Warning notifications", isOn: $preferences.notificationsEnabled)
            }

            Section("Menu bar display") {
                Picker("Primary item", selection: $preferences.menuBarDisplayStyle) {
                    ForEach(PreferencesModel.MenuBarDisplayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Text(preferences.menuBarDisplayStyle == .summary ? "Shows the compact idi CPU/memory summary in one menu-bar item." : "Shows enabled modules directly in the primary menu-bar item; separate module items below remain optional.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Alert thresholds") {
                Slider(value: $preferences.cpuWarningThreshold, in: 0.5...0.98, step: 0.01) {
                    Text("CPU warning")
                } minimumValueLabel: {
                    Text("50%")
                } maximumValueLabel: {
                    Text("98%")
                }
                Text("CPU warning at \(Int(preferences.cpuWarningThreshold * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $preferences.memoryWarningThreshold, in: 0.5...0.98, step: 0.01) {
                    Text("Memory warning")
                } minimumValueLabel: {
                    Text("50%")
                } maximumValueLabel: {
                    Text("98%")
                }
                Text("Memory warning at \(Int(preferences.memoryWarningThreshold * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $preferences.diskWarningThreshold, in: 0.5...0.98, step: 0.01) {
                    Text("Disk warning")
                } minimumValueLabel: {
                    Text("50%")
                } maximumValueLabel: {
                    Text("98%")
                }
                Text("Disk warning at \(Int(preferences.diskWarningThreshold * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Popover modules") {
                ForEach(preferences.availableModules, id: \.self) { module in
                    Toggle(module, isOn: Binding(
                        get: { preferences.enabledModules.contains(module) },
                        set: { _ in preferences.toggleModule(module) }
                    ))
                }
            }

            Section("Separate menu bar items") {
                ForEach(preferences.availableModules, id: \.self) { module in
                    Toggle(module, isOn: Binding(
                        get: { preferences.separateMenuBarModules.contains(module) },
                        set: { _ in preferences.toggleSeparateMenuBarModule(module) }
                    ))
                }
            }
        }
        .tint(.cyan)
        .scrollContentBackground(.hidden)
        .background(LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), .cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .padding(22)
        .frame(width: 520, height: 680)
    }
}
