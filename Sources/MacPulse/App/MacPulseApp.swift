import SwiftUI

@main
struct MacPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences: AppPreferences
    @StateObject private var monitor: SystemMonitor
    @StateObject private var windowRouter: WindowRouter

    init() {
        let preferences = AppPreferences()
        let monitor = SystemMonitor(preferences: preferences)
        let windowRouter = WindowRouter()
        _preferences = StateObject(wrappedValue: preferences)
        _monitor = StateObject(wrappedValue: monitor)
        _windowRouter = StateObject(wrappedValue: windowRouter)
    }

    var body: some Scene {
        WindowGroup(id: SceneIdentity.controlCenter) {
            ControlCenterWindowView(monitor: monitor, preferences: preferences)
                .preferredColorScheme(preferences.configuration.appearanceMode.colorScheme)
                .background(ControlCenterSceneConnector(windowRouter: windowRouter))
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                windowRouter.openControlCenter = {
                    openWindow(id: SceneIdentity.controlCenter)
                }
            }
    }
}
