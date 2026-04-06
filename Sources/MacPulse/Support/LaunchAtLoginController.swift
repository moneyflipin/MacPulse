import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    enum State: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unsupported(String)

        var title: String {
            switch self {
            case .enabled:
                "Включен"
            case .disabled:
                "Выключен"
            case .requiresApproval:
                "Нужно подтверждение"
            case let .unsupported(message):
                message
            }
        }

        var summary: String {
            switch self {
            case .enabled:
                "MacPulse будет автоматически запускаться при входе в систему."
            case .disabled:
                "Автозапуск отключен."
            case .requiresApproval:
                "macOS просит подтвердить автозапуск в объектах входа."
            case let .unsupported(message):
                message
            }
        }

        var isEnabledLike: Bool {
            switch self {
            case .enabled, .requiresApproval:
                true
            case .disabled, .unsupported:
                false
            }
        }
    }

    @Published private(set) var state: State = .disabled

    init() {
        refresh()
    }

    func refresh() {
        guard #available(macOS 13, *) else {
            state = .unsupported("Требуется macOS 13 или новее")
            return
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            state = .enabled
        case .requiresApproval:
            state = .requiresApproval
        case .notRegistered, .notFound:
            state = .disabled
        @unknown default:
            state = .unsupported("Статус автозапуска не удалось определить")
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard #available(macOS 13, *) else {
            state = .unsupported("Требуется macOS 13 или новее")
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            state = .unsupported(error.localizedDescription)
        }
    }

    func openSystemSettings() {
        guard #available(macOS 13, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
}
