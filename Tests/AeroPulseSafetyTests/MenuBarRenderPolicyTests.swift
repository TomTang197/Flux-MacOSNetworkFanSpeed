import XCTest
@testable import AeroPulsePerformanceCore

final class MenuBarRenderPolicyTests: XCTestCase {
    func testChangedMetricIsThrottledUntilMinimumIntervalExpires() {
        var policy = MenuBarRenderPolicy(minimumInterval: 2)
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(policy.shouldRender(key: "download:1", now: start))
        XCTAssertFalse(policy.shouldRender(key: "download:2", now: start.addingTimeInterval(1)))
        XCTAssertTrue(policy.shouldRender(key: "download:3", now: start.addingTimeInterval(2)))
    }

    func testIdenticalMetricNeverRequestsAnotherRender() {
        var policy = MenuBarRenderPolicy(minimumInterval: 2)
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(policy.shouldRender(key: "gpu:20", now: start))
        XCTAssertFalse(policy.shouldRender(key: "gpu:20", now: start.addingTimeInterval(10)))
    }
}
