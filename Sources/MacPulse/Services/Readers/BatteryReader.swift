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
        let timeRemaining = batteryTimeRemaining(from: powerSource, smartBattery: smartBattery)
        let temperatureCelsius = smartBattery.flatMap { properties in
            if let rawTemperature = number(from: properties["Temperature"]) {
                return rawTemperature / 100
            }
            return nil
        }
        let powerSourceName = makePowerSourceName(isCharging: isCharging, isConnectedToPower: isConnectedToPower)

        return BatteryStats(
            percentage: percentage,
            isCharging: isCharging,
            isConnectedToPower: isConnectedToPower,
            cycleCount: cycleCount,
            healthPercent: healthPercent,
            wearPercent: wearPercent,
            timeRemainingMinutes: timeRemaining,
            temperatureCelsius: temperatureCelsius,
            powerSourceName: powerSourceName
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

    private func batteryTimeRemaining(from powerSource: [String: Any]?, smartBattery: [String: Any]?) -> Int? {
        if let timeToEmpty = powerSource?[kIOPSTimeToEmptyKey as String] as? Int, timeToEmpty > 0 {
            return timeToEmpty
        }

        if let timeToFull = powerSource?[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
            return timeToFull
        }

        if let fallback = smartBattery?["TimeRemaining"] as? Int, fallback > 0 {
            return fallback
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

    private func makePowerSourceName(isCharging: Bool, isConnectedToPower: Bool) -> String {
        if isCharging {
            return "Зарядка"
        }
        if isConnectedToPower {
            return "От адаптера"
        }
        return "От батареи"
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
