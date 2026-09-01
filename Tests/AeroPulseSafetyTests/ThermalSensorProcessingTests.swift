import XCTest
@testable import AeroPulsePerformanceCore

final class ThermalSensorProcessingTests: XCTestCase {
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

    func testPrimaryCPUTemperatureAveragesAllUsableCPUChannels() throws {
        let sensors = [
            SensorInfo(id: "TCMb", name: "CPU Die", temperature: 40, isEnabled: true),
            SensorInfo(id: "TCMz", name: "CPU Hotspot", temperature: 40, isEnabled: true),
            SensorInfo(id: "Te05", name: "E-Core Sensor 1", temperature: 33, isEnabled: true),
            SensorInfo(id: "Te06", name: "E-Core Sensor 2", temperature: 38, isEnabled: true),
        ]

        let temperature = try XCTUnwrap(
            ThermalSensorProcessing.primaryCPUTemperature(from: sensors)
        )
        XCTAssertEqual(temperature, 37.75, accuracy: 0.001)
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
}
