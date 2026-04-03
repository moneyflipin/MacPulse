import AppKit
import SwiftUI

private struct CompactPopoverMetric: Identifiable {
    let id = UUID()
    let title: String
    let compactTitle: String
    let value: String
    let icon: String
}

struct MenuBarStatusView: View {
    let snapshot: SystemSnapshot
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        MenuBarStatusLineComposer.text(
            snapshot: snapshot,
            configuration: preferences.configuration
        )
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(
            minWidth: MenuBarStatusLineComposer.reservedWidth(for: preferences.configuration),
            alignment: .leading
        )
        .contentTransition(.opacity)
        .id(layoutIdentity)
    }

    private var layoutIdentity: String {
        let segments = MenuBarStatusLineComposer.segments(
            snapshot: snapshot,
            configuration: preferences.configuration
        )
        let hasTemp = snapshot.thermal.primaryTemperatureCelsius != nil ? "temp" : "notemp"
        let hasBattery = snapshot.battery != nil ? "battery" : "nobattery"
        let state = snapshot.health.state.rawValue
        return "\(preferences.configuration.menuBarMode.rawValue)-\(preferences.configuration.menuBarPreset.rawValue)-\(preferences.configuration.menuBarDisplayStyle.rawValue)-\(hasTemp)-\(hasBattery)-\(state)-\(segments.count)"
    }
}

struct MenuBarDashboardView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let openControlCenter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacPulse")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text(monitor.snapshot.health.state == .live ? monitor.snapshot.thermalHeadline : monitor.snapshot.health.state.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(Formatting.timestamp(monitor.snapshot.timestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(popoverMetrics) { metric in
                    popoverMetricCard(metric)
                }
            }

            statusCaption

            if let hottest = monitor.snapshot.hottestSensor {
                HStack(spacing: 8) {
                    Image(systemName: "flame")
                        .foregroundStyle(.orange)

                    Text("Самый горячий датчик: \(hottest.name) \(Formatting.temperature(hottest.valueCelsius))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack {
                Button("Центр управления") {
                    openControlCenter()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Spacer()

                Button {
                    Task {
                        await monitor.refreshNow(forceAll: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.thinMaterial.opacity(0.68))
            }
        )
        .preferredColorScheme(preferences.configuration.appearanceMode.colorScheme)
    }

    private var popoverMetrics: [CompactPopoverMetric] {
        guard !isAwaitingFirstSnapshot else {
            return [
                CompactPopoverMetric(title: "Статус", compactTitle: "Статус", value: "Подключаемся", icon: monitor.snapshot.health.state.symbolName),
                CompactPopoverMetric(title: "Опрос", compactTitle: "Опрос", value: monitor.activeRefreshDescription, icon: "timer"),
            ]
        }

        var metrics = [
            CompactPopoverMetric(title: "CPU", compactTitle: "CPU", value: Formatting.percent(monitor.snapshot.cpu.usagePercent), icon: "cpu"),
            CompactPopoverMetric(title: "Память", compactTitle: "RAM", value: Formatting.percent(monitor.snapshot.memory.usagePercent), icon: "memorychip"),
        ]

        if let temperature = monitor.snapshot.thermal.primaryTemperatureCelsius {
            metrics.append(
                CompactPopoverMetric(title: "Температура", compactTitle: "Темп.", value: Formatting.temperature(temperature), icon: "thermometer.medium")
            )
        }

        if let battery = monitor.snapshot.battery {
            metrics.append(
                CompactPopoverMetric(
                    title: "Батарея",
                    compactTitle: "Бат.",
                    value: Formatting.percent(battery.percentage),
                    icon: battery.isCharging ? "bolt.batteryblock" : "battery.75"
                )
            )
        }

        return Array(metrics.prefix(4))
    }

    private var statusCaption: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.snapshot.health.state.symbolName)
                .foregroundStyle(statusTint)

            Text(monitor.snapshot.summarySentence)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func popoverMetricCard(_ metric: CompactPopoverMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(metric.compactTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(metric.value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .help(metric.title)
        .accessibilityLabel(metric.title)
    }

    private var isAwaitingFirstSnapshot: Bool {
        monitor.snapshot.health.lastSuccessfulUpdate == nil
    }

    private var statusTint: Color {
        switch monitor.snapshot.health.state {
        case .bootstrapping:
            .blue
        case .live:
            .green
        case .degraded:
            .orange
        }
    }
}
