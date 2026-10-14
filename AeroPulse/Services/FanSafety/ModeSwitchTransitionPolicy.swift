//
//  ModeSwitchTransitionPolicy.swift
//  AeroPulse
//

import Foundation

public struct ModeSwitchTransitionPolicy: Equatable {
    public let duration: TimeInterval
    public private(set) var targetModeRaw: String?
    public private(set) var startedAt: Date?

    public init(duration: TimeInterval = 4.0) {
        self.duration = max(1.0, duration)
    }

    public mutating func startTransition(to modeRaw: String, now: Date) {
        targetModeRaw = modeRaw
        startedAt = now
    }

    public func remainingSeconds(now: Date) -> Int? {
        guard let startedAt else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        guard elapsed < duration else { return nil }
        return max(1, Int(ceil(duration - elapsed)))
    }

    public mutating func tick(now: Date) -> (isTransitioning: Bool, remainingSeconds: Int?) {
        guard let startedAt else {
            return (false, nil)
        }
        let elapsed = now.timeIntervalSince(startedAt)
        if elapsed >= duration {
            self.startedAt = nil
            self.targetModeRaw = nil
            return (false, nil)
        }
        let remaining = max(1, Int(ceil(duration - elapsed)))
        return (true, remaining)
    }

    public mutating func cancel() {
        startedAt = nil
        targetModeRaw = nil
    }
}
