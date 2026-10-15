import Foundation

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

    public init(capacity: Int = 60) {
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
