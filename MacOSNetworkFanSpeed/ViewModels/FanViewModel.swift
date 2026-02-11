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
    @Published var isMonitoring: Bool = false

    private let monitor = FanMonitor()
    private let pollingQueue = DispatchQueue(label: "com.bandan.me.fan.monitor", qos: .utility)
    private var timer: AnyCancellable?
    private var refreshInterval: Double = 2.0
    private var sensorPollTick: Int = 0
    private var isUpdatingStats = false
    private let sensorPollingStride = 2

    init() {
        self._isMonitoring = Published(wrappedValue: true)

        // Defer side effects until next run loop to avoid publishing warnings during init.
        DispatchQueue.main.async { [weak self] in
            if self?.isMonitoring == true {
                self?.startMonitoring()
            }
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
        guard !isUpdatingStats else { return }
        isUpdatingStats = true

        let shouldRefreshSensors = sensors.isEmpty || (sensorPollTick % sensorPollingStride == 0)
        sensorPollTick += 1

        pollingQueue.async { [weak self] in
            guard let self = self else { return }
            let newFans = self.monitor.getFans()
            let newSensors = shouldRefreshSensors ? self.monitor.getSensors() : nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.fans != newFans { self.fans = newFans }
                if let newSensors, self.sensors != newSensors {
                    self.sensors = newSensors
                }
                self.isUpdatingStats = false
            }
        }
    }

    var primaryFanRPM: String {
        guard let firstFan = fans.first else { return "0 \(AppStrings.rpmUnit)" }
        return "\(firstFan.currentRPM) \(AppStrings.rpmUnit)"
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
}
