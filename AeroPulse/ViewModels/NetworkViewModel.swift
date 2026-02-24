//
//  NetworkViewModel.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import SwiftUI

/// `NetworkViewModel` manages the state of the network speed meter, coordinates updates, and persists settings.
final class NetworkViewModel: ObservableObject {

    struct ProcessUsageLine: Identifiable, Equatable {
        let pid: Int
        let name: String
        let value: String

        var id: String { "\(pid)-\(name)-\(value)" }
    }

    // MARK: - Published Properties

    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var diskReadSpeed: String = "0 KB/s"
    @Published var diskWriteSpeed: String = "0 KB/s"
    @Published var downloadTotal: String = "0 B"
    @Published var uploadTotal: String = "0 B"
    @Published var diskReadTotal: String = "0 B"
    @Published var diskWriteTotal: String = "0 B"
    @Published var diskTotalCapacity: String = "--"
    @Published var diskFreeCapacity: String = "--"
    @Published var diskUsedPercent: String = "--"
    @Published var cpuUsage: String = "0%"
    @Published var gpuUsage: String = "--"
    @Published var memoryUsage: String = "0%"
    @Published var memoryUsed: String = "--"
    @Published var memoryTotal: String = "--"
    @Published var topCPUProcesses: [ProcessUsageLine] = []
    @Published var topGPUProcesses: [ProcessUsageLine] = [
        ProcessUsageLine(pid: -1, name: "Per-process GPU", value: "N/A")
    ]
    @Published var topMemoryProcesses: [ProcessUsageLine] = []

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
    private let systemMonitor = SystemMonitor()
    private let processMonitor = ProcessMonitor()
    private let processMonitorQueue = DispatchQueue(label: "AeroPulse.ProcessMonitor", qos: .utility)
    private var lastStats: NetworkMonitor.InterfaceStats?
    private var lastDiskStats: DiskMonitor.DiskStats?
    private var lastCPUTicks: SystemMonitor.CPUTicks?
    private var lastTimestamp: Date?
    private var lastDiskSampleTimestamp: Date?
    private var lastCapacitySampleTimestamp: Date?
    private var lastMemorySampleTimestamp: Date?
    private var lastGPUSampleTimestamp: Date?
    private var lastProcessSampleTimestamp: Date?
    private var isSamplingProcessUsage = false
    private var sessionDownloadBytes: UInt64 = 0
    private var sessionUploadBytes: UInt64 = 0
    private var sessionDiskReadBytes: UInt64 = 0
    private var sessionDiskWriteBytes: UInt64 = 0
    private var timer: AnyCancellable?
    private let diskSampleInterval: TimeInterval = 2.0
    private let capacitySampleInterval: TimeInterval = 15.0
    private let memorySampleInterval: TimeInterval = 2.0
    private let gpuSampleInterval: TimeInterval = 1.0
    private let processSampleInterval: TimeInterval = 3.0
    private static let capacityFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useTB, .useGB, .useMB]
        return formatter
    }()

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter
    }()

    private static let totalFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useTB, .useGB, .useMB, .useKB, .useBytes]
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

        // Avoid publishing state while SwiftUI is still constructing the StateObject graph.
        DispatchQueue.main.async { [weak self] in
            self?.startMonitoring()
        }
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
        let currentCPUTicks = systemMonitor.currentCPUTicks()

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
            let bytesInDelta =
                currentStats.bytesIn >= lastStats.bytesIn ? currentStats.bytesIn - lastStats.bytesIn : 0
            let bytesOutDelta =
                currentStats.bytesOut >= lastStats.bytesOut ? currentStats.bytesOut - lastStats.bytesOut : 0

            let diffIn = Double(bytesInDelta)
            let diffOut = Double(bytesOutDelta)

            let downBps = diffIn / timeInterval
            let upBps = diffOut / timeInterval

            setIfChanged(&self.downloadSpeed, formatSpeed(downBps))
            setIfChanged(&self.uploadSpeed, formatSpeed(upBps))
            accumulate(&sessionDownloadBytes, delta: bytesInDelta)
            accumulate(&sessionUploadBytes, delta: bytesOutDelta)
            setIfChanged(&self.downloadTotal, formatTransferTotal(sessionDownloadBytes))
            setIfChanged(&self.uploadTotal, formatTransferTotal(sessionUploadBytes))
        }

        if let currentCPUTicks {
            if let lastCPUTicks = self.lastCPUTicks,
                let cpuPercent = systemMonitor.cpuUsagePercent(previous: lastCPUTicks, current: currentCPUTicks)
            {
                setIfChanged(&self.cpuUsage, String(format: "%.0f%%", cpuPercent))
            }
            self.lastCPUTicks = currentCPUTicks
        }

        if shouldSampleGPU(at: currentTimestamp) {
            if let gpuPercent = systemMonitor.currentGPUUsagePercent() {
                setIfChanged(&self.gpuUsage, String(format: "%.0f%%", gpuPercent))
            } else {
                setIfChanged(&self.gpuUsage, "--")
            }
            self.lastGPUSampleTimestamp = currentTimestamp
        }

        if shouldSampleDisk(at: currentTimestamp) {
            let currentDiskStats = diskMonitor.getDiskUsage()
            if
                let lastDiskStats = self.lastDiskStats,
                let lastDiskSampleTimestamp = self.lastDiskSampleTimestamp
            {
                let diskInterval = currentTimestamp.timeIntervalSince(lastDiskSampleTimestamp)
                if diskInterval > 0 {
                    let diskReadDelta =
                        currentDiskStats.bytesRead >= lastDiskStats.bytesRead
                        ? currentDiskStats.bytesRead - lastDiskStats.bytesRead : 0
                    let diskWriteDelta =
                        currentDiskStats.bytesWritten >= lastDiskStats.bytesWritten
                        ? currentDiskStats.bytesWritten - lastDiskStats.bytesWritten : 0

                    let diskReadDiff = Double(diskReadDelta)
                    let diskWriteDiff = Double(diskWriteDelta)

                    let diskReadBps = diskReadDiff / diskInterval
                    let diskWriteBps = diskWriteDiff / diskInterval

                    setIfChanged(&self.diskReadSpeed, formatSpeed(diskReadBps))
                    setIfChanged(&self.diskWriteSpeed, formatSpeed(diskWriteBps))
                    accumulate(&sessionDiskReadBytes, delta: diskReadDelta)
                    accumulate(&sessionDiskWriteBytes, delta: diskWriteDelta)
                    setIfChanged(&self.diskReadTotal, formatTransferTotal(sessionDiskReadBytes))
                    setIfChanged(&self.diskWriteTotal, formatTransferTotal(sessionDiskWriteBytes))
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

        if shouldSampleMemory(at: currentTimestamp), let memorySample = systemMonitor.currentMemorySample() {
            setIfChanged(&self.memoryUsage, String(format: "%.0f%%", memorySample.usedRatio * 100))
            setIfChanged(&self.memoryUsed, formatMemory(memorySample.usedBytes))
            setIfChanged(&self.memoryTotal, formatMemory(memorySample.totalBytes))
            self.lastMemorySampleTimestamp = currentTimestamp
        }

        sampleProcessUsageIfNeeded(at: currentTimestamp)

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

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }

    private func formatTransferTotal(_ bytes: UInt64) -> String {
        Self.totalFormatter.string(fromByteCount: Int64(bytes))
    }

    private func shouldSampleDisk(at timestamp: Date) -> Bool {
        guard let lastDiskSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastDiskSampleTimestamp) >= diskSampleInterval
    }

    private func shouldSampleCapacity(at timestamp: Date) -> Bool {
        guard let lastCapacitySampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastCapacitySampleTimestamp) >= capacitySampleInterval
    }

    private func shouldSampleMemory(at timestamp: Date) -> Bool {
        guard let lastMemorySampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastMemorySampleTimestamp) >= memorySampleInterval
    }

    private func shouldSampleGPU(at timestamp: Date) -> Bool {
        guard let lastGPUSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastGPUSampleTimestamp) >= gpuSampleInterval
    }

    private func shouldSampleProcessUsage(at timestamp: Date) -> Bool {
        guard let lastProcessSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastProcessSampleTimestamp) >= processSampleInterval
    }

    private func sampleProcessUsageIfNeeded(at timestamp: Date) {
        guard shouldSampleProcessUsage(at: timestamp), !isSamplingProcessUsage else { return }

        isSamplingProcessUsage = true
        lastProcessSampleTimestamp = timestamp

        processMonitorQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.processMonitor.currentTopProcesses(limit: 3)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let snapshot {
                    self.applyProcessUsageSnapshot(snapshot)
                }
                self.isSamplingProcessUsage = false
            }
        }
    }

    private func applyProcessUsageSnapshot(_ snapshot: ProcessMonitor.Snapshot) {
        setIfChanged(&self.topCPUProcesses, snapshot.topCPU.map { stat in
            ProcessUsageLine(
                pid: stat.pid,
                name: stat.name,
                value: String(format: "%.0f%%", stat.cpuPercent)
            )
        })

        setIfChanged(&self.topMemoryProcesses, snapshot.topMemory.map { stat in
            ProcessUsageLine(
                pid: stat.pid,
                name: stat.name,
                value: formatCompactMemory(stat.rssBytes)
            )
        })
    }

    private func formatCompactMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1fG", gb)
        } else if mb >= 10 {
            return String(format: "%.0fM", mb)
        } else {
            return String(format: "%.1fM", mb)
        }
    }

    private func setIfChanged(_ value: inout String, _ newValue: String) {
        if value != newValue {
            value = newValue
        }
    }

    private func setIfChanged<T: Equatable>(_ value: inout [T], _ newValue: [T]) {
        if value != newValue {
            value = newValue
        }
    }

    private func accumulate(_ value: inout UInt64, delta: UInt64) {
        if UInt64.max - value < delta {
            value = UInt64.max
        } else {
            value += delta
        }
    }
}

