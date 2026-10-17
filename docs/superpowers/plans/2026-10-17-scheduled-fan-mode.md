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

- [x] **Step 1: Write failing unit test for `FanScheduleConfig` serialization and normalization**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement `FanScheduleConfig.swift`**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit**

---

### Task 2: `FanSchedulePolicy` Core Engine

- [x] **Step 1: Write failing unit tests for time window matching, cross-midnight, and boundary transitions**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement `FanSchedulePolicy.swift`**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit**

---

### Task 3: Localization Strings in `AppConstants.swift`

- [x] **Step 1: Add localization getters in `AppStrings`**
- [x] **Step 2: Run tests to verify compilation**
- [x] **Step 3: Commit**

---

### Task 4: Integrate `FanSchedulePolicy` into `FanViewModel`

- [x] **Step 1: Add schedule properties, persistence, and timer evaluation hooks**
- [x] **Step 2: Run test suite to verify no regressions**
- [x] **Step 3: Commit**

---

### Task 5: UI Integration in `FanControlCard.swift`

- [x] **Step 1: Add `scheduleSection` to `FanControlCard.swift`**
- [x] **Step 2: Run `swift test` to verify build & test passes**
- [x] **Step 3: Build Release app with `xcodebuild`**
- [x] **Step 4: Commit**

---

### Task 6: Verification & Local Deployment

- [x] **Step 1: Sign, install to `/Applications/AeroPulse.app`, and launch**
- [x] **Step 2: Verify in running app**
- [x] **Step 3: Commit and push changes to `main`**
