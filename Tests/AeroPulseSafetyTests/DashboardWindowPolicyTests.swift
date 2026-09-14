import XCTest
import AeroPulsePerformanceCore

final class DashboardWindowPolicyTests: XCTestCase {
    func testMinimizedWindowTriggersDeminiaturizeAndOrderFront() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let state = DashboardWindowState(isRegistered: true, isVisible: false, isMiniaturized: true)
        let action = policy.evaluateReopen(state: state, at: Date())
        XCTAssertEqual(action, .deminiaturizeAndOrderFront)
    }

    func testVisibleWindowTriggersOrderFront() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let state = DashboardWindowState(isRegistered: true, isVisible: true, isMiniaturized: false)
        let action = policy.evaluateReopen(state: state, at: Date())
        XCTAssertEqual(action, .orderFront)
    }

    func testClosedWindowTriggersOpenNewWindow() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let state = DashboardWindowState(isRegistered: false, isVisible: false, isMiniaturized: false)
        let action = policy.evaluateReopen(state: state, at: Date())
        XCTAssertEqual(action, .openNewWindow)
    }

    func testDebounceThrottlesRapidSubsequentReopenRequests() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let now = Date()
        let state = DashboardWindowState(isRegistered: false, isVisible: false, isMiniaturized: false)

        let first = policy.evaluateReopen(state: state, at: now)
        XCTAssertEqual(first, .openNewWindow)

        // Request 50ms later (within 150ms window) should be ignored
        let rapid = policy.evaluateReopen(state: state, at: now.addingTimeInterval(0.05))
        XCTAssertEqual(rapid, .ignoreThrottled)

        // Request 160ms later should succeed
        let later = policy.evaluateReopen(state: state, at: now.addingTimeInterval(0.16))
        XCTAssertEqual(later, .openNewWindow)
    }

    func testOpeningInProgressAlwaysIgnored() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let state = DashboardWindowState(
            isRegistered: false,
            isVisible: false,
            isMiniaturized: false,
            isOpeningInProgress: true
        )
        let action = policy.evaluateReopen(state: state)
        XCTAssertEqual(action, .ignoreThrottled)
    }

    func testHiddenAppTriggersUnhideAndOrderFront() {
        var policy = DashboardWindowPolicy(debounceInterval: 0.15)
        let state = DashboardWindowState(
            isRegistered: true,
            isVisible: false,
            isMiniaturized: false,
            isAppHidden: true
        )
        let action = policy.evaluateReopen(state: state)
        XCTAssertEqual(action, .unhideAndOrderFront)
    }
}
