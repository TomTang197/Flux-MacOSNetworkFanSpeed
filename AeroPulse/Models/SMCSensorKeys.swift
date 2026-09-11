//
//  SMCSensorKeys.swift
//  AeroPulse
//
//  Created by Bandan.K on 02/02/26.
//  Chip-specific SMC catalogs. A channel index is not a physical CPU core index.
//

import Foundation
#if SWIFT_PACKAGE
import AeroPulsePerformanceCore
#endif

struct SMCSensorKeys {

    // MARK: - Sensor Definition
    struct SensorDefinition: Equatable, Hashable {
        let name: String
        let key: String
        let category: SensorCategory
        let cpuTier: CPUSensorTier?
        let gpuKind: GPUSensorKind?
        let coreIndex: Int?

        init(
            name: String,
            key: String,
            category: SensorCategory = .system,
            cpuTier: CPUSensorTier? = nil,
            gpuKind: GPUSensorKind? = nil,
            coreIndex: Int? = nil
        ) {
            self.name = name
            self.key = key
            self.category = category
            self.cpuTier = cpuTier
            self.gpuKind = gpuKind
            self.coreIndex = coreIndex
        }
    }

    // MARK: - CPU Sensors
    struct CPU {
        static let coreAverage = SensorDefinition(name: "CPU Core Average", key: "mACC", category: .cpu, cpuTier: .diePackage)
        static let packageAverage = SensorDefinition(name: "CPU Package Average", key: "TC0P", category: .cpu, cpuTier: .diePackage)
        static let die = SensorDefinition(name: "CPU Die", key: "TCMb", category: .cpu, cpuTier: .diePackage)
        static let hotspot = SensorDefinition(name: "CPU Hotspot", key: "TCMz", category: .cpu, cpuTier: .diePackage)

        // MARK: - Apple Silicon M5 (base: S/E; Pro and Max: S/P)
        struct M5 {
            // Super Cores (S-Cores)
            static let superCore1 = SensorDefinition(name: "S-Core Sensor 1", key: "Tp00", category: .cpu, cpuTier: .superCore, coreIndex: 1)
            static let superCore2 = SensorDefinition(name: "S-Core Sensor 2", key: "Tp04", category: .cpu, cpuTier: .superCore, coreIndex: 2)
            static let superCore3 = SensorDefinition(name: "S-Core Sensor 3", key: "Tp08", category: .cpu, cpuTier: .superCore, coreIndex: 3)
            static let superCore4 = SensorDefinition(name: "S-Core Sensor 4", key: "Tp0C", category: .cpu, cpuTier: .superCore, coreIndex: 4)
            static let superCore5 = SensorDefinition(name: "S-Core Sensor 5", key: "Tp0G", category: .cpu, cpuTier: .superCore, coreIndex: 5)
            static let superCore6 = SensorDefinition(name: "S-Core Sensor 6", key: "Tp0K", category: .cpu, cpuTier: .superCore, coreIndex: 6)

            static let superCores: [SensorDefinition] = [
                superCore1, superCore2, superCore3, superCore4, superCore5, superCore6
            ]

            // Performance Cores (P-Cores)
            static let perfCore1 = SensorDefinition(name: "P-Core Sensor 1", key: "Tp0O", category: .cpu, cpuTier: .performanceCore, coreIndex: 1)
            static let perfCore2 = SensorDefinition(name: "P-Core Sensor 2", key: "Tp0R", category: .cpu, cpuTier: .performanceCore, coreIndex: 2)
            static let perfCore3 = SensorDefinition(name: "P-Core Sensor 3", key: "Tp0U", category: .cpu, cpuTier: .performanceCore, coreIndex: 3)
            static let perfCore4 = SensorDefinition(name: "P-Core Sensor 4", key: "Tp0X", category: .cpu, cpuTier: .performanceCore, coreIndex: 4)
            static let perfCore5 = SensorDefinition(name: "P-Core Sensor 5", key: "Tp0a", category: .cpu, cpuTier: .performanceCore, coreIndex: 5)
            static let perfCore6 = SensorDefinition(name: "P-Core Sensor 6", key: "Tp0d", category: .cpu, cpuTier: .performanceCore, coreIndex: 6)
            static let perfCore7 = SensorDefinition(name: "P-Core Sensor 7", key: "Tp0g", category: .cpu, cpuTier: .performanceCore, coreIndex: 7)
            static let perfCore8 = SensorDefinition(name: "P-Core Sensor 8", key: "Tp0j", category: .cpu, cpuTier: .performanceCore, coreIndex: 8)
            static let perfCore9 = SensorDefinition(name: "P-Core Sensor 9", key: "Tp0m", category: .cpu, cpuTier: .performanceCore, coreIndex: 9)
            static let perfCore10 = SensorDefinition(name: "P-Core Sensor 10", key: "Tp0p", category: .cpu, cpuTier: .performanceCore, coreIndex: 10)
            static let perfCore11 = SensorDefinition(name: "P-Core Sensor 11", key: "Tp0u", category: .cpu, cpuTier: .performanceCore, coreIndex: 11)
            static let perfCore12 = SensorDefinition(name: "P-Core Sensor 12", key: "Tp0y", category: .cpu, cpuTier: .performanceCore, coreIndex: 12)

