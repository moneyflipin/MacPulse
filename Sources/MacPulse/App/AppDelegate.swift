import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func configureStatusBar(monitor: SystemMonitor, preferences: AppPreferences, windowRouter: WindowRouter) {
        guard statusBarController == nil else { return }
        statusBarController = StatusBarController(
            monitor: monitor,
            preferences: preferences,
            windowRouter: windowRouter
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
