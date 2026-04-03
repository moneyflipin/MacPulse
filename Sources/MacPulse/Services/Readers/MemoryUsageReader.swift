import Foundation
import Darwin
import Darwin.Mach

struct MemoryUsageReader {
    func read() -> MemoryStats? {
        let total = ProcessInfo.processInfo.physicalMemory

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let free = (UInt64(vmStats.free_count) + UInt64(vmStats.speculative_count)) * UInt64(pageSize)
        let active = UInt64(vmStats.active_count) * UInt64(pageSize)
        let inactive = UInt64(vmStats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(vmStats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(vmStats.compressor_page_count) * UInt64(pageSize)
        let used = min(total, active + inactive + wired + compressed)
        let swap = readSwapUsage()
        let pressure = pressureLevel(
            usedBytes: used,
            totalBytes: total,
            freeBytes: free,
            compressedBytes: compressed,
            swapUsedBytes: swap.used
        )

        return MemoryStats(
            usedBytes: used,
            totalBytes: total,
            freeBytes: free,
            compressedBytes: compressed,
            appBytes: active,
            wiredBytes: wired,
            cachedBytes: inactive,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressureLevel: pressure
        )
    }

    private func readSwapUsage() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride

        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            sysctlbyname("vm.swapusage", pointer, &size, nil, 0)
        }

        guard result == 0 else { return (0, 0) }
        return (UInt64(usage.xsu_used), UInt64(usage.xsu_total))
    }

    private func pressureLevel(
        usedBytes: UInt64,
        totalBytes: UInt64,
        freeBytes: UInt64,
        compressedBytes: UInt64,
        swapUsedBytes: UInt64
    ) -> MemoryPressureLevel {
        guard totalBytes > 0 else { return .normal }

        let usedRatio = Double(usedBytes) / Double(totalBytes)
        let freeRatio = Double(freeBytes) / Double(totalBytes)
        let compressedRatio = Double(compressedBytes) / Double(totalBytes)
        let swapRatio = Double(swapUsedBytes) / Double(totalBytes)

        if usedRatio > 0.94 || swapUsedBytes > 4 * 1_073_741_824 || (compressedRatio > 0.18 && freeRatio < 0.08) {
            return .critical
        }

        if usedRatio > 0.88 || swapUsedBytes > 1_073_741_824 || (compressedRatio > 0.12 && freeRatio < 0.12) || swapRatio > 0.08 {
            return .high
        }

        if usedRatio > 0.78 || compressedRatio > 0.08 || freeRatio < 0.16 {
            return .elevated
        }

        return .normal
    }
}
