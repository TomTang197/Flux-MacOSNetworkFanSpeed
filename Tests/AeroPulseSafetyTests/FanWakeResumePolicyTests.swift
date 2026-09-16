import XCTest
@testable import AeroPulseFanSafety

final class FanWakeResumePolicyTests: XCTestCase {
    func testWillSleepWhenCustomActiveRecordsIntentAndRequestsSystemAuto() {
        var policy = FanWakeResumePolicy()
        let action = policy.handleWillSleep(isCustomModeActive: true)

        XCTAssertEqual(action, .restoreSystemAuto)
        XCTAssertEqual(policy.state, .sleeping)
        XCTAssertEqual(policy.targetToResume, .customRules)
    }

    func testWillSleepWhenCustomInactiveDoesNotRecordResumeIntent() {
        var policy = FanWakeResumePolicy()
        let action = policy.handleWillSleep(isCustomModeActive: false)

        XCTAssertEqual(action, .restoreSystemAuto)
        XCTAssertEqual(policy.state, .sleeping)
        XCTAssertNil(policy.targetToResume)
    }

    func testWakeFromSleepWithoutResumeIntentTransitionsDirectlyToActive() {
        var policy = FanWakeResumePolicy()
        _ = policy.handleWillSleep(isCustomModeActive: false)
        policy.handleDidWake()

        XCTAssertEqual(policy.state, .active)
        let action = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(action, .none)
    }

    func testWakeFromSleepWithCustomIntentRequiresTwoConsecutiveFreshSamples() {
        var policy = FanWakeResumePolicy(requiredFreshSamples: 2)
        _ = policy.handleWillSleep(isCustomModeActive: true)
        policy.handleDidWake()

        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 0))

        // Sample 1: Fresh
        let action1 = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(action1, .none)
        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 1))

        // Sample 2: Fresh -> Should trigger resume!
        let action2 = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(action2, .resume(.customRules))
        XCTAssertEqual(policy.state, .active)
        XCTAssertNil(policy.targetToResume)
    }

    func testStaleSampleResetsConsecutiveFreshCount() {
        var policy = FanWakeResumePolicy(requiredFreshSamples: 2)
        _ = policy.handleWillSleep(isCustomModeActive: true)
        policy.handleDidWake()

        // Sample 1: Fresh
        _ = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 1))

        // Sample 2: Stale (e.g. pre-sleep cached reading) -> resets
        let action2 = policy.handleSample(isFresh: false, helperInstalled: true)
        XCTAssertEqual(action2, .none)
        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 0))

        // Sample 3: Fresh -> count is 1
        _ = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 1))

        // Sample 4: Fresh -> count is 2 -> Resume!
        let action4 = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(action4, .resume(.customRules))
    }

    func testMissingHelperPreventsResume() {
        var policy = FanWakeResumePolicy(requiredFreshSamples: 2)
        _ = policy.handleWillSleep(isCustomModeActive: true)
        policy.handleDidWake()

        // Fresh but helper missing
        let action = policy.handleSample(isFresh: true, helperInstalled: false)
        XCTAssertEqual(action, .none)
        XCTAssertEqual(policy.state, .waking(consecutiveFreshSamples: 0))
    }

    func testUserOverrideCancelsPendingResume() {
        var policy = FanWakeResumePolicy(requiredFreshSamples: 2)
        _ = policy.handleWillSleep(isCustomModeActive: true)
        policy.handleDidWake()

        policy.handleUserOverride()
        XCTAssertEqual(policy.state, .active)
        XCTAssertNil(policy.targetToResume)

        let action = policy.handleSample(isFresh: true, helperInstalled: true)
        XCTAssertEqual(action, .none)
    }
}
