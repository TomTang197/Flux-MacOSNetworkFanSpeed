import XCTest
@testable import AeroPulseFanSafety

final class GameModeFanLinkagePolicyTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testDisabledPolicyDoesNotSwitchModeOnGameEnter() {
        var policy = GameModeFanLinkagePolicy()
        let decision = policy.handleGameModeChange(
            isActive: true,
            now: baseDate,
            enabled: false,
            exitDelay: 60
        )

        XCTAssertEqual(decision.action, .none)
        XCTAssertTrue(decision.isGamingActive)
        XCTAssertFalse(decision.isCooldownActive)
    }

    func testEnabledPolicySwitchesToRulesOnGameEnter() {
        var policy = GameModeFanLinkagePolicy()
        let decision = policy.handleGameModeChange(
            isActive: true,
            now: baseDate,
            enabled: true,
            exitDelay: 60
        )

        XCTAssertEqual(decision.action, .switchMode(.rules))
        XCTAssertTrue(decision.isGamingActive)
        XCTAssertFalse(decision.isCooldownActive)
        XCTAssertNil(decision.remainingCooldown)
    }

    func testExitGameModeWithDelayStartsCooldown() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 60)

        let exitDate = baseDate.addingTimeInterval(300)
        let exitDecision = policy.handleGameModeChange(
            isActive: false,
            now: exitDate,
            enabled: true,
            exitDelay: 60
        )

        XCTAssertEqual(exitDecision.action, .none)
        XCTAssertFalse(exitDecision.isGamingActive)
        XCTAssertTrue(exitDecision.isCooldownActive)
        XCTAssertEqual(exitDecision.remainingCooldown, 60)
    }

    func testExitGameModeWithZeroDelaySwitchesImmediatelyToAuto() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 0)

        let exitDate = baseDate.addingTimeInterval(300)
        let exitDecision = policy.handleGameModeChange(
            isActive: false,
            now: exitDate,
            enabled: true,
            exitDelay: 0
        )

        XCTAssertEqual(exitDecision.action, .switchMode(.auto))
        XCTAssertFalse(exitDecision.isGamingActive)
        XCTAssertFalse(exitDecision.isCooldownActive)
    }

    func testTimerTickDecreasesRemainingCooldownAndSwitchesToAutoWhenExpired() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 60)

        let exitDate = baseDate.addingTimeInterval(100)
        _ = policy.handleGameModeChange(isActive: false, now: exitDate, enabled: true, exitDelay: 60)

        // 30 seconds later
        let tick1 = policy.handleTimerTick(
            now: exitDate.addingTimeInterval(30),
            enabled: true,
            exitDelay: 60
        )
        XCTAssertEqual(tick1.action, .none)
        XCTAssertTrue(tick1.isCooldownActive)
        XCTAssertEqual(tick1.remainingCooldown, 30)

        // 60 seconds later (expired)
        let tick2 = policy.handleTimerTick(
            now: exitDate.addingTimeInterval(60),
            enabled: true,
            exitDelay: 60
        )
        XCTAssertEqual(tick2.action, .switchMode(.auto))
        XCTAssertFalse(tick2.isCooldownActive)
        XCTAssertNil(tick2.remainingCooldown)
    }

    func testReenteringGameModeDuringCooldownCancelsCooldownAndSwitchesToRules() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 60)

        let exitDate = baseDate.addingTimeInterval(100)
        _ = policy.handleGameModeChange(isActive: false, now: exitDate, enabled: true, exitDelay: 60)

        // Reenter game mode 20 seconds later
        let reenterDate = exitDate.addingTimeInterval(20)
        let reenterDecision = policy.handleGameModeChange(
            isActive: true,
            now: reenterDate,
            enabled: true,
            exitDelay: 60
        )

        XCTAssertEqual(reenterDecision.action, .switchMode(.rules))
        XCTAssertTrue(reenterDecision.isGamingActive)
        XCTAssertFalse(reenterDecision.isCooldownActive)
        XCTAssertNil(reenterDecision.remainingCooldown)
    }

    func testManualOverridePreventsAutoRevertOnExit() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 60)

        // User manually changes fan mode during gaming
        policy.handleUserManualOverride()

        let exitDate = baseDate.addingTimeInterval(100)
        let exitDecision = policy.handleGameModeChange(
            isActive: false,
            now: exitDate,
            enabled: true,
            exitDelay: 60
        )

        XCTAssertEqual(exitDecision.action, .none)
        XCTAssertFalse(exitDecision.isCooldownActive)
    }

    func testDisablingLinkageDuringCooldownClearsCooldown() {
        var policy = GameModeFanLinkagePolicy()
        _ = policy.handleGameModeChange(isActive: true, now: baseDate, enabled: true, exitDelay: 60)

        let exitDate = baseDate.addingTimeInterval(100)
        _ = policy.handleGameModeChange(isActive: false, now: exitDate, enabled: true, exitDelay: 60)

        let settingsDecision = policy.handleSettingsChanged(
            enabled: false,
            exitDelay: 60,
            now: exitDate.addingTimeInterval(10)
        )

        XCTAssertEqual(settingsDecision.action, .none)
        XCTAssertFalse(settingsDecision.isCooldownActive)
        XCTAssertNil(settingsDecision.remainingCooldown)
    }
}
