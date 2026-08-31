import XCTest
@testable import FanHelperSafety

final class FanControlLeaseTests: XCTestCase {
    func testControlledLeaseExpiresAtTimeout() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)

        lease.noteControl(ofFan: 0, owner: owner, at: start)

        XCTAssertFalse(lease.shouldRestore(at: start.addingTimeInterval(11.9)))
        XCTAssertTrue(lease.shouldRestore(at: start.addingTimeInterval(12)))
    }

    func testHeartbeatExtendsActiveLease() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: start)

        XCTAssertTrue(lease.noteHeartbeat(owner: owner, at: start.addingTimeInterval(10)))

        XCTAssertFalse(lease.shouldRestore(at: start.addingTimeInterval(21.9)))
        XCTAssertTrue(lease.shouldRestore(at: start.addingTimeInterval(22)))
    }

    func testHeartbeatDoesNotActivateIdleLease() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        var lease = FanControlLease(timeout: 12)

        XCTAssertFalse(lease.noteHeartbeat(owner: UUID(), at: now))

        XCTAssertFalse(lease.isActive)
        XCTAssertFalse(lease.shouldRestore(at: now.addingTimeInterval(30)))
    }

    func testRestoringLastControlledFanClearsLease() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: now)
        lease.noteControl(ofFan: 1, owner: owner, at: now)

        lease.noteRestored(fan: 0, owner: owner)
        XCTAssertTrue(lease.isActive)

        lease.noteRestored(fan: 1, owner: owner)
        XCTAssertFalse(lease.isActive)
        XCTAssertFalse(lease.shouldRestore(at: now.addingTimeInterval(30)))
    }

    func testRestoreAllClearsLease() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: now)

        lease.noteRestoredAll()

        XCTAssertFalse(lease.isActive)
        XCTAssertTrue(lease.controlledFans.isEmpty)
    }

    func testSecondClientCannotTakeOverActiveLease() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        let otherClient = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: now)

        XCTAssertTrue(lease.allowsControl(from: owner))
        XCTAssertFalse(lease.allowsControl(from: otherClient))
        XCTAssertFalse(lease.noteHeartbeat(owner: otherClient, at: now.addingTimeInterval(5)))
        XCTAssertTrue(lease.shouldRestore(at: now.addingTimeInterval(12)))
    }

    func testOnlyOwnerDisconnectRequiresRestore() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        let staleClient = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: now)

        XCTAssertFalse(lease.shouldRestoreAfterDisconnect(of: staleClient))
        XCTAssertTrue(lease.shouldRestoreAfterDisconnect(of: owner))
    }

    func testRecoveryRequiredRejectsHeartbeatsAndRetriesImmediately() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: now)

        lease.noteRecoveryRequired()

        XCTAssertFalse(lease.allowsControl(from: owner))
        XCTAssertTrue(lease.allowsRecovery(from: owner))
        XCTAssertFalse(lease.noteHeartbeat(owner: owner, at: now.addingTimeInterval(1)))
        XCTAssertTrue(lease.shouldRestore(at: now.addingTimeInterval(1)))
    }

    func testBoundedOwnerProgressExtendsLeaseDuringAtomicBatch() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let owner = UUID()
        var lease = FanControlLease(timeout: 12)
        lease.noteControl(ofFan: 0, owner: owner, at: start)

        XCTAssertTrue(lease.noteProgress(owner: owner, at: start.addingTimeInterval(10)))
        XCTAssertFalse(lease.shouldRestore(at: start.addingTimeInterval(21.9)))
        XCTAssertTrue(lease.shouldRestore(at: start.addingTimeInterval(22)))
    }
}
