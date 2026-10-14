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

    func testReconnectGraceWindowShortensRetryInterval() {
        let reconnectedAt = Date(timeIntervalSince1970: 1_000)
        let invalidatedAt = Date(timeIntervalSince1970: 1_001)

        // Inside grace window (1.5s after reconnect): 1.0s grace interval applies
        // At 0.5s after invalidation: should still skip
        XCTAssertTrue(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: Date(timeIntervalSince1970: 1_001.5),
                retryInterval: 30,
                reconnectedAt: reconnectedAt,
                reconnectGraceWindow: 6.0,
                graceRetryInterval: 1.0
            )
        )

        // At 1.1s after invalidation: should NOT skip (1.0s grace interval passed!)
        XCTAssertFalse(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: Date(timeIntervalSince1970: 1_002.1),
                retryInterval: 30,
                reconnectedAt: reconnectedAt,
                reconnectGraceWindow: 6.0,
                graceRetryInterval: 1.0
            )
        )
    }

    func testAfterGraceWindowExpiresNormalRetryIntervalApplies() {
        let reconnectedAt = Date(timeIntervalSince1970: 1_000)
        let invalidatedAt = Date(timeIntervalSince1970: 1_010) // 10s after reconnect (grace window 6s expired)

        // 5s after invalidation: 30s base interval applies
        XCTAssertTrue(
            InvalidSensorRetryPolicy.shouldSkipRetry(
                invalidatedAt: invalidatedAt,
                now: Date(timeIntervalSince1970: 1_015),
                retryInterval: 30,
                reconnectedAt: reconnectedAt,
                reconnectGraceWindow: 6.0,
                graceRetryInterval: 1.0
            )
        )
    }
}
