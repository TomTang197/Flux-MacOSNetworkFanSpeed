//
//  FanViewModel.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//  Updated with threshold-based fan speed rules on 30/08/26.
//

import AppKit
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
    @Published private(set) var isRulesStandby: Bool = false

    private let monitor = FanMonitor()
    private let controlClient = FanControlClient.shared
    private let helperInstaller = PrivilegedHelperInstaller.shared
    private let samplingQueue = DispatchQueue(label: "AeroPulse.FanMonitorSampling", qos: .utility)
    private var timer: AnyCancellable?
    private let detailedRefreshInterval: TimeInterval = 2.0
    private let backgroundRefreshInterval: TimeInterval = 4.0
    private let maximumControlTemperatureAge: TimeInterval = 6.0
    private var helperPollCounter = 0
    private var emptySampleCounter = 0
    private var isSamplingData = false
    private var detailedSamplingSources: Set<DetailedSamplingSource> = []
    private var controlTemperatureSample: (value: Double, sampledAt: Date)?
    private var ruleTargetSubmissionGate = FanTargetSubmissionGate()
    private var defaultNotificationObservers: [NSObjectProtocol] = []
    private var workspaceNotificationObservers: [NSObjectProtocol] = []

    init() {
        loadRules()
        observeSafetyLifecycleEvents()
        DispatchQueue.main.async { [weak self] in
            self?.startMonitoring()
            self?.refreshHelperStatus()
        }
    }

    deinit {
        timer?.cancel()
        for observer in defaultNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceNotificationObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func observeSafetyLifecycleEvents() {
        let terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoreSystemControlForSafety(waitForReply: true)
        }
        defaultNotificationObservers.append(terminationObserver)

        let leaseObserver = NotificationCenter.default.addObserver(
            forName: .fanControlLeaseLost,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.currentMode = .auto
            self?.activeRule = nil
            self?.isRulesStandby = false
            self?.ruleTargetSubmissionGate.reset()
        }
        defaultNotificationObservers.append(leaseObserver)

        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoreSystemControlForSafety(waitForReply: true)
        }
        workspaceNotificationObservers.append(sleepObserver)
    }

    private func restoreSystemControlForSafety(waitForReply: Bool) {
        currentMode = .auto
        activeRule = nil
        isRulesStandby = false
        ruleTargetSubmissionGate.reset()

        guard waitForReply else {
            controlClient.resetToAutomatic()
            return
        }

        let reply = DispatchSemaphore(value: 0)
        controlClient.resetToAutomatic { _ in reply.signal() }
        _ = reply.wait(timeout: .now() + 1.5)
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
        isRulesStandby = false
        ruleTargetSubmissionGate.reset()

        switch mode {
        case .auto:
            activeRule = nil
            controlClient.setControlTemperatureDeadline(nil)
            controlClient.resetToAutomatic { [weak self] _ in
                self?.refreshData()
            }

        case .fullBlast:
            activeRule = nil
            controlClient.setControlTemperatureDeadline(nil)
            applyFanTargets(fans.map { (index: $0.id, rpm: $0.maxRPM) })

        case .manual:
            activeRule = nil
            controlClient.setControlTemperatureDeadline(nil)
            var targets: [(index: Int, rpm: Int)] = []
            for fan in fans {
                let rpm = manualTargetRPM[fan.id] ?? (fan.minRPM + fan.maxRPM) / 2
                manualTargetRPM[fan.id] = rpm
                targets.append((index: fan.id, rpm: rpm))
            }
            applyFanTargets(targets)

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
            var targets: [(index: Int, rpm: Int)] = []
            for f in fans {
                let fanClamped = max(f.minRPM, min(clamped, f.maxRPM))
                manualTargetRPM[f.id] = fanClamped
                targets.append((index: f.id, rpm: fanClamped))
            }
            applyFanTargets(targets)
        } else {
            applyFanTargets([(index: fanIndex, rpm: clamped)])
        }
    }

    private func applyFanTargets(
        _ targets: [(index: Int, rpm: Int)],
        refreshAfterCompletion: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        controlClient.setFanTargets(targets) { [weak self] success in
            DispatchQueue.main.async {
                if refreshAfterCompletion {
                    self?.refreshData()
                }
                completion?(success)
            }
        }
    }

    func applyThresholdRules() {
        let now = Date()
        guard let sample = controlTemperatureSample,
              TemperatureFreshnessPolicy.isFresh(
                  sampledAt: sample.sampledAt,
                  now: now,
                  maximumAge: maximumControlTemperatureAge
              ) else {
            restoreSystemControlForSafety(waitForReply: false)
            return
        }
        let controlTemperature = sample.value
        let decision = FanRuleMatchPolicy.decision(
            temperature: controlTemperature,
            thresholds: rules.map(\.temperature)
        )
        guard case .matched(let matchedIndex) = decision,
              rules.indices.contains(matchedIndex) else {
            enterRulesStandby()
            return
        }

        let matched = rules[matchedIndex]
        activeRule = matched
        isRulesStandby = false
        controlClient.setControlTemperatureDeadline(
            sample.sampledAt.addingTimeInterval(maximumControlTemperatureAge)
        )

        let speedPercentage = matched.speedPercentage

        let targets = fans.map { fan in
            let range = Double(fan.maxRPM - fan.minRPM)
            let target = fan.minRPM + Int(range * Double(speedPercentage) / 100.0)
            let clamped = max(fan.minRPM, min(target, fan.maxRPM))
            return (index: fan.id, rpm: clamped)
        }
        let targetMap = Dictionary(uniqueKeysWithValues: targets.map { ($0.index, $0.rpm) })
        guard let submission = ruleTargetSubmissionGate.request(targetMap) else { return }
        submitRuleTargets(submission)
    }

    private func submitRuleTargets(_ submission: FanTargetSubmissionGate.Submission) {
        let targets = submission.targets.keys.sorted().compactMap { index in
            submission.targets[index].map { (index: index, rpm: $0) }
        }
        applyFanTargets(
            targets,
            refreshAfterCompletion: false
        ) { [weak self] success in
            guard let self else { return }
            let nextSubmission = self.ruleTargetSubmissionGate.complete(
                submission,
                succeeded: success
            )
            guard success, self.currentMode == .custom, let nextSubmission else { return }
            self.submitRuleTargets(nextSubmission)
        }
    }

    private func enterRulesStandby() {
        activeRule = nil
        controlClient.setControlTemperatureDeadline(nil)
        ruleTargetSubmissionGate.reset()

        guard !isRulesStandby else { return }
        isRulesStandby = true
        controlClient.resetToAutomatic()
    }

    private func sampleControlTemperature(
        from sampledSensors: [SensorInfo]
    ) -> (value: Double, sampledAt: Date)? {
        guard let sample = ThermalSensorProcessing.controlTemperatureSample(
            from: sampledSensors
        ) else {
            return nil
        }
        return (sample.value, sample.sampledAt)
    }

    var primaryFanRPM: String {
        guard let primaryFan = fans.first else { return "0 \(AppStrings.rpmUnit)" }
        return "\(primaryFan.currentRPM) \(AppStrings.rpmUnit)"
    }

    var primaryTemp: String {
        guard let temperature = ThermalSensorProcessing.primaryCPUTemperature(from: sensors) else {
            return "--\u{00B0}C"
        }
        return String(format: "%.0f\u{00B0}C", temperature)
    }

    var primaryGPUTemp: String {
        guard let temperature = ThermalSensorProcessing.primaryGPUTemperature(from: sensors) else {
            return "--\u{00B0}C"
        }
        return String(format: "%.0f\u{00B0}C", temperature)
    }

    var compactAverageTemperatureSummary: String {
        let cpuAverage = ThermalSensorProcessing.primaryCPUTemperature(from: sensors)
        let gpuAverage = ThermalSensorProcessing.primaryGPUTemperature(from: sensors)

        switch (cpuAverage, gpuAverage) {
        case let (.some(cpu), .some(gpu)):
            return String(format: "C%.0f° G%.0f°", cpu, gpu)
        case let (.some(cpu), .none):
            return String(format: "C%.0f°", cpu)
        case let (.none, .some(gpu)):
            return String(format: "G%.0f°", gpu)
        case (.none, .none):
            return "C--° G--°"
        }
    }

    var controlAverageTemp: String {
        guard let temperature = ThermalSensorProcessing.controlTemperatureSample(from: sensors)?.value else {
            return "--\u{00B0}C"
        }
        return String(format: "%.0f\u{00B0}C", temperature)
    }

    func refreshData() {
        guard !isSamplingData else { return }
        isSamplingData = true

        samplingQueue.async { [weak self] in
            guard let self else { return }
            let sampledFans = self.monitor.getFans().sorted { $0.id < $1.id }
            let sampledSensors = self.monitor.getSensors()
            let sampledControlTemperature = self.sampleControlTemperature(from: sampledSensors)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.fans != sampledFans {
                    self.fans = sampledFans
                }
                if self.sensors != sampledSensors {
                    self.sensors = sampledSensors
                }
                if let sampledControlTemperature {
                    self.controlTemperatureSample = sampledControlTemperature
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
}
