import Foundation

enum InvalidSensorRetryPolicy {
    static func shouldSkipRetry(
        invalidatedAt: Date,
        now: Date,
        retryInterval: TimeInterval
    ) -> Bool {
        let age = now.timeIntervalSince(invalidatedAt)
        return age >= 0 && age < retryInterval
    }
}
