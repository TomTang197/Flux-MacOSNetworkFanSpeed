import XCTest
@testable import AeroPulseFanSafety

final class TemperatureFreshnessPolicyTests: XCTestCase {
    func testRejectsMissingTimestamp() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertFalse(TemperatureFreshnessPolicy.isFresh(sampledAt: nil, now: now, maximumAge: 6))
    }

    func testAcceptsSampleThroughMaximumAge() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertTrue(
            TemperatureFreshnessPolicy.isFresh(
                sampledAt: now.addingTimeInterval(-6),
                now: now,
                maximumAge: 6
            )
        )
    }

    func testRejectsStaleSample() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertFalse(
            TemperatureFreshnessPolicy.isFresh(
                sampledAt: now.addingTimeInterval(-6.001),
                now: now,
                maximumAge: 6
            )
        )
    }

    func testRejectsFutureTimestampAfterClockMovesBackwards() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertFalse(
            TemperatureFreshnessPolicy.isFresh(
                sampledAt: now.addingTimeInterval(1),
                now: now,
                maximumAge: 6
            )
        )
    }
}
