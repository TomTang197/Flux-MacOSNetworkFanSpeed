//
//  SystemMonitor.swift
//  AeroPulse
//

import Foundation

final class SystemMonitor {
    struct CPUTicks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    struct MemorySample {
        let usedBytes: UInt64
        let totalBytes: UInt64
        let usedRatio: Double
    }

    func currentCPUTicks() -> CPUTicks? {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return CPUTicks(
            user: UInt64(max(cpuInfo.cpu_ticks.0, 0)),
            system: UInt64(max(cpuInfo.cpu_ticks.1, 0)),
            idle: UInt64(max(cpuInfo.cpu_ticks.2, 0)),
            nice: UInt64(max(cpuInfo.cpu_ticks.3, 0))
        )
    }

    func cpuUsagePercent(previous: CPUTicks, current: CPUTicks) -> Double? {
        let userDiff = current.user >= previous.user ? current.user - previous.user : 0
        let systemDiff = current.system >= previous.system ? current.system - previous.system : 0
        let idleDiff = current.idle >= previous.idle ? current.idle - previous.idle : 0
        let niceDiff = current.nice >= previous.nice ? current.nice - previous.nice : 0

        let total = userDiff + systemDiff + idleDiff + niceDiff
        guard total > 0 else { return nil }

        let busy = userDiff + systemDiff + niceDiff
        return (Double(busy) / Double(total)) * 100
    }

    func currentMemorySample() -> MemorySample? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        // Match Activity Monitor style more closely:
        // app/internal pages + wired + compressed.
        let usedPages = UInt64(vmStats.internal_page_count)
            + UInt64(vmStats.wire_count)
            + UInt64(vmStats.compressor_page_count)
        let usedBytes = usedPages * UInt64(pageSize)
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard totalBytes > 0 else { return nil }
        let clampedUsedBytes = min(usedBytes, totalBytes)

        let usedRatio = min(max(Double(clampedUsedBytes) / Double(totalBytes), 0), 1)
        return MemorySample(
            usedBytes: clampedUsedBytes,
            totalBytes: totalBytes,
            usedRatio: usedRatio
        )
    }
}
