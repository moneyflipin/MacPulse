import AppKit
import SwiftUI

enum SceneIdentity {
    static let controlCenter = "control-center"
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ConfiguringView()
        view.configure = configure
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? ConfiguringView else { return }
        view.configure = configure
        view.configureIfNeeded()
    }

    private final class ConfiguringView: NSView {
        var configure: ((NSWindow) -> Void)?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            guard let newWindow, let configure else { return }
            configure(newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureIfNeeded()
        }

        func configureIfNeeded() {
            guard let window, let configure else { return }
            configure(window)
        }
    }
}

struct MacPulseWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                WindowConfigurator { window in
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.toolbarStyle = .unifiedCompact
                    window.isMovableByWindowBackground = true
                }
            )
    }
}

extension View {
    func macPulseWindowStyle() -> some View {
        modifier(MacPulseWindowStyle())
    }
}
