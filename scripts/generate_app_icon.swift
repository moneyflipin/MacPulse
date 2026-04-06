import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let packagingURL = rootURL.appendingPathComponent("Packaging", isDirectory: true)
let iconsetURL = packagingURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let masterPNGURL = packagingURL.appendingPathComponent("AppIcon-master.png")
let icnsURL = packagingURL.appendingPathComponent("AppIcon.icns")

func makeBitmap(size: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

func savePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MacPulseIcon", code: 1)
    }

    try data.write(to: url, options: .atomic)
}

func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    let baseRect = rect.insetBy(dx: 48, dy: 48)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 224, yRadius: 224)

    let baseGradient = NSGradient(
        colors: [
            rgba(12, 20, 37),
            rgba(20, 58, 92),
            rgba(19, 112, 120),
        ]
    )!
    baseGradient.draw(in: basePath, angle: 52)

    NSGraphicsContext.saveGraphicsState()
    basePath.addClip()

    rgba(255, 255, 255, 0.12).setFill()
    NSBezierPath(ovalIn: NSRect(x: baseRect.maxX - 350, y: baseRect.maxY - 310, width: 420, height: 420)).fill()

    rgba(255, 140, 92, 0.24).setFill()
    NSBezierPath(ovalIn: NSRect(x: baseRect.maxX - 280, y: baseRect.minY - 40, width: 360, height: 360)).fill()

    rgba(80, 214, 202, 0.16).setFill()
    NSBezierPath(ovalIn: NSRect(x: baseRect.minX - 80, y: baseRect.maxY - 280, width: 420, height: 420)).fill()

    let panelRect = NSRect(x: 178, y: 188, width: 668, height: 648)
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 168, yRadius: 168)
    rgba(13, 24, 42, 0.34).setFill()
    panelPath.fill()

    rgba(255, 255, 255, 0.12).setStroke()
    panelPath.lineWidth = 3
    panelPath.stroke()

    let highlightPath = NSBezierPath(roundedRect: NSRect(x: panelRect.minX + 30, y: panelRect.maxY - 84, width: 220, height: 18), xRadius: 9, yRadius: 9)
    rgba(255, 255, 255, 0.15).setFill()
    highlightPath.fill()

    let pulse = NSBezierPath()
    pulse.move(to: NSPoint(x: 262, y: 488))
    pulse.line(to: NSPoint(x: 384, y: 488))
    pulse.line(to: NSPoint(x: 438, y: 632))
    pulse.line(to: NSPoint(x: 506, y: 382))
    pulse.line(to: NSPoint(x: 594, y: 560))
    pulse.line(to: NSPoint(x: 684, y: 492))
    pulse.line(to: NSPoint(x: 762, y: 492))
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round
    pulse.lineWidth = 52

    NSGraphicsContext.saveGraphicsState()
    let pulseShadow = NSShadow()
    pulseShadow.shadowBlurRadius = 28
    pulseShadow.shadowOffset = .zero
    pulseShadow.shadowColor = rgba(70, 236, 224, 0.42)
    pulseShadow.set()
    rgba(240, 248, 255, 0.96).setStroke()
    pulse.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let accentDotRect = NSRect(x: 738, y: 468, width: 74, height: 74)
    let accentDot = NSBezierPath(ovalIn: accentDotRect)

    NSGraphicsContext.saveGraphicsState()
    let dotShadow = NSShadow()
    dotShadow.shadowBlurRadius = 32
    dotShadow.shadowOffset = .zero
    dotShadow.shadowColor = rgba(255, 132, 84, 0.48)
    dotShadow.set()
    rgba(255, 139, 90, 1).setFill()
    accentDot.fill()
    NSGraphicsContext.restoreGraphicsState()

    let ring = NSBezierPath(ovalIn: accentDotRect.insetBy(dx: -18, dy: -18))
    ring.lineWidth = 10
    rgba(255, 255, 255, 0.22).setStroke()
    ring.stroke()

    let gridColor = rgba(255, 255, 255, 0.08)
    gridColor.setStroke()
    for x in stride(from: panelRect.minX + 80, to: panelRect.maxX - 40, by: 132) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x, y: panelRect.minY + 88))
        line.line(to: NSPoint(x: x, y: panelRect.maxY - 110))
        line.lineWidth = 2
        line.stroke()
    }

    for y in stride(from: panelRect.minY + 96, to: panelRect.maxY - 80, by: 128) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: panelRect.minX + 82, y: y))
        line.line(to: NSPoint(x: panelRect.maxX - 82, y: y))
        line.lineWidth = 2
        line.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()

    let border = NSBezierPath(roundedRect: baseRect, xRadius: 224, yRadius: 224)
    border.lineWidth = 4
    rgba(255, 255, 255, 0.16).setStroke()
    border.stroke()
}

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let masterRep = makeBitmap(size: 1024, draw: drawIcon)
try savePNG(masterRep, to: masterPNGURL)

let masterImage = NSImage(size: NSSize(width: 1024, height: 1024))
masterImage.addRepresentation(masterRep)

let iconSizes: [(Int, String)] = [
    (16, "16x16"),
    (32, "16x16@2x"),
    (32, "32x32"),
    (64, "32x32@2x"),
    (128, "128x128"),
    (256, "128x128@2x"),
    (256, "256x256"),
    (512, "256x256@2x"),
    (512, "512x512"),
    (1024, "512x512@2x"),
]

for (size, name) in iconSizes {
    let rep = makeBitmap(size: size) { targetRect in
        masterImage.draw(
            in: targetRect,
            from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
            operation: .copy,
            fraction: 1
        )
    }

    try savePNG(rep, to: iconsetURL.appendingPathComponent("icon_\(name).png"))
}

guard let destination = CGImageDestinationCreateWithURL(
    icnsURL as CFURL,
    UTType.icns.identifier as CFString,
    iconSizes.count,
    nil
) else {
    throw NSError(domain: "MacPulseIcon", code: 2)
}

for (size, name) in iconSizes {
    let iconURL = iconsetURL.appendingPathComponent("icon_\(name).png")
    guard
        let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NSError(domain: "MacPulseIcon", code: 3)
    }

    let properties: [CFString: Any] = [
        kCGImagePropertyPixelWidth: size,
        kCGImagePropertyPixelHeight: size,
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
}

guard CGImageDestinationFinalize(destination) else {
    throw NSError(domain: "MacPulseIcon", code: 4)
}

print("Master PNG: \(masterPNGURL.path)")
print("ICNS: \(icnsURL.path)")
