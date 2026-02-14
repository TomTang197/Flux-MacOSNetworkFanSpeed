//
//  SMCSensorKeys.swift
//  AeroPulse
//
//  Created by Bandan.K on 02/02/26.
//

import Foundation

struct SMCSensorKeys {

    // MARK: - Sensor Definition
    struct SensorDefinition {
        let name: String
        let key: String
    }

    // MARK: - CPU Sensors
    struct CPU {
        static let coreAverage = SensorDefinition(name: "CPU Core Average", key: "mACC")
        static let packageAverage = SensorDefinition(name: "CPU Package Average", key: "TC0P")

        // Performance Cores (P-cores) - Extended for M2/M3 Ultra
        struct PerformanceCores {
            static let sensor1 = SensorDefinition(name: "P-Core Sensor 1", key: "Tp09")
            static let sensor2 = SensorDefinition(name: "P-Core Sensor 2", key: "Tp0b")
            static let sensor3 = SensorDefinition(name: "P-Core Sensor 3", key: "Tp0d")
            static let sensor4 = SensorDefinition(name: "P-Core Sensor 4", key: "Tp0f")
            static let sensor5 = SensorDefinition(name: "P-Core Sensor 5", key: "Tp0h")
            static let sensor6 = SensorDefinition(name: "P-Core Sensor 6", key: "Tp0j")
            static let sensor7 = SensorDefinition(name: "P-Core Sensor 7", key: "Tp0l")
            static let sensor8 = SensorDefinition(name: "P-Core Sensor 8", key: "Tp0n")
            static let sensor9 = SensorDefinition(name: "P-Core Sensor 9", key: "Tp0p")
            static let sensor10 = SensorDefinition(name: "P-Core Sensor 10", key: "Tp0r")
            static let sensor11 = SensorDefinition(name: "P-Core Sensor 11", key: "Tp0t")
            static let sensor12 = SensorDefinition(name: "P-Core Sensor 12", key: "Tp0v")
            static let sensor13 = SensorDefinition(name: "P-Core Sensor 13", key: "Tp0x")
            static let sensor14 = SensorDefinition(name: "P-Core Sensor 14", key: "Tp0z")
            static let sensor15 = SensorDefinition(name: "P-Core Sensor 15", key: "Tp11")
            static let sensor16 = SensorDefinition(name: "P-Core Sensor 16", key: "Tp13")
            static let sensor17 = SensorDefinition(name: "P-Core Sensor 17", key: "Tp15")
            static let sensor18 = SensorDefinition(name: "P-Core Sensor 18", key: "Tp17")
            static let sensor19 = SensorDefinition(name: "P-Core Sensor 19", key: "Tp19")
            static let sensor20 = SensorDefinition(name: "P-Core Sensor 20", key: "Tp1b")

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5,
                sensor6, sensor7, sensor8, sensor9, sensor10,
                sensor11, sensor12, sensor13, sensor14, sensor15,
                sensor16, sensor17, sensor18, sensor19, sensor20,
            ]
        }

        // Efficiency Cores (E-cores) - Extended for larger chips
        struct EfficiencyCores {
            static let sensor1 = SensorDefinition(name: "E-Core Sensor 1", key: "Tp01")
            static let sensor2 = SensorDefinition(name: "E-Core Sensor 2", key: "Tp02")
            static let sensor3 = SensorDefinition(name: "E-Core Sensor 3", key: "Tp03")
            static let sensor4 = SensorDefinition(name: "E-Core Sensor 4", key: "Tp04")
            static let sensor5 = SensorDefinition(name: "E-Core Sensor 5", key: "Tp05")
            static let sensor6 = SensorDefinition(name: "E-Core Sensor 6", key: "Tp06")
            static let sensor7 = SensorDefinition(name: "E-Core Sensor 7", key: "Tp07")
            static let sensor8 = SensorDefinition(name: "E-Core Sensor 8", key: "Tp08")
            static let sensor9 = SensorDefinition(name: "E-Core Sensor 9", key: "Tp0a")
            static let sensor10 = SensorDefinition(name: "E-Core Sensor 10", key: "Tp0c")
            static let sensor11 = SensorDefinition(name: "E-Core Sensor 11", key: "Tp0e")
            static let sensor12 = SensorDefinition(name: "E-Core Sensor 12", key: "Tp0g")
            static let sensor13 = SensorDefinition(name: "E-Core Sensor 13", key: "Tp0i")
            static let sensor14 = SensorDefinition(name: "E-Core Sensor 14", key: "Tp0k")
            static let sensor15 = SensorDefinition(name: "E-Core Sensor 15", key: "Tp0m")
            static let sensor16 = SensorDefinition(name: "E-Core Sensor 16", key: "Tp0o")

