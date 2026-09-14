import Foundation

public enum DashboardWindowAction: Equatable {
    case deminiaturizeAndOrderFront
    case unhideAndOrderFront
    case orderFront
    case openNewWindow
    case ignoreThrottled
}

public struct DashboardWindowState: Equatable {
    public var isRegistered: Bool
    public var isVisible: Bool
    public var isMiniaturized: Bool
    public var isAppHidden: Bool
    public var isOpeningInProgress: Bool

    public init(
        isRegistered: Bool,
        isVisible: Bool,
        isMiniaturized: Bool,
        isAppHidden: Bool = false,
        isOpeningInProgress: Bool = false
    ) {
        self.isRegistered = isRegistered
        self.isVisible = isVisible
        self.isMiniaturized = isMiniaturized
        self.isAppHidden = isAppHidden
        self.isOpeningInProgress = isOpeningInProgress
    }
}

public struct DashboardWindowPolicy {
    public let debounceInterval: TimeInterval
    private var lastActionUptime: TimeInterval

    public init(debounceInterval: TimeInterval = 0.15, initialUptime: TimeInterval = -1000) {
        self.debounceInterval = max(0, debounceInterval)
        self.lastActionUptime = initialUptime
    }

    public mutating func evaluateReopen(
        state: DashboardWindowState,
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> DashboardWindowAction {
        if state.isOpeningInProgress {
            return .ignoreThrottled
        }

        guard uptime - lastActionUptime >= debounceInterval else {
            return .ignoreThrottled
        }
        lastActionUptime = uptime

        if state.isMiniaturized {
            return .deminiaturizeAndOrderFront
        }
        if state.isAppHidden {
            return .unhideAndOrderFront
        }
        if state.isVisible {
            return .orderFront
        }
        return .openNewWindow
    }

    /// Overload for backwards compatibility with tests using `Date`
    public mutating func evaluateReopen(
        state: DashboardWindowState,
        at date: Date
    ) -> DashboardWindowAction {
        evaluateReopen(state: state, uptime: date.timeIntervalSinceReferenceDate)
    }
}
