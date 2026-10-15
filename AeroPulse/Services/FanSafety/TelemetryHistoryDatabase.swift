import Foundation
import SQLite3

public struct TelemetryRollupRecord: Equatable {
    public let id: Int64?
    public let metricKey: String
    public let resolution: Int // 1: 1m (24h), 2: 15m (7d), 3: 1h (30d)
    public let bucketTime: Int64
    public let avgValue: Double
    public let minValue: Double
    public let maxValue: Double

    public init(
        id: Int64? = nil,
        metricKey: String,
        resolution: Int,
        bucketTime: Int64,
        avgValue: Double,
        minValue: Double,
        maxValue: Double
    ) {
        self.id = id
        self.metricKey = metricKey
        self.resolution = resolution
        self.bucketTime = bucketTime
        self.avgValue = avgValue
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

public enum TelemetryDatabaseError: Error {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
}

public final class TelemetryHistoryDatabase {
    private var db: OpaquePointer?
    private let path: String

    public init(path: String = ":memory:") throws {
        self.path = path
        try openDatabase()
        try createSchema()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func openDatabase() throws {
        if path != ":memory:" {
            let fileURL = URL(fileURLWithPath: path)
            let folderURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &handle, flags, nil) != SQLITE_OK {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw TelemetryDatabaseError.openFailed(msg)
        }
        self.db = handle

        // WAL mode for fast non-blocking concurrent reads and writes
        if path != ":memory:" {
            _ = executeSQL("PRAGMA journal_mode=WAL;")
            _ = executeSQL("PRAGMA synchronous=NORMAL;")
        }
    }

    private func executeSQL(_ sql: String) -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS telemetry_rollups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            metric_key TEXT NOT NULL,
            resolution INTEGER NOT NULL,
            bucket_time INTEGER NOT NULL,
            avg_value REAL NOT NULL,
            min_value REAL NOT NULL,
            max_value REAL NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_rollup_unique
        ON telemetry_rollups(metric_key, resolution, bucket_time);

        CREATE INDEX IF NOT EXISTS idx_rollup_query
        ON telemetry_rollups(metric_key, resolution, bucket_time ASC);
        """
        guard executeSQL(sql) else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Schema creation error"
            throw TelemetryDatabaseError.executionFailed(msg)
        }
    }

    public func insert(record: TelemetryRollupRecord) throws {
        guard let db else { throw TelemetryDatabaseError.openFailed("Database closed") }
        let sql = """
        INSERT INTO telemetry_rollups (metric_key, resolution, bucket_time, avg_value, min_value, max_value)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(metric_key, resolution, bucket_time) DO UPDATE SET
            avg_value = excluded.avg_value,
            min_value = excluded.min_value,
            max_value = excluded.max_value;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TelemetryDatabaseError.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (record.metricKey as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(record.resolution))
        sqlite3_bind_int64(stmt, 3, record.bucketTime)
        sqlite3_bind_double(stmt, 4, record.avgValue)
        sqlite3_bind_double(stmt, 5, record.minValue)
        sqlite3_bind_double(stmt, 6, record.maxValue)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TelemetryDatabaseError.stepFailed(msg)
        }
    }

    public func insert(records: [TelemetryRollupRecord]) throws {
        guard !records.isEmpty else { return }
        _ = executeSQL("BEGIN TRANSACTION;")
        do {
            for record in records {
                try insert(record: record)
            }
            _ = executeSQL("COMMIT;")
        } catch {
            _ = executeSQL("ROLLBACK;")
            throw error
        }
    }

    public func query(
        metricKey: String,
        resolution: Int,
        startTime: Int64,
        endTime: Int64
    ) throws -> [TelemetryRollupRecord] {
        guard let db else { throw TelemetryDatabaseError.openFailed("Database closed") }
        let sql = """
        SELECT id, metric_key, resolution, bucket_time, avg_value, min_value, max_value
        FROM telemetry_rollups
        WHERE metric_key = ? AND resolution = ? AND bucket_time >= ? AND bucket_time <= ?
        ORDER BY bucket_time ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TelemetryDatabaseError.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (metricKey as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(resolution))
        sqlite3_bind_int64(stmt, 3, startTime)
        sqlite3_bind_int64(stmt, 4, endTime)

        var results: [TelemetryRollupRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let key = String(cString: sqlite3_column_text(stmt, 1))
            let res = Int(sqlite3_column_int(stmt, 2))
            let bTime = sqlite3_column_int64(stmt, 3)
            let avg = sqlite3_column_double(stmt, 4)
            let min = sqlite3_column_double(stmt, 5)
            let max = sqlite3_column_double(stmt, 6)

            results.append(
                TelemetryRollupRecord(
                    id: id,
                    metricKey: key,
                    resolution: res,
                    bucketTime: bTime,
                    avgValue: avg,
                    minValue: min,
                    maxValue: max
                )
            )
        }
        return results
    }

    @discardableResult
    public func prune(resolution: Int, olderThan: Int64) throws -> Int {
        guard let db else { throw TelemetryDatabaseError.openFailed("Database closed") }
        let sql = "DELETE FROM telemetry_rollups WHERE resolution = ? AND bucket_time < ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TelemetryDatabaseError.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(resolution))
        sqlite3_bind_int64(stmt, 2, olderThan)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TelemetryDatabaseError.stepFailed(msg)
        }
        return Int(sqlite3_changes(db))
    }
}
