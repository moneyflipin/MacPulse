import Combine
import Foundation

private struct AppProfileAccumulator {
    var displayName: String
    var latestPID: Int
    var executablePath: String?
    var sampleCount: Int
    var totalCPU: Double
    var totalMemoryBytes: UInt64
    var peakCPU: Double
    var peakMemoryBytes: UInt64
    var lastSeen: Date
    var isTerminatible: Bool

    mutating func ingest(process: ProcessResource, at timestamp: Date) {
        displayName = process.name
        latestPID = process.pid
        executablePath = process.executablePath
        sampleCount += 1
        totalCPU += process.cpuPercent
        totalMemoryBytes += process.memoryBytes
        peakCPU = max(peakCPU, process.cpuPercent)
        peakMemoryBytes = max(peakMemoryBytes, process.memoryBytes)
        lastSeen = timestamp
        isTerminatible = isTerminatible || Foundation.ProcessInfo.processInfo.processIdentifier != process.pid
    }

    func makeProfile(key: String) -> AppResourceProfile {
        AppResourceProfile(
            key: key,
            displayName: displayName,
            lastSeen: lastSeen,
            sampleCount: sampleCount,
            averageCPU: sampleCount == 0 ? 0 : totalCPU / Double(sampleCount),
            peakCPU: peakCPU,
            peakMemoryBytes: peakMemoryBytes,
            averageMemoryBytes: sampleCount == 0 ? 0 : totalMemoryBytes / UInt64(sampleCount),
            latestPID: latestPID,
            executablePath: executablePath,
            isTerminatible: isTerminatible
        )
    }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder
    @Published private(set) var history: [MetricHistoryPoint] = []
    @Published private(set) var events: [SystemEvent] = []
    @Published private(set) var appProfiles: [AppResourceProfile] = []

    private let preferences: AppPreferences
    private let pipeline = MetricsPipeline()
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let maxHistorySamples = 1_800
    private let maxEvents = 160
    private var lastSnapshotForEvents: SystemSnapshot?
    private var profileStore: [String: AppProfileAccumulator] = [:]

