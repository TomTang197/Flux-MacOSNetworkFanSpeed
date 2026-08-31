import Foundation

struct WindowInteractionPolicy {
    let settleDelay: TimeInterval
    private(set) var isInteracting = false

    private var interactionToken: UInt64 = 0

    init(settleDelay: TimeInterval = 0.18) {
        self.settleDelay = max(0, settleDelay)
    }

    @discardableResult
    mutating func beginInteraction() -> UInt64 {
        interactionToken &+= 1
        isInteracting = true
        return interactionToken
    }

    @discardableResult
    mutating func finishInteraction(ifCurrent token: UInt64) -> Bool {
        guard isInteracting, token == interactionToken else { return false }
        isInteracting = false
        return true
    }
}
