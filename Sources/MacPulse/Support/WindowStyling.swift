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

private struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }

        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
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
