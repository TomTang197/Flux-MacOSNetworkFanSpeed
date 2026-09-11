import XCTest
@testable import AeroPulsePerformanceCore

final class ThermalSensorProcessingTests: XCTestCase {
    func testExplicitProximityMetadataIsNotOverriddenByPackageKeyAlias() {
        let sensor = SensorInfo(id: "TC0P", name: "CPU Proximity", temperature: 48, isEnabled: true, category: .cpu, cpuTier: .other)
        XCTAssertEqual(sensor.shortName, "Prox")
        XCTAssertTrue(ThermalSensorGroups(sensors: [sensor]).diePackageSensors.isEmpty)
    }

    func testM5KeepsGenericGPUFallbackWhenCuratedChannelsAreUnavailable() {
        let sensors = [SensorInfo(id: "vACC", name: "GPU Average", temperature: 52, isEnabled: true)]
        XCTAssertEqual(ThermalSensorProcessing.normalizeGPUSensors(sensors, preferM5Channels: true), sensors)
    }

    func testUnreadableCuratedGPUChannelDoesNotSuppressValidFallback() throws {
        for (temperature, enabled) in [(Double.nan, true), (55.0, false)] {
            let sensors = [
                SensorInfo(id: "Tg0U", name: "GPU Sensor 1", temperature: temperature, isEnabled: enabled),
                SensorInfo(id: "vACC", name: "GPU Average", temperature: 52, isEnabled: true),
            ]
            let normalized = ThermalSensorProcessing.normalizeGPUSensors(sensors, preferM5Channels: true)
            XCTAssertEqual(try XCTUnwrap(ThermalSensorProcessing.primaryGPUTemperature(from: normalized)), 52)
        }
    }

    func testExplicitM5CatalogTakesPrecedenceOverM4KeyOverlap() {
        let sensors = ["Tg1U", "Tg1k", "Tg0U", "Tg1Y"].map {
            SensorInfo(id: $0, name: "GPU Sensor \($0)", temperature: 50, isEnabled: true)
        }
        let normalized = ThermalSensorProcessing.normalizeGPUSensors(sensors, preferM5Channels: true)
        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg0U", "Tg1Y"]))
    }

