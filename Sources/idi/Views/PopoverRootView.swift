import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject private var telemetryStore: TelemetryStore
    @EnvironmentObject private var preferences: PreferencesModel

    let showPreferences: () -> Void
    let togglePause: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(telemetryStore.visibleModules) { module in
                        ModuleCard(module: module, density: preferences.density)
                    }
                }
                .padding(.vertical, 2)
            }

            footer
        }
        .padding(14)
        .frame(width: 420, height: 620)
        .background(background)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.blue.opacity(0.16))
                Image(systemName: "waveform.path.ecg")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("idi")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Text("Compact Mac telemetry")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Updated \(telemetryStore.snapshot.updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(preferences.isPaused ? "Paused" : telemetryStore.snapshot.healthState.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((preferences.isPaused ? Color.orange : telemetryStore.snapshot.healthState.color).opacity(0.18))
                    .foregroundStyle(preferences.isPaused ? Color.orange : telemetryStore.snapshot.healthState.color)
                    .clipShape(Capsule())
                Text("\(telemetryStore.visibleModules.count) modules")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Preferences", action: showPreferences)
            Button(preferences.isPaused ? "Resume" : "Pause", action: togglePause)
            Spacer()
            Button("Quit", action: quit)
                .keyboardShortcut("q")
        }
        .buttonStyle(.bordered)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.black.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ModuleCard: View {
    let module: TelemetryModule
    let density: PreferencesModel.Density

    var body: some View {
        VStack(alignment: .leading, spacing: density == .compact ? 8 : 10) {
            HStack(spacing: 9) {
                Image(systemName: module.symbol)
                    .font(.headline)
                    .foregroundStyle(module.accent.color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(module.name)
                        .font(.headline)
                    Text(module.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(module.value)
                    .font(.system(size: density == .compact ? 18 : 21, weight: .semibold, design: .rounded))
                Circle()
                    .fill(module.healthState.color)
                    .frame(width: 7, height: 7)
            }

            VStack(alignment: .leading, spacing: 5) {
                Sparkline(samples: module.samples, color: module.accent.color)
                    .frame(height: density == .compact ? 24 : 32)
                if density != .compact {
                    legend
                }
            }

            if density != .compact {
                detailPresentation
            }
        }
        .padding(density == .compact ? 11 : 13)
        .frame(maxWidth: .infinity, minHeight: density == .compact ? 104 : 136, alignment: .topLeading)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(module.accent.color.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("Graph")
                .font(.caption2.weight(.bold))
                .foregroundStyle(module.accent.color)
            Text("min \(percent(module.samples.min() ?? 0))")
            Text("max \(percent(module.samples.max() ?? 0))")
            Text("current \(percent(module.latestSample))")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var detailPresentation: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(module.name == "Apps" ? "Process table" : "Detail groups")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(module.accent.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(module.accent.color.opacity(0.12), in: Capsule())
                Text("\(module.detailRows.count) rows")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            if module.name == "Apps" {
                processRows
            } else {
                groupedRows
            }
        }
    }

    private var groupedRows: some View {
        VStack(spacing: 5) {
            ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                if index > 0, index % 4 == 0 {
                    Divider().opacity(0.35)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 10)
                    Text(row.value)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                }
                .font(.caption2)
            }
        }
    }

    private var processRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sort view")
                Spacer()
                Text("PID / CPU / MEM / Avg / Peak")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)

            ForEach(visibleRows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.label)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
                .font(.caption2)
                .padding(.vertical, 3)
                .overlay(alignment: .bottom) { Divider().opacity(0.25) }
            }
        }
    }

    private var visibleRows: [DetailRow] {
        Array(module.detailRows.prefix(density == .detailed ? 22 : 14))
    }

    private func percent(_ value: Double) -> String {
        "\(Int(max(0, min(1, value)) * 100))%"
    }
}

struct Sparkline: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard let first = samples.first else { return }
                let width = proxy.size.width
                let height = proxy.size.height
                let step = samples.count > 1 ? width / CGFloat(samples.count - 1) : 0

                path.move(to: CGPoint(x: 0, y: height - CGFloat(first) * height))
                for index in samples.indices.dropFirst() {
                    let point = CGPoint(
                        x: CGFloat(index) * step,
                        y: height - CGFloat(samples[index]) * height
                    )
                    path.addLine(to: point)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

extension ModuleAccent {
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        case .orange:
            return .orange
        case .mint:
            return .mint
        case .pink:
            return .pink
        case .yellow:
            return .yellow
        case .cyan:
            return .cyan
        }
    }
}

extension HealthState {
    var color: Color {
        switch self {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}
