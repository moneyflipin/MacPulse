import Foundation
import IOKit
import IOKit.ps

struct BatteryReader {
    func read() -> BatteryStats? {
        let powerSource = readPowerSourceDescription()
        let smartBattery = readSmartBatteryProperties()

        guard powerSource != nil || smartBattery != nil else {
            return nil
        }

        let percentage = batteryPercentage(from: powerSource, smartBattery: smartBattery)
        let isCharging = (powerSource?[kIOPSIsChargingKey as String] as? Bool) ?? (smartBattery?["IsCharging"] as? Bool) ?? false
        let isConnectedToPower = ((powerSource?[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String))
            || ((smartBattery?["ExternalConnected"] as? Bool) ?? false)
        let cycleCount = smartBattery?["CycleCount"] as? Int
        let designCapacity = number(from: smartBattery?["DesignCapacity"])
        let maxCapacity = number(from: smartBattery?["AppleRawMaxCapacity"])
            ?? number(from: smartBattery?["MaxCapacity"])
            ?? number(from: smartBattery?["NominalChargeCapacity"])
        let healthPercent = healthPercent(maxCapacity: maxCapacity, designCapacity: designCapacity)
        let wearPercent = healthPercent.map { max(0, 100 - $0) }
        let timeToFullCharge = batteryTimeToFullCharge(from: powerSource, smartBattery: smartBattery)
        let timeToEmpty = batteryTimeToEmpty(from: powerSource, smartBattery: smartBattery)
        let timeRemaining = isCharging ? (timeToFullCharge ?? timeToEmpty) : (timeToEmpty ?? timeToFullCharge)
        let temperatureCelsius = smartBattery.flatMap { properties in
            if let rawTemperature = number(from: properties["Temperature"]) {
                return rawTemperature / 100
            }
            return nil
        }
        let adapterPowerWatts = adapterPowerWatts(from: smartBattery)
        let powerFlowWatts = powerFlowWatts(from: smartBattery)
        let powerSourceName = makePowerSourceName(
            isCharging: isCharging,
            isConnectedToPower: isConnectedToPower,
            adapterPowerWatts: adapterPowerWatts,
            powerFlowWatts: powerFlowWatts,
            percentage: percentage
        )

        return BatteryStats(
            percentage: percentage,
            isCharging: isCharging,
            isConnectedToPower: isConnectedToPower,
            cycleCount: cycleCount,
            healthPercent: healthPercent,
            wearPercent: wearPercent,
            timeRemainingMinutes: timeRemaining,
            timeToFullChargeMinutes: timeToFullCharge,
            timeToEmptyMinutes: timeToEmpty,
            temperatureCelsius: temperatureCelsius,
            powerSourceName: powerSourceName,
            adapterPowerWatts: adapterPowerWatts,
            powerFlowWatts: powerFlowWatts
        )
    }

    private func readPowerSourceDescription() -> [String: Any]? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array

        for source in sources {
            guard let unmanagedDescription = IOPSGetPowerSourceDescription(info, source) else {
                continue
            }

            guard let description = unmanagedDescription.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = description[kIOPSTypeKey as String] as? String
            if type == (kIOPSInternalBatteryType as String) {
                return description
            }
        }

        return nil
    }

    private func readSmartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS else { return nil }

