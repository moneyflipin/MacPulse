import Foundation

enum CaptureState: String, Sendable {
    case bootstrapping
    case live
    case degraded

    var title: String {
        switch self {
        case .bootstrapping:
            "Подключаемся"
        case .live:
            "Данные в норме"
        case .degraded:
            "Есть временный сбой"
        }
    }

    var summary: String {
        switch self {
        case .bootstrapping:
            "Инициализируем системные источники и собираем первые показания."
        case .live:
            "Метрики обновляются штатно и без лишней нагрузки на систему."
        case .degraded:
            "Показываем последние валидные данные, пока один из источников восстанавливается."
        }
    }

    var symbolName: String {
        switch self {
        case .bootstrapping:
            "arrow.triangle.2.circlepath"
        case .live:
            "checkmark.circle"
        case .degraded:
            "exclamationmark.triangle"
        }
    }
}

enum SensorGroup: String, CaseIterable, Identifiable, Sendable {
    case cpuPerformance
    case cpuEfficiency
    case soc
    case gpu
    case battery
    case board
    case power
    case other

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .cpuPerformance:
            7
        case .cpuEfficiency:
            6
        case .soc:
            5
        case .gpu:
            4
        case .battery:
            3
        case .board:
            2
        case .power:
            1
        case .other:
            0
        }
    }

    var title: String {
        switch self {
        case .cpuPerformance:
            "P-ядра CPU"
        case .cpuEfficiency:
            "E-ядра CPU"
        case .soc:
            "SoC"
        case .gpu:
            "GPU"
        case .battery:
            "Батарея"
        case .board:
            "Плата"
        case .power:
            "Питание"
        case .other:
            "Прочее"
        }
    }
}

enum MemoryPressureLevel: String, CaseIterable, Sendable {
    case normal
    case elevated
    case high
    case critical

    var title: String {
        switch self {
        case .normal:
            "Низкое"
        case .elevated:
            "Повышено"
        case .high:
            "Высокое"
        case .critical:
            "Критично"
        }
    }
}

enum ThermalCondition: String, CaseIterable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .nominal:
            "Нормально"
        case .fair:
            "Повышено"
        case .serious:
            "Высокая нагрузка"
        case .critical:
            "Критично"
        case .unknown:
            "Неизвестно"
        }
    }

    var summary: String {
        switch self {
        case .nominal:
            "Система работает стабильно"
        case .fair:
            "Температуры выше обычного"
        case .serious:
            "Есть заметный нагрев и троттлинг возможен"
        case .critical:
            "Нагрузка слишком высокая, стоит снизить ее"
        case .unknown:
            "Термальное состояние не удалось определить"
        }
    }
}

struct SensorReading: Identifiable, Hashable, Sendable {
    let rawName: String
    let name: String
    let valueCelsius: Double
    let group: SensorGroup

    var id: String { rawName }
}

struct CPUStats: Sendable {
    let usagePercent: Double
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
    let coreCount: Int
}

struct MemoryStats: Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let freeBytes: UInt64
    let compressedBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let cachedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
    let pressureLevel: MemoryPressureLevel

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100
    }

    var availableBytes: UInt64 {
        freeBytes + cachedBytes
    }

    var swapUsagePercent: Double {
        guard swapTotalBytes > 0 else { return 0 }
        return (Double(swapUsedBytes) / Double(swapTotalBytes)) * 100
    }
}

struct ProcessResource: Identifiable, Hashable, Sendable {
    let pid: Int
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let executablePath: String?

    var id: Int { pid }
}

struct ProcessSummary: Sendable {
    let topCPU: [ProcessResource]
    let topMemory: [ProcessResource]

    var isEmpty: Bool {
        topCPU.isEmpty && topMemory.isEmpty
    }

    var observed: [ProcessResource] {
        var seen = Set<Int>()
        return (topCPU + topMemory).filter { process in
            seen.insert(process.pid).inserted
        }
    }

    static let empty = ProcessSummary(topCPU: [], topMemory: [])
}

struct DiskStats: Sendable {
    let usedBytes: UInt64
    let freeBytes: UInt64
    let totalBytes: UInt64

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100
    }
}

struct BatteryStats: Sendable {
    let percentage: Double
    let isCharging: Bool
    let isConnectedToPower: Bool
    let cycleCount: Int?
    let healthPercent: Double?
    let wearPercent: Double?
    let timeRemainingMinutes: Int?
    let timeToFullChargeMinutes: Int?
    let timeToEmptyMinutes: Int?
    let temperatureCelsius: Double?
    let powerSourceName: String
    let adapterPowerWatts: Double?
    let powerFlowWatts: Double?

    var healthState: String {
        if let wearPercent, wearPercent > 20 {
            return "Требует внимания"
        }
        if isCharging {
            return "Заряжается"
        }
        return "Нормально"
    }

    var statusTitle: String {
        if isCharging {
            return "Заряжается"
        }
        if isConnectedToPower {
            return percentage >= 99 ? "Полный заряд" : "От адаптера"
        }
        return "От батареи"
    }

    var statusSymbolName: String {
        if isCharging {
            return "bolt.batteryblock"
        }
        if isConnectedToPower {
            return "powerplug"
        }
        return "battery.75"
    }

