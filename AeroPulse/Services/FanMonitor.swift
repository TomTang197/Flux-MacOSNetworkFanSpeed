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
    private static let smcHexChars = Array("0123456789abcdef")
    private let cpuBrand = FanMonitor.readCPUBrand()
    private let expectedPerformanceCoreCount = FanMonitor.readCoreCount("hw.perflevel0.physicalcpu")
    private let expectedEfficiencyCoreCount = FanMonitor.readCoreCount("hw.perflevel1.physicalcpu")
    private let knownPerformanceCoreKeys = Set(SMCSensorKeys.CPU.PerformanceCores.all.map(\.key))
    private let knownEfficiencyCoreKeys = Set(SMCSensorKeys.CPU.EfficiencyCores.all.map(\.key))

    private var fanPollCount = 0
    private var sensorPollCount = 0
    private var cachedFanCount: Int?
    private var cachedFanInfo: [Int: FanStaticInfo] = [:]
    private var cachedFanRPM: [Int: Int] = [:]
    private var discoveredSensorDefinitions: [SMCSensorKeys.SensorDefinition] = []
    private var extendedCoreDefinitions: [SMCSensorKeys.SensorDefinition] = []
    private var extendedGPUDefinitions: [SMCSensorKeys.SensorDefinition] = []
    private var hasScannedExtendedCoreKeys = false
    private var hasScannedExtendedGPUKeys = false
    private var lastKnownTemperatures: [String: (value: Double, sampledAt: Date)] = [:]

    private var usesM4MaxSensorCatalog: Bool {
        cpuBrand.localizedCaseInsensitiveContains("Apple M4 Max")
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

    func getFans() -> [FanInfo] {
        if cachedFanCount == nil || cachedFanInfo.isEmpty {
            refreshFanTopology()
        }

        var fans: [FanInfo] = []
        let count = cachedFanCount ?? 2

        for i in 0..<count {
            let currentReading = smc.getFanRPM(i)
            if let currentReading, currentReading > 0 {
                cachedFanRPM[i] = currentReading
            }
            guard let rpm = currentReading ?? cachedFanRPM[i] else { continue }

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
        let fallbackKeys: [(id: String, name: String)] = [
            ("TCMb", "CPU Die"),
            ("TCMz", "CPU Hotspot"),
            ("Te05", "E-Core Sensor 1"),
            ("Te0S", "E-Core Sensor 2"),
            ("Te06", "E-Core Sensor 3"),
            ("Te0T", "E-Core Sensor 4"),
            ("TC0P", "CPU Package"),
            ("mACC", "CPU Core Average"),
            ("Tp0P", "CPU Proximity"),
            ("Tp01", "CPU Core 1"),
            ("Tp02", "CPU Core 2"),
            ("Tp03", "CPU Core 3"),
            ("Tp04", "CPU Core 4"),
            ("Tg1U", "GPU Sensor 1"),
            ("Tg1k", "GPU Sensor 2"),
            ("Tg0K", "GPU Sensor 3"),
            ("Tg0L", "GPU Sensor 4"),
            ("Tg0e", "GPU Sensor 6"),
            ("Tg0j", "GPU Sensor 7"),
            ("Tg0k", "GPU Sensor 8"),
            ("TG0P", "GPU Proximity"),
            ("vACC", "GPU Average"),
            ("Tg05", "GPU Cluster 1"),
            ("Tg0b", "GPU Cluster 2"),
            ("Tg0d", "GPU Cluster 3"),
            ("Ts0P", "SSD"),
            ("TH0x", "SSD Controller"),
        ]

        var sensors: [SensorInfo] = []
        var seen = Set<String>()
        for key in fallbackKeys {
            guard ThermalSensorProcessing.isUsableCPUSensorKey(key.id, cpuBrand: cpuBrand) else {
                continue
            }
            guard let value = smc.getTemperature(key.id) else { continue }
            guard seen.insert(canonicalizedDynamicSensorKey(key.id)).inserted else { continue }
            sensors.append(
                SensorInfo(id: key.id, name: key.name, temperature: value, isEnabled: true)
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
        var definitions = supportedDefinitions(
            SMCSensorKeys.allSensors + extendedCoreDefinitions + extendedGPUDefinitions
        )
        var discoveredSensors = readSensors(from: definitions)

        let expectedCoreTotal = expectedPerformanceCoreCount + expectedEfficiencyCoreCount
        if !hasScannedExtendedCoreKeys,
            !usesM4MaxSensorCatalog,
            expectedCoreTotal > 0,
            countPotentialCoreSensors(in: discoveredSensors) < expectedCoreTotal
        {
            hasScannedExtendedCoreKeys = true
            extendedCoreDefinitions = discoverAdditionalCoreDefinitions(excluding: definitions)
            if !extendedCoreDefinitions.isEmpty {
                definitions = supportedDefinitions(
                    SMCSensorKeys.allSensors + extendedCoreDefinitions + extendedGPUDefinitions
                )
                discoveredSensors = readSensors(from: definitions)
            }
        }

        if !hasScannedExtendedGPUKeys, !usesM4MaxSensorCatalog {
            hasScannedExtendedGPUKeys = true
            extendedGPUDefinitions = discoverAdditionalGPUDefinitions(excluding: definitions)
            if !extendedGPUDefinitions.isEmpty {
                definitions = supportedDefinitions(
                    SMCSensorKeys.allSensors + extendedCoreDefinitions + extendedGPUDefinitions
                )
                discoveredSensors = readSensors(from: definitions)
            }
        }

        if discoveredSensors.isEmpty {
            definitions = supportedDefinitions(SMCSensorKeys.IntelFallback.all)
        }

        return definitions
    }

    private func supportedDefinitions(
        _ definitions: [SMCSensorKeys.SensorDefinition]
    ) -> [SMCSensorKeys.SensorDefinition] {
        definitions.filter {
            ThermalSensorProcessing.isUsableCPUSensorKey($0.key, cpuBrand: cpuBrand)
        }
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
                        sampledAt: now
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
                        sampledAt: cached.sampledAt
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

    private static let smcBase36Chars = Array("0123456789abcdefghijklmnopqrstuvwxyz")

    private func discoverAdditionalCoreDefinitions(
        excluding existingDefinitions: [SMCSensorKeys.SensorDefinition]
    ) -> [SMCSensorKeys.SensorDefinition] {
        let existingKeys = Set(existingDefinitions.map { canonicalizedDynamicSensorKey($0.key) })
        var dynamicDefinitions: [SMCSensorKeys.SensorDefinition] = []
        var seenCanonicalKeys = existingKeys

        for prefix in ["Tp", "Te"] {
            for first in ["0", "1", "2", "x"] {
                for second in FanMonitor.smcBase36Chars {
                    let key = "\(prefix)\(first)\(second)"
                    let canonicalKey = canonicalizedDynamicSensorKey(key)
                    if seenCanonicalKeys.contains(canonicalKey) { continue }
                    guard let temp = smc.getTemperature(key), temp > 0, temp < 150 else { continue }
                    seenCanonicalKeys.insert(canonicalKey)
                    dynamicDefinitions.append(
                        SMCSensorKeys.SensorDefinition(name: "CPU Core Sensor \(key)", key: key)
                    )
                }
            }
        }

        dynamicDefinitions.sort { $0.key < $1.key }
        return dynamicDefinitions
    }

    private func discoverAdditionalGPUDefinitions(
        excluding existingDefinitions: [SMCSensorKeys.SensorDefinition]
    ) -> [SMCSensorKeys.SensorDefinition] {
        let existingKeys = Set(existingDefinitions.map { canonicalizedDynamicSensorKey($0.key) })
        var dynamicDefinitions: [SMCSensorKeys.SensorDefinition] = []
        var seenCanonicalKeys = existingKeys

        for prefix in ["Tg", "TG"] {
            for first in ["0", "1", "2", "3"] {
                for second in FanMonitor.smcBase36Chars {
                    let key = "\(prefix)\(first)\(second)"
                    let canonicalKey = canonicalizedDynamicSensorKey(key)
                    if seenCanonicalKeys.contains(canonicalKey) { continue }
                    guard let temp = smc.getTemperature(key), temp > 0, temp < 150 else { continue }
                    seenCanonicalKeys.insert(canonicalKey)
                    dynamicDefinitions.append(
                        SMCSensorKeys.SensorDefinition(name: "GPU Sensor \(key)", key: key)
                    )
                }
            }
        }

        dynamicDefinitions.sort { $0.key < $1.key }
        return dynamicDefinitions
    }

    struct CPUTier {
        let name: String
        let prefix: String
        let count: Int
    }

    private static func readCPUTiers() -> [CPUTier] {
        var size = MemoryLayout<Int32>.size
        var nperflevels: Int32 = 0
        var tiers: [CPUTier] = []

        if sysctlbyname("hw.nperflevels", &nperflevels, &size, nil, 0) == 0 && nperflevels > 0 {
            for i in 0..<nperflevels {
                var count: Int32 = 0
                var nameBuf = [CChar](repeating: 0, count: 64)
                var nameSize = nameBuf.count
                sysctlbyname("hw.perflevel\(i).physicalcpu", &count, &size, nil, 0)
                sysctlbyname("hw.perflevel\(i).name", &nameBuf, &nameSize, nil, 0)
                let rawName = String(cString: nameBuf).trimmingCharacters(in: .whitespacesAndNewlines)
                guard count > 0 else { continue }

                let prefix: String
                let lowerName = rawName.lowercased()
                if lowerName.contains("super") || lowerName.contains("ultra") {
                    prefix = "S-Core"
                } else if lowerName.contains("perf") {
                    prefix = "P-Core"
                } else if lowerName.contains("effic") {
                    prefix = "E-Core"
                } else if nperflevels >= 3 {
                    prefix = i == 0 ? "S-Core" : (i == 1 ? "P-Core" : "E-Core")
                } else if nperflevels == 2 {
                    prefix = i == 0 ? "P-Core" : "E-Core"
                } else {
                    prefix = "Core"
                }

                tiers.append(CPUTier(name: rawName.isEmpty ? prefix : rawName, prefix: prefix, count: Int(count)))
            }
        }

        if tiers.isEmpty {
            let total = readCoreCount("hw.physicalcpu")
            let fallbackCount = total > 0 ? total : 8
            tiers.append(CPUTier(name: "Performance", prefix: "P-Core", count: fallbackCount))
        }

        return tiers
    }

    private func normalizeCoreSensors(_ sensors: [SensorInfo]) -> [SensorInfo] {
        sensors
            .filter { !$0.id.localizedCaseInsensitiveContains("synthetic") }
            .sorted { $0.name < $1.name }
    }

    private func normalizeGPUSensors(_ sensors: [SensorInfo]) -> [SensorInfo] {
        ThermalSensorProcessing.normalizeGPUSensors(
            sensors,
            preferM4Channels: usesM4MaxSensorCatalog
        )
    }

    private func isPotentialCoreSensor(_ sensor: SensorInfo) -> Bool {
        sensor.id.hasPrefix("Tp")
            || sensor.id.hasPrefix("Te")
            || sensor.name.contains("Core")
            || sensor.name.contains(AppStrings.pCoreFilter)
            || sensor.name.contains(AppStrings.eCoreFilter)
    }

    private func isKnownPerformanceCore(_ sensor: SensorInfo) -> Bool {
        knownPerformanceCoreKeys.contains(sensor.id) || sensor.name.contains(AppStrings.pCoreFilter)
    }

    private func isKnownEfficiencyCore(_ sensor: SensorInfo) -> Bool {
        knownEfficiencyCoreKeys.contains(sensor.id)
            || sensor.id.hasPrefix("Te")
            || sensor.name.contains(AppStrings.eCoreFilter)
    }

    private func countPotentialCoreSensors(in sensors: [SensorInfo]) -> Int {
        sensors.filter { isPotentialCoreSensor($0) }.count
    }

    private func canonicalizedDynamicSensorKey(_ key: String) -> String {
        if key.hasPrefix("TG") {
            return "Tg" + key.dropFirst(2)
        }
        return key
    }

    private static func readCoreCount(_ sysctlName: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(sysctlName, &value, &size, nil, 0)
        guard result == 0, value > 0 else { return 0 }
        return Int(value)
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
