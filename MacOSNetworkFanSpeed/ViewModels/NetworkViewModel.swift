//
//  NetworkViewModel.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import SwiftUI

/// `NetworkViewModel` manages the state of the network speed meter, coordinates updates, and persists settings.
final class NetworkViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var diskReadSpeed: String = "0 KB/s"
    @Published var diskWriteSpeed: String = "0 KB/s"
    @Published var diskTotalCapacity: String = "--"
    @Published var diskFreeCapacity: String = "--"
    @Published var diskUsedPercent: String = "--"

    @Published var enabledMetrics: Set<MetricType> = [.download, .upload] {
        didSet {
            let encoded = enabledMetrics.map { $0.rawValue }
            UserDefaults.standard.set(encoded, forKey: "EnabledMetrics")
        }
    }

    @Published var refreshInterval: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "RefreshInterval")
            restartTimer()
        }
    }

    // MARK: - Private Properties

    private let monitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()
    private var lastStats: NetworkMonitor.InterfaceStats?
    private var lastDiskStats: DiskMonitor.DiskStats?
    private var lastTimestamp: Date?
    private var lastDiskSampleTimestamp: Date?
    private var lastCapacitySampleTimestamp: Date?
    private var timer: AnyCancellable?
    private let diskSampleInterval: TimeInterval = 2.0
    private let capacitySampleInterval: TimeInterval = 15.0
    private static let capacityFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useTB, .useGB, .useMB]
        return formatter
    }()

    // MARK: - Initializer

    init() {
        // Load persisted settings
        if let savedMetrics = UserDefaults.standard.stringArray(forKey: "EnabledMetrics") {
            let metrics = savedMetrics.compactMap { MetricType(rawValue: $0) }
            self.enabledMetrics = Set(metrics)
        }

        let interval = UserDefaults.standard.double(forKey: "RefreshInterval")
        self.refreshInterval = interval > 0 ? interval : 1.0

        startMonitoring()
    }

    // MARK: - Monitoring Logic

    func startMonitoring() {
        restartTimer()
        updateSpeed()
    }

    private func restartTimer() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSpeed()
            }
    }

    private func updateSpeed() {
        let currentStats = monitor.getNetworkUsage()
        let currentTimestamp = Date()

        if
            let lastStats = self.lastStats,
            let lastTimestamp = self.lastTimestamp
        {
            let timeInterval = currentTimestamp.timeIntervalSince(lastTimestamp)
            guard timeInterval > 0 else {
                self.lastStats = currentStats
                self.lastTimestamp = currentTimestamp
                return
            }

            // Speed = (Current Bytes - Last Bytes) / Time Interval
            // We use max(0, ...) to handle potential overflows or counter resets (rare).
            let diffIn = Double(
                currentStats.bytesIn >= lastStats.bytesIn ? currentStats.bytesIn - lastStats.bytesIn : 0
            )
            let diffOut = Double(
                currentStats.bytesOut >= lastStats.bytesOut ? currentStats.bytesOut - lastStats.bytesOut : 0
            )

            let downBps = diffIn / timeInterval
            let upBps = diffOut / timeInterval

            setIfChanged(&self.downloadSpeed, formatSpeed(downBps))
            setIfChanged(&self.uploadSpeed, formatSpeed(upBps))
        }

        if shouldSampleDisk(at: currentTimestamp) {
            let currentDiskStats = diskMonitor.getDiskUsage()
            if
                let lastDiskStats = self.lastDiskStats,
                let lastDiskSampleTimestamp = self.lastDiskSampleTimestamp
            {
                let diskInterval = currentTimestamp.timeIntervalSince(lastDiskSampleTimestamp)
                if diskInterval > 0 {
                    let diskReadDiff = Double(
                        currentDiskStats.bytesRead >= lastDiskStats.bytesRead
                            ? currentDiskStats.bytesRead - lastDiskStats.bytesRead : 0
                    )
                    let diskWriteDiff = Double(
                        currentDiskStats.bytesWritten >= lastDiskStats.bytesWritten
                            ? currentDiskStats.bytesWritten - lastDiskStats.bytesWritten : 0
                    )

                    let diskReadBps = diskReadDiff / diskInterval
                    let diskWriteBps = diskWriteDiff / diskInterval

                    setIfChanged(&self.diskReadSpeed, formatSpeed(diskReadBps))
                    setIfChanged(&self.diskWriteSpeed, formatSpeed(diskWriteBps))
                }
            }

            self.lastDiskStats = currentDiskStats
            self.lastDiskSampleTimestamp = currentTimestamp
        }

        if shouldSampleCapacity(at: currentTimestamp), let capacity = diskMonitor.getDiskCapacity(),
            capacity.totalBytes > 0
        {
            setIfChanged(&self.diskTotalCapacity, formatCapacity(capacity.totalBytes))
            setIfChanged(&self.diskFreeCapacity, formatCapacity(capacity.freeBytes))
            let usedRatio = Double(capacity.usedBytes) / Double(capacity.totalBytes)
            setIfChanged(&self.diskUsedPercent, String(format: "%.0f%%", usedRatio * 100))
            self.lastCapacitySampleTimestamp = currentTimestamp
        }

        self.lastStats = currentStats
        self.lastTimestamp = currentTimestamp
    }

    /// Formats raw bytes per second into human-readable strings.
    /// KB/s, MB/s, GB/s according to magnitude.
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1.0 {
            return String(format: "%.2f GB/s", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB/s", mb)
        } else if kb >= 1.0 {
            return String(format: "%.1f KB/s", kb)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }

    private func formatCapacity(_ bytes: UInt64) -> String {
        Self.capacityFormatter.string(fromByteCount: Int64(bytes))
    }

    private func shouldSampleDisk(at timestamp: Date) -> Bool {
        guard let lastDiskSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastDiskSampleTimestamp) >= diskSampleInterval
    }

    private func shouldSampleCapacity(at timestamp: Date) -> Bool {
        guard let lastCapacitySampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastCapacitySampleTimestamp) >= capacitySampleInterval
    }

    private func setIfChanged(_ value: inout String, _ newValue: String) {
        if value != newValue {
            value = newValue
        }
    }
}
