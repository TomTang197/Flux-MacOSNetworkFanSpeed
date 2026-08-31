import XCTest
@testable import AeroPulsePerformanceCore

final class ThermalSensorProcessingTests: XCTestCase {
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

        XCTAssertEqual(groups.cpu.map(\.id), ["Tp01"])
        XCTAssertEqual(groups.gpu.map(\.id), ["Tg05"])
        XCTAssertEqual(Set(groups.system.map(\.id)), Set(["TC0P", "Ts0P"]))
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
}
