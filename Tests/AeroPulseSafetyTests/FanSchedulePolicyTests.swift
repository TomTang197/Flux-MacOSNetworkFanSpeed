import XCTest
@testable import AeroPulseFanSafety

final class FanSchedulePolicyTests: XCTestCase {
    func testConfigInitializationAndNormalization() {
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 25, // should clamp to 23
            startMinute: -5, // should clamp to 0
            endHour: 8,
            endMinute: 30,
            scheduledMode: .auto,
            defaultMode: .custom
        )
        XCTAssertEqual(config.startHour, 23)
        XCTAssertEqual(config.startMinute, 0)
        XCTAssertEqual(config.endHour, 8)
        XCTAssertEqual(config.endMinute, 30)
        XCTAssertEqual(config.scheduledMode, .auto)
        XCTAssertEqual(config.defaultMode, .custom)
    }

    func testConfigCodableRoundTrip() throws {
        let original = FanScheduleConfig(
            isEnabled: true,
            startHour: 22,
            startMinute: 30,
            endHour: 7,
            endMinute: 15,
            scheduledMode: .auto,
            defaultMode: .custom
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FanScheduleConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSameDayWindowDetection() {
        let policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 30
        )

        XCTAssertFalse(policy.isTimeInSchedule(hour: 8, minute: 59, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 9, minute: 0, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 12, minute: 0, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 17, minute: 29, config: config))
        XCTAssertFalse(policy.isTimeInSchedule(hour: 17, minute: 30, config: config))
        XCTAssertFalse(policy.isTimeInSchedule(hour: 22, minute: 0, config: config))
    }

    func testCrossMidnightWindowDetection() {
        let policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 23, startMinute: 0,
            endHour: 8, endMinute: 0
        )

        XCTAssertFalse(policy.isTimeInSchedule(hour: 22, minute: 59, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 23, minute: 0, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 23, minute: 45, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 0, minute: 0, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 4, minute: 15, config: config))
        XCTAssertTrue(policy.isTimeInSchedule(hour: 7, minute: 59, config: config))
        XCTAssertFalse(policy.isTimeInSchedule(hour: 8, minute: 0, config: config))
        XCTAssertFalse(policy.isTimeInSchedule(hour: 14, minute: 0, config: config))
    }

    func testManualOverrideResetsOnBoundaryCross() {
        var policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 23, startMinute: 0,
            endHour: 8, endMinute: 0,
            scheduledMode: .auto,
            defaultMode: .custom
        )

        // Entering schedule at 23:00
        let action1 = policy.evaluate(hour: 23, minute: 0, config: config, currentMode: .custom)
        XCTAssertEqual(action1, .switchMode(.auto))
        XCTAssertFalse(policy.isUserOverridden)

        // User manually overrides to .fullBlast inside window
        policy.handleUserManualOverride()
        XCTAssertTrue(policy.isUserOverridden)

        // Subsequent tick inside window keeps manual override
        let action2 = policy.evaluate(hour: 23, minute: 30, config: config, currentMode: .fullBlast)
        XCTAssertEqual(action2, .none)
        XCTAssertTrue(policy.isUserOverridden)

        // Leaving schedule at 08:00 crosses boundary -> override clears, switches to defaultMode
        let action3 = policy.evaluate(hour: 8, minute: 0, config: config, currentMode: .fullBlast)
        XCTAssertEqual(action3, .switchMode(.custom))
        XCTAssertFalse(policy.isUserOverridden)
    }

    func testReconcileWakeCrossesBoundary() {
        var policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 23, startMinute: 0,
            endHour: 8, endMinute: 0,
            scheduledMode: .auto,
            defaultMode: .custom
        )

        // Slept during the day (14:00) outside schedule
        _ = policy.evaluate(hour: 14, minute: 0, config: config, currentMode: .custom)
        XCTAssertFalse(policy.isTimeInSchedule(hour: 14, minute: 0, config: config))

        // Woke up at 02:00 at night inside schedule
        let action = policy.reconcileWake(hour: 2, minute: 0, config: config, currentMode: .custom)
        XCTAssertEqual(action, .switchMode(.auto))
        XCTAssertFalse(policy.isUserOverridden)
    }

    func testDisabledConfigAlwaysReturnsNone() {
        var policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: false,
            startHour: 23, startMinute: 0,
            endHour: 8, endMinute: 0,
            scheduledMode: .auto,
            defaultMode: .custom
        )

        XCTAssertFalse(policy.isTimeInSchedule(hour: 23, minute: 30, config: config))
        let action = policy.evaluate(hour: 23, minute: 30, config: config, currentMode: .custom)
        XCTAssertEqual(action, .none)
    }

    func testEqualStartAndEndTimeDoesNotTrigger() {
        var policy = FanSchedulePolicy()
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 10, startMinute: 0,
            endHour: 10, endMinute: 0,
            scheduledMode: .auto,
            defaultMode: .custom
        )

        XCTAssertFalse(policy.isTimeInSchedule(hour: 10, minute: 0, config: config))
        let action = policy.evaluate(hour: 10, minute: 0, config: config, currentMode: .custom)
        XCTAssertEqual(action, .none)
    }
}
