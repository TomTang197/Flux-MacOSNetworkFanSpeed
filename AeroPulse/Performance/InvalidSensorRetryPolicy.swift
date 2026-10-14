import Foundation

enum InvalidSensorRetryPolicy {
    static func shouldSkipRetry(
        invalidatedAt: Date,
        now: Date,
        retryInterval: TimeInterval,
        reconnectedAt: Date? = nil,
        reconnectGraceWindow: TimeInterval = 6.0,
        graceRetryInterval: TimeInterval = 1.0
    ) -> Bool {
        let effectiveInterval: TimeInterval
        if let reconnectedAt,
           now.timeIntervalSince(reconnectedAt) >= 0,
           now.timeIntervalSince(reconnectedAt) < reconnectGraceWindow {
            effectiveInterval = graceRetryInterval
        } else {
            effectiveInterval = retryInterval
        }

        let age = now.timeIntervalSince(invalidatedAt)
        return age >= 0 && age < effectiveInterval
    }
}
