struct FanTargetSubmissionGate {
    struct Submission: Equatable {
        let id: UInt64
        let targets: [Int: Int]
    }

    private var nextSubmissionID: UInt64 = 0
    private var activeSubmission: Submission?
    private var pendingTargets: [Int: Int]?
    private var lastSucceededTargets: [Int: Int]?

    mutating func request(_ targets: [Int: Int]) -> Submission? {
        if let activeSubmission {
            if activeSubmission.targets == targets {
                pendingTargets = nil
            } else if pendingTargets != targets {
                pendingTargets = targets
            }
            return nil
        }

        guard lastSucceededTargets != targets else { return nil }
        return startSubmission(for: targets)
    }

    mutating func complete(_ submission: Submission, succeeded: Bool) -> Submission? {
        guard activeSubmission?.id == submission.id else { return nil }
        activeSubmission = nil

        guard succeeded else {
            pendingTargets = nil
            lastSucceededTargets = nil
            return nil
        }

        lastSucceededTargets = submission.targets
        guard let pendingTargets else { return nil }
        self.pendingTargets = nil
        guard pendingTargets != lastSucceededTargets else { return nil }
        return startSubmission(for: pendingTargets)
    }

    mutating func reset() {
        activeSubmission = nil
        pendingTargets = nil
        lastSucceededTargets = nil
    }

    private mutating func startSubmission(for targets: [Int: Int]) -> Submission {
        nextSubmissionID &+= 1
        let submission = Submission(id: nextSubmissionID, targets: targets)
        activeSubmission = submission
        return submission
    }
}
