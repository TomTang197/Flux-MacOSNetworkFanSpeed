//
//  FanMonitor.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import Foundation

class FanMonitor: ObservableObject {
    private let smc = SMCService.shared

    struct FanData {
        let rpm: Int
        let minRPM: Int
        let maxRPM: Int
    }

    struct SensorData {
        let name: String
        let key: String
        let temperature: Double
    }

    func getFans() -> [FanInfo] {
        var fans: [FanInfo] = []

        // Check key "Num " or "#pn " for count
        let countKey = smc.readKey("Num ") ?? smc.readKey("#pn ")
        let count = countKey.map { Int($0.bytes[0]) } ?? 2  // Default to 2 if count fails

        for i in 0..<count {
            if let rpm = smc.getFanRPM(i) {
                // Try to get min/max
                let minVal = smc.readKey("F\(i)Mn")
                let maxVal = smc.readKey("F\(i)Mx")

                let minRPM = minVal.map { Int(smc.bytesToFloat($0)) } ?? 0
                let maxRPM = maxVal.map { Int(smc.bytesToFloat($0)) } ?? 6000

                fans.append(
                    FanInfo(
                        id: i,
                        name: i == 0 ? "Exhaust" : "Fan \(i)",
                        currentRPM: rpm,
                        minRPM: minRPM,
                        maxRPM: maxRPM,
                        mode: .auto
                    )
                )
            }
        }

        // If still empty and in simulator, add mock
        #if targetEnvironment(simulator)
            if fans.isEmpty {
                fans = [
                    FanInfo(id: 0, name: "Exhaust", currentRPM: 1250, minRPM: 1200, maxRPM: 6000, mode: .auto)
                ]
            }
        #endif

        return fans
    }

    func getSensors() -> [SensorInfo] {
        // Use centralized sensor key definitions
        let keys = SMCSensorKeys.allSensors

        print("🌡️ FanMonitor: Starting sensor enumeration...")
        var sensors: [SensorInfo] = []
        for sensor in keys {
            if let temp = smc.getTemperature(sensor.key) {
                if temp > 0 && temp < 150 {
                    sensors.append(
                        SensorInfo(id: sensor.key, name: sensor.name, temperature: temp, isEnabled: true)
                    )
                } else {
                    print("  ⚠️ Sensor filtered (out of range): \(sensor.name) (\(sensor.key)) = \(temp)°C")
                }
            }
        }

        // Fallback: If no M-series specific keys found, try common Intel ones
        if sensors.isEmpty {
            let intelKeys = SMCSensorKeys.IntelFallback.all
            for sensor in intelKeys {
                if let temp = smc.getTemperature(sensor.key) {
                    sensors.append(
                        SensorInfo(id: sensor.key, name: sensor.name, temperature: temp, isEnabled: true)
                    )
                }
            }
        }

        // Filter out duplicates (if keys were shared)
        var uniqueSensors: [SensorInfo] = []
        var seenKeys = Set<String>()
        for sensor in sensors {
            if !seenKeys.contains(sensor.id) {
                uniqueSensors.append(sensor)
                seenKeys.insert(sensor.id)
            }
        }

        uniqueSensors.sort { $0.name < $1.name }

        #if targetEnvironment(simulator)
            if uniqueSensors.isEmpty {
                uniqueSensors = [
                    SensorInfo(id: "TW0P", name: "Airport Proximity", temperature: 99.7, isEnabled: true),
                    SensorInfo(id: "TC0P", name: "CPU Core Average", temperature: 95.6, isEnabled: true),
                    SensorInfo(
                        id: "Tp09",
                        name: "CPU Performance Core 1",
                        temperature: 97.4,
                        isEnabled: true
                    ),
                    SensorInfo(id: "TG0P", name: "GPU Cluster Area", temperature: 93.9, isEnabled: true),
                    SensorInfo(id: "Ts0P", name: "APPLE SSD", temperature: 97.0, isEnabled: true),
                ]
            }
        #endif

        return uniqueSensors
    }

}