    func testCoreAveragePreservesRealFortyDegreesAndItsTimestamp() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let sensors = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 90, isEnabled: true, sampledAt: now.addingTimeInterval(-5)),
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 40, isEnabled: true, sampledAt: now),
            SensorInfo(id: "Tp00", name: "S-Core Sensor 1", temperature: 50, isEnabled: true, sampledAt: now.addingTimeInterval(-1)),
        ]
        let sample = try XCTUnwrap(ThermalSensorProcessing.averageCPUTemperatureSample(from: sensors))
        XCTAssertEqual(sample.value, 45)
        XCTAssertEqual(sample.sampledAt, now.addingTimeInterval(-1))
        XCTAssertEqual(ThermalSensorGroups(sensors: sensors).diePackageSensors.count, 1)
    }

    func testInvalidOrDisabledCoresFallBackToPackageForControl() throws {
        let sensors = [
            SensorInfo(id: "Tp00", name: "S-Core Sensor 1", temperature: .nan, isEnabled: true),
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 55, isEnabled: false),
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 62, isEnabled: true),
            SensorInfo(id: "vACC", name: "GPU Average", temperature: 48, isEnabled: true),
        ]
        XCTAssertEqual(try XCTUnwrap(ThermalSensorProcessing.controlTemperatureSample(from: sensors)).value, 62)
    }

    func testEfficiencyOnlyReadingsUseDieCoverageWhenPerformanceCoresAreMissing() throws {
        let sensors = [
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 39, isEnabled: true),
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 50, isEnabled: true),
            SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 74, isEnabled: true),
        ]
        XCTAssertEqual(try XCTUnwrap(ThermalSensorProcessing.primaryCPUTemperature(from: sensors)), 62)
        XCTAssertEqual(try XCTUnwrap(ThermalSensorProcessing.primaryCPUTemperature(from: Array(sensors.prefix(1)))), 39)
    }

    func testThermalDetailUsesOneColumnWhenNarrowAndNeverMoreThanTwo() {
        XCTAssertEqual(
            ThermalSensorProcessing.thermalDetailColumnCount(availableWidth: 400),
            1
        )
        XCTAssertEqual(
            ThermalSensorProcessing.thermalDetailColumnCount(availableWidth: 700),
            2
        )
        XCTAssertEqual(
            ThermalSensorProcessing.thermalDetailColumnCount(availableWidth: 1_600),
            2
        )
    }

    func testNormalizeGPUSensorsKeepsOnlyUniqueHardwareReadings() {
        let sensors = [
            SensorInfo(id: "Tg05", name: "GPU Cluster 1", temperature: 44, isEnabled: true),
            SensorInfo(id: "TG05", name: "GPU Cluster duplicate", temperature: 45, isEnabled: true),
            SensorInfo(id: "vACC", name: "GPU Average", temperature: 43, isEnabled: true),
            SensorInfo(id: "TC0P", name: "CPU Package", temperature: 51, isEnabled: true),
        ]

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(
            sensors,
            reportedGPUCoreCount: 40
        )

        XCTAssertEqual(normalized.filter { ThermalSensorProcessing.isGPUSensor($0) }.count, 2)
        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg05", "vACC", "TC0P"]))
        XCTAssertFalse(normalized.contains { $0.id.hasPrefix("TgCore") })
        XCTAssertFalse(normalized.contains { $0.name.hasPrefix("GPU Core Sensor ") })
    }

    func testGroupsPartitionEverySensorExactlyOnce() {
        let sensors = [
            SensorInfo(id: "Tp01", name: "P-Core Sensor 1", temperature: 52, isEnabled: true),
            SensorInfo(id: "TC0P", name: "CPU Package", temperature: 50, isEnabled: true),
            SensorInfo(id: "Tg05", name: "GPU Cluster 1", temperature: 45, isEnabled: true),
            SensorInfo(id: "Ts0P", name: "SSD", temperature: 38, isEnabled: true),
        ]

        let groups = ThermalSensorGroups(sensors: sensors)

        XCTAssertEqual(Set(groups.cpu.map(\.id)), Set(["Tp01", "TC0P"]))
        XCTAssertEqual(groups.gpu.map(\.id), ["Tg05"])
        XCTAssertEqual(groups.system.map(\.id), ["Ts0P"])
        XCTAssertEqual(groups.cpu.count + groups.gpu.count + groups.system.count, sensors.count)
    }

    func testGroupsRecognizeRawCPUSensorsWhenNormalizedCoresAreAbsent() {
        let sensors = [
            SensorInfo(id: "TC0P", name: "CPU Package", temperature: 50, isEnabled: true),
            SensorInfo(id: "Ts0P", name: "SSD", temperature: 38, isEnabled: true),
        ]

        let groups = ThermalSensorGroups(sensors: sensors)

        XCTAssertEqual(groups.cpu.map(\.id), ["TC0P"])
        XCTAssertEqual(groups.system.map(\.id), ["Ts0P"])
    }

    func testGroupsDiscardSyntheticCPUReadingsWhenRealDieSensorsExist() {
        let sensors = [
            SensorInfo(id: "P-CoreSynthetic1", name: "P-Core Sensor 1", temperature: 40, isEnabled: true),
            SensorInfo(id: "P-CoreSynthetic2", name: "P-Core Sensor 2", temperature: 40, isEnabled: true),
            SensorInfo(id: "E-CoreSynthetic1", name: "E-Core Sensor 1", temperature: 40, isEnabled: true),
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 52, isEnabled: true),
            SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 64, isEnabled: true),
            SensorInfo(id: "Ts0P", name: "SSD", temperature: 38, isEnabled: true),
        ]

        let groups = ThermalSensorGroups(sensors: sensors)

        XCTAssertEqual(Set(groups.cpu.map(\.id)), Set(["TCMb", "TCMz"]))
        XCTAssertFalse(groups.cpu.contains { $0.id.localizedCaseInsensitiveContains("synthetic") })
        XCTAssertEqual(groups.system.map(\.id), ["Ts0P"])
    }

    func testGroupsKeepLegitimateFortyDegreeCPUSensorsWithoutPlatformEvidence() {
        let placeholderKeys = ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0Y"]
        let coreSensors = placeholderKeys.enumerated().map { index, key in
            SensorInfo(
                id: key,
                name: "P-Core Sensor \(index + 1)",
                temperature: 40,
                isEnabled: true
            )
        }
        let live = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 52, isEnabled: true),
            SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 64, isEnabled: true),
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 48, isEnabled: true),
            SensorInfo(id: "Te0S", name: "E-Core Sensor 2", temperature: 51, isEnabled: true),
        ]

        let groups = ThermalSensorGroups(sensors: coreSensors + live)

        XCTAssertEqual(Set(groups.cpu.map(\.id)), Set(placeholderKeys + ["TCMb", "TCMz", "Te05", "Te0S"]))
    }

    func testM4MaxCatalogRejectsLegacyPlaceholderKeysWithoutAffectingOtherChips() {
        XCTAssertFalse(
            ThermalSensorProcessing.isUsableCPUSensorKey("Tp01", cpuBrand: "Apple M4 Max")
        )
        XCTAssertTrue(
            ThermalSensorProcessing.isUsableCPUSensorKey("TCMb", cpuBrand: "Apple M4 Max")
        )
        XCTAssertTrue(
            ThermalSensorProcessing.isUsableCPUSensorKey("Tp01", cpuBrand: "Apple M4 Pro")
        )
        XCTAssertTrue(
            ThermalSensorProcessing.isUsableCPUSensorKey("Tp01", cpuBrand: "Apple M2 Max")
        )
    }

    func testControlTemperatureUsesHigherSubsystemAverageAndPreservesOldestTimestamp() throws {
        let hardwareTimestamp = Date(timeIntervalSinceReferenceDate: 1_000)
        let sensors = [
            SensorInfo(
                id: "TCMb",
                name: "CPU Die",
                temperature: 40,
                isEnabled: true,
                sampledAt: hardwareTimestamp
            ),
            SensorInfo(
                id: "TCMz",
                name: "CPU Hotspot",
                temperature: 60,
                isEnabled: true,
                sampledAt: hardwareTimestamp.addingTimeInterval(-1)
            ),
            SensorInfo(
                id: "Tg1U",
                name: "GPU Sensor 1",
                temperature: 54,
                isEnabled: true,
                sampledAt: hardwareTimestamp.addingTimeInterval(-2)
            ),
            SensorInfo(
                id: "Tg1k",
                name: "GPU Sensor 2",
                temperature: 58,
                isEnabled: true,
                sampledAt: hardwareTimestamp.addingTimeInterval(-3)
            ),
        ]

        let cpuAverage = try XCTUnwrap(
            ThermalSensorProcessing.averageCPUTemperatureSample(from: sensors)
        )
        let gpuAverage = try XCTUnwrap(
            ThermalSensorProcessing.averageGPUTemperatureSample(from: sensors)
        )
        let controlSample = try XCTUnwrap(
            ThermalSensorProcessing.controlTemperatureSample(from: sensors)
        )

        XCTAssertEqual(cpuAverage.value, 50, accuracy: 0.001)
        XCTAssertEqual(cpuAverage.sampledAt, hardwareTimestamp.addingTimeInterval(-1))
        XCTAssertEqual(gpuAverage.value, 56, accuracy: 0.001)
        XCTAssertEqual(gpuAverage.sampledAt, hardwareTimestamp.addingTimeInterval(-3))
        XCTAssertEqual(controlSample.value, 56, accuracy: 0.001)
        XCTAssertEqual(controlSample.sampledAt, hardwareTimestamp.addingTimeInterval(-3))
    }

    func testPrimaryCPUTemperatureUsesCoreChannelsWithoutDoubleCountingDie() throws {
        let sensors = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 40, isEnabled: true),
            SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 40, isEnabled: true),
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 33, isEnabled: true),
            SensorInfo(id: "Tp01", name: "P-Core Sensor 1", temperature: 38, isEnabled: true),
        ]

        let temperature = try XCTUnwrap(
            ThermalSensorProcessing.primaryCPUTemperature(from: sensors)
        )
        XCTAssertEqual(temperature, 35.5, accuracy: 0.001)
    }

    func testPrimaryCPUTemperatureFallsBackToDieWhenCoreChannelsAreUnavailable() throws {
        let sensors = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 53, isEnabled: true),
            SensorInfo(id: "Ts0P", name: "SSD", temperature: 38, isEnabled: true),
        ]

        let temperature = try XCTUnwrap(
            ThermalSensorProcessing.primaryCPUTemperature(from: sensors)
        )
        XCTAssertEqual(temperature, 53, accuracy: 0.001)
    }

    func testPrimaryGPUTemperatureAveragesGPUChannelsOnly() throws {
        let sensors = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 60, isEnabled: true),
            SensorInfo(id: "Tg1U", name: "GPU Sensor 1", temperature: 42, isEnabled: true),
            SensorInfo(id: "Tg1k", name: "GPU Sensor 2", temperature: 46, isEnabled: true),
        ]

        let temperature = try XCTUnwrap(
            ThermalSensorProcessing.primaryGPUTemperature(from: sensors)
        )
        XCTAssertEqual(temperature, 44, accuracy: 0.001)
    }

    func testGPUIdentityTakesPrecedenceOverGenericCoreName() {
        let sensor = SensorInfo(
            id: "vACC",
            name: "GPU Core Average",
            temperature: 48,
            isEnabled: true
        )

        let groups = ThermalSensorGroups(sensors: [sensor])

        XCTAssertTrue(groups.cpu.isEmpty)
        XCTAssertEqual(groups.gpu.map(\.id), ["vACC"])
    }

    func testNormalizeGPUSensorsUsesCuratedM4ChannelsInsteadOfEveryDiscoveredKey() {
        let curatedKeys = ["Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"]
        let curated = curatedKeys.enumerated().map { index, key in
            SensorInfo(
                id: key,
                name: "GPU \(index + 1)",
                temperature: Double(45 + index),
                isEnabled: true
            )
        }
        let discoveredExtras = (0..<17).map { index in
            SensorInfo(
                id: String(format: "Tg%02x", index + 32),
                name: "GPU Sensor \(index + 9)",
                temperature: Double(40 + index),
                isEnabled: true
            )
        }
        let cpu = SensorInfo(id: "TCMb", name: "CPU Die", temperature: 52, isEnabled: true)

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(
            curated + discoveredExtras + [cpu]
        )

        XCTAssertEqual(
            Set(normalized.filter { ThermalSensorProcessing.isGPUSensor($0) }.map(\.id)),
            Set(curatedKeys)
        )
        XCTAssertEqual(normalized.filter { ThermalSensorProcessing.isGPUSensor($0) }.count, 8)
        XCTAssertTrue(normalized.contains { $0.id == "TCMb" })
    }

    func testSingleM4GPUAnchorDoesNotDiscardOtherwiseValidChannels() {
        let sensors = [
            SensorInfo(id: "Tg1U", name: "GPU 1", temperature: 45, isEnabled: true),
            SensorInfo(id: "Tg05", name: "GPU Legacy", temperature: 46, isEnabled: true),
            SensorInfo(id: "vACC", name: "GPU Average", temperature: 47, isEnabled: true),
        ]

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(sensors)

        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg1U", "Tg05", "vACC"]))
    }

    func testExplicitM4MaxCatalogUsesCuratedChannelsWithPartialDiscovery() {
        let sensors = [
            SensorInfo(id: "Tg1U", name: "GPU 1", temperature: 45, isEnabled: true),
            SensorInfo(id: "Tg0K", name: "GPU 3", temperature: 46, isEnabled: true),
            SensorInfo(id: "Tg05", name: "GPU Legacy", temperature: 47, isEnabled: true),
            SensorInfo(id: "vACC", name: "GPU Average", temperature: 48, isEnabled: true),
        ]

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(
            sensors,
            preferM4Channels: true
        )

        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg1U", "Tg0K"]))
    }

    func testGPUKeySuffixCaseRemainsDistinct() {
        let sensors = [
            SensorInfo(id: "Tg0K", name: "GPU 1", temperature: 45, isEnabled: true),
            SensorInfo(id: "Tg0k", name: "GPU 2", temperature: 49, isEnabled: true),
        ]

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(sensors)

        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg0K", "Tg0k"]))
    }

    func testAppleSiliconGenerationDetection() {
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M1 Max"), .m1(variant: .max))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M2 Pro"), .m2(variant: .pro))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M3"), .m3(variant: .base))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M4 Max"), .m4(variant: .max))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M4 Pro"), .m4(variant: .pro))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M5 Pro"), .m5(variant: .pro))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M5 Max"), .m5(variant: .max))
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Intel(R) Core(TM) i7"), .intel)
    }

    func testM5KeyUsabilityAcceptsAllTiers() {
        let m5Brand = "Apple M5 Pro"
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("Tp00", cpuBrand: m5Brand))
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("Tp0O", cpuBrand: m5Brand))
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("Te05", cpuBrand: m5Brand))
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("TC0P", cpuBrand: m5Brand))

        // M4 Max rejects Tp* dummy keys
        let m4MaxBrand = "Apple M4 Max"
        XCTAssertFalse(ThermalSensorProcessing.isUsableCPUSensorKey("Tp00", cpuBrand: m4MaxBrand))
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("Te05", cpuBrand: m4MaxBrand))
        XCTAssertTrue(ThermalSensorProcessing.isUsableCPUSensorKey("TCMb", cpuBrand: m4MaxBrand))
    }

    func testM5ThreeTierPartitioningAndOrdering() {
        let s1 = SensorInfo(id: "Tp00", name: "S-Core Sensor 1", temperature: 48, isEnabled: true, category: .cpu, cpuTier: .superCore, coreIndex: 1)
        let s2 = SensorInfo(id: "Tp04", name: "S-Core Sensor 2", temperature: 50, isEnabled: true, category: .cpu, cpuTier: .superCore, coreIndex: 2)
        let p1 = SensorInfo(id: "Tp0O", name: "P-Core Sensor 1", temperature: 45, isEnabled: true, category: .cpu, cpuTier: .performanceCore, coreIndex: 1)
        let p2 = SensorInfo(id: "Tp0R", name: "P-Core Sensor 2", temperature: 46, isEnabled: true, category: .cpu, cpuTier: .performanceCore, coreIndex: 2)
        let e1 = SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 42, isEnabled: true, category: .cpu, cpuTier: .efficiencyCore, coreIndex: 1)
        let e2 = SensorInfo(id: "Te0S", name: "E-Core Sensor 2", temperature: 41, isEnabled: true, category: .cpu, cpuTier: .efficiencyCore, coreIndex: 2)
        let die = SensorInfo(id: "TCMb", name: "CPU Die", temperature: 49, isEnabled: true, category: .cpu, cpuTier: .diePackage)
        let gpu = SensorInfo(id: "Tg0U", name: "GPU Sensor 1", temperature: 44, isEnabled: true, category: .gpu, gpuKind: .cluster, coreIndex: 1)
        let ssd = SensorInfo(id: "Ts0P", name: "SSD", temperature: 38, isEnabled: true, category: .storage)

        let all = [die, e2, p2, s2, e1, p1, s1, gpu, ssd]
        let groups = ThermalSensorGroups(sensors: all)

        XCTAssertEqual(groups.superCores.map(\.id), ["Tp00", "Tp04"])
        XCTAssertEqual(groups.performanceCores.map(\.id), ["Tp0O", "Tp0R"])
        XCTAssertEqual(groups.efficiencyCores.map(\.id), ["Te05", "Te0S"])
        XCTAssertEqual(groups.diePackageSensors.map(\.id), ["TCMb"])
        XCTAssertEqual(groups.gpu.map(\.id), ["Tg0U"])
        XCTAssertEqual(groups.system.map(\.id), ["Ts0P"])
    }

    func testSensorShortNameInference() {
        let s = SensorInfo(id: "Tp00", name: "S-Core Sensor 1", temperature: 45, isEnabled: true)
        let p = SensorInfo(id: "Tp0O", name: "P-Core Sensor 1", temperature: 45, isEnabled: true)
        let e = SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 45, isEnabled: true)
        let g = SensorInfo(id: "Tg0U", name: "GPU Sensor 1", temperature: 45, isEnabled: true)
        let die = SensorInfo(id: "TCMb", name: "CPU Die", temperature: 45, isEnabled: true)
        let hotspot = SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 45, isEnabled: true)
        let pkg = SensorInfo(id: "TC0P", name: "CPU Package", temperature: 45, isEnabled: true)

        XCTAssertEqual(s.shortName, "S1")
        XCTAssertEqual(p.shortName, "P1")
        XCTAssertEqual(e.shortName, "E1")
        XCTAssertEqual(g.shortName, "G1")
        XCTAssertEqual(die.shortName, "Die")
        XCTAssertEqual(hotspot.shortName, "Hotspot")
        XCTAssertEqual(pkg.shortName, "Pkg")
    }

    func testM5GPUNormalization() {
        let m5Sensors = [
            SensorInfo(id: "Tg0U", name: "GPU 1", temperature: 45, isEnabled: true),
            SensorInfo(id: "Tg1Y", name: "GPU 6", temperature: 46, isEnabled: true),
            SensorInfo(id: "Tg0X", name: "GPU 2", temperature: 47, isEnabled: true),
            SensorInfo(id: "Tg99", name: "GPU Dummy", temperature: 40, isEnabled: true),
        ]

        let normalized = ThermalSensorProcessing.normalizeGPUSensors(m5Sensors, preferM5Channels: true)
        XCTAssertEqual(Set(normalized.map(\.id)), Set(["Tg0U", "Tg1Y", "Tg0X"]))
    }
}
