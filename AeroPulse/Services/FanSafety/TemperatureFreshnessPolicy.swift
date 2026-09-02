import Foundation

enum TemperatureFreshnessPolicy {
    static func isFresh(
        sampledAt: Date?,
        now: Date,
        maximumAge: TimeInterval
    ) -> Bool {
        guard let sampledAt, maximumAge >= 0 else { return false }
        let age = now.timeIntervalSince(sampledAt)
        return age >= 0 && age <= maximumAge
    }
}

enum FanRuleMatchDecision: Equatable {
    case standby
    case matched(index: Int)
}

enum FanRuleMatchPolicy {
    static func decision(
        temperature: Double,
        thresholds: [Double]
    ) -> FanRuleMatchDecision {
        let matched = thresholds.enumerated()
            .filter { temperature >= $0.element }
            .max { $0.element < $1.element }
        guard let matched else {
            return .standby
        }
        return .matched(index: matched.offset)
    }
}

struct FanRuleControlTarget: Equatable {
    let ruleIndex: Int?
    let speedPercentage: Int

    init(ruleIndex: Int?, speedPercentage: Int) {
        self.ruleIndex = ruleIndex
        self.speedPercentage = max(0, min(100, speedPercentage))
    }
}

struct FanRuleControlDecision: Equatable {
    let target: FanRuleControlTarget
    let remainingDelay: TimeInterval?
}

struct FanRuleDownshiftPolicy {
    private var currentTarget: FanRuleControlTarget
    private var pendingDownshiftStartedAt: Date?

    init(initialTarget: FanRuleControlTarget) {
        currentTarget = initialTarget
    }

    mutating func decision(
        requestedTarget: FanRuleControlTarget,
        now: Date,
        delayEnabled: Bool,
        delay: TimeInterval
    ) -> FanRuleControlDecision {
        guard requestedTarget.speedPercentage < currentTarget.speedPercentage,
              delayEnabled,
              delay > 0 else {
            currentTarget = requestedTarget
            pendingDownshiftStartedAt = nil
            return FanRuleControlDecision(target: currentTarget, remainingDelay: nil)
        }

        let startedAt = pendingDownshiftStartedAt ?? now
        pendingDownshiftStartedAt = startedAt
        let elapsed = max(0, now.timeIntervalSince(startedAt))

        guard elapsed >= delay else {
            return FanRuleControlDecision(
                target: currentTarget,
                remainingDelay: max(0, delay - elapsed)
            )
        }

        currentTarget = requestedTarget
        pendingDownshiftStartedAt = nil
        return FanRuleControlDecision(target: currentTarget, remainingDelay: nil)
    }

    mutating func cancelPendingDownshift() {
        pendingDownshiftStartedAt = nil
    }
}
