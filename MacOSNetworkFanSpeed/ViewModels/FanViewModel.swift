//
//  FanViewModel.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import SwiftUI

final class FanViewModel: ObservableObject {
    @Published var fans: [FanInfo] = []
    @Published var sensors: [SensorInfo] = []
    @Published var isShowingThermalDetails: Bool = false
    @Published var helperInstalled: Bool = false
    @Published var isInstallingHelper: Bool = false
    @Published var helperStatusMessage: String = AppStrings.helperMissing

    @Published var activePreset: String = "Automatic"
    @Published var isMonitoring: Bool = false

    private let monitor = FanMonitor()
    private let fanControl: FanControlProviding = FanControlClient.shared
    private let helperInstaller = PrivilegedHelperInstaller.shared
    private let fanWriteQueue = DispatchQueue(label: "com.bandan.me.FanWriteQueue", qos: .userInitiated)
    private var timer: AnyCancellable?
    private var refreshInterval: Double = 2.0
    private var pendingRPMWrites: [Int: DispatchWorkItem] = [:]
    private var manualSetpointRPM: [Int: Int] = [:]
    private var helperHealthPollCounter = 0
    private var helperHealthFailureCount = 0
    private let helperHealthFailureThreshold = 3

    init() {
        let savedPreset = UserDefaults.standard.string(forKey: "FanPreset") ?? "Automatic"
        self._activePreset = Published(wrappedValue: savedPreset)
        self._isMonitoring = Published(wrappedValue: true)

        // Defer side effects until next run loop to avoid publishing warnings during init.
        DispatchQueue.main.async { [weak self] in
            if self?.isMonitoring == true {
                self?.startMonitoring()
            }
            self?.applyPreset()
            self?.refreshHelperStatus()
        }
    }

    private func applyPreset() {
        let preset = activePreset
        let currentFans = fans

        guard !currentFans.isEmpty else { return }
        cancelPendingRPMWrites()

        fanWriteQueue.async { [weak self] in
            guard let self = self else { return }
            for fan in currentFans {
                switch preset {
                case "Automatic":
                    self.fanControl.setFanMode(index: fan.id, manual: false)
                case "Full Blast":
                    self.fanControl.setFanMode(index: fan.id, manual: true)
                    self.fanControl.setFanTargetRPM(index: fan.id, rpm: fan.maxRPM)
                case "Manual":
                    // Manual mode writes are driven by the slider setpoints.
                    continue
                default:
                    continue
                }
            }
        }
    }

    func setManualRPM(fanID: Int, rpm: Int) {
        // Change preset to "Manual" if it's not already
        if activePreset != "Manual" {
            DispatchQueue.main.async { [weak self] in
                self?.setActivePreset("Manual")
            }
        }

        let bounds = fans.first(where: { $0.id == fanID })
        let minRPM = bounds?.minRPM ?? 0
        let maxRPM = bounds?.maxRPM ?? max(rpm, 0)
        let clampedRPM = min(max(rpm, minRPM), maxRPM)
        manualSetpointRPM[fanID] = clampedRPM

        pendingRPMWrites[fanID]?.cancel()
        let writeItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.fanControl.setFanMode(index: fanID, manual: true)
            self.fanControl.setFanTargetRPM(index: fanID, rpm: clampedRPM)
            DispatchQueue.main.async { [weak self] in
                self?.pendingRPMWrites[fanID] = nil
            }
        }

