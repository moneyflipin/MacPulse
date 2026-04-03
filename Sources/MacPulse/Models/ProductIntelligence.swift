import Foundation
import SwiftUI

enum InsightSeverity: String, Codable, Sendable {
    case healthy
    case info
    case warning
    case critical

    var title: String {
        switch self {
        case .healthy:
            "Норма"
        case .info:
            "Инфо"
        case .warning:
            "Внимание"
        case .critical:
            "Важно"
        }
    }

    var tint: Color {
        switch self {
        case .healthy:
            .green
        case .info:
            .blue
        case .warning:
            .orange
        case .critical:
            .red
        }
    }

    var systemImage: String {
        switch self {
        case .healthy:
            "checkmark.circle"
        case .info:
            "lightbulb"
        case .warning:
            "exclamationmark.triangle"
        case .critical:
            "flame"
        }
    }
}

struct SmartInsight: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let summary: String
    let severity: InsightSeverity
}

struct BatteryCoachSummary: Sendable {
    let headline: String
    let score: Int
    let severity: InsightSeverity
    let summary: String
    let recommendations: [String]
}

struct AppResourceProfile: Identifiable, Sendable {
    let key: String
    let displayName: String
    let lastSeen: Date
    let sampleCount: Int
    let averageCPU: Double
    let peakCPU: Double
    let peakMemoryBytes: UInt64
    let averageMemoryBytes: UInt64
    let latestPID: Int
    let executablePath: String?
    let isTerminatible: Bool

    var id: String { key }

    var impactScore: Double {
        averageCPU + (peakCPU * 0.45) + (Double(peakMemoryBytes) / 1_073_741_824) * 8
    }
}

enum CleanupHelperKind: String, Sendable {
    case openActivityMonitor
    case activateTopApp
    case terminateTopApp
    case revealTopExecutable
    case exportReport
}

struct CleanupHelper: Identifiable, Sendable {
    let id = UUID()
    let kind: CleanupHelperKind
    let title: String
    let summary: String
    let systemImage: String
    let severity: InsightSeverity
    let targetProcess: ProcessResource?
}

struct SystemEvent: Identifiable, Sendable {
    let timestamp: Date
    let title: String
    let detail: String
    let severity: InsightSeverity
    let systemImage: String

    var id: String {
        "\(timestamp.timeIntervalSince1970)-\(title)"
    }
}

enum ProductIntelligence {
    static func insights(
        snapshot: SystemSnapshot,
        profiles: [AppResourceProfile]
    ) -> [SmartInsight] {
        var items: [SmartInsight] = []

        if snapshot.cpu.usagePercent >= 85 {
            let culprit = snapshot.processes.topCPU.first?.name ?? "неизвестный процесс"
            items.append(
                SmartInsight(
                    title: "CPU под высокой нагрузкой",
                    summary: "Сейчас CPU загружен на \(Formatting.percent(snapshot.cpu.usagePercent)), чаще всего влияет \(culprit).",
                    severity: .critical
                )
            )
        } else if snapshot.cpu.usagePercent >= 55 {
            items.append(
                SmartInsight(
                    title: "CPU заметно занят",
                    summary: "Нагрузка выше обычного, но пока без признаков аварийного поведения.",
                    severity: .warning
                )
            )
        }

        switch snapshot.memory.pressureLevel {
        case .normal:
            break
        case .elevated:
            items.append(
                SmartInsight(
                    title: "Память стала плотнее",
                    summary: "macOS уже активнее использует сжатие. Стоит проверить тяжелые приложения.",
                    severity: .warning
                )
            )
        case .high:
            items.append(
                SmartInsight(
                    title: "Память под давлением",
                    summary: "Сжатая память и swap растут. Самый быстрый выигрыш даст закрытие тяжелых приложений.",
                    severity: .critical
                )
            )
        case .critical:
            items.append(
                SmartInsight(
                    title: "Памяти реально не хватает",
                    summary: "Система упирается в swap, и отклик уже может проседать.",
                    severity: .critical
                )
            )
        }

        if snapshot.thermal.condition == .fair || snapshot.thermal.condition == .serious || snapshot.thermal.condition == .critical {
            items.append(
                SmartInsight(
                    title: "Есть нагрев",
                    summary: "Термальное состояние: \(snapshot.thermal.condition.title). Если это длится, лучше проверить активные процессы.",
                    severity: snapshot.thermal.condition == .fair ? .warning : .critical
                )
            )
        }

        if let battery = snapshot.battery, let wear = battery.wearPercent, wear >= 20 {
            items.append(
                SmartInsight(
                    title: "Батарея требует внимания",
                    summary: "Износ уже около \(Formatting.percent(wear, decimals: 0)). Стоит чаще следить за температурами и циклами.",
                    severity: .warning
                )
            )
        }

        if snapshot.disk.totalBytes > 0, snapshot.disk.freeBytes < 60 * 1_073_741_824 {
            items.append(
                SmartInsight(
                    title: "Мало свободного места",
                    summary: "Осталось \(Formatting.bytes(snapshot.disk.freeBytes)). Это уже может влиять на swap и общее поведение системы.",
                    severity: .warning
                )
            )
        }

        if items.isEmpty {
            let profileHeadline = profiles.first.map { "Самый заметный профиль сейчас: \($0.displayName)." } ?? "Система выглядит сбалансированной."
            items.append(
                SmartInsight(
                    title: "Mac работает спокойно",
                    summary: "\(profileHeadline) Критических отклонений не видно.",
                    severity: .healthy
                )
            )
        }

        return Array(items.prefix(4))
    }

