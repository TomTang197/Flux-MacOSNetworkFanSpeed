//
//  NetworkViewModel.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import Darwin
import SwiftUI

/// `NetworkViewModel` manages the state of the network speed meter, coordinates updates, and persists settings.
final class NetworkViewModel: ObservableObject {

    enum DetailedSamplingSource: Hashable {
        case dashboardWindow
        case menuBarPopover
    }

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
    @Published var powerUsage: String = "-- W"
    @Published var powerSubtitle: String = ""
    @Published var chargingPowerUsage: String = "-- W"
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
    private var lastPowerSampleTimestamp: Date?
    private var lastGPUSampleTimestamp: Date?
    private var lastProcessSampleTimestamp: Date?
    private var isSamplingProcessUsage = false
    private var detailedSamplingSources: Set<DetailedSamplingSource> = []
    private var sessionDownloadBytes: UInt64 = 0
    private var sessionUploadBytes: UInt64 = 0
    private var sessionDiskReadBytes: UInt64 = 0
    private var sessionDiskWriteBytes: UInt64 = 0
    private var presentationUpdateGate = PresentationUpdateGate()
    private var timer: AnyCancellable?
    private let diskSampleInterval: TimeInterval = 2.0
    private let capacitySampleInterval: TimeInterval = 15.0
    private let memorySampleInterval: TimeInterval = 2.0
    private let powerSampleInterval: TimeInterval = 2.0
    private let gpuSampleIntervalDetailed: TimeInterval = 1.0
    private let gpuSampleIntervalBackground: TimeInterval = 2.0
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

    var isDetailedSamplingEnabled: Bool {
        !detailedSamplingSources.isEmpty
    }

    func setDetailedSampling(_ enabled: Bool, source: DetailedSamplingSource) {
        let wasEnabled = isDetailedSamplingEnabled

        if enabled {
            detailedSamplingSources.insert(source)
        } else {
            detailedSamplingSources.remove(source)
        }

        let isEnabled = isDetailedSamplingEnabled
        guard wasEnabled != isEnabled else { return }

        lastGPUSampleTimestamp = nil

        if isEnabled {
            lastProcessSampleTimestamp = nil
            sampleProcessUsageIfNeeded(at: Date())
        } else {
            setIfChanged(&topCPUProcesses, [])
            setIfChanged(&topMemoryProcesses, [])
        }
    }

    /// Pauses only observable UI publication. Sampling and cumulative byte accounting continue.
    func setPresentationUpdatesPaused(_ paused: Bool) {
        let shouldRefresh = presentationUpdateGate.setPaused(paused)
        guard shouldRefresh else { return }
        updateSpeed()
    }

    private let samplingQueue = DispatchQueue(label: "AeroPulse.NetworkSampling", qos: .utility)
    private var isSampling = false

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
        guard !isSampling else { return }
        isSampling = true
        let currentTimestamp = Date()

