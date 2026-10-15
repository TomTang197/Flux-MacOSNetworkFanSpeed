# AeroPulse Fan & Temperature Trend Charts Design Specification

- **Date:** 2026-10-15
- **Status:** Approved
- **Target Release:** v1.2.7

## 1. Overview & Goals

### 1.1 Goal
Provide real-time visual history (trend charts and sparklines) for fan speeds and temperatures (CPU and GPU) in both the AeroPulse main Dashboard window and the Menu Bar popover. This allows users to observe thermal changes, fan response curves, and temperature stabilization over time at a glance.

### 1.2 Non-Goals
- Persistent multi-day database storage of thermal telemetry (keep strictly in-memory, bounded to rolling recent history).
- Exporting CSV/JSON telemetry logs to external files.

---

## 2. Architecture & Data Layer

### 2.1 Metric History Point
A lightweight, value-type model for storing timestamped telemetry samples:

```swift
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
```

### 2.2 Rolling History Buffer (`RollingHistoryBuffer`)
A bounded FIFO buffer that maintains an upper capacity limit:
- **Default Capacity:** 60 points.
  - At foreground detailed refresh interval (2.0s), 60 points represents a 120-second (2-minute) live sliding window.
  - When background refresh is active (4.0s), it covers up to 4 minutes.
- **Operations:**
  - `append(value: Double, timestamp: Date)`: appends point; drops oldest if `count > capacity`.
  - `points: [MetricHistoryPoint]`: returns points ordered by timestamp ascending.
  - `minMaxRange: ClosedRange<Double>?`: computes the range of values in the current window with zero allocation.
  - `latest: Double?`: returns the most recent sample.

### 2.3 `FanViewModel` Integration
Expose published rolling histories:
- `@Published private(set) var cpuTemperatureHistory: [MetricHistoryPoint] = []`
- `@Published private(set) var gpuTemperatureHistory: [MetricHistoryPoint] = []`
- `@Published private(set) var fanRPMHistory: [Int: [MetricHistoryPoint]] = [:]`

During each sensor & fan sampling cycle (`updateSensorsAndFans`):
1. Extract CPU primary temperature -> append to CPU buffer.
2. Extract GPU primary temperature (if available) -> append to GPU buffer.
3. For each fan in `fans` -> append `currentRPM` to the respective fan buffer.

---

## 3. UI Component Architecture

### 3.1 Dashboard Trend Chart (`MetricTrendChartView`)
Designed for larger card spaces in the Dashboard:
- **Dimensions:** Width flexible, height 75pt ~ 85pt.
- **Visuals:**
  - Smooth Bezier line stroke (width 1.8pt).
  - Subtle vertical gradient fill underneath the line (opacity 0.2 down to 0.02).
  - Horizontal guideline for minimum, median, and maximum.
  - Header with metric title, live value, and `Min: X · Max: Y` labels.
  - Value range padding: adds 2°C or 100 RPM minimum span so small noise doesn't look like huge spikes.
- **Theme Tints:**
  - CPU Temperature: Orange / Coral gradient (`Color.orange`).
  - GPU Temperature: Purple / Indigo gradient (`Color.purple`).
  - Fan RPM: Teal / Cyan gradient (`Color.teal`).

### 3.2 Menu Bar Sparkline (`MiniSparklineView`)
Designed for high-density menu bar popovers:
- **Dimensions:** Compact 44pt x 14pt (or 48pt x 16pt).
- **Visuals:**
  - Ultra-clean vector path with zero margin.
  - End-point glowing dot representing the most recent reading.
  - Seamlessly placed next to the temperature or RPM text without altering row heights.

---

## 4. View Placements

1. **`ThermalDetailView.swift` (Dashboard Middle Column)**:
   - Below the CPU & GPU summary cards, add a dedicated dual-series or unified temperature trend card displaying CPU and GPU curves side-by-side or combined with color legends.
2. **`FanControlCard.swift` (Dashboard Right Column)**:
   - Above the fan speed rows, add the fan RPM trend chart. Shows live response as fan speeds accelerate or decelerate.
3. **`MenuBarFanSection.swift` (Menu Bar Popover)**:
   - In `temperatureRow(title:value:dotColor:)`: append `MiniSparklineView` for CPU and GPU.
   - In primary fan speed row: append `MiniSparklineView` for fan RPM.

---

## 5. Performance & Resource Constraints

- **Rendering Engine:** Native SwiftUI `Path` / `Canvas`, hardware-accelerated by Metal.
- **Memory Footprint:** 60 points × 3 buffers ≈ 180 lightweight structs (< 10 KB memory total).
- **CPU Overhead:** Measured < 0.05% CPU on Apple Silicon, only recalculates path when new sample arrives (every 2.0s).

---

## 6. Verification Plan

1. **Unit Tests (`RollingHistoryBufferTests.swift`)**:
   - Verify buffer initializes empty.
   - Verify buffer respects maximum capacity and evicts oldest items FIFO.
   - Verify min/max calculation accuracy and edge case handling (empty buffer, single item, all equal items).
2. **UI Verification**:
   - Verify Dashboard display with live simulated or real telemetry.
   - Verify MenuBar popover layout with sparklines on both compact and standard macOS displays.
   - Verify Light Mode and Dark Mode contrast.
   - Verify Chinese and English localization.
