import Foundation

struct FanControlLease {
    private(set) var controlledFans: Set<Int> = []
    private(set) var lastHeartbeat: Date?
    private(set) var owner: UUID?
    private(set) var recoveryRequired = false
    let timeout: TimeInterval

    init(timeout: TimeInterval) {
        precondition(timeout > 0)
        self.timeout = timeout
    }

    var isActive: Bool {
        !controlledFans.isEmpty
    }

    func allowsControl(from client: UUID) -> Bool {
        !recoveryRequired && (owner == nil || owner == client)
    }

    func allowsRecovery(from client: UUID) -> Bool {
        owner == nil || owner == client
    }

    @discardableResult
    mutating func noteControl(ofFan index: Int, owner client: UUID, at date: Date) -> Bool {
        guard allowsControl(from: client) else { return false }
        owner = client
        controlledFans.insert(index)
        lastHeartbeat = date
        return true
    }

    @discardableResult
    mutating func noteHeartbeat(owner client: UUID, at date: Date) -> Bool {
        guard isActive, owner == client, !recoveryRequired else { return false }
        lastHeartbeat = date
        return true
    }

    @discardableResult
    mutating func noteProgress(owner client: UUID, at date: Date) -> Bool {
        guard isActive, owner == client, !recoveryRequired else { return false }
        lastHeartbeat = date
        return true
    }

    mutating func noteRecoveryRequired() {
        if isActive {
            recoveryRequired = true
        }
    }

    mutating func noteRestored(fan index: Int, owner client: UUID) {
        guard owner == client else { return }
        controlledFans.remove(index)
        if controlledFans.isEmpty {
            lastHeartbeat = nil
            owner = nil
            recoveryRequired = false
        }
    }

    mutating func noteRestoredAll() {
        controlledFans.removeAll()
        lastHeartbeat = nil
        owner = nil
        recoveryRequired = false
    }

    func shouldRestore(at date: Date) -> Bool {
        guard isActive else { return false }
        if recoveryRequired { return true }
        guard let lastHeartbeat else { return true }
        let age = date.timeIntervalSince(lastHeartbeat)
        return age < 0 || age >= timeout
    }

    func shouldRestoreAfterDisconnect(of client: UUID) -> Bool {
        isActive && owner == client
    }
}

enum PrimaryFallbackExecutor {
    static func run<Result>(
        primary: () -> Result,
        isSuccess: (Result) -> Bool,
        fallback: () -> Result
    ) -> Result {
        let primaryResult = primary()
        guard !isSuccess(primaryResult) else { return primaryResult }
        return fallback()
    }
}

enum FanModeWriteOperation: Equatable {
    case writeFtst(UInt8)
    case wait(seconds: TimeInterval)
    case writeMode(UInt8)
}

enum FanModeWritePlanner {
    static func plan(manual: Bool, hasFtst: Bool) -> [FanModeWriteOperation] {
        var operations: [FanModeWriteOperation] = []
        if manual, hasFtst {
            operations.append(.writeFtst(1))
            operations.append(.wait(seconds: 3))
        }
        operations.append(.writeMode(manual ? 1 : 0))
        return operations
    }
}

enum FanModeUnlockRetryPolicy {
    static let maximumModeWriteAttempts = 300
    static let retryInterval: TimeInterval = 0.1

    static func shouldRetry(afterAttempt attempt: Int) -> Bool {
        attempt > 0 && attempt < maximumModeWriteAttempts
    }
}

enum FanTargetBatchWriteOperation: Equatable {
    case writeFtst(UInt8)
    case wait(seconds: TimeInterval)
    case writeMode(index: Int, value: UInt8)
    case writeTarget(index: Int, rpm: Int)
}

enum FanTargetBatchWritePlanner {
    static func plan(
        targets: [(index: Int, rpm: Int)],
        hasFtst: Bool
    ) -> [FanTargetBatchWriteOperation] {
        var operations: [FanTargetBatchWriteOperation] = []
        if hasFtst, !targets.isEmpty {
            operations.append(.writeFtst(1))
            operations.append(.wait(seconds: 3))
        }
        for target in targets {
            operations.append(.writeMode(index: target.index, value: 1))
            operations.append(.writeTarget(index: target.index, rpm: target.rpm))
        }
        return operations
    }
}

enum FanCommandValidator {
    private static let absoluteMaximumRPM = 20_000

    static func isValidFanIndex(_ index: Int, fanCount: Int?) -> Bool {
        guard index >= 0 else { return false }
        guard let fanCount else { return false }
        return fanCount > 0 && fanCount <= 16 && index < fanCount
    }

    static func isValidTargetRPM(_ rpm: Int, minimum: Int?, maximum: Int?) -> Bool {
        guard rpm >= 0, rpm <= absoluteMaximumRPM,
              let minimum, let maximum,
              minimum >= 0, maximum >= minimum else { return false }
        return rpm >= minimum && rpm <= maximum
    }
}
