import Foundation

public enum FanScheduleAction: Equatable {
    case none
    case switchMode(ScheduledFanTarget)
}

public struct FanSchedulePolicy: Equatable {
    public private(set) var lastEvaluatedInSchedule: Bool? = nil
    public private(set) var isUserOverridden: Bool = false

    public init(
        lastEvaluatedInSchedule: Bool? = nil,
        isUserOverridden: Bool = false
    ) {
        self.lastEvaluatedInSchedule = lastEvaluatedInSchedule
        self.isUserOverridden = isUserOverridden
    }

    public func isTimeInSchedule(hour: Int, minute: Int, config: FanScheduleConfig) -> Bool {
        guard config.isEnabled else { return false }
        let currentOffset = hour * 60 + minute
        let startOffset = config.startHour * 60 + config.startMinute
        let endOffset = config.endHour * 60 + config.endMinute

        guard startOffset != endOffset else { return false }

        if startOffset < endOffset {
            // Same-day window
            return currentOffset >= startOffset && currentOffset < endOffset
        } else {
            // Cross-midnight window
            return currentOffset >= startOffset || currentOffset < endOffset
        }
    }

    public mutating func evaluate(
        hour: Int,
        minute: Int,
        config: FanScheduleConfig,
        currentMode: ScheduledFanTarget
    ) -> FanScheduleAction {
        guard config.isEnabled else {
            lastEvaluatedInSchedule = nil
            isUserOverridden = false
            return .none
        }

        let inSchedule = isTimeInSchedule(hour: hour, minute: minute, config: config)
        let targetMode = inSchedule ? config.scheduledMode : config.defaultMode

        if let previousInSchedule = lastEvaluatedInSchedule {
            if inSchedule != previousInSchedule {
                // Boundary crossed: clear override and apply new target mode
                lastEvaluatedInSchedule = inSchedule
                isUserOverridden = false
                return targetMode != currentMode ? .switchMode(targetMode) : .none
            }
        } else {
            // First evaluation on startup or config enable
            lastEvaluatedInSchedule = inSchedule
            isUserOverridden = false
            return targetMode != currentMode ? .switchMode(targetMode) : .none
        }

        // Inside same window: respect manual override if present
        if isUserOverridden {
            return .none
        }

        // If not overridden but mode drifted away from expected target
        if currentMode != targetMode {
            return .switchMode(targetMode)
        }

        return .none
    }

    public mutating func handleUserManualOverride() {
        isUserOverridden = true
    }

    public mutating func resetOverride() {
        isUserOverridden = false
    }

    public mutating func reconcileWake(
        hour: Int,
        minute: Int,
        config: FanScheduleConfig,
        currentMode: ScheduledFanTarget
    ) -> FanScheduleAction {
        guard config.isEnabled else { return .none }
        let inSchedule = isTimeInSchedule(hour: hour, minute: minute, config: config)
        if inSchedule != lastEvaluatedInSchedule {
            lastEvaluatedInSchedule = inSchedule
            isUserOverridden = false
            let targetMode = inSchedule ? config.scheduledMode : config.defaultMode
            return targetMode != currentMode ? .switchMode(targetMode) : .none
        }
        return .none
    }
}
