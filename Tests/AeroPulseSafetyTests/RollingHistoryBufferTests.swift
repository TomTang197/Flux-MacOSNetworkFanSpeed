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
}