            static let performanceCores: [SensorDefinition] = [
                perfCore1, perfCore2, perfCore3, perfCore4, perfCore5, perfCore6,
                perfCore7, perfCore8, perfCore9, perfCore10, perfCore11, perfCore12
            ]

            // Efficiency Cores (E-Cores)
            static let effCore1 = SensorDefinition(name: "E-Core Sensor 1", key: "Te05", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 1)
            static let effCore2 = SensorDefinition(name: "E-Core Sensor 2", key: "Te0S", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 2)
            static let effCore3 = SensorDefinition(name: "E-Core Sensor 3", key: "Te09", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 3)
            static let effCore4 = SensorDefinition(name: "E-Core Sensor 4", key: "Te0H", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 4)

            static let efficiencyCores: [SensorDefinition] = [
                effCore1, effCore2, effCore3, effCore4
            ]

            static let all: [SensorDefinition] = superCores + performanceCores + efficiencyCores
        }

        // MARK: - Apple Silicon M4 Family
        struct M4 {
            static let efficiencyCore1 = SensorDefinition(name: "E-Core Sensor 1", key: "Te05", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 1)
            static let efficiencyCore2 = SensorDefinition(name: "E-Core Sensor 2", key: "Te0S", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 2)
            static let efficiencyCore3 = SensorDefinition(name: "E-Core Sensor 3", key: "Te09", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 3)
            static let efficiencyCore4 = SensorDefinition(name: "E-Core Sensor 4", key: "Te0H", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 4)

            static let performanceCore1 = SensorDefinition(name: "P-Core Sensor 1", key: "Tp01", category: .cpu, cpuTier: .performanceCore, coreIndex: 1)
            static let performanceCore2 = SensorDefinition(name: "P-Core Sensor 2", key: "Tp05", category: .cpu, cpuTier: .performanceCore, coreIndex: 2)
            static let performanceCore3 = SensorDefinition(name: "P-Core Sensor 3", key: "Tp09", category: .cpu, cpuTier: .performanceCore, coreIndex: 3)
            static let performanceCore4 = SensorDefinition(name: "P-Core Sensor 4", key: "Tp0D", category: .cpu, cpuTier: .performanceCore, coreIndex: 4)
            static let performanceCore5 = SensorDefinition(name: "P-Core Sensor 5", key: "Tp0V", category: .cpu, cpuTier: .performanceCore, coreIndex: 5)
            static let performanceCore6 = SensorDefinition(name: "P-Core Sensor 6", key: "Tp0Y", category: .cpu, cpuTier: .performanceCore, coreIndex: 6)
            static let performanceCore7 = SensorDefinition(name: "P-Core Sensor 7", key: "Tp0b", category: .cpu, cpuTier: .performanceCore, coreIndex: 7)
            static let performanceCore8 = SensorDefinition(name: "P-Core Sensor 8", key: "Tp0e", category: .cpu, cpuTier: .performanceCore, coreIndex: 8)

            static let all: [SensorDefinition] = [
                efficiencyCore1, efficiencyCore2, efficiencyCore3, efficiencyCore4,
                performanceCore1, performanceCore2, performanceCore3, performanceCore4,
                performanceCore5, performanceCore6, performanceCore7, performanceCore8
            ]
        }

