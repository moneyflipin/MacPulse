import AppKit
import Combine
import SwiftUI

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let monitor: SystemMonitor
    private let preferences: AppPreferences
    private let windowRouter: WindowRouter

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostingController = NSHostingController(
        rootView: MenuBarDashboardView(
            monitor: monitor,
            preferences: preferences,
            openControlCenter: { [weak self] in
                self?.openControlCenter()
            }
        )
    )
    private lazy var statusLineView = PassthroughHostingView(
        rootView: MenuBarStatusView(
            snapshot: monitor.snapshot,
            preferences: preferences
        )
    )

    init(monitor: SystemMonitor, preferences: AppPreferences, windowRouter: WindowRouter) {
        self.monitor = monitor
        self.preferences = preferences
        self.windowRouter = windowRouter
        super.init()

        configureStatusItem()
        configurePopover()
        bindState()
        refreshUI()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "MacPulse"
        button.imagePosition = .imageLeft

        statusLineView.translatesAutoresizingMaskIntoConstraints = false
        statusLineView.setFrameSize(statusLineView.fittingSize)
        button.addSubview(statusLineView)

        NSLayoutConstraint.activate([
            statusLineView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
            statusLineView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
            statusLineView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    private func bindState() {
        monitor.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

        preferences.$configuration
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)
    }

    private func refreshUI() {
        guard let button = statusItem.button else { return }

        statusLineView.rootView = MenuBarStatusView(
            snapshot: monitor.snapshot,
            preferences: preferences
        )
        statusLineView.layoutSubtreeIfNeeded()
        let contentWidth = statusLineView.fittingSize.width + 12
        statusItem.length = max(contentWidth, MenuBarStatusLineComposer.reservedWidth(for: preferences.configuration) + 12)
        button.needsLayout = true
        button.needsDisplay = true

        hostingController.rootView = MenuBarDashboardView(
            monitor: monitor,
            preferences: preferences,
            openControlCenter: { [weak self] in
                self?.openControlCenter()
            }
        )
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        refreshUI()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openControlCenter() {
        popover.performClose(nil)
        windowRouter.presentControlCenter()
    }
}
