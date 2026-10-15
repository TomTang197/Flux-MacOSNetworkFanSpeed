# Fan and Temperature Trend Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time historical trend charts and sparklines for fan speeds and CPU/GPU temperatures across the AeroPulse Dashboard and Menu Bar popover.

**Architecture:** A bounded FIFO ring buffer (`RollingHistoryBuffer`) maintains timestamped metric points (`MetricHistoryPoint`) with zero dynamic reallocation or memory leakage. SwiftUI hardware-accelerated Bezier curves and gradient fills display full trend cards in the Dashboard (`MetricTrendChartView`) and compact sparklines in the Menu Bar popover (`MiniSparklineView`).

**Tech Stack:** Swift 5.9, SwiftUI (Path, Canvas, Shapes), Combine, XCTest.

---

### File Structure Map
- **Create:**
  - `AeroPulse/Services/FanSafety/RollingHistoryBuffer.swift`: Data structure for fixed-capacity rolling metrics.
  - `Tests/AeroPulseSafetyTests/RollingHistoryBufferTests.swift`: Comprehensive unit tests for rolling history buffer.
  - `AeroPulse/Views/MetricTrendChartView.swift`: Full-sized trend chart component with gridlines, Bezier curve, gradient fill, min/max bounds.
  - `AeroPulse/Views/MiniSparklineView.swift`: Ultra-compact sparkline view for MenuBar rows.
- **Modify:**
  - `AeroPulse/ViewModels/FanViewModel.swift`: Store rolling buffers for CPU temp, GPU temp, and fan RPMs, pushing updates on each sampling tick.
  - `AeroPulse/Views/ThermalDetailView.swift`: Add temperature trend chart below CPU/GPU summary cards.
  - `AeroPulse/Views/FanControlCard.swift`: Add fan RPM trend chart above fan speed rows.
  - `AeroPulse/Views/MenuBarFanSection.swift`: Add `MiniSparklineView` in temperature rows and primary fan speed row.
  - `AeroPulse/Localization/AppStrings.swift`: Add localized labels for trend charts.

---

### Task 1: Rolling History Buffer & Point Model (TDD)

**Files:**
- Create: `AeroPulse/Services/FanSafety/RollingHistoryBuffer.swift`
- Create: `Tests/AeroPulseSafetyTests/RollingHistoryBufferTests.swift`

- [x] **Step 1: Write failing unit test for `RollingHistoryBuffer`**

```swift
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
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter RollingHistoryBufferTests`
Expected: Compilation failure because `RollingHistoryBuffer` does not exist yet.

- [x] **Step 3: Implement `MetricHistoryPoint` and `RollingHistoryBuffer`**

```swift
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
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --filter RollingHistoryBufferTests`
Expected: PASS (4 tests passed).

- [x] **Step 5: Commit**

```bash
git add AeroPulse/Services/FanSafety/RollingHistoryBuffer.swift Tests/AeroPulseSafetyTests/RollingHistoryBufferTests.swift
git commit -m "feat(telemetry): add RollingHistoryBuffer and MetricHistoryPoint with tests"
```

---

### Task 2: Hook History Buffers into `FanViewModel`

**Files:**
- Modify: `AeroPulse/ViewModels/FanViewModel.swift`

- [x] **Step 1: Declare history properties and buffer instances in `FanViewModel`**

Add `@Published` properties:
```swift
@Published private(set) var cpuTemperatureHistory: [MetricHistoryPoint] = []
@Published private(set) var gpuTemperatureHistory: [MetricHistoryPoint] = []
@Published private(set) var fanRPMHistory: [Int: [MetricHistoryPoint]] = [:]
```

Add private buffers:
```swift
private var cpuHistoryBuffer = RollingHistoryBuffer(capacity: 60)
private var gpuHistoryBuffer = RollingHistoryBuffer(capacity: 60)
private var fanRPMHistoryBuffers: [Int: RollingHistoryBuffer] = [:]
```