        pendingRPMWrites[fanID] = writeItem
        fanWriteQueue.asyncAfter(deadline: .now() + 0.2, execute: writeItem)
    }

    func setActivePreset(_ preset: String) {
        guard activePreset != preset else { return }
        activePreset = preset
        UserDefaults.standard.set(preset, forKey: "FanPreset")
        if preset == "Manual" {
            seedManualSetpointsIfNeeded()
        }
        DispatchQueue.main.async { [weak self] in
            self?.applyPreset()
        }
    }

    func setMonitoring(_ enabled: Bool) {
        guard isMonitoring != enabled else { return }
        isMonitoring = enabled
        if enabled {
            startMonitoring()
        } else {
            timer?.cancel()
        }
    }

    func manualDisplayRPM(for fanID: Int, fallback: Int) -> Int {
        if let fan = fans.first(where: { $0.id == fanID }), let setpoint = manualSetpointRPM[fanID] {
            return min(max(setpoint, fan.minRPM), fan.maxRPM)
        }
        if let current = fans.first(where: { $0.id == fanID }) {
            let preferred = current.targetRPM ?? current.currentRPM
            return min(max(preferred, current.minRPM), current.maxRPM)
        }
        return fallback
    }

    func refreshHelperStatus() {
        let installed = helperInstaller.isInstalled()
        guard installed else {
            helperHealthFailureCount = helperHealthFailureThreshold
            helperInstalled = false
            helperStatusMessage = AppStrings.helperMissing
            return
        }

        fanControl.checkHelperHealth { [weak self] healthy in
            guard let self = self else { return }
            if healthy {
                self.helperHealthFailureCount = 0
                self.helperInstalled = true
                self.helperStatusMessage = AppStrings.helperInstalled
                return
            }

            self.helperHealthFailureCount += 1
            if self.helperHealthFailureCount >= self.helperHealthFailureThreshold || !self.helperInstalled {
                self.helperInstalled = false
                self.helperStatusMessage = AppStrings.helperUnhealthy
            }
        }
    }

    func installHelper() {
        guard !isInstallingHelper else { return }

        isInstallingHelper = true
        helperStatusMessage = AppStrings.helperInstalling

        helperInstaller.install { [weak self] result in
            guard let self = self else { return }
            self.isInstallingHelper = false
            switch result {
            case .success:
                FanControlClient.shared.forceHelperRecheck()
                self.helperHealthFailureCount = 0
                self.helperStatusMessage = AppStrings.helperInstallSuccess
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.refreshHelperStatus()
                }
            case let .failure(error):
                self.helperInstalled = false
                self.helperStatusMessage = "\(AppStrings.helperInstallFailedPrefix) \(error.localizedDescription)"
            }
        }
    }

    func startMonitoring() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
        updateStats()  // Initial update
    }

    func updateStats() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let newFans = self.monitor.getFans()
            let newSensors = self.monitor.getSensors()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let hadNoFans = self.fans.isEmpty
                let displayFans = self.activePreset == "Manual"
                    ? self.mergeManualSetpoints(into: newFans) : newFans

                if self.fans != displayFans {
                    self.fans = displayFans
                }
                if self.sensors != newSensors {
                    self.sensors = newSensors
                }

                if hadNoFans && !displayFans.isEmpty {
                    self.applyPreset()
                }

                if self.activePreset == "Manual" {
                    self.enforceManualSetpoints()
                }

                self.helperHealthPollCounter += 1
                if self.helperHealthPollCounter >= 10 {
                    self.helperHealthPollCounter = 0
                    self.refreshHelperStatus()
                }
            }
        }
    }

    var primaryFanRPM: String {
        guard let firstFan = fans.first else { return "0 rpm" }
        return "\(firstFan.currentRPM) rpm"
    }

    var primaryTemp: String {
        // Calculate average of all CPU-related sensors
        let cpuSensors = sensors.filter { sensor in
            sensor.name.contains("P-Core") || sensor.name.contains("E-Core")
                || sensor.name.contains("CPU Core") || sensor.name.contains("CPU Package")
        }

        guard !cpuSensors.isEmpty else { return "0°C" }

        let avgTemp = cpuSensors.reduce(0.0) { $0 + $1.temperature } / Double(cpuSensors.count)
        return String(format: "%.0f°C", avgTemp)
    }

    private func cancelPendingRPMWrites() {
        for item in pendingRPMWrites.values {
            item.cancel()
        }
        pendingRPMWrites.removeAll()
    }

    private func seedManualSetpointsIfNeeded() {
        for fan in fans {
            if manualSetpointRPM[fan.id] != nil { continue }
            let preferred = fan.targetRPM ?? fan.currentRPM
            manualSetpointRPM[fan.id] = min(max(preferred, fan.minRPM), fan.maxRPM)
        }
    }

    private func mergeManualSetpoints(into sampledFans: [FanInfo]) -> [FanInfo] {
        var merged = sampledFans
        var seenFanIDs = Set<Int>()

        for index in merged.indices {
            let fan = merged[index]
            seenFanIDs.insert(fan.id)

            let preferred = manualSetpointRPM[fan.id] ?? fan.targetRPM ?? fan.currentRPM
            let clamped = min(max(preferred, fan.minRPM), fan.maxRPM)
            manualSetpointRPM[fan.id] = clamped
            merged[index].targetRPM = clamped
        }

        if !seenFanIDs.isEmpty {
            manualSetpointRPM = manualSetpointRPM.filter { seenFanIDs.contains($0.key) }
        }

        return merged
    }

    private func enforceManualSetpoints() {
        let setpoints = manualSetpointRPM
        guard !setpoints.isEmpty else { return }

        fanWriteQueue.async { [weak self] in
            guard let self = self else { return }
            for fan in self.fans {
                guard let target = setpoints[fan.id] else { continue }
                self.fanControl.setFanMode(index: fan.id, manual: true)
                self.fanControl.setFanTargetRPM(index: fan.id, rpm: target)
            }
        }
    }

}
