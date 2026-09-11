import Foundation

struct SensorTemperatureSample: Equatable {
    let value: Double
    let sampledAt: Date
}

enum ThermalSensorProcessing {
    private static let curatedM4GPUKeys = Set([
        "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k",
    ])

    private static let curatedM5GPUKeys = Set([
        "Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g",
    ])

    static func thermalDetailColumnCount(availableWidth: Double) -> Int {
        let contentWidth = max(availableWidth - 20, 0)
        return contentWidth >= 500 ? 2 : 1
    }

    static func normalizeGPUSensors(
        _ sensors: [SensorInfo],
        reportedGPUCoreCount _: Int = 0,
        preferM4Channels: Bool? = nil,
        preferM5Channels: Bool? = nil
    ) -> [SensorInfo] {
        let availableGPUKeys = Set(sensors.filter { isGPUSensor($0) && isUsableTemperature($0) }
            .map { canonicalGPUKey($0.id) })
        let hasM4ThermalChannels = preferM4Channels
            ?? (availableGPUKeys.contains("Tg1U") && availableGPUKeys.contains("Tg1k"))
        let hasM5ThermalChannels = preferM5Channels
            ?? (availableGPUKeys.contains("Tg0U") && availableGPUKeys.contains("Tg1Y"))
        let preferredKeys = hasM5ThermalChannels ? curatedM5GPUKeys
            : (hasM4ThermalChannels ? curatedM4GPUKeys : nil)
        // Keep average/proximity fallback readings if none of the preferred channels
        // can be read. Prefer one catalog, never the intersection of two chip tables.
        let activeKeys = preferredKeys.flatMap {
            $0.isDisjoint(with: availableGPUKeys) ? nil : $0
        }

        var normalized: [SensorInfo] = []
        normalized.reserveCapacity(sensors.count)
        var seenGPUKeys = Set<String>()

        for sensor in sensors {
            guard isGPUSensor(sensor) else {
                normalized.append(sensor)
                continue
            }

            let canonicalKey = canonicalGPUKey(sensor.id)
            if let activeKeys, !activeKeys.contains(canonicalKey) {
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
        let gen = AppleSiliconGeneration.detect(brand: cpuBrand)
        if case .m4(let variant) = gen, variant == .max, key.hasPrefix("Tp") {
            return false
        }
        return true
    }

    static func averageCPUTemperatureSample(from sensors: [SensorInfo]) -> SensorTemperatureSample? {
        let cpu = ThermalSensorGroups(sensors: sensors).cpu
        let cores = cpu.filter {
            $0.cpuTier == .superCore || $0.cpuTier == .performanceCore || $0.cpuTier == .efficiencyCore
        }
        let coreAverage = averageTemperatureSample(from: cores)
        let hasPerformanceReading = cores.contains {
            ($0.cpuTier == .performanceCore || $0.cpuTier == .superCore) && isUsableTemperature($0)
        }
        // Do not average aggregates back into core channels. When P/S sensors are
        // missing (observed on M4 Max), prefer die/package coverage over E-only
        // readings; otherwise load on performance cores can go unrepresented.
        if hasPerformanceReading { return coreAverage }
        return averageTemperatureSample(from: cpu.filter { $0.cpuTier == .diePackage })
            ?? coreAverage
            ?? averageTemperatureSample(from: cpu)
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
        if sensor.category == .gpu || sensor.gpuKind != nil {
            return true
        }
        if sensor.category == .cpu || sensor.category == .storage || sensor.category == .system {
            return false
        }
        return sensor.id.hasPrefix("Tg")
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
        let validSensors = sensors.filter(isUsableTemperature)
        guard !validSensors.isEmpty,
              let oldestTimestamp = validSensors.map(\.sampledAt).min() else {
            return nil
        }

        let average = validSensors.map(\.temperature).reduce(0, +) / Double(validSensors.count)
        return SensorTemperatureSample(value: average, sampledAt: oldestTimestamp)
    }

    private static func isUsableTemperature(_ sensor: SensorInfo) -> Bool {
        sensor.isEnabled && sensor.temperature.isFinite && sensor.temperature > 0 && sensor.temperature < 150
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

    var superCores: [SensorInfo] {
        cpu.filter { $0.cpuTier == .superCore }
           .sorted { ($0.coreIndex ?? 0) < ($1.coreIndex ?? 0) }
    }

    var performanceCores: [SensorInfo] {
        cpu.filter { $0.cpuTier == .performanceCore }
           .sorted { ($0.coreIndex ?? 0) < ($1.coreIndex ?? 0) }
    }

    var efficiencyCores: [SensorInfo] {
        cpu.filter { $0.cpuTier == .efficiencyCore }
           .sorted { ($0.coreIndex ?? 0) < ($1.coreIndex ?? 0) }
    }

    var diePackageSensors: [SensorInfo] {
        cpu.filter { $0.cpuTier == .diePackage }
           .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var otherCPUSensors: [SensorInfo] {
        cpu.filter { sensor in
            sensor.cpuTier != .superCore
                && sensor.cpuTier != .performanceCore
                && sensor.cpuTier != .efficiencyCore
                && sensor.cpuTier != .diePackage
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func cpuSensors(for tier: CPUSensorTier) -> [SensorInfo] {
        cpu.filter { $0.cpuTier == tier }
    }

    private static func isCPUSensor(_ sensor: SensorInfo) -> Bool {
        if sensor.category == .cpu || sensor.cpuTier != nil {
            return true
        }
        if sensor.category == .gpu || sensor.category == .storage || sensor.category == .system {
            return false
        }
        let hasCPUName = sensor.name.localizedCaseInsensitiveContains("performance core")
            || sensor.name.localizedCaseInsensitiveContains("efficiency core")
            || sensor.name.localizedCaseInsensitiveContains("super core")
            || sensor.name.localizedCaseInsensitiveContains("s-core")
            || sensor.name.localizedCaseInsensitiveContains("p-core")
            || sensor.name.localizedCaseInsensitiveContains("e-core")
            || sensor.name.localizedCaseInsensitiveContains("CPU")
            || sensor.name.localizedCaseInsensitiveContains("Core")

        return sensor.id.hasPrefix("TC")
            || sensor.id.hasPrefix("Te")
            || sensor.id.hasPrefix("Tp")
            || sensor.id.hasPrefix("Tf")
            || hasCPUName
    }
}