    static func batteryCoach(snapshot: SystemSnapshot, history: [MetricHistoryPoint]) -> BatteryCoachSummary? {
        guard let battery = snapshot.battery else { return nil }

        var score = 100
        var recommendations: [String] = []

        if let wear = battery.wearPercent {
            score -= Int(min(max(wear, 0), 35))
            if wear >= 18 {
                recommendations.append("Батарея уже заметно изношена. Избегай длительного нагрева под зарядкой.")
            }
        }

        if let cycles = battery.cycleCount, cycles >= 700 {
            score -= min(18, max(0, (cycles - 700) / 40))
            recommendations.append("Циклов уже много, поэтому полезно держать терморежим под контролем.")
        }

        if let temperature = battery.temperatureCelsius, temperature >= 35 {
            score -= min(10, Int(temperature - 34))
            recommendations.append("Температура батареи повышена. На тяжелой работе лучше не держать Mac на мягкой поверхности.")
        }

        if battery.isConnectedToPower, battery.percentage >= 95 {
            recommendations.append("Если Mac почти всегда на адаптере, старайся периодически давать батарее рабочий цикл ниже 100%.")
        }

        let trend = batteryTrend(from: history)
        if trend < -8 {
            recommendations.append("Заряд уходит заметно быстрее обычного. Проверь фоновые процессы и температуру.")
        }

        let clampedScore = min(100, max(35, score))
        let severity: InsightSeverity
        switch clampedScore {
        case 85...:
            severity = .healthy
        case 70...84:
            severity = .info
        case 55...69:
            severity = .warning
        default:
            severity = .critical
        }

        if recommendations.isEmpty {
            recommendations = [
                "Сейчас батарея выглядит спокойно. Главный приоритет — избегать постоянного сильного нагрева."
            ]
        }

        return BatteryCoachSummary(
            headline: batteryHeadline(for: clampedScore),
            score: clampedScore,
            severity: severity,
            summary: batterySummary(for: battery, score: clampedScore),
            recommendations: recommendations
        )
    }

    static func cleanupHelpers(
        snapshot: SystemSnapshot,
        profiles: [AppResourceProfile]
    ) -> [CleanupHelper] {
        var items: [CleanupHelper] = [
            CleanupHelper(
                kind: .openActivityMonitor,
                title: "Открыть Мониторинг системы",
                summary: "Самый безопасный способ быстро посмотреть процессы и завершить лишнее вручную.",
                systemImage: "gauge.with.dots.needle.50percent",
                severity: .info,
                targetProcess: nil
            ),
            CleanupHelper(
                kind: .exportReport,
                title: "Экспортировать снимок Mac",
                summary: "Сохранить отчет по текущему состоянию и истории для диагностики.",
                systemImage: "square.and.arrow.up",
                severity: .info,
                targetProcess: nil
            ),
        ]

        if let topProcess = snapshot.processes.topCPU.first {
            items.append(
                CleanupHelper(
                    kind: .activateTopApp,
                    title: "Показать \(topProcess.name)",
                    summary: "Быстро перейти к процессу, который сейчас сильнее всего влияет на систему.",
                    systemImage: "arrow.up.forward.app",
                    severity: .warning,
                    targetProcess: topProcess
                )
            )

            items.append(
                CleanupHelper(
                    kind: .revealTopExecutable,
                    title: "Показать файл процесса",
                    summary: "Открыть исполняемый файл в Finder и проверить, что это за источник нагрузки.",
                    systemImage: "folder",
                    severity: .info,
                    targetProcess: topProcess
                )
            )
        }

        if let terminatable = profiles.first(where: \.isTerminatible) {
            items.append(
                CleanupHelper(
                    kind: .terminateTopApp,
                    title: "Мягко закрыть \(terminatable.displayName)",
                    summary: "Использовать обычное завершение приложения, без принудительного убийства процесса.",
                    systemImage: "xmark.circle",
                    severity: .warning,
                    targetProcess: ProcessResource(
                        pid: terminatable.latestPID,
                        name: terminatable.displayName,
                        cpuPercent: terminatable.averageCPU,
                        memoryBytes: terminatable.peakMemoryBytes,
                        executablePath: terminatable.executablePath
                    )
                )
            )
        }

        return Array(items.prefix(5))
    }

