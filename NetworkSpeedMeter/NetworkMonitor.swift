import Foundation

/// `NetworkMonitor` is responsible for fetching raw network interface statistics from the macOS system.
/// It uses the BSD sockets API `getifaddrs` which is the standard way to retrieve network interface information on Unix-like systems.
final class NetworkMonitor {

    /// A structure to hold cumulative bytes sent and received.
    struct InterfaceStats {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
    }

    /// Fetches the current cumulative network statistics across all active physical interfaces.
    ///
    /// This function performs the following steps:
    /// 1. Calls `getifaddrs` to get a linked list of `ifaddrs` structures describing each interface.
    /// 2. Iterates through the list, filtering for AF_LINK (Link level) addresses.
    /// 3. Ignores loopback interfaces (lo0) to measure actual external traffic.
    /// 4. Extracts byte counts from the `if_data` structure associated with each interface.
    ///
    /// - Returns: An `InterfaceStats` object containing totals since system boot.
    func getNetworkUsage() -> InterfaceStats {
        var stats = InterfaceStats()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        // getifaddrs: Creates a linked list of structures describing the network interfaces of the local system.
        // Returns 0 on success, -1 on failure.
        guard getifaddrs(&ifaddr) == 0 else { return stats }

        // Ensure the memory is freed after we are done.
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            // ifa_addr: Pointer to a sockaddr structure that contains the interface address.
            // sa_family: Address family (e.g., AF_INET, AF_INET6, AF_LINK).
            // AF_LINK: Link-level interface. This is where we get the data usage stats (I/O bytes).
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)

                // Skip loopback interfaces as they don't represent external network traffic.
                if !name.hasPrefix("lo") {
                    // ifa_data: Pointer to system-specific data. On macOS, this points to `if_data`.
                    // if_data: Contains various interface statistics like packets in/out, bytes in/out, errors, etc.
                    if let data = interface.ifa_data {
                        // Cast the UnsafeMutableRawPointer to UnsafeMutablePointer<if_data>.
                        let interfaceData = data.assumingMemoryBound(to: if_data.self)

                        // ifi_ibytes: Cumulative bytes received.
                        // ifi_obytes: Cumulative bytes sent.
                        stats.bytesIn += UInt64(interfaceData.pointee.ifi_ibytes)
                        stats.bytesOut += UInt64(interfaceData.pointee.ifi_obytes)
                    }
                }
            }
        }

        return stats
    }
}
