import Foundation

public enum TrendTimeRange: String, CaseIterable, Identifiable, Equatable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    public var id: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .twentyFourHours: return 86400
        case .sevenDays: return 604800
        case .thirtyDays: return 2592000
        }
    }

    public var isLongTerm: Bool {
        switch self {
        case .twentyFourHours, .sevenDays, .thirtyDays:
            return true
        default:
            return false
        }
    }
}

public struct MetricHistoryPoint: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let value: Double

    public init(id: UUID = UUID(), timestamp: Date = Date(), value: Double) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}

public struct RollingHistoryBuffer: Equatable {
    public let capacity: Int
    private var storage: [MetricHistoryPoint] = []

    public init(capacity: Int = 1000) {
        self.capacity = max(2, capacity)
        self.storage.reserveCapacity(self.capacity)
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }

    public var count: Int {
        storage.count
    }

    public var points: [MetricHistoryPoint] {
        storage
    }

    public var latest: Double? {
        storage.last?.value
    }

    public var minMaxRange: ClosedRange<Double>? {
        guard let first = storage.first?.value else { return nil }
        var minVal = first
        var maxVal = first
        for point in storage {
            if point.value < minVal { minVal = point.value }
            if point.value > maxVal { maxVal = point.value }
        }
        return minVal...maxVal
    }

    public func points(within duration: TimeInterval, from now: Date = Date()) -> [MetricHistoryPoint] {
        let cutoff = now.addingTimeInterval(-duration)
        guard let firstIdx = storage.firstIndex(where: { $0.timestamp >= cutoff }) else {
            return []
        }
        return Array(storage[firstIdx...])
    }

    public mutating func append(value: Double, timestamp: Date = Date()) {
        if storage.count >= capacity {
            storage.removeFirst(storage.count - capacity + 1)
        }
        storage.append(MetricHistoryPoint(timestamp: timestamp, value: value))
    }

    public mutating func clear() {
        storage.removeAll(keepingCapacity: true)
    }
}
