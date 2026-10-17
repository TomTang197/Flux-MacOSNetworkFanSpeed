# Scheduled Fan Mode Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement scheduled fan mode switching in AeroPulse, enabling automatic transitions between modes (e.g. night quiet Auto mode vs day Rules mode) with cross-midnight support and temporary manual override handling.

**Architecture:** A standalone, deterministic `FanSchedulePolicy` handles time matching, cross-midnight calculations, boundary triggers, and override state transitions. `FanViewModel` coordinates the policy with hardware fan controls, while `FanControlCard` provides a native Apple HIG expandable UI panel with `DatePicker` components.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, macOS 26 SDK.

---

## File Structure

```
AeroPulse/
├── Models/
│   └── FanScheduleConfig.swift             # Model: Codable configuration for schedule
├── Services/
│   └── FanSafety/
│       └── FanSchedulePolicy.swift         # Deterministic schedule evaluation & override state machine
├── ViewModels/
│   └── FanViewModel.swift                  # Integration: policy lifecycle, timer eval, user override hooks
├── Helpers/
│   └── AppConstants.swift                  # Localization keys and strings
└── Views/
    └── FanControlCard.swift                # UI: Collapsible Apple HIG schedule section with DatePickers

Tests/
└── AeroPulseSafetyTests/
    └── FanSchedulePolicyTests.swift        # Unit tests covering all time window cases, boundaries, and overrides
```

---

## Tasks

### Task 1: `FanScheduleConfig` Data Model

**Files:**
- Create: `AeroPulse/Models/FanScheduleConfig.swift`
- Test: `Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift`

- [ ] **Step 1: Write failing unit test for `FanScheduleConfig` serialization and normalization**

```swift
// In Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift
import XCTest
@testable import AeroPulse

final class FanSchedulePolicyTests: XCTestCase {
    func testConfigInitializationAndNormalization() {
        let config = FanScheduleConfig(
            isEnabled: true,
            startHour: 25, // should clamp to 23
            startMinute: -5, // should clamp to 0
            endHour: 8,
            endMinute: 30,
            scheduledMode: .auto,
            defaultMode: .custom
        )
        XCTAssertEqual(config.startHour, 23)
        XCTAssertEqual(config.startMinute, 0)
        XCTAssertEqual(config.endHour, 8)
        XCTAssertEqual(config.endMinute, 30)
        XCTAssertEqual(config.scheduledMode, .auto)
        XCTAssertEqual(config.defaultMode, .custom)
    }

    func testConfigCodableRoundTrip() throws {
        let original = FanScheduleConfig(
            isEnabled: true,
            startHour: 22,
            startMinute: 30,
            endHour: 7,
            endMinute: 15,
            scheduledMode: .auto,
            defaultMode: .custom
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FanScheduleConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FanSchedulePolicyTests`
Expected: FAIL with "cannot find 'FanScheduleConfig' in scope"

- [ ] **Step 3: Implement `FanScheduleConfig.swift`**

```swift
// In AeroPulse/Models/FanScheduleConfig.swift
import Foundation

public struct FanScheduleConfig: Codable, Equatable {
    public var isEnabled: Bool
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var scheduledMode: FanMode
    public var defaultMode: FanMode

    public init(
        isEnabled: Bool = false,
        startHour: Int = 23,
        startMinute: Int = 0,
        endHour: Int = 8,
        endMinute: Int = 0,
        scheduledMode: FanMode = .auto,
        defaultMode: FanMode = .custom
    ) {
        self.isEnabled = isEnabled
        self.startHour = max(0, min(23, startHour))
        self.startMinute = max(0, min(59, startMinute))
        self.endHour = max(0, min(23, endHour))
        self.endMinute = max(0, min(59, endMinute))
        self.scheduledMode = scheduledMode
        self.defaultMode = defaultMode
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FanSchedulePolicyTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Models/FanScheduleConfig.swift Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift
git commit -m "feat(schedule): add FanScheduleConfig data model and unit tests"
```