            static let all: [SensorDefinition] = [
                sensor1, sensor2, sensor3, sensor4, sensor5,
                sensor6, sensor7, sensor8, sensor9, sensor10,
                sensor11, sensor12, sensor13, sensor14, sensor15,
                sensor16,
            ]
        }

        static let all: [SensorDefinition] =
            [coreAverage, packageAverage] + PerformanceCores.all + EfficiencyCores.all
    }

    // MARK: - GPU Sensors
    struct GPU {
        static let average = SensorDefinition(name: "GPU Average", key: "vACC")
        static let cluster1 = SensorDefinition(name: "GPU Cluster 1", key: "Tg05")
        static let cluster2 = SensorDefinition(name: "GPU Cluster 2", key: "Tg0b")
        static let cluster3 = SensorDefinition(name: "GPU Cluster 3", key: "Tg0d")
        static let cluster4 = SensorDefinition(name: "GPU Cluster 4", key: "Tg0f")
        static let proximity = SensorDefinition(name: "GPU Proximity", key: "TG0P")

        static let all: [SensorDefinition] = [
            average, cluster1, cluster2, cluster3, cluster4, proximity,
        ]
    }

    // MARK: - Storage Sensors
    struct Storage {
        static let ssdController = SensorDefinition(name: "SSD Controller", key: "TH0x")
        static let ssdDie1 = SensorDefinition(name: "SSD Die 1", key: "TH0A")
        static let ssdDie2 = SensorDefinition(name: "SSD Die 2", key: "TH0B")
        static let ssdDie3 = SensorDefinition(name: "SSD Die 3", key: "TH0C")
        static let nand = SensorDefinition(name: "NAND", key: "TH1A")
        static let appleSSD = SensorDefinition(name: "APPLE SSD", key: "Ts0P")

        static let all: [SensorDefinition] = [
            ssdController, ssdDie1, ssdDie2, ssdDie3, nand, appleSSD,
        ]
    }

    // MARK: - System Sensors
    struct System {
        static let powerManagerDie = SensorDefinition(name: "Power Manager Die", key: "Tp0C")
        static let powerSupplyProximity = SensorDefinition(
            name: "Power Supply Proximity",
            key: "Tp0P"
        )
        static let batteryDie = SensorDefinition(name: "Battery Die", key: "Tb0R")
        static let batteryProximity = SensorDefinition(name: "Battery Proximity", key: "TB0T")
        static let ambient = SensorDefinition(name: "Ambient", key: "TA0p")
        static let palmRest = SensorDefinition(name: "Palm Rest", key: "pSTR")
        static let airportProximity = SensorDefinition(name: "Airport Proximity", key: "TW0P")
        static let mainboardProximity = SensorDefinition(name: "Mainboard Proximity", key: "Tm0P")
        static let memoryProximity = SensorDefinition(name: "Memory Proximity", key: "TM0P")

        static let all: [SensorDefinition] = [
            powerManagerDie, powerSupplyProximity, batteryDie, batteryProximity,
            ambient, palmRest, airportProximity, mainboardProximity, memoryProximity,
        ]
    }

    // MARK: - All Sensors Combined
    static let allSensors: [SensorDefinition] =
        CPU.all + GPU.all + Storage.all + System.all

    // MARK: - Intel Fallback Sensors
    struct IntelFallback {
        static let cpuCore1 = SensorDefinition(name: "CPU Core 1", key: "TC0P")
        static let cpuCore2 = SensorDefinition(name: "CPU Core 2", key: "TC0H")
        static let gpuPECI = SensorDefinition(name: "GPU PECI", key: "TG0E")

        static let all: [SensorDefinition] = [cpuCore1, cpuCore2, gpuPECI]
    }
}
