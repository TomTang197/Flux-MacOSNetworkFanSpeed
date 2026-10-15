import XCTest
@testable import AeroPulseFanSafety

final class TelemetryHistoryStoreTests: XCTestCase {
    var db: TelemetryHistoryDatabase!
    var store: TelemetryHistoryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try TelemetryHistoryDatabase(path: ":memory:")
        store = TelemetryHistoryStore(database: db)
    }

    override func tearDownWithError() throws {
        store = nil
        db = nil
        try super.tearDownWithError()
    }

    func testRecordSampleAccumulationAndFlush() {
        let t0 = Date(timeIntervalSinceReferenceDate: 60) // exact minute 1

        store.record(metricKey: "cpu_temp", value: 40.0, timestamp: t0)
        store.record(metricKey: "cpu_temp", value: 60.0, timestamp: t0.addingTimeInterval(10))
        store.record(metricKey: "cpu_temp", value: 50.0, timestamp: t0.addingTimeInterval(20))

        // Force flush minute 1
        store.flushActiveBuckets(at: t0.addingTimeInterval(61))

        let history = store.queryHistory(
            metricKey: "cpu_temp",
            range: .twentyFourHours,
            now: t0.addingTimeInterval(70)
        )
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.avgValue, 50.0)
        XCTAssertEqual(history.first?.minValue, 40.0)
        XCTAssertEqual(history.first?.maxValue, 60.0)
    }

    func testCascadingRollupTo15MinAndHourly() throws {
        // Record 15 minute buckets
        let start = Date(timeIntervalSinceReferenceDate: 0)
        for min in 0..<15 {
            let t = start.addingTimeInterval(Double(min * 60))
            store.record(metricKey: "gpu_temp", value: 40.0 + Double(min), timestamp: t)
            store.flushActiveBuckets(at: t.addingTimeInterval(60))
        }

        // Trigger 15-min rollup
        store.aggregateFifteenMinuteRollups(at: start.addingTimeInterval(900))

        let sevenDayHistory = store.queryHistory(
            metricKey: "gpu_temp",
            range: .sevenDays,
            now: start.addingTimeInterval(950)
        )
        XCTAssertEqual(sevenDayHistory.count, 1)
        XCTAssertEqual(sevenDayHistory.first?.minValue, 40.0)
        XCTAssertEqual(sevenDayHistory.first?.maxValue, 54.0)
    }

    func testPruningDeletesOldData() throws {
        let now = Date(timeIntervalSinceReferenceDate: 3_000_000)
        let oldRecord = TelemetryRollupRecord(
            metricKey: "cpu_temp",
            resolution: 1,
            bucketTime: Int64(now.timeIntervalSinceReferenceDate - 100_000), // > 24h ago
            avgValue: 50,
            minValue: 45,
            maxValue: 55
        )
        try db.insert(record: oldRecord)

        store.pruneOldRecords(now: now)

        let result = store.queryHistory(metricKey: "cpu_temp", range: .twentyFourHours, now: now)
        XCTAssertTrue(result.isEmpty)
    }
}
