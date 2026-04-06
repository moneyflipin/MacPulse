import Foundation

struct PersistedMonitorState: Codable, Sendable {
    let history: [MetricHistoryPoint]
    let events: [SystemEvent]
}

actor HistoryPersistenceStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseDirectory =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appDirectory = baseDirectory.appendingPathComponent("MacPulse", isDirectory: true)
        fileURL = appDirectory.appendingPathComponent("monitor-state.json")
    }

    func load() -> PersistedMonitorState? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PersistedMonitorState.self, from: data)
        } catch {
            return nil
        }
    }

    func save(history: [MetricHistoryPoint], events: [SystemEvent]) {
        let payload = PersistedMonitorState(history: history, events: events)

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
        }
    }
}
