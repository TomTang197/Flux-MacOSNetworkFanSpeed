# Long-Term (Day/Week/Month) History Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement long-term historical tracking and visualization for CPU/GPU temperatures and fan speeds over Day (24 Hours), Week (7 Days), and Month (30 Days) using native SQLite storage and hierarchical rollups.

**Architecture:**
- **Storage**: Native SQLite3 (`import SQLite3`, zero external dependencies), stored at `~/Library/Application Support/AeroPulse/telemetry_history.sqlite`.
- **Downsampling Strategy**:
  - Realtime: 2s in-memory buffer (30m).
  - 24 Hours: 1-minute rollups (~1,440 points).
  - 7 Days: 15-minute rollups (~672 points).
  - 30 Days: 1-hour rollups (~720 points).
- **Presentation**: Metal-backed `Canvas` in `MetricTrendChartView` with crosshair hover inspection and date/time tooltips.

---

### File Structure Map
- **Create:**
  - `AeroPulse/Services/FanSafety/TelemetryHistoryDatabase.swift`: Native SQLite3 database manager.
  - `AeroPulse/Services/FanSafety/TelemetryHistoryStore.swift`: Aggregation engine for minutely, 15-min, and hourly rollups.
  - `Tests/AeroPulseSafetyTests/TelemetryHistoryDatabaseTests.swift`: Unit tests for SQLite database operations.
  - `Tests/AeroPulseSafetyTests/TelemetryHistoryStoreTests.swift`: Unit tests for rollup aggregation and pruning.
- **Modify:**
  - `AeroPulse/Services/FanSafety/RollingHistoryBuffer.swift`: Expand `TrendTimeRange` with `twentyFourHours`, `sevenDays`, `thirtyDays`.
  - `AeroPulse/ViewModels/FanViewModel.swift`: Feed telemetry samples into `TelemetryHistoryStore`.
  - `AeroPulse/Views/MetricTrendChartView.swift`: Support loading and rendering long-term rollup series.
  - `AeroPulse/Helpers/AppConstants.swift`: Add localization strings for day/week/month.

---

### Task 1: SQLite Storage Layer (TDD)

**Files:**
- Create: `AeroPulse/Services/FanSafety/TelemetryHistoryDatabase.swift`
- Create: `Tests/AeroPulseSafetyTests/TelemetryHistoryDatabaseTests.swift`

- [ ] **Step 1: Write failing unit tests for `TelemetryHistoryDatabase`**
  - Test database initialization in memory (`:memory:`).
  - Test insertion of rollup records.
  - Test query by metric key, resolution, and time range.
  - Test pruning of records older than cutoff.

- [ ] **Step 2: Run test to verify failure**
  - Run: `swift test --filter TelemetryHistoryDatabaseTests`

- [ ] **Step 3: Implement `TelemetryHistoryDatabase`**
  - Open/create SQLite connection.
  - Execute schema creation and index creation.
  - Prepared statements for insert, query, and prune.
  - Safe error handling and connection close.

- [ ] **Step 4: Run test to verify passes**
  - Run: `swift test --filter TelemetryHistoryDatabaseTests`

- [ ] **Step 5: Commit**
  - `git commit -m "feat(telemetry): add TelemetryHistoryDatabase with SQLite3 and unit tests"`

---

### Task 2: Telemetry Aggregation Engine (TDD)

**Files:**
- Create: `AeroPulse/Services/FanSafety/TelemetryHistoryStore.swift`
- Create: `Tests/AeroPulseSafetyTests/TelemetryHistoryStoreTests.swift`

- [ ] **Step 1: Write failing unit tests for `TelemetryHistoryStore`**
  - Test 1-minute bucket accumulation (sum, min, max, count).
  - Test flushing 1-minute rollup.
  - Test cascading 15-minute and 1-hour rollup calculation.
  - Test query for Day, Week, Month resolutions.

- [ ] **Step 2: Run test to verify failure**
  - Run: `swift test --filter TelemetryHistoryStoreTests`

- [ ] **Step 3: Implement `TelemetryHistoryStore`**
  - Background serial queue for non-blocking database writes.
  - Bucket accumulator structure for active samples.
  - Rollup trigger logic on boundary crossings.
  - Historical query API returning `[HistoricalRollupPoint]`.

- [ ] **Step 4: Run test to verify passes**
  - Run: `swift test --filter TelemetryHistoryStoreTests`

- [ ] **Step 5: Commit**
  - `git commit -m "feat(telemetry): add TelemetryHistoryStore rollup aggregation with unit tests"`

---

### Task 3: Hook TelemetryHistoryStore into FanViewModel

**Files:**
- Modify: `AeroPulse/ViewModels/FanViewModel.swift`

- [ ] **Step 1: Initialize `TelemetryHistoryStore.shared` in `FanViewModel`**
- [ ] **Step 2: Forward sampled temperatures and fan speeds on every refresh tick**
- [ ] **Step 3: Run unit tests**
  - Run: `swift test`
- [ ] **Step 4: Commit**
  - `git commit -m "feat(viewmodel): feed telemetry samples into TelemetryHistoryStore"`

---

### Task 4: Expand TrendTimeRange & Update MetricTrendChartView

**Files:**
- Modify: `AeroPulse/Services/FanSafety/RollingHistoryBuffer.swift`
- Modify: `AeroPulse/Views/MetricTrendChartView.swift`
- Modify: `AeroPulse/Helpers/AppConstants.swift`

- [ ] **Step 1: Add `twentyFourHours` (24h), `sevenDays` (7d), `thirtyDays` (30d) to `TrendTimeRange`**
- [ ] **Step 2: Add localized strings in `AppConstants.swift`**
- [ ] **Step 3: Update `MetricTrendChartView` to load historical rollups for long-term ranges**
  - If range is real-time (<= 30m): use in-memory `points`.
  - If range is long-term (24h/7d/30d): query `TelemetryHistoryStore`.
  - Update hover inspection crosshair to display date and min/max stats.
- [ ] **Step 4: Commit**
  - `git commit -m "feat(ui): support 24h, 7d, 30d time ranges in MetricTrendChartView with hover tooltips"`

---

### Task 5: Full System Verification & Release Deployment

- [ ] **Step 1: Run full unit test suite**
  - Run: `swift test`
- [ ] **Step 2: Verify Release build with `xcodebuild`**
  - Run: `xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Release build CODE_SIGNING_ALLOWED=NO`
- [ ] **Step 3: Ad-hoc codesign, install to `/Applications/AeroPulse.app`, and launch**
- [ ] **Step 4: Commit final changes and push to `origin main`**
