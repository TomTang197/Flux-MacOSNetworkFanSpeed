import Foundation

struct MenuBarRenderPolicy {
    private let minimumInterval: TimeInterval
    private var lastKey: String?
    private var lastRenderDate: Date?

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = max(0, minimumInterval)
    }

    mutating func shouldRender(key: String, now: Date = Date()) -> Bool {
        if key == lastKey {
            return false
        }

        if let lastRenderDate,
           now.timeIntervalSince(lastRenderDate) < minimumInterval {
            return false
        }

        lastKey = key
        lastRenderDate = now
        return true
    }
}
