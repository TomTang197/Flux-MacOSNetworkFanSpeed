# Day/Week/Month Long-Term Telemetry History Design Specification

## Overview
This specification details the architecture, storage engine, downsampling rollup strategy, and UI presentation for tracking CPU/GPU temperatures and fan speed telemetry over extended periods: **Day (24 Hours)**, **Week (7 Days)**, and **Month (30 Days)** in AeroPulse.

---

## 1. Problem & Architecture Goals

### 1.1 Challenges of Long-Term Monitoring
- Sampling at 2-second intervals generates ~43,200 points per day and ~1,296,000 points per month per metric.
- Keeping raw points in memory causes memory pressure, slow UI rendering, and excessive battery/CPU usage.
- Storing uncompressed raw points on disk leads to database bloat (~50-100MB) and slow query performance.

### 1.2 Design Goals
1. **Zero External Dependencies**: Use macOS built-in native `libsqlite3` (`import SQLite3`).
2. **Hierarchical Rollup Engine (RRD Strategy)**:
   - **Realtime (RAM)**: 2s interval, in-memory ring buffer (up to 30 mins).
   - **24 Hours (Day)**: 1-minute rollup buckets (average, min, max). Kept for 24h (~1,440 points).
   - **7 Days (Week)**: 15-minute rollup buckets (average, min, max). Kept for 7d (~672 points).
   - **30 Days (Month)**: 1-hour rollup buckets (average, min, max). Kept for 30d (~720 points).
3. **Minimal Footprint**: Database size strictly bounded under **2 MB** for all metrics over a month.
4. **Seamless UI Integration**:
   - The time range selector on `MetricTrendChartView` expands to include `[1m | 5m | 30m | 24h | 7d | 30d]`.
   - Hover inspection crosshair snaps to historical timestamps with min, max, and average tooltips.
   - Smooth Metal `Canvas` rendering with zero layout thrashing or frame stutter.

---

## 2. Storage & Database Schema

### Database Location
`~/Library/Application Support/AeroPulse/telemetry_history.sqlite`

### Schema Definition
```sql
CREATE TABLE IF NOT EXISTS telemetry_rollups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_key TEXT NOT NULL,          -- 'cpu_temp', 'gpu_temp', 'fan_rpm_<id>'
    resolution INTEGER NOT NULL,        -- 1: 1-minute, 2: 15-minute, 3: 1-hour
    bucket_time INTEGER NOT NULL,       -- Unix epoch seconds (aligned to bucket boundary)
    avg_value REAL NOT NULL,
    min_value REAL NOT NULL,
    max_value REAL NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_rollup_unique
ON telemetry_rollups(metric_key, resolution, bucket_time);

CREATE INDEX IF NOT EXISTS idx_rollup_query
ON telemetry_rollups(metric_key, resolution, bucket_time DESC);
```

### Retention & Pruning
- Resolution 1 (1 min): Pruned when `bucket_time < now - 86,400` (24h).
- Resolution 2 (15 min): Pruned when `bucket_time < now - 604,800` (7d).
- Resolution 3 (1 hr): Pruned when `bucket_time < now - 2,592,000` (30d).

---

## 3. Telemetry Aggregation Engine

```
[Hardware SMC Sampling (Every 2s)]
                │
                ▼
      FanViewModel Telemetry Tick
                │
                ├──► RollingHistoryBuffer (RAM, Realtime 30m)
                │
                ▼
      TelemetryHistoryStore (Background Serial Queue)
                │
         1-Minute Accumulator
                │
         (On Minute Boundary)
                ├─► Insert 1-Minute Rollup (Resolution 1)
                │
         (On 15-Minute Boundary)
                ├─► Aggregate & Insert 15-Minute Rollup (Resolution 2)
                │
         (On 1-Hour Boundary)
                ├─► Aggregate & Insert 1-Hour Rollup (Resolution 3)
                │
                └─► Prune Expired Records
```

---

## 4. UI & Interaction Design

### Time Range Selector
- Realtime Ranges: `1分 (1m)`, `5分 (5m)`, `30分 (30m)`
- Long-Term Ranges: `24时 (24h)`, `7天 (7d)`, `30天 (30d)`

### Hover Tooltip
- Short-term: `23:25:12 · 48°C · GPU: 42°C`
- 24 Hours: `14:30 · 均值: 48°C (42°C ~ 65°C)`
- 7 Days: `10-15 14:00 · 均值: 50°C (40°C ~ 75°C)`
- 30 Days: `10-12 · 均值: 49°C (38°C ~ 78°C)`

---

## 5. Testing & Verification Strategy
- **Unit Testing**: Test SQLite database creation, bucket insertion, rollups aggregation, duplicate key handling, time filtering, and pruning logic with in-memory SQLite database (`:memory:`).
- **Performance Verification**: Benchmark insertion and query speed (< 1ms).
- **Release Compilation**: Full `swift test` and `xcodebuild` Release scheme verification.
