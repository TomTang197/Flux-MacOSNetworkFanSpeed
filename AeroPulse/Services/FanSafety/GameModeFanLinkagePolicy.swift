import Foundation

public enum GameModeFanTarget: Equatable {
    case rules
    case auto
}

public enum GameModeLinkageAction: Equatable {
    case none
    case switchMode(GameModeFanTarget)
}

public struct GameModeLinkageDecision: Equatable {
    public let action: GameModeLinkageAction
    public let remainingCooldown: TimeInterval?
    public let isGamingActive: Bool
    public let isCooldownActive: Bool

    public init(
        action: GameModeLinkageAction,
        remainingCooldown: TimeInterval? = nil,
        isGamingActive: Bool = false,
        isCooldownActive: Bool = false
    ) {
        self.action = action
        self.remainingCooldown = remainingCooldown
        self.isGamingActive = isGamingActive
        self.isCooldownActive = isCooldownActive
    }
}

public struct GameModeFanLinkagePolicy {
    private(set) public var isGamingActive: Bool = false
    private(set) public var cooldownStartedAt: Date? = nil
    private(set) public var isUserOverridden: Bool = false

    public init(
        isGamingActive: Bool = false,
        cooldownStartedAt: Date? = nil,
        isUserOverridden: Bool = false
    ) {
        self.isGamingActive = isGamingActive
        self.cooldownStartedAt = cooldownStartedAt
        self.isUserOverridden = isUserOverridden
    }

    public mutating func handleGameModeChange(
        isActive: Bool,
        now: Date,
        enabled: Bool,
        exitDelay: TimeInterval
    ) -> GameModeLinkageDecision {
        if isActive {
            isGamingActive = true
            cooldownStartedAt = nil
            isUserOverridden = false

            guard enabled else {
                return GameModeLinkageDecision(
                    action: .none,
                    remainingCooldown: nil,
                    isGamingActive: true,
                    isCooldownActive: false
                )
            }

            return GameModeLinkageDecision(
                action: .switchMode(.rules),
                remainingCooldown: nil,
                isGamingActive: true,
                isCooldownActive: false
            )
        } else {
            isGamingActive = false

            guard enabled else {
                cooldownStartedAt = nil
                return GameModeLinkageDecision(
                    action: .none,
                    remainingCooldown: nil,
                    isGamingActive: false,
                    isCooldownActive: false
                )
            }

            if isUserOverridden {
                cooldownStartedAt = nil
                return GameModeLinkageDecision(
                    action: .none,
                    remainingCooldown: nil,
                    isGamingActive: false,
                    isCooldownActive: false
                )
            }

            let effectiveDelay = max(0, exitDelay)
            if effectiveDelay <= 0 {
                cooldownStartedAt = nil
                return GameModeLinkageDecision(
                    action: .switchMode(.auto),
                    remainingCooldown: nil,
                    isGamingActive: false,
                    isCooldownActive: false
                )
            }

            cooldownStartedAt = now
            return GameModeLinkageDecision(
                action: .none,
                remainingCooldown: effectiveDelay,
                isGamingActive: false,
                isCooldownActive: true
            )
        }
    }

    public mutating func handleTimerTick(
        now: Date,
        enabled: Bool,
        exitDelay: TimeInterval
    ) -> GameModeLinkageDecision {
        guard enabled, !isGamingActive, let startedAt = cooldownStartedAt, !isUserOverridden else {
            return GameModeLinkageDecision(
                action: .none,
                remainingCooldown: nil,
                isGamingActive: isGamingActive,
                isCooldownActive: false
            )
        }

        let effectiveDelay = max(0, exitDelay)
        let elapsed = max(0, now.timeIntervalSince(startedAt))

        if elapsed >= effectiveDelay {
            cooldownStartedAt = nil
            return GameModeLinkageDecision(
                action: .switchMode(.auto),
                remainingCooldown: nil,
                isGamingActive: false,
                isCooldownActive: false
            )
        } else {
            let remaining = max(0, effectiveDelay - elapsed)
            return GameModeLinkageDecision(
                action: .none,
                remainingCooldown: remaining,
                isGamingActive: false,
                isCooldownActive: true
            )
        }
    }

    public mutating func handleUserManualOverride() {
        if isGamingActive || cooldownStartedAt != nil {
            isUserOverridden = true
            cooldownStartedAt = nil
        }
    }

    public mutating func handleSettingsChanged(
        enabled: Bool,
        exitDelay: TimeInterval,
        now: Date
    ) -> GameModeLinkageDecision {
        if !enabled {
            cooldownStartedAt = nil
            isUserOverridden = false
            return GameModeLinkageDecision(
                action: .none,
                remainingCooldown: nil,
                isGamingActive: isGamingActive,
                isCooldownActive: false
            )
        }

        if isGamingActive && !isUserOverridden {
            return GameModeLinkageDecision(
                action: .switchMode(.rules),
                remainingCooldown: nil,
                isGamingActive: true,
                isCooldownActive: false
            )
        }

        let remaining: TimeInterval? = cooldownStartedAt.flatMap { startedAt in
            let elapsed = max(0, now.timeIntervalSince(startedAt))
            return elapsed < exitDelay ? (exitDelay - elapsed) : nil
        }

        return GameModeLinkageDecision(
            action: .none,
            remainingCooldown: remaining,
            isGamingActive: isGamingActive,
            isCooldownActive: remaining != nil
        )
    }

    public mutating func reset() {
        isGamingActive = false
        cooldownStartedAt = nil
        isUserOverridden = false
    }
}
