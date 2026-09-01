import XCTest
@testable import AeroPulsePerformanceCore

final class PowerTelemetryProcessingTests: XCTestCase {
    func testAllTelemetryValuesAreConvertedFromMilliwatts() throws {
        let bootValue = try XCTUnwrap(
            PowerTelemetryProcessing.watts(fromMilliwatts: 161)
        )
        let normalValue = try XCTUnwrap(
            PowerTelemetryProcessing.watts(fromMilliwatts: 19_092)
        )
        let signedBatteryValue = try XCTUnwrap(
            PowerTelemetryProcessing.watts(fromMilliwatts: -5_500)
        )

        XCTAssertEqual(bootValue, 0.161, accuracy: 0.000_001)
        XCTAssertEqual(normalValue, 19.092, accuracy: 0.000_001)
        XCTAssertEqual(signedBatteryValue, -5.5, accuracy: 0.000_001)
    }

    func testSystemPowerPrefersDirectSystemLoadOverDerivedInputDifference() throws {
        let watts = try XCTUnwrap(
            PowerTelemetryProcessing.systemPowerWatts(
                systemLoadWatts: 31,
                systemPowerInWatts: 80,
                batteryPowerWatts: 20
            )
        )

        XCTAssertEqual(watts, 31, accuracy: 0.000_001)
    }

    func testSystemPowerFallsBackToInputMinusBatteryWhenLoadIsMissing() throws {
        let watts = try XCTUnwrap(
            PowerTelemetryProcessing.systemPowerWatts(
                systemLoadWatts: nil,
                systemPowerInWatts: 80,
                batteryPowerWatts: 20
            )
        )

        XCTAssertEqual(watts, 60, accuracy: 0.000_001)
    }

    func testExplicitZeroSystemLoadDoesNotUseDerivedFallback() throws {
        let watts = try XCTUnwrap(
            PowerTelemetryProcessing.systemPowerWatts(
                systemLoadWatts: 0,
                systemPowerInWatts: 20,
                batteryPowerWatts: 5
            )
        )

        XCTAssertEqual(watts, 0, accuracy: 0.000_001)
    }

    func testSubwattSystemPowerKeepsThreeDecimalPlaces() {
        XCTAssertEqual(
            PowerTelemetryProcessing.formatSystemPowerWatts(0.161),
            "0.161 W"
        )
        XCTAssertEqual(
            PowerTelemetryProcessing.formatSystemPowerWatts(19.092),
            "19.1 W"
        )
    }
}
