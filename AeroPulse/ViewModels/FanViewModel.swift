//
//  FanViewModel.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//  Updated with threshold-based fan speed rules on 30/08/26.
//

import Combine
import Foundation

final class FanViewModel: ObservableObject {
    enum DetailedSamplingSource: Hashable {
        case dashboardWindow
        case menuBarPopover
    }

    private let fanRulesStorageKey = "com.bandan.me.AeroPulse.FanThresholdRules"

    @Published var fans: [FanInfo] = []
    @Published var sensors: [SensorInfo] = []
    @Published var isShowingThermalDetails: Bool = false
    @Published var helperInstalled: Bool = false
    @Published var isInstallingHelper: Bool = false
    @Published var helperStatusMessage: String = AppStrings.helperMissing
    @Published var currentMode: FanMode = .auto
    @Published var manualTargetRPM: [Int: Int] = [:]
    @Published var syncAllFans: Bool = true
    @Published var rules: [FanThresholdRule] = []
    @Published var activeRule: FanThresholdRule? = nil

    private let monitor = FanMonitor()
    private let controlClient = FanControlClient.shared
    private let helperInstaller = PrivilegedHelperInstaller.shared
    private let samplingQueue = DispatchQueue(label: "AeroPulse.FanMonitorSampling", qos: .utility)
    private var timer: AnyCancellable?
    private let detailedRefreshInterval: TimeInterval = 2.0
    private let backgroundRefreshInterval: TimeInterval = 4.0
    private var helperPollCounter = 0
    private var emptySampleCounter = 0
    private var isSamplingData = false
    private var detailedSamplingSources: Set<DetailedSamplingSource> = []

    init() {
        loadRules()
        DispatchQueue.main.async { [weak self] in
            self?.startMonitoring()
            self?.refreshHelperStatus()
        }
    }

    deinit {
        timer?.cancel()
    }

    private var refreshInterval: TimeInterval {
        isDetailedSamplingEnabled ? detailedRefreshInterval : backgroundRefreshInterval
    }

    private var isDetailedSamplingEnabled: Bool {
        !detailedSamplingSources.isEmpty
    }

    func setDetailedSampling(_ enabled: Bool, source: DetailedSamplingSource) {
        let wasEnabled = isDetailedSamplingEnabled

        if enabled {
            detailedSamplingSources.insert(source)
        } else {
            detailedSamplingSources.remove(source)
        }

        guard wasEnabled != isDetailedSamplingEnabled else { return }
        restartTimer()
        if isDetailedSamplingEnabled {
            refreshData()
        }
    }

    func startMonitoring() {
        restartTimer()
        refreshData()
    }