    static func report(
        snapshot: SystemSnapshot,
        configuration: AppConfiguration,
        insights: [SmartInsight],
        profiles: [AppResourceProfile],
        events: [SystemEvent]
    ) -> String {
        let header = """
        MacPulse Report
        Дата: \(snapshot.timestamp.formatted(date: .abbreviated, time: .standard))
        Режим: \(configuration.monitoringProfile.title)
        Интерфейс: \(configuration.experienceMode.title)
        """

        let cpu = "CPU: \(Formatting.percent(snapshot.cpu.usagePercent)) (user \(Formatting.percent(snapshot.cpu.userPercent)), system \(Formatting.percent(snapshot.cpu.systemPercent)))"
        let memory = "Memory: \(Formatting.bytes(snapshot.memory.usedBytes)) / \(Formatting.bytes(snapshot.memory.totalBytes)), swap \(Formatting.bytes(snapshot.memory.swapUsedBytes)), pressure \(snapshot.memory.pressureLevel.title)"
        let disk = "Disk: свободно \(Formatting.bytes(snapshot.disk.freeBytes)) из \(Formatting.bytes(snapshot.disk.totalBytes))"
        let thermal = "Thermal: \(snapshot.thermal.condition.title), основная температура \(snapshot.thermal.primaryTemperatureCelsius.map(Formatting.temperature) ?? "нет")"
        let battery = snapshot.battery.map {
            let cycles = $0.cycleCount.map(String.init) ?? "нет"
            let wear = $0.wearPercent.map { Formatting.percent($0, decimals: 0) } ?? "нет"
            return "Battery: \(Formatting.percent($0.percentage)), \($0.healthState), циклы \(cycles), износ \(wear)"
        } ?? "Battery: нет встроенной батареи"

        let insightsBlock = insights.map { "- [\($0.severity.title)] \($0.title): \($0.summary)" }.joined(separator: "\n")
        let profilesBlock = profiles.prefix(5).map {
            "- \($0.displayName): avg CPU \(Formatting.percent($0.averageCPU, decimals: 1)), peak CPU \(Formatting.percent($0.peakCPU, decimals: 1)), peak RAM \(Formatting.bytes($0.peakMemoryBytes))"
        }.joined(separator: "\n")
        let eventsBlock = events.prefix(8).map {
            "- \($0.timestamp.formatted(date: .omitted, time: .shortened)) [\($0.severity.title)] \($0.title): \($0.detail)"
        }.joined(separator: "\n")

        return [
            header,
            "Система:",
            cpu,
            memory,
            disk,
            thermal,
            battery,
            "",
            "Инсайты:",
            insightsBlock.isEmpty ? "- нет" : insightsBlock,
            "",
            "Профили приложений:",
            profilesBlock.isEmpty ? "- нет" : profilesBlock,
            "",
            "Последние события:",
            eventsBlock.isEmpty ? "- нет" : eventsBlock,
        ].joined(separator: "\n")
    }

    private static func batteryHeadline(for score: Int) -> String {
        switch score {
        case 85...:
            "Батарея выглядит здорово"
        case 70...84:
            "Батарея в норме"
        case 55...69:
            "Есть факторы для контроля"
        default:
            "Батарее нужен более частый контроль"
        }
    }

    private static func batterySummary(for battery: BatteryStats, score: Int) -> String {
        var parts = [
            "Счет здоровья \(score)/100",
            battery.healthState,
        ]

        if let cycles = battery.cycleCount {
            parts.append("\(cycles) циклов")
        }

        if let wear = battery.wearPercent {
            parts.append("износ \(Formatting.percent(wear, decimals: 0))")
        }

        return parts.joined(separator: " • ")
    }

    private static func batteryTrend(from history: [MetricHistoryPoint]) -> Double {
        let values = history.compactMap(\.batteryPercentage)
        guard let first = values.first, let last = values.last else { return 0 }
        return last - first
    }
}
