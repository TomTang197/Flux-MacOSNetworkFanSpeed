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
        var stats = DiskStats()
        var iterator: io_iterator_t = 0

        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching("IOBlockStorageDriver"),
                &iterator
            ) == KERN_SUCCESS
        else { return stats }

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
                let dictionary = properties?.takeRetainedValue() as? [String: Any],
                let ioStats = dictionary["Statistics"] as? [String: Any]
            else { continue }

            stats.bytesRead += Self.toUInt64(ioStats["Bytes (Read)"])
            stats.bytesWritten += Self.toUInt64(ioStats["Bytes (Write)"])
        }

        return stats
    }

    func getDiskCapacity() -> DiskCapacity? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard
                let total = attributes[.systemSize] as? NSNumber,
                let free = attributes[.systemFreeSize] as? NSNumber
            else { return nil }

            return DiskCapacity(
                totalBytes: total.uint64Value,
                freeBytes: free.uint64Value
            )
        } catch {
            return nil
        }
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