---

### Task 2: `FanSchedulePolicy` Core Engine

**Files:**
- Create: `AeroPulse/Services/FanSafety/FanSchedulePolicy.swift`
- Modify: `Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift`

- [ ] **Step 1: Write failing unit tests for time window matching, cross-midnight, and boundary transitions**

```swift
// Add to Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift
func testSameDayWindowDetection() {
    let policy = FanSchedulePolicy()
    let config = FanScheduleConfig(
        isEnabled: true,
        startHour: 9, startMinute: 0,
        endHour: 17, endMinute: 30
    )

    XCTAssertFalse(policy.isTimeInSchedule(hour: 8, minute: 59, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 9, minute: 0, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 12, minute: 0, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 17, minute: 29, config: config))
    XCTAssertFalse(policy.isTimeInSchedule(hour: 17, minute: 30, config: config))
    XCTAssertFalse(policy.isTimeInSchedule(hour: 22, minute: 0, config: config))
}

func testCrossMidnightWindowDetection() {
    let policy = FanSchedulePolicy()
    let config = FanScheduleConfig(
        isEnabled: true,
        startHour: 23, startMinute: 0,
        endHour: 8, endMinute: 0
    )

    XCTAssertFalse(policy.isTimeInSchedule(hour: 22, minute: 59, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 23, minute: 0, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 23, minute: 45, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 0, minute: 0, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 4, minute: 15, config: config))
    XCTAssertTrue(policy.isTimeInSchedule(hour: 7, minute: 59, config: config))
    XCTAssertFalse(policy.isTimeInSchedule(hour: 8, minute: 0, config: config))
    XCTAssertFalse(policy.isTimeInSchedule(hour: 14, minute: 0, config: config))
}

func testManualOverrideResetsOnBoundaryCross() {
    var policy = FanSchedulePolicy()
    let config = FanScheduleConfig(
        isEnabled: true,
        startHour: 23, startMinute: 0,
        endHour: 8, endMinute: 0,
        scheduledMode: .auto,
        defaultMode: .custom
    )

    // Entering schedule at 23:00
    let action1 = policy.evaluate(hour: 23, minute: 0, config: config, currentMode: .custom)
    XCTAssertEqual(action1, .switchMode(.auto))
    XCTAssertFalse(policy.isUserOverridden)

    // User manually overrides to .fullBlast inside window
    policy.handleUserManualOverride()
    XCTAssertTrue(policy.isUserOverridden)

    // Subsequent tick inside window keeps manual override
    let action2 = policy.evaluate(hour: 23, minute: 30, config: config, currentMode: .fullBlast)
    XCTAssertEqual(action2, .none)
    XCTAssertTrue(policy.isUserOverridden)

    // Leaving schedule at 08:00 crosses boundary -> override clears, switches to defaultMode
    let action3 = policy.evaluate(hour: 8, minute: 0, config: config, currentMode: .fullBlast)
    XCTAssertEqual(action3, .switchMode(.custom))
    XCTAssertFalse(policy.isUserOverridden)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FanSchedulePolicyTests`
Expected: FAIL with "cannot find 'FanSchedulePolicy' in scope"

- [ ] **Step 3: Implement `FanSchedulePolicy.swift`**

