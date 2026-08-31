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
