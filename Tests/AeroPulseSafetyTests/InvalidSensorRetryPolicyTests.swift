import XCTest
@testable import AeroPulsePerformanceCore

final class InvalidSensorRetryPolicyTests: XCTestCase {
    func testSkipsRetryOnlyInsideRetryWindow() {
        let invalidatedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: invalidatedAt.addingTimeInterval(29),
                retryInterval: 30
            )
        )
        XCTAssertFalse(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: invalidatedAt.addingTimeInterval(30),
                retryInterval: 30
            )
        )
    }

    func testClockMovingBackwardRetriesImmediately() {
        let invalidatedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: invalidatedAt.addingTimeInterval(-1),
                retryInterval: 30
            )
        )
    }
}
