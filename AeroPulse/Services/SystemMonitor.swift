//
//  SystemMonitor.swift
//  AeroPulse
//

import Foundation
import IOKit
import IOKit.ps

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

    private let gpuUtilizationKeys = [
        "Device Utilization %",
        "GPU Utilization %",
        "GPU Usage %",
        "GPU Busy(%)",
        "GPU Activity(%)",
    ]
    private let totalPowerTelemetryKeys = [
        "SystemPowerIn",
        "SystemLoad",
    ]
    private let chargingPowerTelemetryKeys = [
        "BatteryPower",
    ]

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

    func currentPowerUsageWatts() -> Double? {
        if let totalPower = currentTotalPowerUsageWatts() {
            return totalPower
        }

        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        var samples: [Double] = []

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as? [String: Any],
                (description[kIOPSIsPresentKey as String] as? Bool) != false
            else {
                continue
            }

            guard
                let amperage = numberValue(from: description[kIOPSCurrentKey as String]),
                let voltage = numberValue(from: description[kIOPSVoltageKey as String])
            else {
                continue
            }

            let watts = abs(amperage * voltage) / 1_000_000
            guard watts.isFinite, watts > 0 else { continue }
            samples.append(watts)
        }

        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    func currentChargingPowerWatts() -> Double? {
        guard let snapshot = currentSmartBatterySnapshot() else { return nil }

        if let isCharging = snapshot.isCharging, !isCharging {
            return 0
        }

        if let telemetry = snapshot.telemetry {
            for key in chargingPowerTelemetryKeys {
                if let raw = numberValue(from: telemetry[key]) {
                    let watts = normalizePowerValue(abs(raw))
                    if watts > 0 { return watts }
                }
            }

            if
                let inputRaw = numberValue(from: telemetry["SystemPowerIn"]),
                let loadRaw = numberValue(from: telemetry["SystemLoad"])
            {
                let watts = normalizePowerValue(max(inputRaw - loadRaw, 0))
                if watts > 0 { return watts }
            }
        }

        if let isCharging = snapshot.isCharging, !isCharging {
            return 0
        }

        guard
            let currentMilliamp = snapshot.amperage,
            let voltageMillivolt = snapshot.voltage
        else {
            return nil
        }

        if snapshot.isCharging == nil, currentMilliamp <= 0 {
            return 0
        }

        let watts = abs(currentMilliamp * voltageMillivolt) / 1_000_000
        guard watts.isFinite else { return nil }
        return max(watts, 0)
    }

    private func currentTotalPowerUsageWatts() -> Double? {
        return withSmartBatteryService { service in
            guard
                let telemetryObject = IORegistryEntryCreateCFProperty(
                    service,
                    "PowerTelemetryData" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue(),
                let telemetry = telemetryObject as? [String: Any]
            else {
                return nil
            }

            for key in totalPowerTelemetryKeys {
                if let raw = numberValue(from: telemetry[key]) {
                    let watts = normalizePowerValue(raw)
                    if watts > 0 { return watts }
                }
            }

            if
                let currentMilliamp = numberValue(from: telemetry["SystemCurrentIn"]),
                let voltageMillivolt = numberValue(from: telemetry["SystemVoltageIn"])
            {
                let watts = abs(currentMilliamp * voltageMillivolt) / 1_000_000
                if watts.isFinite, watts > 0 {
                    return watts
                }
            }

            return nil
        }
    }

    private func normalizePowerValue(_ raw: Double) -> Double {
        guard raw.isFinite, raw > 0 else { return 0 }

        // Battery telemetry fields are typically reported in mW.
        if raw >= 500 {
            return raw / 1000
        }
        return raw
    }

    func currentGPUUsagePercent() -> Double? {
        // Different Macs expose GPU data under different accelerator classes.
        for serviceClass in ["IOAccelerator", "IOAccelerator2D", "AGXAccelerator"] {
            if let usage = gpuUsagePercent(forServiceClass: serviceClass) {
                return usage
            }
        }
        return nil
    }

    private func gpuUsagePercent(forServiceClass serviceClass: String) -> Double? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(serviceClass),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var samples: [Double] = []

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            guard
                let statsObject = IORegistryEntryCreateCFProperty(
                    service,
                    "PerformanceStatistics" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue(),
                let stats = statsObject as? [String: Any],
                let usage = parseGPUUsagePercent(from: stats)
            else {
                continue
            }

            samples.append(usage)
        }

        guard !samples.isEmpty else { return nil }
        let average = samples.reduce(0, +) / Double(samples.count)
        return clampGPUPercent(average)
    }

    private func parseGPUUsagePercent(from stats: [String: Any]) -> Double? {
        for key in gpuUtilizationKeys {
            if let value = numberValue(from: stats[key]) {
                return clampGPUPercent(value)
            }
        }

        // Fallback for some Apple Silicon snapshots where only renderer/tiler values appear.
        if
            let renderer = numberValue(from: stats["Renderer Utilization %"]),
            let tiler = numberValue(from: stats["Tiler Utilization %"])
        {
            return clampGPUPercent((renderer + tiler) / 2)
        }

        return nil
    }

    private func numberValue(from raw: Any?) -> Double? {
        if let value = raw as? NSNumber {
            return value.doubleValue
        }
        if let value = raw as? String {
            return Double(value)
        }
        return nil
    }

    private func boolValue(from raw: Any?) -> Bool? {
        if let value = raw as? Bool {
            return value
        }
        if let value = raw as? NSNumber {
            return value.boolValue
        }
        if let value = raw as? String {
            switch value.lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func withSmartBatteryService<T>(_ body: (io_registry_entry_t) -> T?) -> T? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return body(service)
    }

    private struct SmartBatterySnapshot {
        let telemetry: [String: Any]?
        let isCharging: Bool?
        let amperage: Double?
        let voltage: Double?
    }

    private func currentSmartBatterySnapshot() -> SmartBatterySnapshot? {
        return withSmartBatteryService { service in
            let telemetry = IORegistryEntryCreateCFProperty(
                service,
                "PowerTelemetryData" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any]

            let isCharging = boolValue(
                from: IORegistryEntryCreateCFProperty(
                    service,
                    "IsCharging" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            )

            let amperage = numberValue(
                from: IORegistryEntryCreateCFProperty(
                    service,
                    "Amperage" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            ) ?? numberValue(
                from: IORegistryEntryCreateCFProperty(
                    service,
                    "InstantAmperage" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            )

            let voltage = numberValue(
                from: IORegistryEntryCreateCFProperty(
                    service,
                    "Voltage" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            )

            return SmartBatterySnapshot(
                telemetry: telemetry,
                isCharging: isCharging,
                amperage: amperage,
                voltage: voltage
            )
        }
    }

    private func clampGPUPercent(_ rawValue: Double) -> Double {
        guard rawValue.isFinite else { return 0 }

        let normalized: Double
        if rawValue <= 1 {
            normalized = rawValue * 100
        } else if rawValue > 100 && rawValue <= 10_000 {
            // Some drivers expose centi-percent values.
            normalized = rawValue / 100
        } else {
            normalized = rawValue
        }

        return min(max(normalized, 0), 100)
    }
}