        // MARK: - Legacy / Generic Performance Cores (M1 / M2)
        struct PerformanceCores {
            static let sensor1 = SensorDefinition(name: "P-Core Sensor 1", key: "Tp01", category: .cpu, cpuTier: .performanceCore, coreIndex: 1)
            static let sensor2 = SensorDefinition(name: "P-Core Sensor 2", key: "Tp05", category: .cpu, cpuTier: .performanceCore, coreIndex: 2)
            static let sensor3 = SensorDefinition(name: "P-Core Sensor 3", key: "Tp0D", category: .cpu, cpuTier: .performanceCore, coreIndex: 3)
            static let sensor4 = SensorDefinition(name: "P-Core Sensor 4", key: "Tp0H", category: .cpu, cpuTier: .performanceCore, coreIndex: 4)
            static let sensor5 = SensorDefinition(name: "P-Core Sensor 5", key: "Tp0L", category: .cpu, cpuTier: .performanceCore, coreIndex: 5)
            static let sensor6 = SensorDefinition(name: "P-Core Sensor 6", key: "Tp0P", category: .cpu, cpuTier: .performanceCore, coreIndex: 6)
            static let sensor7 = SensorDefinition(name: "P-Core Sensor 7", key: "Tp0X", category: .cpu, cpuTier: .performanceCore, coreIndex: 7)
            static let sensor8 = SensorDefinition(name: "P-Core Sensor 8", key: "Tp0b", category: .cpu, cpuTier: .performanceCore, coreIndex: 8)
            static let sensor9 = SensorDefinition(name: "P-Core Sensor 9", key: "Tp0f", category: .cpu, cpuTier: .performanceCore, coreIndex: 9)
            static let sensor10 = SensorDefinition(name: "P-Core Sensor 10", key: "Tp0j", category: .cpu, cpuTier: .performanceCore, coreIndex: 10)
            static let sensor11 = SensorDefinition(name: "P-Core Sensor 11", key: "Tp0d", category: .cpu, cpuTier: .performanceCore, coreIndex: 11)
            static let sensor12 = SensorDefinition(name: "P-Core Sensor 12", key: "Tp0h", category: .cpu, cpuTier: .performanceCore, coreIndex: 12)

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5,
                sensor6, sensor7, sensor8, sensor9, sensor10,
                sensor11, sensor12
            ]
        }

