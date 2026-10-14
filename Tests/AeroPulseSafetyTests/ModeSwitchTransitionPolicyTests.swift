import XCTest
@testable import AeroPulseFanSafety

final class ModeSwitchTransitionPolicyTests: XCTestCase {
    func testInitialStateIsNotTransitioning() {
        let policy = ModeSwitchTransitionPolicy(duration: 4.0)
        XCTAssertNil(policy.remainingSeconds(now: Date()))
        XCTAssertNil(policy.targetModeRaw)
    }

    func testStartTransitionSetsTargetAndCalculatesRemaining() {
        var policy = ModeSwitchTransitionPolicy(duration: 4.0)
        let start = Date(timeIntervalSinceReferenceDate: 100)

        policy.startTransition(to: "Max", now: start)
        XCTAssertEqual(policy.targetModeRaw, "Max")
        XCTAssertEqual(policy.remainingSeconds(now: start), 4)
        XCTAssertEqual(policy.remainingSeconds(now: start.addingTimeInterval(1.1)), 3)
        XCTAssertEqual(policy.remainingSeconds(now: start.addingTimeInterval(2.1)), 2)
        XCTAssertEqual(policy.remainingSeconds(now: start.addingTimeInterval(3.1)), 1)
        XCTAssertNil(policy.remainingSeconds(now: start.addingTimeInterval(4.0)))
    }

    func testTickTransitionsUntilDurationElapsed() {
        var policy = ModeSwitchTransitionPolicy(duration: 4.0)
        let start = Date(timeIntervalSinceReferenceDate: 100)

        policy.startTransition(to: "Auto", now: start)

        let tick1 = policy.tick(now: start.addingTimeInterval(1.0))
        XCTAssertTrue(tick1.isTransitioning)
        XCTAssertEqual(tick1.remainingSeconds, 3)

        let tickFinal = policy.tick(now: start.addingTimeInterval(4.0))
        XCTAssertFalse(tickFinal.isTransitioning)
        XCTAssertNil(tickFinal.remainingSeconds)
        XCTAssertNil(policy.targetModeRaw)
    }

    func testCancelClearsTransition() {
        var policy = ModeSwitchTransitionPolicy(duration: 4.0)
        let start = Date(timeIntervalSinceReferenceDate: 100)

        policy.startTransition(to: "Rules", now: start)
        policy.cancel()

        XCTAssertNil(policy.targetModeRaw)
        XCTAssertNil(policy.remainingSeconds(now: start))
    }
}
