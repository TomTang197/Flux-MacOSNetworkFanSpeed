import XCTest
@testable import FanHelperSafety

final class PrimaryFallbackExecutorTests: XCTestCase {
    func testSuccessfulPrimaryDoesNotRunFallback() {
        var events: [String] = []

        let result = PrimaryFallbackExecutor.run(
            primary: {
                events.append("direct")
                return 0
            },
            isSuccess: { $0 == 0 },
            fallback: {
                events.append("external")
                return 1
            }
        )

        XCTAssertEqual(result, 0)
        XCTAssertEqual(events, ["direct"])
    }

    func testFailedPrimaryRunsFallbackSecond() {
        var events: [String] = []

        let result = PrimaryFallbackExecutor.run(
            primary: {
                events.append("direct")
                return 1
            },
            isSuccess: { $0 == 0 },
            fallback: {
                events.append("external")
                return 0
            }
        )

        XCTAssertEqual(result, 0)
        XCTAssertEqual(events, ["direct", "external"])
    }
}
