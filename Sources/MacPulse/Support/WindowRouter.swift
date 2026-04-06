import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class WindowRouter: ObservableObject {
    var openControlCenter: (() -> Void)?

    private weak var controlCenterWindow: NSWindow?
    private var didApplyInitialControlCenterVisibility = false

    func bindControlCenter(window: NSWindow, showOnLaunch: Bool, hasCompletedOnboarding: Bool) {
        controlCenterWindow = window
        window.isReleasedWhenClosed = false

        guard !didApplyInitialControlCenterVisibility else { return }
        didApplyInitialControlCenterVisibility = true

        guard hasCompletedOnboarding, !showOnLaunch else {
            window.alphaValue = 1
            return
        }

        // Hide the window before the first visible presentation to avoid a startup flash.
        window.alphaValue = 0
        window.orderOut(nil)
    }

    func presentControlCenter() {
        if let controlCenterWindow {
            controlCenterWindow.alphaValue = 1
            controlCenterWindow.makeKeyAndOrderFront(nil)
            controlCenterWindow.orderFrontRegardless()
        } else {
            openControlCenter?()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