```swift
// In AeroPulse/Services/FanSafety/FanSchedulePolicy.swift
import Foundation

public enum FanScheduleAction: Equatable {
    case none
    case switchMode(FanMode)
}

public struct FanSchedulePolicy: Equatable {
    public private(set) var lastEvaluatedInSchedule: Bool? = nil
    public private(set) var isUserOverridden: Bool = false

    public init() {}

    public func isTimeInSchedule(hour: Int, minute: Int, config: FanScheduleConfig) -> Bool {
        guard config.isEnabled else { return false }
        let currentOffset = hour * 60 + minute
        let startOffset = config.startHour * 60 + config.startMinute
        let endOffset = config.endHour * 60 + config.endMinute

        guard startOffset != endOffset else { return false }

        if startOffset < endOffset {
            // Same-day window
            return currentOffset >= startOffset && currentOffset < endOffset
        } else {
            // Cross-midnight window
            return currentOffset >= startOffset || currentOffset < endOffset
        }
    }

    public mutating func evaluate(
        hour: Int,
        minute: Int,
        config: FanScheduleConfig,
        currentMode: FanMode
    ) -> FanScheduleAction {
        guard config.isEnabled else {
            lastEvaluatedInSchedule = nil
            isUserOverridden = false
            return .none
        }

        let inSchedule = isTimeInSchedule(hour: hour, minute: minute, config: config)
        let targetMode = inSchedule ? config.scheduledMode : config.defaultMode

        if let previousInSchedule = lastEvaluatedInSchedule {
            if inSchedule != previousInSchedule {
                // Boundary crossed: clear override and apply new target mode
                lastEvaluatedInSchedule = inSchedule
                isUserOverridden = false
                return targetMode != currentMode ? .switchMode(targetMode) : .none
            }
        } else {
            // First evaluation on startup or config enable
            lastEvaluatedInSchedule = inSchedule
            isUserOverridden = false
            return targetMode != currentMode ? .switchMode(targetMode) : .none
        }

        // Inside same window: respect manual override if present
        if isUserOverridden {
            return .none
        }

        // If not overridden but mode drifted away from expected target
        if currentMode != targetMode {
            return .switchMode(targetMode)
        }

        return .none
    }

    public mutating func handleUserManualOverride() {
        isUserOverridden = true
    }

    public mutating func resetOverride() {
        isUserOverridden = false
    }

    public mutating func reconcileWake(
        hour: Int,
        minute: Int,
        config: FanScheduleConfig,
        currentMode: FanMode
    ) -> FanScheduleAction {
        guard config.isEnabled else { return .none }
        let inSchedule = isTimeInSchedule(hour: hour, minute: minute, config: config)
        if inSchedule != lastEvaluatedInSchedule {
            lastEvaluatedInSchedule = inSchedule
            isUserOverridden = false
            let targetMode = inSchedule ? config.scheduledMode : config.defaultMode
            return targetMode != currentMode ? .switchMode(targetMode) : .none
        }
        return .none
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FanSchedulePolicyTests`
Expected: PASS (all tests pass)

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Services/FanSafety/FanSchedulePolicy.swift Tests/AeroPulseSafetyTests/FanSchedulePolicyTests.swift
git commit -m "feat(schedule): implement FanSchedulePolicy with cross-midnight and override state machine"
```

---

### Task 3: Localization Strings in `AppConstants.swift`

**Files:**
- Modify: `AeroPulse/Helpers/AppConstants.swift`

- [ ] **Step 1: Add localization getters in `AppStrings`**

```swift
// In AeroPulse/Helpers/AppConstants.swift
    static var scheduleSectionTitle: String { tr(en: "Mode Schedule", zh: "模式定时计划") }
    static var scheduleDesc: String { tr(en: "Automatically switch fan modes on a daily schedule.", zh: "在每日设定时段自动切换风扇模式。") }
    static var scheduleStartTime: String { tr(en: "Start", zh: "开始时间") }
    static var scheduleEndTime: String { tr(en: "End", zh: "结束时间") }
    static var scheduledModeLabel: String { tr(en: "In-Schedule Mode", zh: "时段内模式") }
    static var defaultModeLabel: String { tr(en: "Out-of-Schedule Mode", zh: "时段外模式") }
    static var scheduleActiveBadge: String { tr(en: "Scheduled Active", zh: "计划生效中") }
    static var scheduleOverriddenBadge: String { tr(en: "Temporary Override", zh: "已临时手动接管") }
    static var crossMidnightTag: String { tr(en: "Overnight", zh: "跨午夜") }
