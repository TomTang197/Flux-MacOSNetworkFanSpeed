import Foundation

struct SensorTemperatureSample: Equatable {
    let value: Double
    let sampledAt: Date
}

enum ThermalSensorProcessing {
    private static let curatedM4GPUKeys = Set([
        "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k",
    ])

    static func thermalDetailColumnCount(availableWidth: Double) -> Int {
        let contentWidth = max(availableWidth - 20, 0)
        return contentWidth >= 500 ? 2 : 1
    }

    static func normalizeGPUSensors(
        _ sensors: [SensorInfo],
        reportedGPUCoreCount _: Int = 0,
        preferM4Channels: Bool? = nil
    ) -> [SensorInfo] {
        let availableGPUKeys = Set(sensors.map { canonicalGPUKey($0.id) })
        let hasM4ThermalChannels = preferM4Channels
            ?? (availableGPUKeys.contains("Tg1U") && availableGPUKeys.contains("Tg1k"))
        var normalized: [SensorInfo] = []
        normalized.reserveCapacity(sensors.count)
        var seenGPUKeys = Set<String>()

        for sensor in sensors {
            guard isGPUSensor(sensor) else {
                normalized.append(sensor)
                continue
            }

            let canonicalKey = canonicalGPUKey(sensor.id)
            if hasM4ThermalChannels, !curatedM4GPUKeys.contains(canonicalKey) {
                continue
            }
            guard seenGPUKeys.insert(canonicalKey).inserted else { continue }
            normalized.append(sensor)
        }

        normalized.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return normalized
    }

    static func isUsableCPUSensorKey(_ key: String, cpuBrand: String) -> Bool {
        let usesM4MaxCatalog = cpuBrand.localizedCaseInsensitiveContains("Apple M4 Max")
        return !(usesM4MaxCatalog && key.hasPrefix("Tp"))
    }

    static func averageCPUTemperatureSample(from sensors: [SensorInfo]) -> SensorTemperatureSample? {
        averageTemperatureSample(from: ThermalSensorGroups(sensors: sensors).cpu)
    }

    static func averageGPUTemperatureSample(from sensors: [SensorInfo]) -> SensorTemperatureSample? {
        averageTemperatureSample(from: ThermalSensorGroups(sensors: sensors).gpu)
    }

    static func controlTemperatureSample(from sensors: [SensorInfo]) -> SensorTemperatureSample? {
        let candidates = [
            averageCPUTemperatureSample(from: sensors),
            averageGPUTemperatureSample(from: sensors),
        ].compactMap { $0 }

        guard let highestAverage = candidates.max(by: { $0.value < $1.value }) else {
            return nil
        }

        if candidates.allSatisfy({ $0.value == highestAverage.value }),
           let oldestTimestamp = candidates.map(\.sampledAt).min() {
            return SensorTemperatureSample(
                value: highestAverage.value,
                sampledAt: oldestTimestamp
            )
        }
        return highestAverage
    }

    static func primaryCPUTemperature(from sensors: [SensorInfo]) -> Double? {
        averageCPUTemperatureSample(from: sensors)?.value
    }

    static func primaryGPUTemperature(from sensors: [SensorInfo]) -> Double? {
        averageGPUTemperatureSample(from: sensors)?.value
    }

    static func isGPUSensor(_ sensor: SensorInfo) -> Bool {
        sensor.id.hasPrefix("Tg")
            || sensor.id.hasPrefix("TG")
            || sensor.id == "vACC"
            || sensor.name.localizedCaseInsensitiveContains("GPU")
    }

    private static func canonicalGPUKey(_ key: String) -> String {
        if key.hasPrefix("TG") {
            return "Tg" + key.dropFirst(2)
        }
        return key
    }

    private static func averageTemperatureSample(
        from sensors: [SensorInfo]
    ) -> SensorTemperatureSample? {
        let validSensors = sensors.filter {
            $0.isEnabled && $0.temperature.isFinite && $0.temperature > 0 && $0.temperature < 150
        }
        guard !validSensors.isEmpty,
              let oldestTimestamp = validSensors.map(\.sampledAt).min() else {
            return nil
        }

        let average = validSensors.map(\.temperature).reduce(0, +) / Double(validSensors.count)
        return SensorTemperatureSample(value: average, sampledAt: oldestTimestamp)
    }
}

struct ThermalSensorGroups: Equatable {
    let cpu: [SensorInfo]
    let gpu: [SensorInfo]
    let system: [SensorInfo]

    init(sensors: [SensorInfo]) {
        var cpu: [SensorInfo] = []
        var gpu: [SensorInfo] = []
        var system: [SensorInfo] = []
        cpu.reserveCapacity(sensors.count)
        gpu.reserveCapacity(sensors.count)
        system.reserveCapacity(sensors.count)

        for sensor in sensors {
            if sensor.id.localizedCaseInsensitiveContains("synthetic") {
                continue
            }

            if ThermalSensorProcessing.isGPUSensor(sensor) {
                gpu.append(sensor)
            } else if Self.isCPUSensor(sensor) {
                cpu.append(sensor)
            } else {
                system.append(sensor)
            }
        }

        self.cpu = cpu
        self.gpu = gpu.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.system = system
    }

    private static func isCPUSensor(_ sensor: SensorInfo) -> Bool {
        let hasCPUName = sensor.name.localizedCaseInsensitiveContains("performance core")
            || sensor.name.localizedCaseInsensitiveContains("efficiency core")
            || sensor.name.localizedCaseInsensitiveContains("CPU")
            || sensor.name.localizedCaseInsensitiveContains("Core")

        return sensor.id.hasPrefix("TC")
            || sensor.id.hasPrefix("Te")
            || hasCPUName
    }
}
