import XCTest
@testable import AeroPulseFanSafety

final class TelemetryHistoryDatabaseTests: XCTestCase {
    var db: TelemetryHistoryDatabase!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try TelemetryHistoryDatabase(path: ":memory:")
    }

    override func tearDownWithError() throws {
        db = nil
        try super.tearDownWithError()
    }

    func testDatabaseInitializationAndSchemaCreation() throws {
        XCTAssertNotNil(db)
    }

    func testInsertAndQuerySingleRecord() throws {
        let record = TelemetryRollupRecord(
            metricKey: "cpu_temp",
            resolution: 1,
            bucketTime: 1000,
            avgValue: 48.5,
            minValue: 45.0,
            maxValue: 52.0
        )
        try db.insert(record: record)

        let results = try db.query(
            metricKey: "cpu_temp",
            resolution: 1,
            startTime: 900,
            endTime: 1100
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.metricKey, "cpu_temp")
        XCTAssertEqual(results.first?.resolution, 1)
        XCTAssertEqual(results.first?.bucketTime, 1000)
        XCTAssertEqual(results.first?.avgValue, 48.5)
        XCTAssertEqual(results.first?.minValue, 45.0)
        XCTAssertEqual(results.first?.maxValue, 52.0)
    }

    func testUpsertUpdatesExistingBucket() throws {
        let record1 = TelemetryRollupRecord(
            metricKey: "cpu_temp",
            resolution: 1,
            bucketTime: 1000,
            avgValue: 48.0,
            minValue: 45.0,
            maxValue: 50.0
        )
        try db.insert(record: record1)

        let record2 = TelemetryRollupRecord(
            metricKey: "cpu_temp",
            resolution: 1,
            bucketTime: 1000,
            avgValue: 55.0,
            minValue: 45.0,
            maxValue: 60.0
        )
        try db.insert(record: record2)

        let results = try db.query(
            metricKey: "cpu_temp",
            resolution: 1,
            startTime: 900,
            endTime: 1100
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.avgValue, 55.0)
        XCTAssertEqual(results.first?.maxValue, 60.0)
    }

    func testQueryRangeFiltering() throws {
        for t in stride(from: 100, through: 500, by: 100) {
            let record = TelemetryRollupRecord(
                metricKey: "gpu_temp",
                resolution: 1,
                bucketTime: Int64(t),
                avgValue: Double(t) / 10.0,
                minValue: Double(t) / 10.0 - 2,
                maxValue: Double(t) / 10.0 + 2
            )
            try db.insert(record: record)
        }

        // Query only 200..400
        let results = try db.query(
            metricKey: "gpu_temp",
            resolution: 1,
            startTime: 200,
            endTime: 400
        )
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map(\.bucketTime), [200, 300, 400])
    }

    func testPruningDeletesOldRecords() throws {
        for t in stride(from: 100, through: 500, by: 100) {
            let record = TelemetryRollupRecord(
                metricKey: "fan_rpm",
                resolution: 1,
                bucketTime: Int64(t),
                avgValue: Double(t * 10),
                minValue: Double(t * 10 - 50),
                maxValue: Double(t * 10 + 50)
            )
            try db.insert(record: record)
        }

        // Prune older than 300
        let deleted = try db.prune(resolution: 1, olderThan: 300)
        XCTAssertEqual(deleted, 2) // 100 and 200

        let remaining = try db.query(
            metricKey: "fan_rpm",
            resolution: 1,
            startTime: 0,
            endTime: 1000
        )
        XCTAssertEqual(remaining.count, 3)
        XCTAssertEqual(remaining.map(\.bucketTime), [300, 400, 500])
    }
}