        samplingQueue.async { [weak self] in
            guard let self else { return }
            self.performSampling(at: currentTimestamp)
        }
    }

    private func performSampling(at currentTimestamp: Date) {
        let currentStats = monitor.getNetworkUsage()
        let currentCPUTicks = systemMonitor.currentCPUTicks()

        var newDownloadSpeed: String?
        var newUploadSpeed: String?
        var newBytesInDelta: UInt64 = 0
        var newBytesOutDelta: UInt64 = 0

        if
            let lastStats = self.lastStats,
            let lastTimestamp = self.lastTimestamp
        {
            let timeInterval = currentTimestamp.timeIntervalSince(lastTimestamp)
            if timeInterval > 0 {
                let bytesInDelta =
                    currentStats.bytesIn >= lastStats.bytesIn ? currentStats.bytesIn - lastStats.bytesIn : 0
                let bytesOutDelta =
                    currentStats.bytesOut >= lastStats.bytesOut ? currentStats.bytesOut - lastStats.bytesOut : 0

                let diffIn = Double(bytesInDelta)
                let diffOut = Double(bytesOutDelta)

                let downBps = diffIn / timeInterval
                let upBps = diffOut / timeInterval

                newDownloadSpeed = formatSpeed(downBps)
                newUploadSpeed = formatSpeed(upBps)
                newBytesInDelta = bytesInDelta
                newBytesOutDelta = bytesOutDelta
            }
        }

        var newCPUUsage: String?
        if let currentCPUTicks {
            if let lastCPUTicks = self.lastCPUTicks,
                let cpuPercent = systemMonitor.cpuUsagePercent(previous: lastCPUTicks, current: currentCPUTicks)
            {
                newCPUUsage = String(format: "%.0f%%", cpuPercent)
            }
            self.lastCPUTicks = currentCPUTicks
        }

        var newPowerUsage: String?
        var newPowerSubtitle: String?
        var newChargingPowerUsage: String?

        if shouldSamplePower(at: currentTimestamp) {
            if let powerSnapshot = systemMonitor.currentPowerSnapshot() {
                if let powerWatts = powerSnapshot.systemPowerWatts {
                    newPowerUsage = formatPower(powerWatts)
                } else {
                    newPowerUsage = "-- W"
                }

                if let batteryPowerWatts = powerSnapshot.batteryPowerWatts {
                    newChargingPowerUsage = formatTelemetryPower(batteryPowerWatts)
                } else if let chargingWatts = powerSnapshot.chargingPowerWatts {
                    newChargingPowerUsage = formatPower(chargingWatts)
                } else {
                    newChargingPowerUsage = "-- W"
                }

                if let inputWatts = powerSnapshot.systemPowerInWatts {
                    newPowerSubtitle = "\(AppStrings.systemPowerIn): \(formatTelemetryPower(inputWatts))"
                } else {
                    newPowerSubtitle = ""
                }
            } else {
                newPowerUsage = "-- W"
                newPowerSubtitle = ""
                newChargingPowerUsage = "-- W"
            }
            self.lastPowerSampleTimestamp = currentTimestamp
        }

        var newGPUUsage: String?
        if shouldSampleGPU(at: currentTimestamp) {
            if let gpuPercent = systemMonitor.currentGPUUsagePercent() {
                newGPUUsage = String(format: "%.0f%%", gpuPercent)
            } else {
                newGPUUsage = "--"
            }
            self.lastGPUSampleTimestamp = currentTimestamp
        }

        var newDiskReadSpeed: String?
        var newDiskWriteSpeed: String?
        var newDiskReadDelta: UInt64 = 0
        var newDiskWriteDelta: UInt64 = 0

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

                    newDiskReadSpeed = formatSpeed(diskReadBps)
                    newDiskWriteSpeed = formatSpeed(diskWriteBps)
                    newDiskReadDelta = diskReadDelta
                    newDiskWriteDelta = diskWriteDelta
                }
            }

            self.lastDiskStats = currentDiskStats
            self.lastDiskSampleTimestamp = currentTimestamp
        }

        var newDiskTotal: String?
        var newDiskFree: String?
        var newDiskUsedPercent: String?

        if shouldSampleCapacity(at: currentTimestamp), let capacity = diskMonitor.getDiskCapacity(),
            capacity.totalBytes > 0
        {
            newDiskTotal = formatCapacity(capacity.totalBytes)
            newDiskFree = formatCapacity(capacity.freeBytes)
            let usedRatio = Double(capacity.usedBytes) / Double(capacity.totalBytes)
            newDiskUsedPercent = String(format: "%.0f%%", usedRatio * 100)
            self.lastCapacitySampleTimestamp = currentTimestamp
        }

        var newMemoryUsage: String?
        var newMemoryUsed: String?
        var newMemoryTotal: String?

        if shouldSampleMemory(at: currentTimestamp), let memorySample = systemMonitor.currentMemorySample() {
            newMemoryUsage = String(format: "%.0f%%", memorySample.usedRatio * 100)
            newMemoryUsed = formatMemory(memorySample.usedBytes)
            newMemoryTotal = formatMemory(memorySample.totalBytes)
            self.lastMemorySampleTimestamp = currentTimestamp
        }

        sampleProcessUsageIfNeeded(at: currentTimestamp)

        self.lastStats = currentStats
        self.lastTimestamp = currentTimestamp

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if newBytesInDelta > 0 {
                accumulate(&self.sessionDownloadBytes, delta: newBytesInDelta)
            }
            if newBytesOutDelta > 0 {
                accumulate(&self.sessionUploadBytes, delta: newBytesOutDelta)
            }
            if newDiskReadDelta > 0 {
                accumulate(&self.sessionDiskReadBytes, delta: newDiskReadDelta)
            }
            if newDiskWriteDelta > 0 {
                accumulate(&self.sessionDiskWriteBytes, delta: newDiskWriteDelta)
            }

            guard self.presentationUpdateGate.shouldPublishIncomingUpdate() else {
                self.isSampling = false
                return
            }

            if let newDownloadSpeed { setIfChanged(&self.downloadSpeed, newDownloadSpeed) }
            if let newUploadSpeed { setIfChanged(&self.uploadSpeed, newUploadSpeed) }
            if self.sessionDownloadBytes > 0 {
                setIfChanged(&self.downloadTotal, formatTransferTotal(self.sessionDownloadBytes))
            }
            if self.sessionUploadBytes > 0 {
                setIfChanged(&self.uploadTotal, formatTransferTotal(self.sessionUploadBytes))
            }

            if let newCPUUsage { setIfChanged(&self.cpuUsage, newCPUUsage) }
            if let newPowerUsage { setIfChanged(&self.powerUsage, newPowerUsage) }
            if let newPowerSubtitle { setIfChanged(&self.powerSubtitle, newPowerSubtitle) }
            if let newChargingPowerUsage { setIfChanged(&self.chargingPowerUsage, newChargingPowerUsage) }
            if let newGPUUsage { setIfChanged(&self.gpuUsage, newGPUUsage) }

            if let newDiskReadSpeed { setIfChanged(&self.diskReadSpeed, newDiskReadSpeed) }
            if let newDiskWriteSpeed { setIfChanged(&self.diskWriteSpeed, newDiskWriteSpeed) }
            if self.sessionDiskReadBytes > 0 {
                setIfChanged(&self.diskReadTotal, formatTransferTotal(self.sessionDiskReadBytes))
            }
            if self.sessionDiskWriteBytes > 0 {
                setIfChanged(&self.diskWriteTotal, formatTransferTotal(self.sessionDiskWriteBytes))
            }

            if let newDiskTotal { setIfChanged(&self.diskTotalCapacity, newDiskTotal) }
            if let newDiskFree { setIfChanged(&self.diskFreeCapacity, newDiskFree) }
            if let newDiskUsedPercent { setIfChanged(&self.diskUsedPercent, newDiskUsedPercent) }

            if let newMemoryUsage { setIfChanged(&self.memoryUsage, newMemoryUsage) }
            if let newMemoryUsed { setIfChanged(&self.memoryUsed, newMemoryUsed) }
            if let newMemoryTotal { setIfChanged(&self.memoryTotal, newMemoryTotal) }

            self.isSampling = false
        }
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

    private func formatPower(_ watts: Double) -> String {
        PowerTelemetryProcessing.formatSystemPowerWatts(watts)
    }

    private func formatTelemetryPower(_ watts: Double) -> String {
        guard watts.isFinite else { return "-- W" }
        if abs(watts) < 0.0005 { return "0.000 W" }
        return String(format: "%.3f W", watts)
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

    private func shouldSamplePower(at timestamp: Date) -> Bool {
        guard let lastPowerSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastPowerSampleTimestamp) >= powerSampleInterval
    }

    private func shouldSampleGPU(at timestamp: Date) -> Bool {
        let sampleInterval = isDetailedSamplingEnabled ? gpuSampleIntervalDetailed : gpuSampleIntervalBackground
        guard let lastGPUSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastGPUSampleTimestamp) >= sampleInterval
    }

    private func shouldSampleProcessUsage(at timestamp: Date) -> Bool {
        guard let lastProcessSampleTimestamp else { return true }
        return timestamp.timeIntervalSince(lastProcessSampleTimestamp) >= processSampleInterval
    }

    private func sampleProcessUsageIfNeeded(at timestamp: Date) {
        guard isDetailedSamplingEnabled else { return }
        guard shouldSampleProcessUsage(at: timestamp), !isSamplingProcessUsage else { return }

        isSamplingProcessUsage = true
        lastProcessSampleTimestamp = timestamp

        processMonitorQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.processMonitor.currentTopProcesses(limit: 3)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if
                    let snapshot,
                    self.isDetailedSamplingEnabled,
                    self.presentationUpdateGate.shouldPublishIncomingUpdate()
                {
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

    private var previousCPUTimes: [pid_t: (time: UInt64, date: Date)] = [:]

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
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytes = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard bytes > 0 else { return [] }

        let count = min(Int(bytes) / MemoryLayout<pid_t>.size, pids.count)
        let now = Date()
        var results: [ProcessStat] = []
        results.reserveCapacity(count)

        let myPid = getpid()
        var currentActivePids = Set<pid_t>()
        currentActivePids.reserveCapacity(count)

        for pid in pids[0..<count] where pid > 0 && pid != myPid {
            currentActivePids.insert(pid)
            var taskInfo = proc_taskallinfo()
            let res = proc_pidinfo(
                pid,
                PROC_PIDTASKALLINFO,
                0,
                &taskInfo,
                Int32(MemoryLayout<proc_taskallinfo>.size)
            )
            guard res == Int32(MemoryLayout<proc_taskallinfo>.size) else { continue }

            var nameBuffer = [CChar](repeating: 0, count: 256)
            _ = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            var name = String(cString: nameBuffer)
            if name.isEmpty {
                name = withUnsafeBytes(of: taskInfo.pbsd.pbi_comm) { rawBuffer in
                    guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
                    return String(cString: base)
                }
            }
            guard !name.isEmpty else { continue }

            let rssBytes = taskInfo.ptinfo.pti_resident_size
            let cpuTimeNano = taskInfo.ptinfo.pti_total_user + taskInfo.ptinfo.pti_total_system
            var cpuPercent = 0.0

            if let prev = previousCPUTimes[pid] {
                let dt = now.timeIntervalSince(prev.date)
                if dt > 0 && cpuTimeNano >= prev.time {
                    let dCpuSec = Double(cpuTimeNano - prev.time) / 1_000_000_000.0
                    cpuPercent = (dCpuSec / dt) * 100.0
                }
            }
            previousCPUTimes[pid] = (cpuTimeNano, now)

            results.append(
                ProcessStat(
                    pid: Int(pid),
                    name: name,
                    cpuPercent: max(cpuPercent, 0),
                    rssBytes: rssBytes
                )
            )
        }

        if previousCPUTimes.count > currentActivePids.count * 2 {
            previousCPUTimes = previousCPUTimes.filter { currentActivePids.contains($0.key) }
        }

        return results
    }
}
