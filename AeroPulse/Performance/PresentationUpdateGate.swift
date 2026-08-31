struct PresentationUpdateGate {
    private(set) var isPaused = false
    private(set) var hasPendingUpdate = false

    mutating func shouldPublishIncomingUpdate() -> Bool {
        guard !isPaused else {
            hasPendingUpdate = true
            return false
        }

        return true
    }

    /// Returns `true` when a deferred update should be refreshed after resuming.
    @discardableResult
    mutating func setPaused(_ paused: Bool) -> Bool {
        guard paused != isPaused else { return false }
        isPaused = paused

        guard !paused else { return false }
        let shouldRefresh = hasPendingUpdate
        hasPendingUpdate = false
        return shouldRefresh
    }
}