```

- [ ] **Step 2: Run tests to verify compilation**

Run: `swift test`
Expected: PASS (154+ tests pass)

- [ ] **Step 3: Commit**

```bash
git add AeroPulse/Helpers/AppConstants.swift
git commit -m "feat(i18n): add bilingual strings for fan mode scheduling"
```

---

### Task 4: Integrate `FanSchedulePolicy` into `FanViewModel`

**Files:**
- Modify: `AeroPulse/ViewModels/FanViewModel.swift`

- [ ] **Step 1: Add schedule properties, persistence, and timer evaluation hooks**
  - Add published properties:
    - `@Published var fanScheduleConfig: FanScheduleConfig`
    - `@Published var isScheduleActive: Bool = false`
    - `@Published var isScheduleOverridden: Bool = false`
  - Load and save `FanScheduleConfig` to `UserDefaults` under `AeroPulse.FanScheduleConfig`.
  - In `init()`:
    - Load config from `UserDefaults`.
    - Subscribe to `NSWorkspace.didWakeNotification` to invoke `schedulePolicy.reconcileWake(...)`.
  - In `setFanMode(_:isUserInitiated:)`:
    - When `isUserInitiated == true`, invoke `schedulePolicy.handleUserManualOverride()` and update `isScheduleOverridden`.
  - In the periodic timer callback (`sample()` or `updateTimer`):
    - Extract `Calendar.current.dateComponents([.hour, .minute], from: Date())`.
    - Call `schedulePolicy.evaluate(...)`.
    - If action is `.switchMode(targetMode)`, call `setFanMode(targetMode, isUserInitiated: false)`.
    - Update `isScheduleActive = schedulePolicy.isTimeInSchedule(...)` and `isScheduleOverridden = schedulePolicy.isUserOverridden`.

- [ ] **Step 2: Run test suite to verify no regressions**

Run: `swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add AeroPulse/ViewModels/FanViewModel.swift
git commit -m "feat(viewmodel): integrate FanSchedulePolicy into FanViewModel lifecycle"
```

---

### Task 5: UI Integration in `FanControlCard.swift`

**Files:**
- Modify: `AeroPulse/Views/FanControlCard.swift`

- [ ] **Step 1: Add `scheduleSection` to `FanControlCard.swift`**
  - Add section below `gameModeSection`.
  - Header with icon `clock.badge.checkmark`, title `AppStrings.scheduleSectionTitle`, status badge capsule, and Toggle `isOn: $fanViewModel.fanScheduleConfig.isEnabled`.
  - Expanded content (when `isEnabled`):
    - HStack with Start Time `DatePicker` and End Time `DatePicker` (compact `.hourAndMinute`).
    - Helper duration tag (calculates hours/minutes and indicates "Overnight" if cross-midnight).
    - Grid/HStack for `scheduledMode` Picker and `defaultMode` Picker.
    - Style container with `.background(Color.primary.opacity(0.045))` and continuous corner radius.
- [ ] **Step 2: Run `swift test` to verify build & test passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 3: Build Release app with `xcodebuild`**

Run: `xcodebuild -scheme AeroPulse -configuration Release clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add AeroPulse/Views/FanControlCard.swift
git commit -m "feat(ui): add scheduled fan mode settings section to FanControlCard"
```

---

### Task 6: Verification & Local Deployment

**Files:**
- Application binary: `/Applications/AeroPulse.app`

- [ ] **Step 1: Sign, install to `/Applications/AeroPulse.app`, and launch**

```bash
codesign --force --deep --sign - build/Build/Products/Release/AeroPulse.app
killall AeroPulse 2>/dev/null || true
rm -rf /Applications/AeroPulse.app && cp -R build/Build/Products/Release/AeroPulse.app /Applications/
open /Applications/AeroPulse.app
```

- [ ] **Step 2: Verify in running app**
  - Verify "Mode Schedule" section appears in the Fan Control card.
  - Verify toggling on enables time pickers.
  - Verify cross-midnight calculation works smoothly.
  - Verify switching modes updates seamlessly.

- [ ] **Step 3: Commit and push changes to `main`**

```bash
git push origin main
```
