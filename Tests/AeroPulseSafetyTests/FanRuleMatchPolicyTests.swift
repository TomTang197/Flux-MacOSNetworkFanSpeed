import XCTest
@testable import AeroPulseFanSafety

final class FanRuleMatchPolicyTests: XCTestCase {
    func testValidTemperatureBelowEveryThresholdReturnsStandby() {
        XCTAssertEqual(
            FanRuleMatchPolicy.decision(
                temperature: 44.9,
                thresholds: [45, 60, 72, 82]
            ),
            .standby
        )
    }

    func testTemperatureMatchingSeveralThresholdsReturnsHighestThresholdIndex() {
        XCTAssertEqual(
            FanRuleMatchPolicy.decision(
                temperature: 73,
                thresholds: [45, 60, 72, 82]
            ),
            .matched(index: 2)
        )
    }
}