private final class ProcessMonitor {
    struct ProcessStat {
        let pid: Int
        let name: String
        let cpuPercent: Double
        let rssBytes: UInt64
    }

    struct Snapshot {
        let topCPU: [ProcessStat]
        let topMemory: [ProcessStat]
    }

    func currentTopProcesses(limit: Int) -> Snapshot? {
        let rows = fetchProcessStats()
        guard !rows.isEmpty else { return nil }

        let cpuCandidates = rows.filter { $0.cpuPercent > 0.1 }
        let topCPUSource = cpuCandidates.isEmpty ? rows : cpuCandidates
        let topCPU = topCPUSource
            .sorted {
                if $0.cpuPercent != $1.cpuPercent { return $0.cpuPercent > $1.cpuPercent }
                return $0.rssBytes > $1.rssBytes
            }
            .prefix(limit)

        let topMemory = rows
            .sorted {
                if $0.rssBytes != $1.rssBytes { return $0.rssBytes > $1.rssBytes }
                return $0.cpuPercent > $1.cpuPercent
            }
            .prefix(limit)

        return Snapshot(topCPU: Array(topCPU), topMemory: Array(topMemory))
    }

    private func fetchProcessStats() -> [ProcessStat] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "pid=,pcpu=,rss=,comm="]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let currentPID = Int(ProcessInfo.processInfo.processIdentifier)
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in parseProcessLine(String(line)) }
            .filter { $0.pid != currentPID && $0.name != "ps" }
    }

    private func parseProcessLine(_ line: String) -> ProcessStat? {
        let parts = line.split(
            maxSplits: 3,
            omittingEmptySubsequences: true,
            whereSeparator: \.isWhitespace
        )
        guard parts.count >= 4 else { return nil }

        guard
            let pid = Int(parts[0]),
            let cpuPercent = Double(parts[1]),
            let rssKilobytes = UInt64(parts[2])
        else {
            return nil
        }

        let rawCommand = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawCommand.isEmpty else { return nil }

        let displayName = URL(fileURLWithPath: rawCommand).lastPathComponent
        let name = displayName.isEmpty ? rawCommand : displayName

        return ProcessStat(
            pid: pid,
            name: name,
            cpuPercent: max(cpuPercent, 0),
            rssBytes: rssKilobytes * 1024
        )
    }
}
