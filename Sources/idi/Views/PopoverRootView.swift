import AppKit
import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject private var telemetryStore: TelemetryStore
    @EnvironmentObject private var preferences: PreferencesModel
    @State private var selectedModuleName = "CPU"
    @State private var copied = false

    let showPreferences: () -> Void
    let togglePause: () -> Void
    let quit: () -> Void

    private var visibleModules: [TelemetryModule] {
        telemetryStore.visibleModules
    }

    private var selectedModule: TelemetryModule? {
        if let selected = visibleModules.first(where: { $0.name == selectedModuleName }) {
            return selected
        }
        return visibleModules.first
    }

    var body: some View {
        VStack(spacing: 9) {
            header
            HStack(spacing: 10) {
                moduleRail
                    .frame(width: 186)
                detailStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            footer
        }
        .padding(12)
        .frame(minWidth: 620, idealWidth: 700, maxWidth: .infinity, minHeight: 420, idealHeight: 480, maxHeight: .infinity)
        .background(IdiDesign.background())
        .onAppear(perform: repairSelection)
        .onChange(of: telemetryStore.visibleModules.map(\.name)) { _ in repairSelection() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(IdiDesign.cyan)
                .frame(width: 38, height: 38)
                .background(IdiDesign.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("idi cockpit")
                    .font(IdiDesign.title(22, weight: .semibold))
                    .foregroundStyle(IdiDesign.ink)
                Text("Private local telemetry")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(IdiDesign.secondaryInk)
            }

            Spacer()

            HStack(spacing: 8) {
                statusPill(title: preferences.isPaused ? "Paused" : telemetryStore.snapshot.healthState.rawValue, color: preferences.isPaused ? .orange : telemetryStore.snapshot.healthState.color)
                statusPill(title: "\(visibleModules.count) online", color: IdiDesign.cyan)
                Text(telemetryStore.snapshot.updatedAt.formatted(date: .omitted, time: .standard))
                    .font(IdiDesign.mono(.caption, weight: .semibold))
                    .foregroundStyle(IdiDesign.secondaryInk)
            }
        }
        .padding(.horizontal, 4)
    }

    private var moduleRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MODULES")
                .font(IdiDesign.mono(.caption2, weight: .bold))
                .foregroundStyle(IdiDesign.tertiaryInk)
                .padding(.horizontal, 8)

            if visibleModules.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No modules visible")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Enable modules in Preferences to rebuild the cockpit rail.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                    Button("Preferences", action: showPreferences)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IdiDesign.panel(cornerRadius: 18))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(visibleModules) { module in
                            Button {
                                selectedModuleName = module.name
                            } label: {
                                RailRow(module: module, isSelected: module.name == selectedModule?.name)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(IdiDesign.panel(cornerRadius: 20))
    }

    @ViewBuilder
    private var detailStage: some View {
        if let module = selectedModule {
            VStack(alignment: .leading, spacing: 8) {
                hero(for: module)
                DenseChart(samples: telemetryStore.historySummary(for: module.name).values.isEmpty ? module.samples : telemetryStore.historySummary(for: module.name).values, color: module.accent.color)
                    .frame(height: module.name == "Apps" ? 76 : 104)
                    .background(LinearGradient(colors: [Color.black.opacity(0.38), module.accent.color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(module.accent.color.opacity(0.28), lineWidth: 1))
                historyTiles(for: module)
                if module.name != "Apps" {
                    summaryTiles(for: module)
                }
                detailRows(for: module)
                    .frame(maxHeight: .infinity)
            }
            .padding(10)
            .background(IdiDesign.heroPanel(cornerRadius: 24))
        } else {
            VStack(spacing: 14) {
                Image(systemName: "switch.2")
                    .font(.largeTitle)
                    .foregroundStyle(.cyan)
                Text("Cockpit offline")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("No telemetry modules are enabled for the popover.")
                    .foregroundStyle(.white.opacity(0.62))
                Button("Open Preferences", action: showPreferences)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IdiDesign.panel(cornerRadius: 24))
        }
    }

    private func hero(for module: TelemetryModule) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: module.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(module.accent.color)
                .frame(width: 50, height: 50)
                .background(module.accent.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(module.name.uppercased())
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(module.accent.color)
                Text(module.value)
                    .font(IdiDesign.title(30, weight: .semibold))
                    .foregroundStyle(IdiDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(module.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(IdiDesign.secondaryInk)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                statusPill(title: module.healthState.rawValue, color: module.healthState.color)
                Text("current \(percent(module.latestSample))")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
    }

    private func historyTiles(for module: TelemetryModule) -> some View {
        let summary = telemetryStore.historySummary(for: module.name)
        return HStack(spacing: 8) {
            MetricTile(title: "5M MIN", value: percent(summary.min), color: module.accent.color)
            MetricTile(title: "5M AVG", value: percent(summary.average), color: module.accent.color)
            MetricTile(title: "5M MAX", value: percent(summary.peak), color: module.accent.color)
            MetricTile(title: "SAMPLES", value: "\(summary.windowSamples.count)", color: module.accent.color)
        }
    }

    private func summaryTiles(for module: TelemetryModule) -> some View {
        HStack(spacing: 8) {
            MetricTile(title: "MIN", value: percent(module.samples.min() ?? 0), color: module.accent.color)
            MetricTile(title: "MAX", value: percent(module.samples.max() ?? 0), color: module.accent.color)
            MetricTile(title: "NOW", value: percent(module.latestSample), color: module.accent.color)
            ForEach(module.summaryRows.prefix(2)) { row in
                MetricTile(title: row.label.uppercased(), value: row.value, color: module.accent.color)
            }
        }
    }

    @ViewBuilder
    private func detailRows(for module: TelemetryModule) -> some View {
        if module.name == "Apps" {
            ProcessTable(rows: module.detailRows)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(module.groupedDetailRows, id: \.0) { group, rows in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(group.uppercased())
                                .font(.system(.caption2, design: .monospaced).weight(.black))
                                .foregroundStyle(module.accent.color.opacity(0.85))
                            ForEach(rows) { row in
                                DetailLine(row: row)
                            }
                        }
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("read-only sensors · local alerts · no silent public IP")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(IdiDesign.tertiaryInk)

            Spacer()

            HStack(spacing: 6) {
                Button("Preferences", action: showPreferences)
                Button("Refresh") { telemetryStore.refreshNow() }
                Button(preferences.isPaused ? "Resume" : "Pause", action: togglePause)
                Button(copied ? "Copied" : "Copy") { copySummary() }
                Button("Quit", action: quit)
                    .keyboardShortcut("q")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(IdiDesign.cyan)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private func repairSelection() {
        guard !visibleModules.contains(where: { $0.name == selectedModuleName }) else { return }
        selectedModuleName = visibleModules.first?.name ?? ""
    }

    private func copySummary() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TelemetrySnapshot(modules: visibleModules, updatedAt: telemetryStore.snapshot.updatedAt).summaryText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            copied = false
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(max(0, min(1, value)) * 100))%"
    }
}

private struct RailRow: View {
    let module: TelemetryModule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(module.healthState.color)
                .frame(width: 6, height: 6)
            Image(systemName: module.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(module.accent.color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(module.shortCode)
                        .font(.system(.caption2, design: .monospaced).weight(.black))
                    Text(module.name)
                        .font(.caption.weight(.semibold))
                }
                Text(module.value)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? .white : .white.opacity(0.76))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(IdiDesign.tile(cornerRadius: 13, accent: module.accent.color, active: isSelected))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? module.accent.color : .clear)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }
}

private struct DenseChart: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)
            ZStack {
                grid(in: proxy.size)
                if points.count > 1 {
                    area(points: points, size: proxy.size)
                        .fill(LinearGradient(colors: [color.opacity(0.28), IdiDesign.cyan.opacity(0.025)], startPoint: .top, endPoint: .bottom))
                    line(points: points)
                        .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                        .blur(radius: 5)
                    line(points: points)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    if let last = points.last {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                            .shadow(color: color.opacity(0.7), radius: 8)
                            .position(last)
                    }
                }
            }
            .padding(10)
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !samples.isEmpty else { return [] }
        let inset: CGFloat = 12
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        let step = samples.count > 1 ? width / CGFloat(samples.count - 1) : 0
        return samples.enumerated().map { index, sample in
            CGPoint(x: inset + CGFloat(index) * step, y: inset + height - CGFloat(max(0, min(1, sample))) * height)
        }
    }

    private func grid(in size: CGSize) -> some View {
        Path { path in
            for row in 0...4 {
                let y = CGFloat(row) * size.height / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            for column in 0...6 {
                let x = CGFloat(column) * size.width / 6
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(Color.white.opacity(0.055), lineWidth: 0.5)
    }

    private func line(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func area(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height - 12))
            path.addLine(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height - 12))
            path.closeSubpath()
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))
                .lineLimit(1)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(IdiDesign.tile(cornerRadius: 13, accent: color))
    }
}