    private func restartTimer() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshData()
            }
    }

    func refreshHelperStatus() {
        let installed = helperInstaller.isInstalled()
        let message = installed ? AppStrings.helperInstalled : AppStrings.helperMissing

        if helperInstalled != installed {
            helperInstalled = installed
        }
        if helperStatusMessage != message {
            helperStatusMessage = message
        }
    }

    func installHelper(completion: ((Bool) -> Void)? = nil) {
        guard !isInstallingHelper else { return }

        isInstallingHelper = true
        helperStatusMessage = AppStrings.helperInstalling

        helperInstaller.install { [weak self] result in
            guard let self else { return }
            self.isInstallingHelper = false

            switch result {
            case .success:
                self.helperInstalled = true
                self.helperStatusMessage = AppStrings.helperInstallSuccess
                completion?(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.refreshHelperStatus()
                }
            case let .failure(error):
                self.helperInstalled = false
                self.helperStatusMessage =
                    "\(AppStrings.helperInstallFailedPrefix) \(error.localizedDescription)"
                completion?(false)
            }
        }
    }

    // MARK: - Rule Storage & Management

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: fanRulesStorageKey),
           let decoded = try? JSONDecoder().decode([FanThresholdRule].self, from: data),
           !decoded.isEmpty {
            self.rules = decoded.sorted { $0.temperature < $1.temperature }
        } else {
            self.rules = FanThresholdRule.defaultRules.sorted { $0.temperature < $1.temperature }
            saveRules()
        }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: fanRulesStorageKey)
        }
    }

    func addRule(temperature: Double, speedPercentage: Int) {
        let newRule = FanThresholdRule(temperature: temperature, speedPercentage: speedPercentage)
        rules.append(newRule)
        rules.sort { $0.temperature < $1.temperature }
        saveRules()
        if currentMode == .custom {
            applyThresholdRules()
        }
    }

    func updateRule(_ rule: FanThresholdRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            rules.sort { $0.temperature < $1.temperature }
            saveRules()
            if currentMode == .custom {
                applyThresholdRules()
            }
        }
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        if rules.isEmpty {
            rules = FanThresholdRule.defaultRules
        }
        saveRules()
        if currentMode == .custom {
            applyThresholdRules()
        }
    }

    func resetDefaultRules() {
        rules = FanThresholdRule.defaultRules.sorted { $0.temperature < $1.temperature }
        saveRules()
        if currentMode == .custom {
            applyThresholdRules()
        }
    }

    // MARK: - Fan Control Actions

    func setFanMode(_ mode: FanMode) {
        guard helperInstalled else {
            installHelper { [weak self] success in
                if success {
                    self?.setFanMode(mode)
                }
            }
            return
        }

        currentMode = mode

        switch mode {
        case .auto:
            activeRule = nil
            controlClient.resetToAutomatic { [weak self] _ in
                self?.refreshData()
            }

        case .fullBlast:
            activeRule = nil
            for fan in fans {
                controlClient.setFanTargetRPM(index: fan.id, rpm: fan.maxRPM) { [weak self] _ in
                    self?.refreshData()
                }
            }

        case .manual:
            activeRule = nil
            for fan in fans {
                let rpm = manualTargetRPM[fan.id] ?? (fan.minRPM + fan.maxRPM) / 2
                manualTargetRPM[fan.id] = rpm
                controlClient.setFanTargetRPM(index: fan.id, rpm: rpm) { [weak self] _ in
                    self?.refreshData()
                }
            }

        case .custom:
            applyThresholdRules()
        }
    }

    func setTargetRPM(fanIndex: Int, rpm: Int) {
        guard helperInstalled else {
            installHelper { [weak self] success in
                if success {
                    self?.setTargetRPM(fanIndex: fanIndex, rpm: rpm)
                }
            }
            return
        }

        guard let fan = fans.first(where: { $0.id == fanIndex }) else { return }
        let clamped = max(fan.minRPM, min(rpm, fan.maxRPM))
        manualTargetRPM[fanIndex] = clamped

        if syncAllFans {
            for f in fans {
                manualTargetRPM[f.id] = clamped
                controlClient.setFanTargetRPM(index: f.id, rpm: clamped) { [weak self] _ in
                    self?.refreshData()
                }
            }
        } else {
            controlClient.setFanTargetRPM(index: fanIndex, rpm: clamped) { [weak self] _ in
                self?.refreshData()
            }
        }
    }

    func applyThresholdRules() {
        guard let cpuTemp = currentCPUTemperature() else { return }

        // Find the highest threshold satisfied: T >= rule.temperature
        let sortedDesc = rules.sorted { $0.temperature > $1.temperature }
        let matched = sortedDesc.first { cpuTemp >= $0.temperature }
        self.activeRule = matched

        let speedPercentage = matched?.speedPercentage ?? (rules.first?.speedPercentage ?? 30)

        for fan in fans {
            let range = Double(fan.maxRPM - fan.minRPM)
            let target = fan.minRPM + Int(range * Double(speedPercentage) / 100.0)
            let clamped = max(fan.minRPM, min(target, fan.maxRPM))
            controlClient.setFanTargetRPM(index: fan.id, rpm: clamped)
        }
    }

    private func currentCPUTemperature() -> Double? {
        let cpuSensors = cpuTemperatureSensors
        if !cpuSensors.isEmpty {
            return cpuSensors.reduce(0.0) { $0 + $1.temperature } / Double(cpuSensors.count)
        }
        for key in ["TC0P", "Tp0P", "Tp01", "mACC"] {
            if let value = SMCService.shared.getTemperature(key) {
                return value
            }
        }
        return nil
    }

    var primaryFanRPM: String {
        guard let primaryFan = fans.first else { return "0 \(AppStrings.rpmUnit)" }
        return "\(primaryFan.currentRPM) \(AppStrings.rpmUnit)"
    }

    var primaryTemp: String {
        let cpuSensors = cpuTemperatureSensors
        if !cpuSensors.isEmpty {
            let average = cpuSensors.reduce(0.0) { $0 + $1.temperature } / Double(cpuSensors.count)
            return String(format: "%.0f\u{00B0}C", average)
        }

        let cpuNamedSensors = sensors.filter {
            $0.name.localizedCaseInsensitiveContains("CPU")
                || $0.name.localizedCaseInsensitiveContains("Core")
        }
        if !cpuNamedSensors.isEmpty {
            let average = cpuNamedSensors.reduce(0.0) { $0 + $1.temperature }
                / Double(cpuNamedSensors.count)
            return String(format: "%.0f\u{00B0}C", average)
        }

        if let hottestSensor = sensors.max(by: { $0.temperature < $1.temperature }) {
            return String(format: "%.0f\u{00B0}C", hottestSensor.temperature)
        }

        for key in ["TC0P", "Tp0P", "Tp01", "mACC"] {
            if let value = SMCService.shared.getTemperature(key) {
                return String(format: "%.0f\u{00B0}C", value)
            }
        }

        return "--\u{00B0}C"
    }

    func refreshData() {
        guard !isSamplingData else { return }
        isSamplingData = true

        samplingQueue.async { [weak self] in
            guard let self else { return }
            let sampledFans = self.monitor.getFans().sorted { $0.id < $1.id }
            let sampledSensors = self.monitor.getSensors()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.fans != sampledFans {
                    self.fans = sampledFans
                }
                if self.sensors != sampledSensors {
                    self.sensors = sampledSensors
                }

                if self.currentMode == .custom {
                    self.applyThresholdRules()
                }

                if sampledFans.isEmpty && sampledSensors.isEmpty {
                    self.emptySampleCounter += 1
                    if self.emptySampleCounter >= 3 {
                        self.emptySampleCounter = 0
                        SMCService.shared.reconnect()
                    }
                } else {
                    self.emptySampleCounter = 0
                }

                self.helperPollCounter += 1
                if self.helperPollCounter >= 10 {
                    self.helperPollCounter = 0
                    self.refreshHelperStatus()
                }
                self.isSamplingData = false
            }
        }
    }

    private var cpuTemperatureSensors: [SensorInfo] {
        let normalized = sensors.contains {
            $0.name.hasPrefix("P-Core Sensor ") || $0.name.hasPrefix("E-Core Sensor ")
        }

        return sensors.filter { sensor in
            if normalized {
                return sensor.name.hasPrefix("P-Core Sensor ")
                    || sensor.name.hasPrefix("E-Core Sensor ")
            }

            return sensor.id.hasPrefix("Tp")
                || sensor.id.hasPrefix("Te")
                || sensor.id.hasPrefix("TC")
                || sensor.name.contains(AppStrings.pCoreFilter)
                || sensor.name.contains(AppStrings.eCoreFilter)
                || sensor.name.localizedCaseInsensitiveContains("CPU")
        }
    }
}


