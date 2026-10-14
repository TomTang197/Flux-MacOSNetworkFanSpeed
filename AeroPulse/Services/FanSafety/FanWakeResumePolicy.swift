import Foundation

public enum FanResumeTarget: Equatable {
    case customRules
}

public enum FanWakeResumeAction: Equatable {
    case none
    case resume(FanResumeTarget)
    case restoreSystemAuto
    case rearmWaking
    case dropToAuto
}

public enum FanSleepWakeState: Equatable {
    case active
    case sleeping
    case waking(consecutiveFreshSamples: Int)
}

public struct FanWakeResumePolicy {
    public private(set) var state: FanSleepWakeState
    public private(set) var targetToResume: FanResumeTarget?
    public let requiredFreshSamples: Int
    public let maxRecoveryAttempts: Int
    public private(set) var currentRecoveryAttempts: Int = 0

    public init(
        state: FanSleepWakeState = .active,
        targetToResume: FanResumeTarget? = nil,
        requiredFreshSamples: Int = 2,
        maxRecoveryAttempts: Int = 3
    ) {
        self.state = state
        self.targetToResume = targetToResume
        self.requiredFreshSamples = max(1, requiredFreshSamples)
        self.maxRecoveryAttempts = max(1, maxRecoveryAttempts)
    }

    /// Called when the system is about to sleep (NSWorkspace.willSleepNotification)
    /// Returns .restoreSystemAuto so hardware can be safely reset to automatic control during sleep.
    public mutating func handleWillSleep(isCustomModeActive: Bool) -> FanWakeResumeAction {
        state = .sleeping
        // Preserve resume intent if custom mode was active, OR if we were already in the process of waking/resuming
        if isCustomModeActive || targetToResume != nil {
            targetToResume = .customRules
        } else {
            targetToResume = nil
        }
        return .restoreSystemAuto
    }

    /// Called when the system wakes from sleep (NSWorkspace.didWakeNotification)
    public mutating func handleDidWake() {
        currentRecoveryAttempts = 0
        if targetToResume != nil {
            state = .waking(consecutiveFreshSamples: 0)
        } else {
            state = .active
        }
    }

    /// Called whenever a sensor sample freshness evaluation is completed
    public mutating func handleSample(isFresh: Bool, helperInstalled: Bool) -> FanWakeResumeAction {
        guard case .waking(let currentCount) = state, let target = targetToResume else {
            return .none
        }

        guard isFresh && helperInstalled else {
            // If sample is stale or helper is not ready, reset consecutive count
            state = .waking(consecutiveFreshSamples: 0)
            return .none
        }

        let newCount = currentCount + 1
        if newCount >= requiredFreshSamples {
            state = .active
            targetToResume = nil
            return .resume(target)
        } else {
            state = .waking(consecutiveFreshSamples: newCount)
            return .none
        }
    }

    /// Called when fan control lease is lost unexpectedly during or shortly after wake
    public mutating func handleTransientLeaseLoss() -> FanWakeResumeAction {
        guard currentRecoveryAttempts < maxRecoveryAttempts else {
            state = .active
            targetToResume = nil
            return .dropToAuto
        }

        currentRecoveryAttempts += 1
        targetToResume = .customRules
        state = .waking(consecutiveFreshSamples: 0)
        return .rearmWaking
    }

    /// Called when user explicitly selects a fan mode, or external reset cancels resume
    public mutating func handleUserOverride() {
        targetToResume = nil
        currentRecoveryAttempts = 0
        state = .active
    }
}