        return properties?.takeRetainedValue() as? [String: Any]
    }

    private func batteryPercentage(from powerSource: [String: Any]?, smartBattery: [String: Any]?) -> Double {
        if let percentage = number(from: powerSource?[kIOPSCurrentCapacityKey as String]) {
            return percentage
        }

        if
            let currentCapacity = number(from: smartBattery?["CurrentCapacity"]),
            let maxCapacity = number(from: smartBattery?["MaxCapacity"]),
            maxCapacity > 0
        {
            return (currentCapacity / maxCapacity) * 100
        }

        return 0
    }

    private func batteryTimeToEmpty(from powerSource: [String: Any]?, smartBattery: [String: Any]?) -> Int? {
        if let timeToEmpty = powerSource?[kIOPSTimeToEmptyKey as String] as? Int, timeToEmpty > 0 {
            return timeToEmpty
        }

        if let average = sanitizedTimeEstimate(from: smartBattery?["AvgTimeToEmpty"]) {
            return average
        }

        if let fallback = sanitizedTimeEstimate(from: smartBattery?["TimeRemaining"]) {
            return fallback
        }

        return nil
    }

    private func batteryTimeToFullCharge(from powerSource: [String: Any]?, smartBattery: [String: Any]?) -> Int? {
        if let timeToFull = powerSource?[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
            return timeToFull
        }

        if let average = sanitizedTimeEstimate(from: smartBattery?["AvgTimeToFull"]) {
            return average
        }

        if let fallback = sanitizedTimeEstimate(from: smartBattery?["TimeRemaining"]) {
            return fallback
        }

        return nil
    }

    private func adapterPowerWatts(from smartBattery: [String: Any]?) -> Double? {
        number(from: adapterDetailsValue(named: "Watts", smartBattery: smartBattery))
            ?? number(from: adapterDetailsValue(named: "AdapterPower", smartBattery: smartBattery))
    }

    private func powerFlowWatts(from smartBattery: [String: Any]?) -> Double? {
        guard
            let amperage = number(from: smartBattery?["InstantAmperage"]) ?? number(from: smartBattery?["Amperage"]),
            let voltage = number(from: smartBattery?["Voltage"]) ?? number(from: smartBattery?["AppleRawBatteryVoltage"]),
            voltage > 0
        else {
            return nil
        }

        let watts = abs(amperage * voltage) / 1_000_000
        return watts > 0.05 ? watts : nil
    }

    private func adapterDetailsValue(named key: String, smartBattery: [String: Any]?) -> Any? {
        guard let smartBattery else { return nil }

        let candidates = [
            smartBattery["AdapterDetails"],
            smartBattery["AppleRawAdapterDetails"],
        ]

        for candidate in candidates {
            if let dictionary = candidate as? [String: Any], let value = dictionary[key] {
                return value
            }

            if let array = candidate as? [Any] {
                for item in array {
                    if let dictionary = item as? [String: Any], let value = dictionary[key] {
                        return value
                    }
                }
            }
        }

        return nil
    }

    private func healthPercent(maxCapacity: Double?, designCapacity: Double?) -> Double? {
        guard
            let maxCapacity,
            let designCapacity,
            maxCapacity > 0,
            designCapacity > 0
        else {
            return nil
        }

        return (maxCapacity / designCapacity) * 100
    }

    private func makePowerSourceName(
        isCharging: Bool,
        isConnectedToPower: Bool,
        adapterPowerWatts: Double?,
        powerFlowWatts: Double?,
        percentage: Double
    ) -> String {
        let powerDescription = (isConnectedToPower ? adapterPowerWatts : powerFlowWatts).map { watts in
            Formatting.watts(watts)
        }

        if isCharging {
            if let powerDescription {
                return "Заряжается • \(powerDescription)"
            }
            return "Заряжается"
        }
        if isConnectedToPower {
            if percentage >= 99 {
                if let powerDescription {
                    return "Полный заряд • \(powerDescription)"
                }
                return "Полный заряд"
            }

            if let powerDescription {
                return "От адаптера • \(powerDescription)"
            }
            return "От адаптера"
        }
        if let powerFlowWatts {
            return "От батареи • \(Formatting.watts(powerFlowWatts))"
        }
        return "От батареи"
    }

    private func sanitizedTimeEstimate(from value: Any?) -> Int? {
        guard let minutes = number(from: value).map(Int.init), minutes > 0, minutes < 65_000 else {
            return nil
        }

        return minutes
    }

    private func number(from value: Any?) -> Double? {
        switch value {
        case let value as NSNumber:
            value.doubleValue
        case let value as Int:
            Double(value)
        case let value as Double:
            value
        default:
            nil
        }
    }
}