- [x] **Step 2: Append samples in telemetry update pipeline**

In `updateSensorsAndFans(...)` or `refreshData()` after extracting temperatures and fan readings:
```swift
let now = Date()
if let cpuTemp = ThermalSensorProcessing.primaryCPUTemperature(from: newSensors) {
    cpuHistoryBuffer.append(value: cpuTemp, timestamp: now)
    cpuTemperatureHistory = cpuHistoryBuffer.points
}

if let gpuTemp = ThermalSensorProcessing.primaryGPUTemperature(from: newSensors) {
    gpuHistoryBuffer.append(value: gpuTemp, timestamp: now)
    gpuTemperatureHistory = gpuHistoryBuffer.points
}

var updatedFanRPMHistory: [Int: [MetricHistoryPoint]] = [:]
for fan in newFans {
    var buffer = fanRPMHistoryBuffers[fan.id] ?? RollingHistoryBuffer(capacity: 60)
    buffer.append(value: Double(fan.currentRPM), timestamp: now)
    fanRPMHistoryBuffers[fan.id] = buffer
    updatedFanRPMHistory[fan.id] = buffer.points
}
fanRPMHistory = updatedFanRPMHistory
```

- [x] **Step 3: Run unit tests**

Run: `swift test`
Expected: PASS (all 138 tests pass).

- [x] **Step 4: Commit**

```bash
git add AeroPulse/ViewModels/FanViewModel.swift
git commit -m "feat(viewmodel): collect rolling telemetry history in FanViewModel"
```

---

### Task 3: Build `MetricTrendChartView` & `MiniSparklineView`

**Files:**
- Create: `AeroPulse/Views/MetricTrendChartView.swift`
- Create: `AeroPulse/Views/MiniSparklineView.swift`
- Modify: `AeroPulse/Localization/AppStrings.swift`

- [x] **Step 1: Add localization strings**

In `AppStrings.swift`:
```swift
static var trendMin: String { tr(en: "Min", zh: "最低") }
static var trendMax: String { tr(en: "Max", zh: "最高") }
static var temperatureTrend: String { tr(en: "Temperature Trend", zh: "温度走势") }
static var fanRPMTrend: String { tr(en: "Fan Speed Trend", zh: "风扇转速走势") }
```

- [x] **Step 2: Implement `MetricTrendChartView`**

Features:
- Normalized coordinate mapping with minimum vertical padding (span ≥ 5 units).
- Bezier smoothing curve or crisp path with line stroke.
- Bottom-anchored gradient fill under the curve.
- Top bar with metric title, latest value, and Min / Max indicator pills.
- Subtle dotted horizontal baseline and midline guides.

