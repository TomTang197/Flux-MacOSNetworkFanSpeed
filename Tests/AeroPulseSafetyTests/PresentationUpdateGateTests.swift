import XCTest
@testable import AeroPulsePerformanceCore

final class PresentationUpdateGateTests: XCTestCase {
    func testUpdatePublishesWhilePresentationIsActive() {
        var gate = PresentationUpdateGate()

        XCTAssertTrue(gate.shouldPublishIncomingUpdate())
        XCTAssertFalse(gate.hasPendingUpdate)
    }

    func testUpdateIsDeferredWhilePresentationIsPaused() {
        var gate = PresentationUpdateGate()
        _ = gate.setPaused(true)

        XCTAssertFalse(gate.shouldPublishIncomingUpdate())
        XCTAssertTrue(gate.hasPendingUpdate)
    }

    func testResumingAfterDeferredUpdateRequestsOneRefresh() {
        var gate = PresentationUpdateGate()
        _ = gate.setPaused(true)
        _ = gate.shouldPublishIncomingUpdate()

        XCTAssertTrue(gate.setPaused(false))
        XCTAssertFalse(gate.hasPendingUpdate)
        XCTAssertFalse(gate.setPaused(false))
    }

    func testResumingWithoutDeferredUpdateDoesNotRequestRefresh() {
        var gate = PresentationUpdateGate()
        _ = gate.setPaused(true)

        XCTAssertFalse(gate.setPaused(false))
    }
}
