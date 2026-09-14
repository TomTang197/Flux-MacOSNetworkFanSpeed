//
//  FanMonitor.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import Darwin
import Foundation

final class FanMonitor: ObservableObject {
    private let smc = SMCService.shared
    private let fanTopologyRefreshEvery = 30
    private let sensorDiscoveryRefreshEvery = 30
    private let maximumCachedTemperatureAge: TimeInterval = 6
    private let cpuBrand = FanMonitor.readCPUBrand()
    private lazy var cpuGeneration = AppleSiliconGeneration.detect(brand: cpuBrand)
    private lazy var sensorCatalog = SMCSensorKeys.sensors(for: cpuGeneration)

    private var fanPollCount = 0
    private var sensorPollCount = 0
    private var cachedFanCount: Int?
    private var cachedFanInfo: [Int: FanStaticInfo] = [:]
    private var cachedFanRPM: [Int: (rpm: Int, sampledAt: Date)] = [:]
    private let maximumCachedFanRPMAge: TimeInterval = 4
    private var discoveredSensorDefinitions: [SMCSensorKeys.SensorDefinition] = []
    private var lastKnownTemperatures: [String: (value: Double, sampledAt: Date)] = [:]

    private var usesM4MaxSensorCatalog: Bool {
        if case .m4(variant: .max) = cpuGeneration { return true }
        return cpuBrand.localizedCaseInsensitiveContains("Apple M4 Max")
    }

    private var isM5Family: Bool {
        if case .m5 = cpuGeneration { return true }
        return false
    }

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

    private struct FanStaticInfo {
        let name: String
        let minRPM: Int
        let maxRPM: Int
    }

    func clearCache() {
        cachedFanRPM.removeAll()
        lastKnownTemperatures.removeAll()
    }

