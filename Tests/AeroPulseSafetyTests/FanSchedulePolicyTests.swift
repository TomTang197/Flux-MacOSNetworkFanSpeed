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
}
