import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let packagingURL = rootURL.appendingPathComponent("Packaging", isDirectory: true)
let outputURL = packagingURL.appendingPathComponent("DMGBackground.png")

let canvasSize = NSSize(width: 720, height: 440)

func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func drawCenteredText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = canvasSize

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let fullRect = NSRect(origin: .zero, size: canvasSize)

let backgroundGradient = NSGradient(colors: [
    rgba(15, 24, 36),
    rgba(28, 41, 58),
    rgba(34, 53, 73),
])!
backgroundGradient.draw(in: fullRect, angle: 0)

let glowLeft = NSBezierPath(ovalIn: NSRect(x: -80, y: 210, width: 280, height: 180))
rgba(62, 141, 255, 0.14).setFill()
glowLeft.fill()

let glowRight = NSBezierPath(ovalIn: NSRect(x: 520, y: 210, width: 240, height: 170))
rgba(255, 170, 82, 0.12).setFill()
glowRight.fill()

drawRoundedRect(NSRect(x: 24, y: 24, width: 672, height: 392), radius: 28, color: rgba(255, 255, 255, 0.06))

let titleRect = NSRect(x: 70, y: 355, width: 580, height: 34)
drawCenteredText(
    "Перетащите MacPulse в Applications",
    in: titleRect,
    font: .systemFont(ofSize: 24, weight: .bold),
    color: rgba(244, 247, 252)
)

let subtitleRect = NSRect(x: 110, y: 324, width: 500, height: 24)
drawCenteredText(
    "После установки извлеките и удалите этот DMG",
    in: subtitleRect,
    font: .systemFont(ofSize: 14, weight: .medium),
    color: rgba(203, 212, 224, 0.92)
)

let stepLeftRect = NSRect(x: 90, y: 118, width: 180, height: 38)
drawRoundedRect(stepLeftRect, radius: 18, color: rgba(58, 109, 190, 0.18))
drawCenteredText(
    "1. MacPulse",
    in: NSRect(x: stepLeftRect.minX, y: stepLeftRect.minY + 8, width: stepLeftRect.width, height: 22),
    font: .systemFont(ofSize: 14, weight: .semibold),
    color: rgba(214, 231, 255)
)

let stepRightRect = NSRect(x: 450, y: 118, width: 180, height: 38)
drawRoundedRect(stepRightRect, radius: 18, color: rgba(198, 132, 60, 0.18))
drawCenteredText(
    "2. Applications",
    in: NSRect(x: stepRightRect.minX, y: stepRightRect.minY + 8, width: stepRightRect.width, height: 22),
    font: .systemFont(ofSize: 14, weight: .semibold),
    color: rgba(255, 228, 201)
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 265, y: 214))
arrowPath.curve(to: NSPoint(x: 472, y: 214), controlPoint1: NSPoint(x: 328, y: 250), controlPoint2: NSPoint(x: 408, y: 250))
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.lineWidth = 12

NSGraphicsContext.saveGraphicsState()
let arrowShadow = NSShadow()
arrowShadow.shadowBlurRadius = 18
arrowShadow.shadowColor = rgba(133, 191, 255, 0.24)
arrowShadow.shadowOffset = .zero
arrowShadow.set()
rgba(233, 242, 255, 0.92).setStroke()
arrowPath.stroke()
NSGraphicsContext.restoreGraphicsState()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 470, y: 234))
arrowHead.line(to: NSPoint(x: 512, y: 214))
arrowHead.line(to: NSPoint(x: 470, y: 194))
arrowHead.lineJoinStyle = .round
arrowHead.lineCapStyle = .round
arrowHead.lineWidth = 12
rgba(233, 242, 255, 0.92).setStroke()
arrowHead.stroke()

let footerRect = NSRect(x: 110, y: 52, width: 500, height: 28)
drawCenteredText(
    "Откройте программу из Applications после переноса",
    in: footerRect,
    font: .systemFont(ofSize: 13, weight: .regular),
    color: rgba(199, 207, 218, 0.9)
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "MacPulseDMG", code: 1)
}

try data.write(to: outputURL, options: .atomic)
print("DMG background written to \(outputURL.path)")
