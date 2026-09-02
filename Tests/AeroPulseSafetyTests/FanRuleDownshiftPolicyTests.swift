import XCTest
@testable import AeroPulseFanSafety

final class FanRuleDownshiftPolicyTests: XCTestCase {
    private let baseline = FanRuleControlTarget(ruleIndex: nil, speedPercentage: 0)
    private let low = FanRuleControlTarget(ruleIndex: 0, speedPercentage: 30)
    private let medium = FanRuleControlTarget(ruleIndex: 1, speedPercentage: 50)
    private let high = FanRuleControlTarget(ruleIndex: 2, speedPercentage: 75)

    func testRulesActivationCanStartAtHardwareMinimumThenRaiseImmediately() {
        var policy = FanRuleDownshiftPolicy(initialTarget: baseline)

        let decision = policy.decision(
            requestedTarget: medium,
            now: Date(timeIntervalSinceReferenceDate: 100),
            delayEnabled: true,
            delay: 10
        )

        XCTAssertEqual(decision.target, medium)
        XCTAssertNil(decision.remainingDelay)
    }

    func testLowerTargetIsHeldUntilConfiguredDelayHasFullyElapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var policy = FanRuleDownshiftPolicy(initialTarget: high)

        let initial = policy.decision(
            requestedTarget: low,
            now: start,
            delayEnabled: true,
            delay: 10
        )
        let beforeDeadline = policy.decision(
            requestedTarget: low,
            now: start.addingTimeInterval(9.9),
            delayEnabled: true,
            delay: 10
        )
        let atDeadline = policy.decision(
            requestedTarget: low,
            now: start.addingTimeInterval(10),
            delayEnabled: true,
            delay: 10
        )

        XCTAssertEqual(initial.target, high)
        XCTAssertEqual(initial.remainingDelay ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(beforeDeadline.target, high)
        XCTAssertEqual(beforeDeadline.remainingDelay ?? -1, 0.1, accuracy: 0.001)
        XCTAssertEqual(atDeadline.target, low)
        XCTAssertNil(atDeadline.remainingDelay)
    }

    func testTemperatureRecoveryCancelsPendingDownshiftAndRestartsFullDelayLater() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var policy = FanRuleDownshiftPolicy(initialTarget: medium)

        _ = policy.decision(
            requestedTarget: low,
            now: start,
            delayEnabled: true,
            delay: 10
        )
        let recovered = policy.decision(
            requestedTarget: medium,
            now: start.addingTimeInterval(5),
            delayEnabled: true,
            delay: 10
        )
        let lowerAgain = policy.decision(
            requestedTarget: low,
            now: start.addingTimeInterval(11),
            delayEnabled: true,
            delay: 10
        )

        XCTAssertEqual(recovered.target, medium)
        XCTAssertNil(recovered.remainingDelay)
        XCTAssertEqual(lowerAgain.target, medium)
        XCTAssertEqual(lowerAgain.remainingDelay ?? -1, 10, accuracy: 0.001)
    }

    func testFurtherCoolingKeepsOriginalObservationStartAndUsesLatestLowerTarget() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var policy = FanRuleDownshiftPolicy(initialTarget: high)

        _ = policy.decision(
            requestedTarget: medium,
            now: start,
            delayEnabled: true,
            delay: 10
        )
        let colder = policy.decision(
            requestedTarget: baseline,
            now: start.addingTimeInterval(8),
            delayEnabled: true,
            delay: 10
        )
        let atDeadline = policy.decision(
            requestedTarget: baseline,
            now: start.addingTimeInterval(10),
            delayEnabled: true,
            delay: 10
        )

        XCTAssertEqual(colder.target, high)
        XCTAssertEqual(colder.remainingDelay ?? -1, 2, accuracy: 0.001)
        XCTAssertEqual(atDeadline.target, baseline)
        XCTAssertNil(atDeadline.remainingDelay)
    }

    func testDisabledDelayAppliesLowerTargetImmediately() {
        var policy = FanRuleDownshiftPolicy(initialTarget: high)

        let decision = policy.decision(
            requestedTarget: low,
            now: Date(timeIntervalSinceReferenceDate: 100),
            delayEnabled: false,
            delay: 10
        )

        XCTAssertEqual(decision.target, low)
        XCTAssertNil(decision.remainingDelay)
    }

    func testCancellingPendingDownshiftPreservesCurrentTarget() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var policy = FanRuleDownshiftPolicy(initialTarget: high)
        _ = policy.decision(
            requestedTarget: low,
            now: start,
            delayEnabled: true,
            delay: 10
        )

        policy.cancelPendingDownshift()
        let restarted = policy.decision(
            requestedTarget: low,
            now: start.addingTimeInterval(9),
            delayEnabled: true,
            delay: 10
        )

        XCTAssertEqual(restarted.target, high)
        XCTAssertEqual(restarted.remainingDelay ?? -1, 10, accuracy: 0.001)
    }
}
