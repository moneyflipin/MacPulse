import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationCoordinator: ObservableObject {
    enum AuthorizationState: String {
        case unknown
        case notDetermined
        case authorized
        case denied

        var title: String {
            switch self {
            case .unknown:
                "Проверяем"
            case .notDetermined:
                "Нужно разрешение"
            case .authorized:
                "Разрешены"
            case .denied:
                "Отключены"
            }
        }

        var summary: String {
            switch self {
            case .unknown:
                "Проверяем состояние системных уведомлений."
            case .notDetermined:
                "Можно включить алерты о нагреве, swap и нехватке места."
            case .authorized:
                "MacPulse может присылать важные алерты о состоянии Mac."
            case .denied:
                "macOS не разрешает уведомления. Их можно вернуть в настройках системы."
            }
        }
    }

    @Published private(set) var authorizationState: AuthorizationState = .unknown

    private let center = UNUserNotificationCenter.current()
    private let cooldown: TimeInterval = 8 * 60
    private var lastSentAtByKey: [String: Date] = [:]

    init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }

    @discardableResult
    func refreshAuthorizationStatus() async -> AuthorizationState {
        let settings = await center.notificationSettings()

        let state: AuthorizationState
        switch settings.authorizationStatus {
        case .notDetermined:
            state = .notDetermined
        case .denied:
            state = .denied
        case .authorized, .provisional, .ephemeral:
            state = .authorized
        @unknown default:
            state = .unknown
        }

        authorizationState = state
        return state
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let state = await refreshAuthorizationStatus()
        switch state {
        case .authorized:
            return true
        case .denied:
            return false
        case .unknown, .notDetermined:
            break
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        _ = await refreshAuthorizationStatus()
        return granted
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func sendNotification(for event: SystemEvent, enabled: Bool) async {
        guard enabled else { return }
        guard event.severity == .warning || event.severity == .critical else { return }

        let state = await refreshAuthorizationStatus()
        guard state == .authorized else { return }

        let key = "\(event.severity.rawValue)-\(event.title)"
        if let lastSentAt = lastSentAtByKey[key], Date().timeIntervalSince(lastSentAt) < cooldown {
            return
        }
        lastSentAtByKey[key] = Date()

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.detail
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: key + "-\(Int(event.timestamp.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }
}
