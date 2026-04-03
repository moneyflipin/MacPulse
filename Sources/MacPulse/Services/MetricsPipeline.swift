import Foundation

actor MetricsPipeline {
    private let cpuSampler = CPUUsageSampler()
    private let memoryReader = MemoryUsageReader()
    private let diskReader = DiskUsageReader()
    private let batteryReader = BatteryReader()
    private let temperatureReader = HIDTemperatureReader()
    private let processReader = ProcessListReader()

    private var cachedCPU: CPUStats?
    private var cachedMemory: MemoryStats?
    private var cachedDisk: DiskStats?
    private var cachedBattery: BatteryStats?
    private var cachedSensors: [SensorReading] = []
    private var cachedProcesses: ProcessSummary = .empty

    private var lastDiskRefresh: Date?
    private var lastBatteryRefresh: Date?
    private var lastSensorRefresh: Date?
    private var lastProcessRefresh: Date?
    private var lastSuccessfulCoreRefresh: Date?

    func capture(configuration: AppConfiguration, forceAll: Bool = false) -> SystemSnapshot {
        let now = Date()
        var coreIssues: [String] = []

        let cpu = loadCPU(orRecordIn: &coreIssues)
        let memory = loadMemory(orRecordIn: &coreIssues)
        let battery = loadBatteryIfNeeded(now: now, configuration: configuration, force: forceAll)
        let sensors = loadSensorsIfNeeded(now: now, configuration: configuration, force: forceAll)
        let disk = loadDiskIfNeeded(
            now: now,
            configuration: configuration,
            force: forceAll,
            orRecordIn: &coreIssues
        )
        let processes = loadProcessesIfNeeded(now: now, configuration: configuration, force: forceAll)

        if coreIssues.isEmpty {
            lastSuccessfulCoreRefresh = now
        }

        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalCondition = ThermalCondition(ProcessInfo.processInfo.thermalState)
        let primaryTemperature = temperatureReader.primaryTemperature(
            from: sensors,
            batteryTemperature: battery?.temperatureCelsius
        )

        return SystemSnapshot(
            timestamp: now,
            cpu: cpu,
            memory: memory,
            disk: disk,
            battery: battery,
            thermal: ThermalSummary(
                condition: thermalCondition,
                lowPowerMode: lowPowerMode,
                primaryTemperatureCelsius: primaryTemperature,
                sensors: sensors
            ),
            processes: processes,
            health: makeCaptureHealth(issues: coreIssues)
        )
    }

    private func loadCPU(orRecordIn issues: inout [String]) -> CPUStats {
        if let cpu = cpuSampler.read() {
            cachedCPU = cpu
            return cpu
        }

        issues.append("CPU")
        return cachedCPU ?? SystemSnapshot.placeholder.cpu
    }

    private func loadMemory(orRecordIn issues: inout [String]) -> MemoryStats {
        if let memory = memoryReader.read() {
            cachedMemory = memory
            return memory
        }

        issues.append("память")
        return cachedMemory ?? SystemSnapshot.placeholder.memory
    }

    private func loadDiskIfNeeded(
        now: Date,
        configuration: AppConfiguration,
        force: Bool,
        orRecordIn issues: inout [String]
    ) -> DiskStats {
        if force || shouldRefresh(lastRefresh: lastDiskRefresh, now: now, minimumInterval: max(30, configuration.refreshRate.seconds * 6)) {
            if let disk = diskReader.read() {
                cachedDisk = disk
                lastDiskRefresh = now
                return disk
            }

            lastDiskRefresh = now
            issues.append("диск")
            return cachedDisk ?? SystemSnapshot.placeholder.disk
        }

        if let cachedDisk {
            return cachedDisk
        }

        if let disk = diskReader.read() {
            cachedDisk = disk
            lastDiskRefresh = now
            return disk
        }

        lastDiskRefresh = now
        issues.append("диск")
        return SystemSnapshot.placeholder.disk
    }

    private func loadBatteryIfNeeded(now: Date, configuration: AppConfiguration, force: Bool) -> BatteryStats? {
        if force || shouldRefresh(lastRefresh: lastBatteryRefresh, now: now, minimumInterval: max(10, configuration.refreshRate.seconds * 2.5)) {
            let battery = batteryReader.read()
            if let battery {
                cachedBattery = battery
            }
            lastBatteryRefresh = now
            return battery ?? cachedBattery
        }

        if lastBatteryRefresh != nil {
            return cachedBattery
        }

        let battery = batteryReader.read()
        if let battery {
            cachedBattery = battery
        }
        lastBatteryRefresh = now
        return battery ?? cachedBattery
    }

    private func loadSensorsIfNeeded(now: Date, configuration: AppConfiguration, force: Bool) -> [SensorReading] {
        if force || shouldRefresh(lastRefresh: lastSensorRefresh, now: now, minimumInterval: max(4, configuration.refreshRate.seconds * 1.6)) {
            let sensors = temperatureReader.read()
            if !sensors.isEmpty {
                cachedSensors = sensors
            }
            lastSensorRefresh = now
            return sensors.isEmpty ? cachedSensors : sensors
        }

        if lastSensorRefresh != nil {
            return cachedSensors
        }

        let sensors = temperatureReader.read()
        if !sensors.isEmpty {
            cachedSensors = sensors
        }
        lastSensorRefresh = now
        return sensors.isEmpty ? cachedSensors : sensors
    }

    private func shouldRefresh(lastRefresh: Date?, now: Date, minimumInterval: TimeInterval) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= minimumInterval
    }

    private func loadProcessesIfNeeded(now: Date, configuration: AppConfiguration, force: Bool) -> ProcessSummary {
        let minimumInterval = max(20, configuration.refreshRate.seconds * 8)

        if force || shouldRefresh(lastRefresh: lastProcessRefresh, now: now, minimumInterval: minimumInterval) {
            if let processes = processReader.read(limit: 5), !processes.isEmpty {
                cachedProcesses = processes
                lastProcessRefresh = now
                return processes
            }

            lastProcessRefresh = now
            return cachedProcesses
        }

        if lastProcessRefresh != nil {
            return cachedProcesses
        }

        if let processes = processReader.read(limit: 5), !processes.isEmpty {
            cachedProcesses = processes
            lastProcessRefresh = now
            return processes
        }

        lastProcessRefresh = now
        return cachedProcesses
    }

    private func makeCaptureHealth(issues: [String]) -> CaptureHealth {
        guard let lastSuccessfulCoreRefresh else {
            return CaptureHealth(
                state: .bootstrapping,
                lastSuccessfulUpdate: nil,
                issueSummary: "Собираем первые показания с CPU, памяти и диска.",
                usingCachedMetrics: false
            )
        }

        guard !issues.isEmpty else {
            return CaptureHealth(
                state: .live,
                lastSuccessfulUpdate: lastSuccessfulCoreRefresh,
                issueSummary: nil,
                usingCachedMetrics: false
            )
        }

        let issueLabel: String
        if issues.count == 1 {
            issueLabel = "Источник \(issues[0]) временно не ответил"
        } else {
            issueLabel = "Источники \(issues.joined(separator: ", ")) временно не ответили"
        }

        return CaptureHealth(
            state: .degraded,
            lastSuccessfulUpdate: lastSuccessfulCoreRefresh,
            issueSummary: "\(issueLabel), поэтому мы оставили последние валидные значения.",
            usingCachedMetrics: true
        )
    }
}