private struct DetailLine: View {
    let row: DetailRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(row.label)
                .foregroundStyle(row.prominence == .muted ? .white.opacity(0.38) : .white.opacity(0.58))
            Spacer(minLength: 8)
            Text(row.value)
                .fontWeight(row.prominence == .primary ? .bold : .medium)
                .foregroundStyle(row.prominence == .muted ? .white.opacity(0.48) : .white.opacity(0.86))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.caption)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Divider().opacity(0.16) }
    }
}

private struct ProcessTable: View {
    let rows: [DetailRow]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack {
                    Text("PROCESS")
                    Spacer()
                    Text("PID / CPU / MEM / AVG / PEAK")
                }
                .font(.system(.caption2, design: .monospaced).weight(.black))
                .foregroundStyle(.purple.opacity(0.9))
                .padding(.vertical, 6)

                ForEach(rows.prefix(24)) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.label)
                            .lineLimit(1)
                            .foregroundStyle(row.prominence == .muted ? .white.opacity(0.5) : .white.opacity(0.82))
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.caption)
                    .padding(.vertical, 5)
                    .overlay(alignment: .bottom) { Divider().opacity(0.15) }
                }
            }
        }
    }
}

extension ModuleAccent {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .mint: return .mint
        case .pink: return .pink
        case .yellow: return .yellow
        case .cyan: return .cyan
        }
    }
}

extension HealthState {
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