    var displayPowerWatts: Double? {
        if isConnectedToPower {
            return adapterPowerWatts ?? powerFlowWatts
        }
        return powerFlowWatts
    }

    var powerLabel: String? {
        guard let displayPowerWatts else { return nil }

        if isConnectedToPower, let adapterPowerWatts {
            return "Адаптер \(Formatting.watts(adapterPowerWatts))"
        }

        if isCharging {
            return "Заряд \(Formatting.watts(displayPowerWatts))"
        }

        if isConnectedToPower {
            return "Питание \(Formatting.watts(displayPowerWatts))"
        }

        return "Расход \(Formatting.watts(displayPowerWatts))"
    }

    var compactPowerLabel: String? {
        displayPowerWatts.map { Formatting.watts($0, compact: true) }
    }

    var timeEstimateMinutes: Int? {
        if isCharging {
            return timeToFullChargeMinutes ?? timeRemainingMinutes
        }
        if !isConnectedToPower {
            return timeToEmptyMinutes ?? timeRemainingMinutes
        }
        return timeRemainingMinutes
    }

    var timeEstimateLabel: String? {
        guard let rendered = Formatting.relativeBatteryTime(timeEstimateMinutes) else {
            return nil
        }

        if isCharging {
            return "До полной \(rendered)"
        }

        if !isConnectedToPower {
            return "До разрядки \(rendered)"
        }

        return "Еще \(rendered)"
    }

    var compactIndicatorValue: String {
        var parts = [Formatting.percent(percentage)]

        if let compactPowerLabel {
            parts.append(compactPowerLabel)
        }

        return parts.joined(separator: " ")
    }
}

struct ThermalSummary: Sendable {
    let condition: ThermalCondition
    let lowPowerMode: Bool
    let primaryTemperatureCelsius: Double?
    let sensors: [SensorReading]
}

struct CaptureHealth: Sendable {
    let state: CaptureState
    let lastSuccessfulUpdate: Date?
    let issueSummary: String?
    let usingCachedMetrics: Bool

    var statusLine: String {
        issueSummary ?? state.summary
    }
}

struct SystemSnapshot: Sendable {
    let timestamp: Date
    let cpu: CPUStats
    let memory: MemoryStats
    let disk: DiskStats
    let battery: BatteryStats?
    let thermal: ThermalSummary
    let processes: ProcessSummary
    let health: CaptureHealth

    var hottestSensor: SensorReading? {
        thermal.sensors.max { lhs, rhs in
            lhs.valueCelsius < rhs.valueCelsius
        }
    }

    var thermalHeadline: String {
        switch thermal.condition {
        case .nominal:
            return "Спокойная работа"
        case .fair:
            return "Есть заметный нагрев"
        case .serious:
            return "Система под давлением"
        case .critical:
            return "Нужна передышка"
        case .unknown:
            return "Статус не определен"
        }
    }

    var summarySentence: String {
        switch health.state {
        case .bootstrapping:
            return health.statusLine
        case .degraded:
            return health.statusLine
        case .live:
            break
        }

        if let battery, !battery.isConnectedToPower {
            return "Работает от батареи, важно держать обновление экономным."
        }

        if thermal.lowPowerMode {
            return "Режим энергосбережения включен, приложение снизит частоту обновления."
        }

        return "Макбук на связи: основные метрики обновляются часто, тяжелые опросы реже."
    }

    static let placeholder = SystemSnapshot(
        timestamp: .now,
        cpu: CPUStats(
            usagePercent: 0,
            userPercent: 0,
            systemPercent: 0,
            idlePercent: 100,
            coreCount: ProcessInfo.processInfo.activeProcessorCount
        ),
        memory: MemoryStats(
            usedBytes: 0,
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            freeBytes: ProcessInfo.processInfo.physicalMemory,
            compressedBytes: 0,
            appBytes: 0,
            wiredBytes: 0,
            cachedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0,
            pressureLevel: .normal
        ),
        disk: DiskStats(
            usedBytes: 0,
            freeBytes: 0,
            totalBytes: 0
        ),
        battery: nil,
        thermal: ThermalSummary(
            condition: .nominal,
            lowPowerMode: false,
            primaryTemperatureCelsius: nil,
            sensors: []
        ),
        processes: .empty,
        health: CaptureHealth(
            state: .bootstrapping,
            lastSuccessfulUpdate: nil,
            issueSummary: nil,
            usingCachedMetrics: false
        )
    )
}

struct MetricHistoryPoint: Identifiable, Sendable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let swapUsage: Double
    let primaryTemperature: Double?
    let batteryPercentage: Double?
    let memoryPressure: MemoryPressureLevel

    var id: Date { timestamp }

    init(snapshot: SystemSnapshot) {
        timestamp = snapshot.timestamp
        cpuUsage = snapshot.cpu.usagePercent
        memoryUsage = snapshot.memory.usagePercent
        swapUsage = snapshot.memory.swapUsagePercent
        primaryTemperature = snapshot.thermal.primaryTemperatureCelsius
        batteryPercentage = snapshot.battery?.percentage
        memoryPressure = snapshot.memory.pressureLevel
    }
}
