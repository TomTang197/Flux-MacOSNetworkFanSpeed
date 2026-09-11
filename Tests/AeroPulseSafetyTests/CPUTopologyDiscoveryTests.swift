import XCTest
@testable import AeroPulsePerformanceCore

final class CPUTopologyDiscoveryTests: XCTestCase {
    func testBaseM5TranslatesLegacyPerformanceNameToSuper() {
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 0, name: "Performance", levelCount: 2, generation: .m5(variant: .base)), .superCore)
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 1, name: "Efficiency", levelCount: 2, generation: .m5(variant: .base)), .efficiencyCore)
    }

    func testM5ProMaxTranslateLegacyPerflevelNamesToSuperAndPerformance() {
        for variant in [AppleSiliconGeneration.Variant.pro, .max] {
            XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 0, name: "Performance", levelCount: 2, generation: .m5(variant: variant)), .superCore)
            XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 1, name: "Efficiency", levelCount: 2, generation: .m5(variant: variant)), .performanceCore)
            XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 1, name: "", levelCount: 2, generation: .m5(variant: variant)), .performanceCore)
        }
    }

    func testUnknownChipDoesNotInventThreeCoreTiers() {
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 0, name: "", levelCount: 3, generation: .unknownAppleSilicon), .other)
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 1, name: "Medium", levelCount: 3, generation: .unknownAppleSilicon), .performanceCore)
    }

    func testM4RetainsPerformanceAndEfficiencyTiers() {
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 0, name: "Performance", levelCount: 2, generation: .m4(variant: .max)), .performanceCore)
        XCTAssertEqual(CPUTopologyDiscovery.sensorTier(level: 1, name: "", levelCount: 2, generation: .m4(variant: .max)), .efficiencyCore)
    }

    func testUnknownFutureGenerationIsNotMistakenForM1() {
        XCTAssertEqual(AppleSiliconGeneration.detect(brand: "Apple M10 Max"), .unknownAppleSilicon)
    }
}
