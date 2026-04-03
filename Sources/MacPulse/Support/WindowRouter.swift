import AppKit
import Combine
import Foundation

@MainActor
final class WindowRouter: ObservableObject {
    var openControlCenter: (() -> Void)?

    func presentControlCenter() {
        openControlCenter?()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
