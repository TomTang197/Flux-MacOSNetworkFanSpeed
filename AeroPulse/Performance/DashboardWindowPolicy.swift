import Foundation

public enum DashboardWindowAction: Equatable {
    case deminiaturizeAndOrderFront
    case orderFront
    case openNewWindow
    case ignoreThrottled
}

public struct DashboardWindowState: Equatable {
    public var isRegistered: Bool
    public var isVisible: Bool
    public var isMiniaturized: Bool

    public init(isRegistered: Bool, isVisible: Bool, isMiniaturized: Bool) {
        self.isRegistered = isRegistered
        self.isVisible = isVisible
        self.isMiniaturized = isMiniaturized
    }
}

public struct DashboardWindowPolicy {
    public let debounceInterval: TimeInterval
    private var lastActionTime: Date

    public init(debounceInterval: TimeInterval = 0.15, initialTime: Date = .distantPast) {
        self.debounceInterval = max(0, debounceInterval)
        self.lastActionTime = initialTime
    }

    public mutating func evaluateReopen(
        state: DashboardWindowState,
        at currentTime: Date = Date()
    ) -> DashboardWindowAction {
        guard currentTime.timeIntervalSince(lastActionTime) >= debounceInterval else {
            return .ignoreThrottled
        }
        lastActionTime = currentTime

        if state.isMiniaturized {
            return .deminiaturizeAndOrderFront
        }
        if state.isVisible {
            return .orderFront
        }
        return .openNewWindow
    }
}
