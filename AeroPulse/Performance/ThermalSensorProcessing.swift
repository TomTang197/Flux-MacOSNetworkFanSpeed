import Foundation

enum ThermalSensorProcessing {
    static func normalizeGPUSensors(
        _ sensors: [SensorInfo],
        reportedGPUCoreCount _: Int = 0
    ) -> [SensorInfo] {
        var normalized: [SensorInfo] = []
        normalized.reserveCapacity(sensors.count)
        var seenGPUKeys = Set<String>()

        for sensor in sensors {
            guard isGPUSensor(sensor) else {
                normalized.append(sensor)
                continue
            }

            let canonicalKey = canonicalGPUKey(sensor.id)
            guard seenGPUKeys.insert(canonicalKey).inserted else { continue }
            normalized.append(sensor)
        }

        normalized.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return normalized
    }

    static func isGPUSensor(_ sensor: SensorInfo) -> Bool {
        sensor.id.hasPrefix("Tg")
            || sensor.id.hasPrefix("TG")
            || sensor.id == "vACC"
            || sensor.name.localizedCaseInsensitiveContains("GPU")
    }

    private static func canonicalGPUKey(_ key: String) -> String {
        if key.hasPrefix("Tg") || key.hasPrefix("TG") {
            return key.lowercased()
        }
        return key
    }
}

struct ThermalSensorGroups: Equatable {
    let cpu: [SensorInfo]
    let gpu: [SensorInfo]
    let system: [SensorInfo]

    init(sensors: [SensorInfo]) {
        let hasNormalizedCPU = sensors.contains { Self.isNormalizedCPUSensor($0) }
        var cpu: [SensorInfo] = []
        var gpu: [SensorInfo] = []
        var system: [SensorInfo] = []
        cpu.reserveCapacity(sensors.count)
        gpu.reserveCapacity(sensors.count)
        system.reserveCapacity(sensors.count)

        for sensor in sensors {
            if Self.isCPUSensor(sensor, hasNormalizedCPU: hasNormalizedCPU) {
                cpu.append(sensor)
            } else if ThermalSensorProcessing.isGPUSensor(sensor) {
                gpu.append(sensor)
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

    private static func isNormalizedCPUSensor(_ sensor: SensorInfo) -> Bool {
        sensor.name.hasPrefix("S-Core Sensor ")
            || sensor.name.hasPrefix("P-Core Sensor ")
            || sensor.name.hasPrefix("E-Core Sensor ")
            || sensor.name.hasPrefix("CPU Core Sensor ")
    }

    private static func isCPUSensor(_ sensor: SensorInfo, hasNormalizedCPU: Bool) -> Bool {
        if hasNormalizedCPU {
            return isNormalizedCPUSensor(sensor)
        }

        return sensor.name.localizedCaseInsensitiveContains("performance core")
            || sensor.name.localizedCaseInsensitiveContains("efficiency core")
            || sensor.name.localizedCaseInsensitiveContains("CPU")
            || sensor.name.localizedCaseInsensitiveContains("Core")
    }
}