```swift
import SwiftUI

struct MetricTrendChartView: View {
    let title: String
    let points: [MetricHistoryPoint]
    let unit: String
    let tintColor: Color
    var secondaryPoints: [MetricHistoryPoint]? = nil
    var secondaryColor: Color = .purple
    var secondaryTitle: String? = nil

    private var primaryRange: ClosedRange<Double> {
        let values = points.map(\.value) + (secondaryPoints?.map(\.value) ?? [])
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }
        let padding = max(4.0, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            chartArea
                .frame(height: 65)
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let latest = points.last?.value {
                Text(String(format: "%.0f %@", latest, unit))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(tintColor)
            }

            if let secPoints = secondaryPoints, let secLatest = secPoints.last?.value, let secTitle = secondaryTitle {
                Text("· \(secTitle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f %@", secLatest, unit))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(secondaryColor)
            }

            Spacer()

            if let minVal = points.map(\.value).min(), let maxVal = points.map(\.value).max() {
                Text("\(AppStrings.trendMin): \(Int(minVal))\(unit) · \(AppStrings.trendMax): \(Int(maxVal))\(unit)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartArea: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let range = primaryRange

            ZStack {
                // Background gridlines
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w, y: h * 0.5))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                .foregroundStyle(Color.secondary.opacity(0.2))

                if let secondary = secondaryPoints, secondary.count > 1 {
                    curvePath(points: secondary, width: w, height: h, range: range, closed: true)
                        .fill(LinearGradient(colors: [secondaryColor.opacity(0.12), secondaryColor.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    curvePath(points: secondary, width: w, height: h, range: range, closed: false)
                        .stroke(secondaryColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                if points.count > 1 {
                    curvePath(points: points, width: w, height: h, range: range, closed: true)
                        .fill(LinearGradient(colors: [tintColor.opacity(0.20), tintColor.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    curvePath(points: points, width: w, height: h, range: range, closed: false)
                        .stroke(tintColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                    if let lastPt = normalizedPoint(index: points.count - 1, total: points.count, value: points.last!.value, width: w, height: h, range: range) {
                        Circle()
                            .fill(tintColor)
                            .frame(width: 4, height: 4)
                            .position(lastPt)
                    }
                } else {
                    Text(AppStrings.noData)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func normalizedPoint(index: Int, total: Int, value: Double, width: CGFloat, height: CGFloat, range: ClosedRange<Double>) -> CGPoint? {
        guard total > 1, range.upperBound > range.lowerBound else { return nil }
        let x = width * CGFloat(index) / CGFloat(total - 1)
        let normalizedY = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let y = height * (1.0 - CGFloat(normalizedY))
        return CGPoint(x: x, y: max(0, min(height, y)))
    }

    private func curvePath(points: [MetricHistoryPoint], width: CGFloat, height: CGFloat, range: ClosedRange<Double>, closed: Bool) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let coords: [CGPoint] = points.enumerated().compactMap { idx, pt in
            normalizedPoint(index: idx, total: points.count, value: pt.value, width: width, height: height, range: range)
        }
        guard let first = coords.first else { return path }

        path.move(to: first)
        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let curr = coords[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            path.addLine(to: curr)
        }

        if closed, let last = coords.last {
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.addLine(to: CGPoint(x: first.x, y: height))
            path.closeSubpath()
        }

        return path
    }
}
```

- [x] **Step 3: Implement `MiniSparklineView`**

```swift
import SwiftUI

struct MiniSparklineView: View {
    let points: [MetricHistoryPoint]
    let tintColor: Color
    var width: CGFloat = 42
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = points.map(\.value)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let span = max(2.0, maxVal - minVal)
            let lower = minVal - span * 0.1
            let upper = maxVal + span * 0.1

            if points.count > 1 {
                ZStack {
                    Path { p in
                        for (idx, pt) in points.enumerated() {
                            let x = w * CGFloat(idx) / CGFloat(points.count - 1)
                            let normY = (pt.value - lower) / (upper - lower)
                            let y = h * (1.0 - CGFloat(normY))
                            let clampedY = max(1, min(h - 1, y))
                            if idx == 0 {
                                p.move(to: CGPoint(x: x, y: clampedY))
                            } else {
                                p.addLine(to: CGPoint(x: x, y: clampedY))
                            }
                        }
                    }
                    .stroke(tintColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        let normY = (last.value - lower) / (upper - lower)
                        let y = max(1, min(h - 1, h * (1.0 - CGFloat(normY))))
                        Circle()
                            .fill(tintColor)
                            .frame(width: 3, height: 3)
                            .position(x: w, y: y)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: width, height: height)
    }
}
```

- [x] **Step 4: Commit**

```bash
git add AeroPulse/Views/MetricTrendChartView.swift AeroPulse/Views/MiniSparklineView.swift AeroPulse/Localization/AppStrings.swift
git commit -m "feat(ui): create MetricTrendChartView and MiniSparklineView components"
```

---

### Task 4: Integrate Temperature Trend Chart into `ThermalDetailView.swift`

**Files:**
- Modify: `AeroPulse/Views/ThermalDetailView.swift`

