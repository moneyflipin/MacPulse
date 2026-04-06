import SwiftUI

@main
struct MacPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences: AppPreferences
    @StateObject private var notificationCoordinator: NotificationCoordinator
    @StateObject private var launchAtLoginController: LaunchAtLoginController
    @StateObject private var monitor: SystemMonitor
    @StateObject private var windowRouter: WindowRouter

    init() {
        let preferences = AppPreferences()
        let notificationCoordinator = NotificationCoordinator()
        let launchAtLoginController = LaunchAtLoginController()
        let monitor = SystemMonitor(
            preferences: preferences,
            notificationCoordinator: notificationCoordinator
        )
        let windowRouter = WindowRouter()
        _preferences = StateObject(wrappedValue: preferences)
        _notificationCoordinator = StateObject(wrappedValue: notificationCoordinator)
        _launchAtLoginController = StateObject(wrappedValue: launchAtLoginController)
        _monitor = StateObject(wrappedValue: monitor)
        _windowRouter = StateObject(wrappedValue: windowRouter)
    }

    var body: some Scene {
        Window("MacPulse", id: SceneIdentity.controlCenter) {
            ControlCenterWindowView(
                monitor: monitor,
                preferences: preferences,
                notificationCoordinator: notificationCoordinator,
                launchAtLoginController: launchAtLoginController
            )
                .preferredColorScheme(preferences.configuration.appearanceMode.colorScheme)
                .background(
                    ControlCenterSceneConnector(
                        windowRouter: windowRouter,
                        showOnLaunch: preferences.configuration.showControlCenterOnLaunch,
                        hasCompletedOnboarding: preferences.configuration.hasCompletedOnboarding
                    )
                )
                .task {
                    monitor.start()
                    appDelegate.configureStatusBar(
                        monitor: monitor,
                        preferences: preferences,
                        windowRouter: windowRouter
                    )
                }
        }
        .defaultSize(width: 980, height: 720)
    }
}

private struct ControlCenterSceneConnector: View {
    @ObservedObject var windowRouter: WindowRouter
    let showOnLaunch: Bool
    let hasCompletedOnboarding: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .background(
                WindowConfigurator { window in
                    windowRouter.bindControlCenter(
                        window: window,
                        showOnLaunch: showOnLaunch,
                        hasCompletedOnboarding: hasCompletedOnboarding
                    )
                }
            )
            .task {
                windowRouter.openControlCenter = {
                    openWindow(id: SceneIdentity.controlCenter)
                }
            }
    }
}