        // MARK: - Legacy / Generic Efficiency Cores (M1 / M2)
        struct EfficiencyCores {
            static let sensor1 = SensorDefinition(name: "E-Core Sensor 1", key: "Tp09", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 1)
            static let sensor2 = SensorDefinition(name: "E-Core Sensor 2", key: "Tp0T", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 2)
            static let sensor3 = SensorDefinition(name: "E-Core Sensor 3", key: "Tp1h", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 3)
            static let sensor4 = SensorDefinition(name: "E-Core Sensor 4", key: "Tp1t", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 4)
            static let sensor5 = SensorDefinition(name: "E-Core Sensor 5", key: "Tp1p", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 5)
            static let sensor6 = SensorDefinition(name: "E-Core Sensor 6", key: "Tp1l", category: .cpu, cpuTier: .efficiencyCore, coreIndex: 6)

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5, sensor6
            ]
        }

    }

    // MARK: - GPU Sensors
    struct GPU {
        static let average = SensorDefinition(name: "GPU Average", key: "vACC", category: .gpu, gpuKind: .average)
        static let proximity = SensorDefinition(name: "GPU Proximity", key: "TG0P", category: .gpu, gpuKind: .proximity)
        static let cluster1 = SensorDefinition(name: "GPU Cluster 1", key: "Tg05", category: .gpu, gpuKind: .cluster, coreIndex: 1)
        static let cluster2 = SensorDefinition(name: "GPU Cluster 2", key: "Tg0b", category: .gpu, gpuKind: .cluster, coreIndex: 2)
        static let cluster3 = SensorDefinition(name: "GPU Cluster 3", key: "Tg0d", category: .gpu, gpuKind: .cluster, coreIndex: 3)
        static let cluster4 = SensorDefinition(name: "GPU Cluster 4", key: "Tg0f", category: .gpu, gpuKind: .cluster, coreIndex: 4)

        struct M5 {
            static let sensor1 = SensorDefinition(name: "GPU Sensor 1", key: "Tg0U", category: .gpu, gpuKind: .cluster, coreIndex: 1)
            static let sensor2 = SensorDefinition(name: "GPU Sensor 2", key: "Tg0X", category: .gpu, gpuKind: .cluster, coreIndex: 2)
            static let sensor3 = SensorDefinition(name: "GPU Sensor 3", key: "Tg0d", category: .gpu, gpuKind: .cluster, coreIndex: 3)
            static let sensor4 = SensorDefinition(name: "GPU Sensor 4", key: "Tg0g", category: .gpu, gpuKind: .cluster, coreIndex: 4)
            static let sensor5 = SensorDefinition(name: "GPU Sensor 5", key: "Tg0j", category: .gpu, gpuKind: .cluster, coreIndex: 5)
            static let sensor6 = SensorDefinition(name: "GPU Sensor 6", key: "Tg1Y", category: .gpu, gpuKind: .cluster, coreIndex: 6)
            static let sensor7 = SensorDefinition(name: "GPU Sensor 7", key: "Tg1c", category: .gpu, gpuKind: .cluster, coreIndex: 7)
            static let sensor8 = SensorDefinition(name: "GPU Sensor 8", key: "Tg1g", category: .gpu, gpuKind: .cluster, coreIndex: 8)

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5, sensor6, sensor7, sensor8,
            ]
        }

        struct M4 {
            static let sensor1 = SensorDefinition(name: "GPU Sensor 1", key: "Tg1U", category: .gpu, gpuKind: .cluster, coreIndex: 1)
            static let sensor2 = SensorDefinition(name: "GPU Sensor 2", key: "Tg1k", category: .gpu, gpuKind: .cluster, coreIndex: 2)
            static let sensor3 = SensorDefinition(name: "GPU Sensor 3", key: "Tg0K", category: .gpu, gpuKind: .cluster, coreIndex: 3)
            static let sensor4 = SensorDefinition(name: "GPU Sensor 4", key: "Tg0L", category: .gpu, gpuKind: .cluster, coreIndex: 4)
            static let sensor5 = SensorDefinition(name: "GPU Sensor 5", key: "Tg0d", category: .gpu, gpuKind: .cluster, coreIndex: 5)
            static let sensor6 = SensorDefinition(name: "GPU Sensor 6", key: "Tg0e", category: .gpu, gpuKind: .cluster, coreIndex: 6)
            static let sensor7 = SensorDefinition(name: "GPU Sensor 7", key: "Tg0j", category: .gpu, gpuKind: .cluster, coreIndex: 7)
            static let sensor8 = SensorDefinition(name: "GPU Sensor 8", key: "Tg0k", category: .gpu, gpuKind: .cluster, coreIndex: 8)

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5, sensor6, sensor7, sensor8,
            ]
        }

    }

    // MARK: - Storage Sensors
    struct Storage {
        static let ssdController = SensorDefinition(name: "SSD Controller", key: "TH0x", category: .storage)
        static let ssdDie1 = SensorDefinition(name: "SSD Die 1", key: "TH0a", category: .storage)
        static let ssdDie2 = SensorDefinition(name: "SSD Die 2", key: "TH0b", category: .storage)
        static let ssdDie3 = SensorDefinition(name: "SSD Die 3", key: "TH0c", category: .storage)
        static let nand = SensorDefinition(name: "NAND", key: "TH1A", category: .storage)

        static let all: [SensorDefinition] = [
            ssdController, ssdDie1, ssdDie2, ssdDie3, nand
        ]
    }

    // MARK: - System Sensors
    struct System {
        static let batteryDie = SensorDefinition(name: "Battery Die", key: "Tb0R", category: .system)
        static let batteryProximity = SensorDefinition(name: "Battery Proximity", key: "TB0T", category: .system)
        static let ambient = SensorDefinition(name: "Ambient", key: "TA0p", category: .system)
        static let palmRest = SensorDefinition(name: "Palm Rest", key: "pSTR", category: .system)
        static let airportProximity = SensorDefinition(name: "Airport Proximity", key: "TW0P", category: .system)
        static let mainboardProximity = SensorDefinition(name: "Mainboard Proximity", key: "Tm0P", category: .system)
        static let memoryProximity = SensorDefinition(name: "Memory Proximity", key: "TM0P", category: .system)
        static let socZone = SensorDefinition(name: "SoC Zone", key: "Ts0P", category: .system)

        static let all: [SensorDefinition] = [
            batteryDie, batteryProximity, ambient, palmRest,
            airportProximity, mainboardProximity, memoryProximity, socZone
        ]
    }

    // Key/tier mappings: https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift
    // Select one chip catalog before reading or deduplicating: keys change meaning across generations.
    static func sensors(for generation: AppleSiliconGeneration) -> [SensorDefinition] {
        let cpu: [SensorDefinition]
        let gpu: [SensorDefinition]
        switch generation {
        case .intel:
            return IntelFallback.all + [GPU.proximity, GPU.average] + Storage.all + System.all
        case .m1:
            cpu = Array(CPU.PerformanceCores.all.prefix(8)) + Array(CPU.EfficiencyCores.all.prefix(2))
            gpu = gpuChannels(["Tg05", "Tg0D", "Tg0L", "Tg0T"])
        case .m2:
            cpu = cpuChannels(["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"], tier: .performanceCore)
                + cpuChannels(["Tp1h", "Tp1t", "Tp1p", "Tp1l"], tier: .efficiencyCore)
            gpu = gpuChannels(["Tg0f", "Tg0j"])
        case .m3:
            cpu = cpuChannels(["Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"], tier: .performanceCore)
                + cpuChannels(["Te05", "Te0L", "Te0P", "Te0S"], tier: .efficiencyCore)
            gpu = gpuChannels(["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"])
        case .m4(let variant):
            let efficiency = cpuChannels(["Te05", "Te0S", "Te09", "Te0H"], tier: .efficiencyCore)
            if variant == .max {
                // The local M4 Max exposes these additional live CPU channels. Their exact
                // per-core assignment is unverified, so retain raw channel labels.
                cpu = efficiency + cpuChannels(["Te06", "Te0T", "Te04", "Te0R"], tier: .other)
            } else if variant == .pro {
                // Hardware report scoped to M4 Pro (Mac16,8); do not extrapolate
                // these per-core assignments to Max: https://github.com/exelban/stats/issues/3270
                cpu = cpuChannels(["Te05", "Te0S", "Te06", "Te0T"], tier: .efficiencyCore)
                    + cpuChannels(["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0Y", "Tp0b", "Tp0e"], tier: .performanceCore)
            } else {
                cpu = efficiency + CPU.M4.all.filter { $0.cpuTier == .performanceCore }
            }
            gpu = variant == .base
                ? gpuChannels(["Tg0G", "Tg0H", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"])
                : GPU.M4.all
        case .m5(let variant):
            switch variant {
            case .base:
                // Base M5 has S/E cores, not the Pro/Max performance tier. The Te*
                // candidates lack a verified M5 per-core mapping; expose raw labels.
                cpu = CPU.M5.superCores + cpuChannels(CPU.M5.efficiencyCores.map(\.key), tier: .other)
            case .pro, .max:
                cpu = CPU.M5.superCores + CPU.M5.performanceCores
            case .ultra:
                // No verified catalog for this variant; do not guess its topology.
                cpu = []
            }
            gpu = variant == .ultra ? [] : GPU.M5.all
        case .unknownAppleSilicon:
            cpu = []
            gpu = []
        }
        let definitions = [CPU.coreAverage, CPU.packageAverage, CPU.die, CPU.hotspot]
            + cpu + gpu + [GPU.average, GPU.proximity] + Storage.all + System.all
        var seen = Set<String>()
        return definitions.filter { seen.insert($0.key).inserted }
    }

    private static func cpuChannels(_ keys: [String], tier: CPUSensorTier) -> [SensorDefinition] {
        let prefix: String
        switch tier {
        case .superCore: prefix = "S-Core"
        case .performanceCore: prefix = "P-Core"
        case .efficiencyCore: prefix = "E-Core"
        default: prefix = "CPU"
        }
        return keys.enumerated().map { index, key in
            SensorDefinition(
                name: tier == .other ? "CPU Sensor \(key)" : "\(prefix) Sensor \(index + 1)",
                key: key, category: .cpu, cpuTier: tier,
                coreIndex: tier == .other ? nil : index + 1
            )
        }
    }

    private static func gpuChannels(_ keys: [String]) -> [SensorDefinition] {
        keys.enumerated().map { index, key in
            SensorDefinition(name: "GPU Sensor \(index + 1)", key: key, category: .gpu, gpuKind: .cluster, coreIndex: index + 1)
        }
    }

    // MARK: - Intel Fallback Sensors
    struct IntelFallback {
        static let cpuProximity = SensorDefinition(name: "CPU Proximity", key: "TC0P", category: .cpu, cpuTier: .other)
        static let cpuHeatsink = SensorDefinition(name: "CPU Heatsink", key: "TC0H", category: .cpu, cpuTier: .other)
        static let gpuPECI = SensorDefinition(name: "GPU PECI", key: "TG0E", category: .gpu, gpuKind: .average)

        static let all: [SensorDefinition] = [cpuProximity, cpuHeatsink, gpuPECI]
    }
}
