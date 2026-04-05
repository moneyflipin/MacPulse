import AppKit
import SwiftUI

struct MenuBarSegmentDescriptor {
    let icon: String
    let value: String
}

enum MenuBarStatusLineComposer {
    static func segments(snapshot: SystemSnapshot, configuration: AppConfiguration) -> [MenuBarSegmentDescriptor] {
        guard snapshot.health.lastSuccessfulUpdate != nil else {
            return [
                MenuBarSegmentDescriptor(icon: snapshot.health.state.symbolName, value: "...")
            ]
        }

        switch configuration.menuBarPreset {
        case .followMode:
            return modeDrivenSegments(snapshot: snapshot, mode: configuration.menuBarMode)
        case .cpuOnly:
            return [
                MenuBarSegmentDescriptor(icon: "cpu", value: Formatting.percent(snapshot.cpu.usagePercent))
            ]
        case .cpuTemperature:
            var result = [
                MenuBarSegmentDescriptor(icon: "cpu", value: Formatting.percent(snapshot.cpu.usagePercent))
            ]
            if let temperature = snapshot.thermal.primaryTemperatureCelsius {
                result.append(MenuBarSegmentDescriptor(icon: "thermometer.medium", value: Formatting.temperature(temperature)))
            }
            return result
        case .cpuMemoryBattery:
            var result = [
                MenuBarSegmentDescriptor(icon: "cpu", value: Formatting.percent(snapshot.cpu.usagePercent)),
                MenuBarSegmentDescriptor(icon: "memorychip", value: Formatting.percent(snapshot.memory.usagePercent)),
            ]
            if let battery = snapshot.battery {
                result.append(batterySegment(for: battery))
            }
            return result
        }
    }

    static func reservedWidth(for configuration: AppConfiguration) -> CGFloat {
        let count = CGFloat(expectedSegmentCount(for: configuration))

        switch configuration.menuBarDisplayStyle {
        case .iconsAndText:
            return max(48, count * 62)
        case .iconsOnly:
            return max(28, count * 18)
        case .textOnly:
            return max(36, count * 42)
        }
    }

    static func text(snapshot: SystemSnapshot, configuration: AppConfiguration) -> Text {
        segments(snapshot: snapshot, configuration: configuration)
            .enumerated()
            .reduce(Text("")) { partial, item in
                let prefix = item.offset == 0 ? Text("") : Text("  ")
                return partial + prefix + segmentText(item.element, style: configuration.menuBarDisplayStyle)
            }
    }

    @MainActor
    static func attributedTitle(snapshot: SystemSnapshot, configuration: AppConfiguration) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let result = NSMutableAttributedString()

        for (index, segment) in segments(snapshot: snapshot, configuration: configuration).enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }

            switch configuration.menuBarDisplayStyle {
            case .iconsAndText:
                if let image = NSImage(systemSymbolName: segment.icon, accessibilityDescription: nil)?
                    .withSymbolConfiguration(symbolConfiguration)
                {
                    image.isTemplate = true
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(x: 0, y: -1, width: 11, height: 11)
                    result.append(NSAttributedString(attachment: attachment))
                    result.append(NSAttributedString(string: " ", attributes: [.font: font]))
                }

                result.append(
                    NSAttributedString(
                        string: segment.value,
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor.labelColor,
                        ]
                    )
                )
            case .iconsOnly:
                if let image = NSImage(systemSymbolName: segment.icon, accessibilityDescription: nil)?
                    .withSymbolConfiguration(symbolConfiguration)
                {
                    image.isTemplate = true
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(x: 0, y: -1, width: 11, height: 11)
                    result.append(NSAttributedString(attachment: attachment))
                }
            case .textOnly:
                result.append(
                    NSAttributedString(
                        string: segment.value,
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor.labelColor,
                        ]
                    )
                )
            }
        }

        return result
    }

    private static func segmentText(_ segment: MenuBarSegmentDescriptor, style: MenuBarDisplayStyle) -> Text {
        switch style {
        case .iconsAndText:
            return Text(Image(systemName: segment.icon)) + Text(" ") + Text(segment.value)
        case .iconsOnly:
            return Text(Image(systemName: segment.icon))
        case .textOnly:
            return Text(segment.value)
        }
    }

    private static func modeDrivenSegments(snapshot: SystemSnapshot, mode: MenuBarMode) -> [MenuBarSegmentDescriptor] {
        var result = [
            MenuBarSegmentDescriptor(icon: "cpu", value: Formatting.percent(snapshot.cpu.usagePercent))
        ]

        switch mode {
        case .minimal:
            break
        case .balanced:
            if let temperature = snapshot.thermal.primaryTemperatureCelsius {
                result.append(MenuBarSegmentDescriptor(icon: "thermometer.medium", value: Formatting.temperature(temperature)))
            }
            if let battery = snapshot.battery {
                result.append(batterySegment(for: battery))
            }
        case .detailed:
            result.append(MenuBarSegmentDescriptor(icon: "memorychip", value: Formatting.percent(snapshot.memory.usagePercent)))
            if let temperature = snapshot.thermal.primaryTemperatureCelsius {
                result.append(MenuBarSegmentDescriptor(icon: "thermometer.medium", value: Formatting.temperature(temperature)))
            }
            if let battery = snapshot.battery {
                result.append(batterySegment(for: battery))
            }
        }

        return result
    }

    private static func batterySegment(for battery: BatteryStats) -> MenuBarSegmentDescriptor {
        MenuBarSegmentDescriptor(
            icon: battery.statusSymbolName,
            value: battery.compactIndicatorValue
        )
    }

    private static func expectedSegmentCount(for configuration: AppConfiguration) -> Int {
        switch configuration.menuBarPreset {
        case .followMode:
            switch configuration.menuBarMode {
            case .minimal:
                return 1
            case .balanced:
                return 3
            case .detailed:
                return 4
            }
        case .cpuOnly:
            return 1
        case .cpuTemperature:
            return 2
        case .cpuMemoryBattery:
            return 3
        }
    }
}