    init(preferences: AppPreferences) {
        self.preferences = preferences

        Task(priority: .utility) { @MainActor [weak self] in
            self?.start()
        }

        preferences.$configuration
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { [weak self] in
                    await self?.refreshNow(forceAll: true)
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            await bootstrapInitialSnapshot()

            while !Task.isCancelled {
                let nanoseconds = UInt64(currentRefreshIntervalSeconds() * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                if Task.isCancelled {
                    break
                }
                await refreshNow(forceAll: false)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow(forceAll: Bool = false) async {
        let newSnapshot = await pipeline.capture(
            configuration: preferences.configuration,
            forceAll: forceAll
        )

        snapshot = newSnapshot
        appendHistory(with: newSnapshot)
        updateProfiles(with: newSnapshot)
        detectEvents(newSnapshot)
    }

    var activeRefreshDescription: String {
        let seconds = currentRefreshIntervalSeconds()
        return String(format: "%.0f сек", seconds)
    }

    func historyPoints(for window: TrendWindow) -> [MetricHistoryPoint] {
        let cutoff = Date().addingTimeInterval(-window.duration)
        return history.filter { $0.timestamp >= cutoff }
    }

    func eventHistory(for window: TrendWindow) -> [SystemEvent] {
        let cutoff = Date().addingTimeInterval(-window.duration)
        return events.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp > $1.timestamp }
    }

    var insights: [SmartInsight] {
        ProductIntelligence.insights(snapshot: snapshot, profiles: appProfiles)
    }

    var batteryCoach: BatteryCoachSummary? {
        ProductIntelligence.batteryCoach(snapshot: snapshot, history: history)
    }

    var cleanupHelpers: [CleanupHelper] {
        ProductIntelligence.cleanupHelpers(snapshot: snapshot, profiles: appProfiles)
    }

    func makeHealthReport() -> String {
        ProductIntelligence.report(
            snapshot: snapshot,
            configuration: preferences.configuration,
            insights: insights,
            profiles: appProfiles,
            events: eventHistory(for: preferences.configuration.trendWindow)
        )
    }

    private func currentRefreshIntervalSeconds() -> Double {
        let base = preferences.configuration.refreshRate.seconds
        guard preferences.configuration.adaptiveRefresh else {
            return base
        }

        var adjusted = base

        if snapshot.thermal.lowPowerMode {
            adjusted = max(adjusted, 5)
        }

        if snapshot.battery?.isConnectedToPower == false {
            adjusted = max(adjusted, 4)
        }

        return adjusted
    }

    private func appendHistory(with snapshot: SystemSnapshot) {
        guard snapshot.health.lastSuccessfulUpdate != nil else {
            return
        }

        history.append(MetricHistoryPoint(snapshot: snapshot))

        if history.count > maxHistorySamples {
            history.removeFirst(history.count - maxHistorySamples)
        }
    }

    private func bootstrapInitialSnapshot() async {
        for attempt in 0 ..< 3 {
            await refreshNow(forceAll: true)

            if snapshot.health.state != .bootstrapping {
                return
            }

            if attempt < 2 {
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }

    private func updateProfiles(with snapshot: SystemSnapshot) {
        guard snapshot.health.lastSuccessfulUpdate != nil else { return }

        for process in snapshot.processes.observed {
            let key = process.executablePath ?? process.name
            var accumulator = profileStore[key] ?? AppProfileAccumulator(
                displayName: process.name,
                latestPID: process.pid,
                executablePath: process.executablePath,
                sampleCount: 0,
                totalCPU: 0,
                totalMemoryBytes: 0,
                peakCPU: 0,
                peakMemoryBytes: 0,
                lastSeen: snapshot.timestamp,
                isTerminatible: false
            )
            accumulator.ingest(process: process, at: snapshot.timestamp)
            profileStore[key] = accumulator
        }

        let cutoff = snapshot.timestamp.addingTimeInterval(-4 * 60 * 60)
        profileStore = profileStore.filter { $0.value.lastSeen >= cutoff }
        appProfiles = profileStore
            .map { $0.value.makeProfile(key: $0.key) }
            .sorted { lhs, rhs in
                if lhs.impactScore == rhs.impactScore {
                    return lhs.lastSeen > rhs.lastSeen
                }
                return lhs.impactScore > rhs.impactScore
            }
    }

    private func detectEvents(_ snapshot: SystemSnapshot) {
        guard snapshot.health.lastSuccessfulUpdate != nil else { return }
        defer { lastSnapshotForEvents = snapshot }

        guard let previous = lastSnapshotForEvents else { return }

        if previous.cpu.usagePercent < 85, snapshot.cpu.usagePercent >= 85 {
            appendEvent(
                title: "CPU вышел в высокий режим",
                detail: "Загрузка CPU выросла до \(Formatting.percent(snapshot.cpu.usagePercent)).",
                severity: .critical,
                systemImage: "cpu"
            )
        }

        if previous.memory.pressureLevel == .normal, snapshot.memory.pressureLevel != .normal {
            appendEvent(
                title: "Память стала плотнее",
                detail: "Состояние памяти перешло в режим \(snapshot.memory.pressureLevel.title.lowercased()).",
                severity: snapshot.memory.pressureLevel == .elevated ? .warning : .critical,
                systemImage: "memorychip"
            )
        }

        if previous.memory.swapUsedBytes < 1_073_741_824, snapshot.memory.swapUsedBytes >= 1_073_741_824 {
            appendEvent(
                title: "Система ушла в swap",
                detail: "Swap достиг \(Formatting.bytes(snapshot.memory.swapUsedBytes)). Это уже может влиять на отзывчивость.",
                severity: .warning,
                systemImage: "externaldrive.badge.person.crop"
            )
        }

        if previous.thermal.condition == .nominal, snapshot.thermal.condition != .nominal {
            appendEvent(
                title: "Появился нагрев",
                detail: "Термальное состояние сменилось на \(snapshot.thermal.condition.title.lowercased()).",
                severity: snapshot.thermal.condition == .fair ? .warning : .critical,
                systemImage: "thermometer.medium"
            )
        }

        if previous.disk.freeBytes >= 60 * 1_073_741_824, snapshot.disk.freeBytes < 60 * 1_073_741_824 {
            appendEvent(
                title: "Свободное место заканчивается",
                detail: "На системном диске осталось \(Formatting.bytes(snapshot.disk.freeBytes)).",
                severity: .warning,
                systemImage: "internaldrive"
            )
        }
    }

    private func appendEvent(title: String, detail: String, severity: InsightSeverity, systemImage: String) {
        events.insert(
            SystemEvent(
                timestamp: snapshot.timestamp,
                title: title,
                detail: detail,
                severity: severity,
                systemImage: systemImage
            ),
            at: 0
        )

        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }
}
