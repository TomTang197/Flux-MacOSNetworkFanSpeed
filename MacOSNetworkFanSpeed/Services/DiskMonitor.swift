//
//  DiskMonitor.swift
//  MacOSNetworkFanSpeed
//

import Foundation
import IOKit

/// Reads cumulative disk I/O counters from IOBlockStorageDriver.
final class DiskMonitor {
    struct DiskStats {
        var bytesRead: UInt64 = 0
        var bytesWritten: UInt64 = 0
    }

    struct DiskCapacity {
        let totalBytes: UInt64
        let freeBytes: UInt64

        var usedBytes: UInt64 {
            totalBytes > freeBytes ? totalBytes - freeBytes : 0
        }
    }

    func getDiskUsage() -> DiskStats {
        var devices: [String: DiskStats] = [:]
        collectDiskUsage(matching: "IOBlockStorageDriver", into: &devices)
        collectDiskUsage(matching: "IOMedia", into: &devices)

        var total = DiskStats()
        for stats in devices.values {
            total.bytesRead += stats.bytesRead
            total.bytesWritten += stats.bytesWritten
        }
        return total
    }

    func getDiskCapacity() -> DiskCapacity? {
        let volumeKeys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForOpportunisticUsageKey,
        ]

        let candidateURLs: [URL] = [
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
            URL(fileURLWithPath: "/", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true),
        ]

        for url in candidateURLs {
            if let capacity = diskCapacity(from: url, keys: volumeKeys) {
                return capacity
            }
        }

        return fallbackDiskCapacity()
    }

    private func diskCapacity(from url: URL, keys: Set<URLResourceKey>) -> DiskCapacity? {
        guard let values = try? url.resourceValues(forKeys: keys),
            let total = values.volumeTotalCapacity,
            total > 0
        else { return nil }

        let available = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
            ?? values.volumeAvailableCapacityForOpportunisticUsage

        guard let available, available > 0 else { return nil }

        return DiskCapacity(
            totalBytes: UInt64(total),
            freeBytes: UInt64(available)
        )
    }

    private func fallbackDiskCapacity() -> DiskCapacity? {
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
            let total = attributes[.systemSize] as? NSNumber,
            let free = attributes[.systemFreeSize] as? NSNumber
        else { return nil }

        return DiskCapacity(
            totalBytes: total.uint64Value,
            freeBytes: free.uint64Value
        )
    }

    private func collectDiskUsage(matching ioClass: String, into devices: inout [String: DiskStats]) {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching(ioClass),
                &iterator
            ) == KERN_SUCCESS
        else { return }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            var properties: Unmanaged<CFMutableDictionary>?
            guard
                IORegistryEntryCreateCFProperties(
                    service,
                    &properties,
                    kCFAllocatorDefault,
                    0
                ) == KERN_SUCCESS,
                let dictionary = properties?.takeRetainedValue() as? [String: Any]
            else { continue }

            guard let stats = diskStats(from: dictionary) else { continue }
            let identifier = deviceIdentifier(for: service, dictionary: dictionary)
            merge(stats, for: identifier, into: &devices)
        }
    }

    private func diskStats(from dictionary: [String: Any]) -> DiskStats? {
        guard let ioStats = dictionary["Statistics"] as? [String: Any] else { return nil }
        let read = Self.toUInt64(ioStats["Bytes (Read)"])
        let write = Self.toUInt64(ioStats["Bytes (Write)"])
        guard read > 0 || write > 0 else { return nil }
        return DiskStats(bytesRead: read, bytesWritten: write)
    }

    private func merge(_ stats: DiskStats, for identifier: String, into devices: inout [String: DiskStats]) {
        if let existing = devices[identifier] {
            devices[identifier] = DiskStats(
                bytesRead: max(existing.bytesRead, stats.bytesRead),
                bytesWritten: max(existing.bytesWritten, stats.bytesWritten)
            )
        } else {
            devices[identifier] = stats
        }
    }

    private func deviceIdentifier(for service: io_registry_entry_t, dictionary: [String: Any]) -> String {
        if let bsd = dictionary["BSD Name"] as? String, !bsd.isEmpty {
            return bsd
        }
        if let media = dictionary["Media"] as? [String: Any],
            let bsd = media["BSD Name"] as? String,
            !bsd.isEmpty
        {
            return bsd
        }

        var entryID: UInt64 = 0
        if IORegistryEntryGetRegistryEntryID(service, &entryID) == KERN_SUCCESS {
            return "id:\(entryID)"
        }

        return UUID().uuidString
    }

    private static func toUInt64(_ value: Any?) -> UInt64 {
        switch value {
        case let number as NSNumber:
            return number.uint64Value
        case let value as UInt64:
            return value
        case let value as Int:
            return value > 0 ? UInt64(value) : 0
        default:
            return 0
        }
    }
}
