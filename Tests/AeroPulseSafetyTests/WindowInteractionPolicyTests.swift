import XCTest
@testable import AeroPulsePerformanceCore

final class WindowInteractionPolicyTests: XCTestCase {
    func testBeginningInteractionActivatesReducedRendering() {
        var policy = WindowInteractionPolicy(settleDelay: 0.18)

        _ = policy.beginInteraction()

        XCTAssertTrue(policy.isInteracting)
    }

    func testStaleSettleRequestCannotEndNewerInteraction() {
        var policy = WindowInteractionPolicy(settleDelay: 0.18)
        let staleToken = policy.beginInteraction()
        let currentToken = policy.beginInteraction()

        XCTAssertFalse(policy.finishInteraction(ifCurrent: staleToken))
        XCTAssertTrue(policy.isInteracting)
        XCTAssertTrue(policy.finishInteraction(ifCurrent: currentToken))
        XCTAssertFalse(policy.isInteracting)
    }

    func testDefaultSettleDelayKeepsEffectsReducedPastWindowMoveEvents() {
        let policy = WindowInteractionPolicy()

        XCTAssertEqual(policy.settleDelay, 0.18, accuracy: 0.001)
    }
}
