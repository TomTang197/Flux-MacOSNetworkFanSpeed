import XCTest
@testable import FanHelperSafety

final class FanCommandValidatorTests: XCTestCase {
    func testRejectsFanIndexOutsideDetectedTopology() {
        XCTAssertFalse(FanCommandValidator.isValidFanIndex(-1, fanCount: 2))
        XCTAssertTrue(FanCommandValidator.isValidFanIndex(0, fanCount: 2))
        XCTAssertTrue(FanCommandValidator.isValidFanIndex(1, fanCount: 2))
        XCTAssertFalse(FanCommandValidator.isValidFanIndex(2, fanCount: 2))
    }

    func testRejectsFanIndexWhenTopologyIsUnavailable() {
        XCTAssertFalse(FanCommandValidator.isValidFanIndex(0, fanCount: nil))
        XCTAssertFalse(FanCommandValidator.isValidFanIndex(16, fanCount: nil))
    }

    func testRejectsRPMOutsideKnownFanBounds() {
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(1_199, minimum: 1_200, maximum: 6_000))
        XCTAssertTrue(FanCommandValidator.isValidTargetRPM(1_200, minimum: 1_200, maximum: 6_000))
        XCTAssertTrue(FanCommandValidator.isValidTargetRPM(6_000, minimum: 1_200, maximum: 6_000))
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(6_001, minimum: 1_200, maximum: 6_000))
    }

    func testRejectsRPMWhenHardwareBoundsAreUnavailable() {
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(-1, minimum: nil, maximum: nil))
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(0, minimum: nil, maximum: nil))
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(2_000, minimum: nil, maximum: nil))
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(20_001, minimum: nil, maximum: nil))
    }

    func testRejectsRPMWhenOnlyOneHardwareBoundIsAvailable() {
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(2_000, minimum: 1_200, maximum: nil))
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(2_000, minimum: nil, maximum: 6_000))
    }

    func testRejectsInvertedHardwareBounds() {
        XCTAssertFalse(FanCommandValidator.isValidTargetRPM(2_000, minimum: 6_000, maximum: 1_200))
    }
}
