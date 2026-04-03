import Foundation
import Darwin.Mach

final class CPUUsageSampler {
    private var previousInfo: processor_info_array_t?
    private var previousInfoCount: mach_msg_type_number_t = 0

    deinit {
        releasePreviousInfo()
    }

    func read() -> CPUStats? {
        var cpuInfo: processor_info_array_t?
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &infoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return nil }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        var totalTicks: Double = 0

        for index in 0 ..< Int(cpuCount) {
            let offset = Int(CPU_STATE_MAX) * index

            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])

            if let previousInfo {
                let previousUser = Double(previousInfo[offset + Int(CPU_STATE_USER)])
                let previousSystem = Double(previousInfo[offset + Int(CPU_STATE_SYSTEM)])
                let previousIdle = Double(previousInfo[offset + Int(CPU_STATE_IDLE)])
                let previousNice = Double(previousInfo[offset + Int(CPU_STATE_NICE)])

                let deltaUser = (user - previousUser) + (nice - previousNice)
                let deltaSystem = system - previousSystem
                let deltaIdle = idle - previousIdle
                let deltaTotal = deltaUser + deltaSystem + deltaIdle

                totalUser += deltaUser
                totalSystem += deltaSystem
                totalIdle += deltaIdle
                totalTicks += deltaTotal
            } else {
                let combinedUser = user + nice
                let absoluteTotal = combinedUser + system + idle

                totalUser += combinedUser
                totalSystem += system
                totalIdle += idle
                totalTicks += absoluteTotal
            }
        }

        releasePreviousInfo()
        previousInfo = cpuInfo
        previousInfoCount = infoCount

        guard totalTicks > 0 else { return nil }

        let userPercent = (totalUser / totalTicks) * 100
        let systemPercent = (totalSystem / totalTicks) * 100
        let idlePercent = (totalIdle / totalTicks) * 100

        return CPUStats(
            usagePercent: max(0, userPercent + systemPercent),
            userPercent: max(0, userPercent),
            systemPercent: max(0, systemPercent),
            idlePercent: max(0, idlePercent),
            coreCount: Int(cpuCount)
        )
    }

    private func releasePreviousInfo() {
        guard let previousInfo else { return }

        let size = vm_size_t(previousInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: previousInfo), size)

        self.previousInfo = nil
        previousInfoCount = 0
    }
}