    func getFans() -> [FanInfo] {
        if cachedFanCount == nil || cachedFanInfo.isEmpty {
            refreshFanTopology()
        }

        var fans: [FanInfo] = []
        let count = cachedFanCount ?? 2

        for i in 0..<count {
            let currentReading = smc.getFanRPM(i)
            if let currentReading, currentReading > 0 {
                cachedFanRPM[i] = (currentReading, Date())
            }
            let validCachedRPM: Int? = {
                guard let cached = cachedFanRPM[i] else { return nil }
                if Date().timeIntervalSince(cached.sampledAt) <= maximumCachedFanRPMAge {
                    return cached.rpm
                }
                return nil
            }()
            guard let rpm = currentReading ?? validCachedRPM else { continue }

            let info = cachedFanInfo[i] ?? FanStaticInfo(
                name: i == 0 ? "Exhaust" : "Fan \(i)",
                minRPM: 0,
                maxRPM: 6000
            )

            // Read target RPM if possible
            let targetVal = smc.readKey("F\(i)Tg")
            let targetRPM = targetVal.map { Int(smc.bytesToFloat($0)) }

            fans.append(
                FanInfo(
                    id: i,
                    name: info.name,
                    currentRPM: rpm,
                    minRPM: info.minRPM,
                    maxRPM: info.maxRPM,
                    targetRPM: targetRPM,
                    mode: .auto
                )
            )
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
        sensorPollCount += 1
        if discoveredSensorDefinitions.isEmpty || sensorPollCount >= sensorDiscoveryRefreshEvery {
            discoveredSensorDefinitions = discoverSensorDefinitions()
            sensorPollCount = 0
        }

        var sensors = readSensors(from: discoveredSensorDefinitions)
        if sensors.isEmpty {
            sensors = readEssentialFallbackSensors()
        }
        sensors = normalizeCoreSensors(sensors)
        sensors = normalizeGPUSensors(sensors)

        #if targetEnvironment(simulator)
            if sensors.isEmpty {
                sensors = [
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

        return sensors
    }

    private func readEssentialFallbackSensors() -> [SensorInfo] {
        let fallbackDefinitions = sensorCatalog

        var sensors: [SensorInfo] = []
        var seen = Set<String>()
        for def in fallbackDefinitions {
            guard ThermalSensorProcessing.isUsableCPUSensorKey(def.key, cpuBrand: cpuBrand) else {
                continue
            }
            guard let value = smc.getTemperature(def.key) else { continue }
            guard seen.insert(canonicalizedDynamicSensorKey(def.key)).inserted else { continue }
            sensors.append(
                SensorInfo(
                    id: def.key,
                    name: def.name,
                    temperature: value,
                    isEnabled: true,
                    category: def.category,
                    cpuTier: def.cpuTier,
                    gpuKind: def.gpuKind,
                    coreIndex: def.coreIndex
                )
            )
        }
        return sensors
    }

    private func refreshFanTopology() {
        let countKey = smc.readKey("FNum") ?? smc.readKey("Num ") ?? smc.readKey("#pn ")
        if let detectedCount = countKey.map({ Int($0.bytes[0]) }), detectedCount > 0 {
            cachedFanCount = detectedCount
        } else if cachedFanCount == nil {
            cachedFanCount = 2
        }

        guard let count = cachedFanCount else { return }

        var updatedInfo: [Int: FanStaticInfo] = [:]
        for i in 0..<count {
            let minVal = smc.readKey("F\(i)Mn")
            let maxVal = smc.readKey("F\(i)Mx")

            let minRPM = minVal.map { Int(smc.bytesToFloat($0)) } ?? 0
            let maxRPM = maxVal.map { Int(smc.bytesToFloat($0)) } ?? 6000

            updatedInfo[i] = FanStaticInfo(
                name: i == 0 ? "Exhaust" : "Fan \(i)",
                minRPM: minRPM,
                maxRPM: maxRPM
            )
        }

        if !updatedInfo.isEmpty {
            cachedFanInfo = updatedInfo
        }
    }

    private func discoverSensorDefinitions() -> [SMCSensorKeys.SensorDefinition] {
        // Sensor counts do not equal physical core counts. Probe the selected catalog
        // only; prefix guessing can mistake M3 Tf* GPU channels for CPU temperatures.
        sensorCatalog
    }

    private func readSensors(from definitions: [SMCSensorKeys.SensorDefinition]) -> [SensorInfo] {
        var sensors: [SensorInfo] = []
        sensors.reserveCapacity(definitions.count)
        let now = Date()

        for sensor in definitions {
            let temp = smc.getTemperature(sensor.key)
            if let temp, temp > 0, temp < 150 {
                lastKnownTemperatures[sensor.key] = (temp, now)
                sensors.append(
                    SensorInfo(
                        id: sensor.key,
                        name: sensor.name,
                        temperature: temp,
                        isEnabled: true,
                        sampledAt: now,
                        category: sensor.category,
                        cpuTier: sensor.cpuTier,
                        gpuKind: sensor.gpuKind,
                        coreIndex: sensor.coreIndex
                    )
                )
            } else if let cached = lastKnownTemperatures[sensor.key],
                      TemperatureFreshnessPolicy.isFresh(
                          sampledAt: cached.sampledAt,
                          now: now,
                          maximumAge: maximumCachedTemperatureAge
                      ) {
                sensors.append(
                    SensorInfo(
                        id: sensor.key,
                        name: sensor.name,
                        temperature: cached.value,
                        isEnabled: true,
                        sampledAt: cached.sampledAt,
                        category: sensor.category,
                        cpuTier: sensor.cpuTier,
                        gpuKind: sensor.gpuKind,
                        coreIndex: sensor.coreIndex
                    )
                )
            } else {
                lastKnownTemperatures.removeValue(forKey: sensor.key)
            }
        }

        var uniqueSensors: [SensorInfo] = []
        uniqueSensors.reserveCapacity(sensors.count)
        var seenKeys = Set<String>()
        for sensor in sensors {
            let canonicalID = canonicalizedDynamicSensorKey(sensor.id)
            if seenKeys.insert(canonicalID).inserted {
                uniqueSensors.append(sensor)
            }
        }

        uniqueSensors.sort { $0.name < $1.name }
        return uniqueSensors
    }

    func discoverCPUTiers() -> [CPUTierInfo] {
        CPUTopologyDiscovery.discoverTiers()
    }

    private func normalizeCoreSensors(_ sensors: [SensorInfo]) -> [SensorInfo] {
        sensors
            .filter { !$0.id.localizedCaseInsensitiveContains("synthetic") }
            .sorted { $0.name < $1.name }
    }

    private func normalizeGPUSensors(_ sensors: [SensorInfo]) -> [SensorInfo] {
        ThermalSensorProcessing.normalizeGPUSensors(
            sensors,
            preferM4Channels: usesM4MaxSensorCatalog,
            preferM5Channels: isM5Family
        )
    }

    private func canonicalizedDynamicSensorKey(_ key: String) -> String {
        if key.hasPrefix("TG") {
            return "Tg" + key.dropFirst(2)
        }
        return key
    }

    private static func readCPUBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0,
              size > 1 else {
            return ""
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }

}