- [x] **Step 1: Embed `MetricTrendChartView` into `ThermalDetailView`**

Insert the dual-series CPU/GPU temperature trend card below the `ThermalSummaryView` cards and above the sensor list:
```swift
MetricTrendChartView(
    title: AppStrings.tr(en: "CPU", zh: "CPU 温度"),
    points: fanViewModel.cpuTemperatureHistory,
    unit: "°C",
    tintColor: .orange,
    secondaryPoints: fanViewModel.gpuTemperatureHistory,
    secondaryColor: .purple,
    secondaryTitle: AppStrings.tr(en: "GPU", zh: "GPU")
)
.padding(.horizontal, 16)
.padding(.bottom, 6)
```

- [x] **Step 2: Verify `swift test` and view compilation**

Run: `swift test`
Expected: PASS.

- [x] **Step 3: Commit**

```bash
git add AeroPulse/Views/ThermalDetailView.swift
git commit -m "feat(dashboard): integrate dual temperature trend chart in ThermalDetailView"
```

---

### Task 5: Integrate Fan RPM Trend Chart into `FanControlCard.swift`

**Files:**
- Modify: `AeroPulse/Views/FanControlCard.swift`

- [x] **Step 1: Embed `MetricTrendChartView` in `FanControlCard`**

Insert the live Fan RPM trend chart directly above the fan speed rows list when fans are present:
```swift
if isDashboard, let firstFan = sortedFans.first, let history = fanViewModel.fanRPMHistory[firstFan.id], history.count > 1 {
    MetricTrendChartView(
        title: AppStrings.fanRPMTrend,
        points: history,
        unit: "RPM",
        tintColor: .teal
    )
}
```

- [x] **Step 2: Verify `swift test`**

Run: `swift test`
Expected: PASS.

- [x] **Step 3: Commit**

```bash
git add AeroPulse/Views/FanControlCard.swift
git commit -m "feat(dashboard): integrate fan RPM trend chart in FanControlCard"
```

---

### Task 6: Integrate `MiniSparklineView` into `MenuBarFanSection.swift`

**Files:**
- Modify: `AeroPulse/Views/MenuBarFanSection.swift`

- [x] **Step 1: Add sparklines to CPU & GPU temperature rows**

In `temperatureRow(title:value:dotColor:)`:
```swift
private func temperatureRow(
    title: String,
    value: String,
    dotColor: Color,
    history: [MetricHistoryPoint]
) -> some View {
    HStack(spacing: 4) {
        Circle()
            .fill(dotColor)
            .frame(width: 5, height: 5)
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        Text(value)
            .font(.system(size: 12.5, weight: .semibold))
            .monospacedDigit()
            .frame(minWidth: 40, alignment: .trailing)
        if history.count > 1 {
            MiniSparklineView(points: history, tintColor: dotColor)
        }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2.5)
    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    ...
```

- [x] **Step 2: Add sparkline to Fan RPM row in MenuBar**

In the top fan RPM row:
```swift
if let primaryFan = fanViewModel.fans.first,
   let history = fanViewModel.fanRPMHistory[primaryFan.id],
   history.count > 1 {
    MiniSparklineView(points: history, tintColor: .teal, width: 48, height: 16)
}
```

- [x] **Step 3: Run unit tests and verify**

Run: `swift test`
Expected: PASS.

- [x] **Step 4: Commit**

```bash
git add AeroPulse/Views/MenuBarFanSection.swift
git commit -m "feat(menubar): add mini sparklines to temperature and fan RPM rows"
```

---

### Task 7: Full System Verification & Release Build

**Files:**
- None (verification phase)

- [x] **Step 1: Run complete test suite**

Run: `swift test`
Expected: PASS (all tests pass).

- [x] **Step 2: Verify Release build with `xcodebuild`**

Run: `xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Release build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

- [x] **Step 3: Commit any final cleanup and push to branch**

```bash
git push origin main
```
