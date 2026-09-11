import XCTest
@testable import AeroPulsePerformanceCore
@testable import AeroPulseSensorCatalog

final class SMCSensorCatalogTests: XCTestCase {
    func testM4ProReportedReplacementKeysDoNotLeakIntoM4MaxCoreAssignments() throws {
        let pro = SMCSensorKeys.sensors(for: .m4(variant: .pro))
        let max = SMCSensorKeys.sensors(for: .m4(variant: .max))
        for key in ["Te06", "Te0T"] {
            XCTAssertEqual(try XCTUnwrap(pro.first { $0.key == key }).cpuTier, .efficiencyCore)
            XCTAssertEqual(try XCTUnwrap(max.first { $0.key == key }).cpuTier, .other)
        }
        XCTAssertTrue(pro.contains { $0.key == "Tp0H" && $0.cpuTier == .performanceCore })
        XCTAssertFalse(pro.contains { $0.key == "Tp0V" })
    }

    func testAdditionalM4MaxChannelsAreNotAssignedFifthOrSixthEfficiencyCoreIndices() throws {
        let sensors = SMCSensorKeys.sensors(for: .m4(variant: .max))
        for key in ["Te04", "Te0R"] {
            let sensor = try XCTUnwrap(sensors.first { $0.key == key })
            XCTAssertEqual(sensor.cpuTier, .other)
            XCTAssertNil(sensor.coreIndex)
        }
        XCTAssertFalse(sensors.contains { $0.cpuTier == .efficiencyCore && ($0.coreIndex ?? 0) > 4 })
    }

    func testIntelRetainsGPUFallbackAndDoesNotInventPhysicalCoreSensors() throws {
        let sensors = SMCSensorKeys.sensors(for: .intel)
        XCTAssertTrue(sensors.contains { $0.key == "TG0P" && $0.category == .gpu })
        XCTAssertTrue(sensors.contains { $0.key == "vACC" && $0.category == .gpu })
        XCTAssertTrue(sensors.contains { $0.key == "TG0E" && $0.category == .gpu })
        for key in ["TC0P", "TC0H"] {
            let sensor = try XCTUnwrap(sensors.first { $0.key == key })
            XCTAssertEqual(sensor.cpuTier, .other)
            XCTAssertNil(sensor.coreIndex)
        }
    }

    func testSharedKeyUsesTheCurrentChipsCoreTier() throws {
        let cases: [(AppleSiliconGeneration, CPUSensorTier)] = [
            (.m1(variant: .base), .efficiencyCore),
            (.m2(variant: .pro), .performanceCore),
            (.m4(variant: .pro), .performanceCore),
        ]
        for (generation, tier) in cases {
            let matches = SMCSensorKeys.sensors(for: generation).filter { $0.key == "Tp09" }
            XCTAssertEqual(matches.count, 1, "One hardware channel must have one definition: \(generation)")
            XCTAssertEqual(try XCTUnwrap(matches.first).cpuTier, tier)
        }
    }

    func testM4DoesNotReceiveM5SuperCoreDefinitions() {
        let sensors = SMCSensorKeys.sensors(for: .m4(variant: .pro))
        XCTAssertFalse(sensors.contains { $0.cpuTier == .superCore })
        XCTAssertFalse(sensors.contains { $0.key == "Tp0O" })
        XCTAssertFalse(sensors.contains { $0.key == "Tg1Y" })
    }

    func testM5BaseAndProMaxUseDifferentCoreCombinations() {
        let base = SMCSensorKeys.sensors(for: .m5(variant: .base))
        XCTAssertTrue(base.contains { $0.cpuTier == .superCore })
        XCTAssertFalse(base.contains { $0.cpuTier == .performanceCore })
        for variant in [AppleSiliconGeneration.Variant.pro, .max] {
            let sensors = SMCSensorKeys.sensors(for: .m5(variant: variant))
            XCTAssertTrue(sensors.contains { $0.cpuTier == .superCore })
            XCTAssertTrue(sensors.contains { $0.cpuTier == .performanceCore })
            XCTAssertFalse(sensors.contains { $0.cpuTier == .efficiencyCore })
            XCTAssertFalse(sensors.contains { $0.key == "Tp01" })
        }
    }

    func testM3CPUAndGPUChannelsAreNotClassifiedByTfPrefix() throws {
        let sensors = SMCSensorKeys.sensors(for: .m3(variant: .max))
        let cpu = try XCTUnwrap(sensors.first { $0.key == "Tf0A" })
        let gpu = try XCTUnwrap(sensors.first { $0.key == "Tf2A" })
        XCTAssertEqual(cpu.category, .cpu)
        XCTAssertEqual(cpu.cpuTier, .performanceCore)
        XCTAssertEqual(gpu.category, .gpu)
        XCTAssertNil(gpu.cpuTier)
    }

    func testM4MaxCatalogExcludesPlaceholderCoresAndKeepsLiveChannels() {
        let sensors = SMCSensorKeys.sensors(for: .m4(variant: .max))
        XCTAssertFalse(sensors.contains { $0.key.hasPrefix("Tp") })
        XCTAssertTrue(sensors.contains { $0.key == "Te05" })
        XCTAssertTrue(sensors.contains { $0.key == "Te06" })
        XCTAssertTrue(sensors.contains { $0.key == "TCMb" })
    }

    func testIntelAndUnknownChipsDoNotInheritAppleCoreLabels() {
        for generation in [AppleSiliconGeneration.intel, .unknownAppleSilicon] {
            let sensors = SMCSensorKeys.sensors(for: generation)
            XCTAssertFalse(sensors.contains { $0.key.hasPrefix("Tp") || $0.key.hasPrefix("Te") })
            XCTAssertFalse(sensors.contains { $0.cpuTier == .superCore || $0.cpuTier == .efficiencyCore })
        }
    }
}
