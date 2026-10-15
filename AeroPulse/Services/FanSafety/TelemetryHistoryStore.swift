import Foundation

public struct HistoricalRollupPoint: Identifiable, Equatable {
    public let id: String
    public let timestamp: Date
    public let avgValue: Double
    public let minValue: Double
    public let maxValue: Double

    public init(
        timestamp: Date,
        avgValue: Double,
        minValue: Double,
        maxValue: Double
    ) {
        self.id = "\(timestamp.timeIntervalSince1970)"
        self.timestamp = timestamp
        self.avgValue = avgValue
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

public final class TelemetryHistoryStore {
    public static let shared: TelemetryHistoryStore = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("AeroPulse/telemetry_history.sqlite").path
        do {
            let db = try TelemetryHistoryDatabase(path: dbPath)
            return TelemetryHistoryStore(database: db)
        } catch {
            NSLog("Failed to initialize TelemetryHistoryDatabase at \(dbPath): \(error). Falling back to in-memory.")
            let inMemory = try! TelemetryHistoryDatabase(path: ":memory:")
            return TelemetryHistoryStore(database: inMemory)
        }
    }()

    private let database: TelemetryHistoryDatabase
    private let queue = DispatchQueue(label: "com.bandan.me.AeroPulse.TelemetryHistoryStore", qos: .utility)

    private struct BucketAccumulator {
        var count: Int = 0
        var sum: Double = 0
        var min: Double = .infinity
        var max: Double = -.infinity

        mutating func add(_ val: Double) {
            count += 1
            sum += val
            if val < min { min = val }
            if val > max { max = val }
        }

        var avg: Double { count > 0 ? sum / Double(count) : 0 }
    }

    private var activeBuckets: [String: BucketAccumulator] = [:]
    private var currentBucketMinute: Int64 = 0
    private var lastRollup15mMinute: Int64 = 0
    private var lastRollupHourlyMinute: Int64 = 0
    private var lastPruneTimestamp: Date = .distantPast

    public init(database: TelemetryHistoryDatabase) {
        self.database = database
    }

    public func record(metricKey: String, value: Double, timestamp: Date = Date()) {
        queue.async { [weak self] in
            guard let self else { return }
            let epochSeconds = Int64(timestamp.timeIntervalSince1970)
            let bucketMinute = (epochSeconds / 60) * 60

            if self.currentBucketMinute == 0 {
                self.currentBucketMinute = bucketMinute
            } else if bucketMinute > self.currentBucketMinute {
                self.internalFlush(at: timestamp)
                self.currentBucketMinute = bucketMinute
            }

            var accumulator = self.activeBuckets[metricKey] ?? BucketAccumulator()
            accumulator.add(value)
            self.activeBuckets[metricKey] = accumulator
        }
    }

    public func flushActiveBuckets(at timestamp: Date = Date()) {
        queue.sync {
            internalFlush(at: timestamp)
        }
    }

    private func internalFlush(at timestamp: Date) {
        guard !activeBuckets.isEmpty, currentBucketMinute > 0 else { return }

        var records: [TelemetryRollupRecord] = []
        for (key, acc) in activeBuckets where acc.count > 0 {
            records.append(
                TelemetryRollupRecord(
                    metricKey: key,
                    resolution: 1, // 1m rollup
                    bucketTime: currentBucketMinute,
                    avgValue: acc.avg,
                    minValue: acc.min,
                    maxValue: acc.max
                )
            )
        }
        activeBuckets.removeAll()

        do {
            try database.insert(records: records)
        } catch {
            NSLog("TelemetryHistoryStore: Failed to flush 1-minute records: \(error)")
        }

        // Check if 15-minute or hourly rollup should be processed
        let epoch = Int64(timestamp.timeIntervalSince1970)
        let minute15 = (epoch / 900) * 900
        if minute15 > lastRollup15mMinute {
            internalAggregateFifteenMinute(at: timestamp)
            lastRollup15mMinute = minute15
        }

        let minuteHourly = (epoch / 3600) * 3600
        if minuteHourly > lastRollupHourlyMinute {
            internalAggregateHourly(at: timestamp)
            lastRollupHourlyMinute = minuteHourly
        }

        // Periodic pruning once every hour
        if timestamp.timeIntervalSince(lastPruneTimestamp) > 3600 {
            internalPrune(now: timestamp)
            lastPruneTimestamp = timestamp
        }
    }

    public func aggregateFifteenMinuteRollups(at timestamp: Date) {
        queue.sync {
            internalAggregateFifteenMinute(at: timestamp)
        }
    }

    private func internalAggregateFifteenMinute(at timestamp: Date) {
        let epoch = Int64(timestamp.timeIntervalSince1970)
        let bucketTime = ((epoch - 900) / 900) * 900
        let startTime = bucketTime
        let endTime = bucketTime + 899

        let metrics = ["cpu_temp", "gpu_temp", "fan_rpm_0", "fan_rpm_1"]
        for metric in metrics {
            guard let oneMinRecords = try? database.query(
                metricKey: metric,
                resolution: 1,
                startTime: startTime,
                endTime: endTime
            ), !oneMinRecords.isEmpty else { continue }

            let totalCount = oneMinRecords.count
            let avg = oneMinRecords.map(\.avgValue).reduce(0, +) / Double(totalCount)
            let minVal = oneMinRecords.map(\.minValue).min() ?? avg
            let maxVal = oneMinRecords.map(\.maxValue).max() ?? avg

            let record15 = TelemetryRollupRecord(
                metricKey: metric,
                resolution: 2, // 15m rollup
                bucketTime: bucketTime,
                avgValue: avg,
                minValue: minVal,
                maxValue: maxVal
            )
            try? database.insert(record: record15)
        }
    }

    public func aggregateHourlyRollups(at timestamp: Date) {
        queue.sync {
            internalAggregateHourly(at: timestamp)
        }
    }

    private func internalAggregateHourly(at timestamp: Date) {
        let epoch = Int64(timestamp.timeIntervalSince1970)
        let bucketTime = ((epoch - 3600) / 3600) * 3600
        let startTime = bucketTime
        let endTime = bucketTime + 3599

        let metrics = ["cpu_temp", "gpu_temp", "fan_rpm_0", "fan_rpm_1"]
        for metric in metrics {
            guard let records15 = try? database.query(
                metricKey: metric,
                resolution: 2,
                startTime: startTime,
                endTime: endTime
            ), !records15.isEmpty else { continue }

            let totalCount = records15.count
            let avg = records15.map(\.avgValue).reduce(0, +) / Double(totalCount)
            let minVal = records15.map(\.minValue).min() ?? avg
            let maxVal = records15.map(\.maxValue).max() ?? avg

            let recordHourly = TelemetryRollupRecord(
                metricKey: metric,
                resolution: 3, // 1h rollup
                bucketTime: bucketTime,
                avgValue: avg,
                minValue: minVal,
                maxValue: maxVal
            )
            try? database.insert(record: recordHourly)
        }
    }

    public func pruneOldRecords(now: Date = Date()) {
        queue.sync {
            internalPrune(now: now)
        }
    }

    private func internalPrune(now: Date) {
        let epoch = Int64(now.timeIntervalSince1970)
        _ = try? database.prune(resolution: 1, olderThan: epoch - 86400) // Keep 24h of 1m
        _ = try? database.prune(resolution: 2, olderThan: epoch - 604800) // Keep 7d of 15m
        _ = try? database.prune(resolution: 3, olderThan: epoch - 2592000) // Keep 30d of 1h
    }

    public func queryHistory(
        metricKey: String,
        range: TrendTimeRange,
        now: Date = Date()
    ) -> [HistoricalRollupPoint] {
        return queue.sync {
            let epoch = Int64(now.timeIntervalSince1970)
            let startTime = epoch - Int64(range.duration)
            let resolution: Int
            switch range {
            case .twentyFourHours:
                resolution = 1 // 1-minute resolution
            case .sevenDays:
                resolution = 2 // 15-minute resolution
            case .thirtyDays:
                resolution = 3 // 1-hour resolution
            default:
                resolution = 1
            }

            guard let rawRecords = try? database.query(
                metricKey: metricKey,
                resolution: resolution,
                startTime: startTime,
                endTime: epoch
            ) else {
                return []
            }

            return rawRecords.map { rec in
                HistoricalRollupPoint(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(rec.bucketTime)),
                    avgValue: rec.avgValue,
                    minValue: rec.minValue,
                    maxValue: rec.maxValue
                )
            }
        }
    }
}
