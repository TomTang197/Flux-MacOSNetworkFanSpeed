import XCTest
@testable import AeroPulseFanSafety

final class RollingHistoryBufferTests: XCTestCase {
    func testBufferInitialStateIsEmpty() {
        let buffer = RollingHistoryBuffer(capacity: 10)
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertNil(buffer.latest)
        XCTAssertNil(buffer.minMaxRange)
    }

    func testBufferAppendsAndPreservesOrder() {
        var buffer = RollingHistoryBuffer(capacity: 5)
        let t0 = Date(timeIntervalSinceReferenceDate: 100)
        buffer.append(value: 40.0, timestamp: t0)
        buffer.append(value: 50.0, timestamp: t0.addingTimeInterval(1))

        XCTAssertEqual(buffer.count, 2)
        XCTAssertEqual(buffer.latest, 50.0)
        XCTAssertEqual(buffer.points.map(\.value), [40.0, 50.0])
    }

    func testBufferEnforcesCapacityWithFIFOEviction() {
        var buffer = RollingHistoryBuffer(capacity: 3)
        let t0 = Date(timeIntervalSinceReferenceDate: 100)
        buffer.append(value: 10.0, timestamp: t0)
        buffer.append(value: 20.0, timestamp: t0.addingTimeInterval(1))
        buffer.append(value: 30.0, timestamp: t0.addingTimeInterval(2))
        buffer.append(value: 40.0, timestamp: t0.addingTimeInterval(3))

        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.points.map(\.value), [20.0, 30.0, 40.0])
        XCTAssertEqual(buffer.latest, 40.0)
    }

    func testMinMaxRangeCalculation() {
        var buffer = RollingHistoryBuffer(capacity: 10)
        let t0 = Date(timeIntervalSinceReferenceDate: 100)
        buffer.append(value: 45.0, timestamp: t0)
        buffer.append(value: 65.0, timestamp: t0.addingTimeInterval(1))
        buffer.append(value: 35.0, timestamp: t0.addingTimeInterval(2))

        let range = buffer.minMaxRange
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.lowerBound, 35.0)
        XCTAssertEqual(range?.upperBound, 65.0)
    }

    func testClearEmptiesBuffer() {
        var buffer = RollingHistoryBuffer(capacity: 5)
        buffer.append(value: 10.0)
        buffer.append(value: 20.0)
        XCTAssertEqual(buffer.count, 2)

        buffer.clear()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertNil(buffer.latest)
    }

    func testPointsWithinDurationFiltering() {
        var buffer = RollingHistoryBuffer(capacity: 100)
        let now = Date(timeIntervalSinceReferenceDate: 1000)

        buffer.append(value: 10.0, timestamp: now.addingTimeInterval(-400))
        buffer.append(value: 20.0, timestamp: now.addingTimeInterval(-200))
        buffer.append(value: 30.0, timestamp: now.addingTimeInterval(-50))
        buffer.append(value: 40.0, timestamp: now)

        let within1m = buffer.points(within: 60, from: now)
        XCTAssertEqual(within1m.map(\.value), [30.0, 40.0])

        let within5m = buffer.points(within: 300, from: now)
        XCTAssertEqual(within5m.map(\.value), [20.0, 30.0, 40.0])

        let within10m = buffer.points(within: 600, from: now)
        XCTAssertEqual(within10m.map(\.value), [10.0, 20.0, 30.0, 40.0])
    }

    func testTrendTimeRangeDurations() {
        XCTAssertEqual(TrendTimeRange.oneMinute.duration, 60)
        XCTAssertEqual(TrendTimeRange.fiveMinutes.duration, 300)
        XCTAssertEqual(TrendTimeRange.fifteenMinutes.duration, 900)
        XCTAssertEqual(TrendTimeRange.thirtyMinutes.duration, 1800)
    }
}
