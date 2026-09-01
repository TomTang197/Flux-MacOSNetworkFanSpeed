import XCTest
@testable import AeroPulseFanSafety

final class FanTargetSubmissionGateTests: XCTestCase {
    func testDuplicateTargetsAreSuppressedWhileInFlightAndAfterSuccess() throws {
        var gate = FanTargetSubmissionGate()
        let targets = [0: 1_792, 1: 1_792]

        let submission = try XCTUnwrap(gate.request(targets))
        XCTAssertNil(gate.request(targets))
        XCTAssertNil(gate.complete(submission, succeeded: true))
        XCTAssertNil(gate.request(targets))
    }

    func testChangedTargetsWaitForInFlightSubmissionThenStart() throws {
        var gate = FanTargetSubmissionGate()
        let lowTargets = [0: 1_792, 1: 1_792]
        let highTargets = [0: 3_120, 1: 3_120]

        let lowSubmission = try XCTUnwrap(gate.request(lowTargets))
        XCTAssertNil(gate.request(highTargets))

        let highSubmission = try XCTUnwrap(gate.complete(lowSubmission, succeeded: true))
        XCTAssertEqual(highSubmission.targets, highTargets)
    }

    func testOnlyLatestPendingTargetsAreSubmitted() throws {
        var gate = FanTargetSubmissionGate()
        let lowTargets = [0: 1_792, 1: 1_792]
        let middleTargets = [0: 3_120, 1: 3_120]
        let highTargets = [0: 4_891, 1: 4_891]

        let lowSubmission = try XCTUnwrap(gate.request(lowTargets))
        XCTAssertNil(gate.request(middleTargets))
        XCTAssertNil(gate.request(highTargets))

        let nextSubmission = try XCTUnwrap(gate.complete(lowSubmission, succeeded: true))
        XCTAssertEqual(nextSubmission.targets, highTargets)
    }

    func testFailedCurrentSubmissionClearsPendingWorkAndAllowsReacquisition() throws {
        var gate = FanTargetSubmissionGate()
        let lowTargets = [0: 1_792, 1: 1_792]
        let highTargets = [0: 3_120, 1: 3_120]

        let lowSubmission = try XCTUnwrap(gate.request(lowTargets))
        XCTAssertNil(gate.request(highTargets))
        XCTAssertNil(gate.complete(lowSubmission, succeeded: false))

        XCTAssertNotNil(gate.request(highTargets))
    }

    func testOldFailureCannotInvalidateRepeatedNewerTargets() throws {
        var gate = FanTargetSubmissionGate()
        let lowTargets = [0: 1_792, 1: 1_792]
        let highTargets = [0: 3_120, 1: 3_120]

        let firstLowSubmission = try XCTUnwrap(gate.request(lowTargets))
        XCTAssertNil(gate.request(highTargets))
        let highSubmission = try XCTUnwrap(
            gate.complete(firstLowSubmission, succeeded: true)
        )
        XCTAssertNil(gate.request(lowTargets))
        let secondLowSubmission = try XCTUnwrap(
            gate.complete(highSubmission, succeeded: true)
        )

        XCTAssertNil(gate.complete(firstLowSubmission, succeeded: false))
        XCTAssertNil(gate.request(lowTargets))
        XCTAssertEqual(secondLowSubmission.targets, lowTargets)
    }

    func testResetInvalidatesOldCompletionWithSameTargets() throws {
        var gate = FanTargetSubmissionGate()
        let targets = [0: 4_891, 1: 4_891]

        let oldSubmission = try XCTUnwrap(gate.request(targets))
        gate.reset()
        let newSubmission = try XCTUnwrap(gate.request(targets))

        XCTAssertNil(gate.complete(oldSubmission, succeeded: false))
        XCTAssertNil(gate.request(targets))
        XCTAssertNotEqual(oldSubmission.id, newSubmission.id)
    }
}
