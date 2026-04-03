import Foundation
import MacPulseBridge

struct HIDTemperatureReader {
    func read() -> [SensorReading] {
        guard let rawArray = MPHIDCopySensorValues() as? [[String: Any]] else {
            return []
        }

        var mappedReadings: [SensorReading] = []

        for item in rawArray {
            guard
                let rawName = item["rawName"] as? String,
                let groupName = item["group"] as? String,
                let valueCelsius = item["value"] as? Double
            else {
                continue
            }

            let group = mapGroup(from: groupName, rawName: rawName)
            let name = displayName(for: rawName, group: group)

            mappedReadings.append(
                SensorReading(
                    rawName: rawName,
                    name: name,
                    valueCelsius: valueCelsius,
                    group: group
                )
            )
        }

        var groupedReadings: [String: [SensorReading]] = [:]

        for reading in mappedReadings {
            let key = "\(reading.group.rawValue)::\(reading.name)"
            groupedReadings[key, default: []].append(reading)
        }

        var deduplicated: [SensorReading] = []

        for readings in groupedReadings.values {
            guard let first = readings.first else { continue }

            if readings.count == 1 {
                deduplicated.append(first)
                continue
            }

            let averageValue = readings.reduce(0) { $0 + $1.valueCelsius } / Double(readings.count)
            deduplicated.append(
                SensorReading(
                    rawName: first.rawName,
                    name: first.name,
                    valueCelsius: averageValue,
                    group: first.group
                )
            )
        }

        return deduplicated.sorted(by: sensorSort)
    }

    func primaryTemperature(from sensors: [SensorReading], batteryTemperature: Double?) -> Double? {
        let priorityGroups: [SensorGroup] = [.cpuPerformance, .cpuEfficiency, .soc, .gpu]

        for group in priorityGroups {
            let groupSensors = sensors.filter { $0.group == group }
            if !groupSensors.isEmpty {
                return averageTemperature(for: groupSensors)
            }
        }

        if !sensors.isEmpty {
            return averageTemperature(for: sensors.prefix(3))
        }

        return batteryTemperature
    }

    private func averageTemperature<S: Sequence>(for sensors: S) -> Double? where S.Element == SensorReading {
        var total: Double = 0
        var count = 0

        for sensor in sensors {
            total += sensor.valueCelsius
            count += 1
        }

        guard count > 0 else { return nil }
        return total / Double(count)
    }

    private func sensorSort(lhs: SensorReading, rhs: SensorReading) -> Bool {
        if priority(of: lhs.group) == priority(of: rhs.group) {
            return lhs.valueCelsius > rhs.valueCelsius
        }
        return priority(of: lhs.group) > priority(of: rhs.group)
    }

    private func priority(of group: SensorGroup) -> Int {
        switch group {
        case .cpuPerformance:
            7
        case .cpuEfficiency:
            6
        case .soc:
            5
        case .gpu:
            4
        case .battery:
            3
        case .board:
            2
        case .power:
            1
        case .other:
            0
        }
    }

    private func mapGroup(from value: String, rawName: String) -> SensorGroup {
        switch value {
        case "cpu_p":
            return SensorGroup.cpuPerformance
        case "cpu_e":
            return SensorGroup.cpuEfficiency
        case "soc":
            return SensorGroup.soc
        case "gpu":
            return SensorGroup.gpu
        case "battery":
            return SensorGroup.battery
        case "board":
            return SensorGroup.board
        case "power":
            return SensorGroup.power
        default:
            let lowered = rawName.lowercased()
            if lowered.contains("tdie") {
                return SensorGroup.soc
            }
            if lowered.contains("battery") {
                return SensorGroup.battery
            }
            return SensorGroup.other
        }
    }

    private func displayName(for rawName: String, group: SensorGroup) -> String {
        if let suffix = numericSuffix(in: rawName) {
            switch group {
            case .cpuPerformance:
                return "P-ядра \(suffix)"
            case .cpuEfficiency:
                return "E-ядра \(suffix)"
            case .soc:
                return "Кристалл SoC \(suffix)"
            case .board:
                return "Плата \(suffix)"
            case .power:
                return "PMU \(suffix)"
            default:
                break
            }
        }

        switch group {
        case .battery:
            return "Датчик батареи"
        case .gpu:
            return "GPU"
        case .soc:
            return "SoC"
        default:
            return rawName
        }
    }

    private func numericSuffix(in value: String) -> String? {
        let digits = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        guard !digits.isEmpty else { return nil }
        return String(String.UnicodeScalarView(digits))
    }
}
