import XCTest
@testable import FanHelperSafety

final class FanModeWritePlannerTests: XCTestCase {
    func testAppleSiliconManualModeEnablesFtstBeforePerFanMode() {
        XCTAssertEqual(
            FanModeWritePlanner.plan(manual: true, hasFtst: true),
            [.writeFtst(1), .wait(seconds: 3), .writeMode(1)]
        )
    }

    func testPerFanModeWithoutFtstWritesOnlyMode() {
        XCTAssertEqual(
            FanModeWritePlanner.plan(manual: true, hasFtst: false),
            [.writeMode(1)]
        )
    }

    func testAutomaticModeDoesNotEnableFtst() {
        XCTAssertEqual(
            FanModeWritePlanner.plan(manual: false, hasFtst: true),
            [.writeMode(0)]
        )
    }

    func testBatchTargetPlanEnablesGlobalFtstOnlyOnceBeforeAllFans() {
        XCTAssertEqual(
            FanTargetBatchWritePlanner.plan(
                targets: [(index: 0, rpm: 5777), (index: 1, rpm: 5777)],
                hasFtst: true
            ),
            [
                .writeFtst(1),
                .wait(seconds: 3),
                .writeMode(index: 0, value: 1),
                .writeTarget(index: 0, rpm: 5777),
                .writeMode(index: 1, value: 1),
                .writeTarget(index: 1, rpm: 5777),
            ]
        )
    }

    func testThermalManagerModeRetryIsBounded() {
        XCTAssertTrue(FanModeUnlockRetryPolicy.shouldRetry(afterAttempt: 1))
        XCTAssertTrue(FanModeUnlockRetryPolicy.shouldRetry(afterAttempt: 299))
        XCTAssertFalse(FanModeUnlockRetryPolicy.shouldRetry(afterAttempt: 300))
    }
}
