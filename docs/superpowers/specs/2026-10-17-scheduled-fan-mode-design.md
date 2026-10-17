# Scheduled Fan Mode Switching Design Specification

## Overview
This specification details the architecture, state coordination, boundary trigger algorithm, and UI presentation for the **Scheduled Fan Mode Switching** (模式定时切换) feature in AeroPulse. It allows users to automatically switch fan control modes based on a routine time window (for example, switching to quiet Auto mode at night from 23:00 to 08:00, and returning to custom Temperature Rules during the day).

---

## 1. Problem & Goals

### 1.1 User Problem
- Many users desire ultra-quiet operation at night (preferring macOS `Auto` or a silent profile) while requiring aggressive cooling (`Rules` or higher RPM) during active daytime working hours.
- Manually switching fan modes twice a day is tedious and prone to being forgotten.
- If users temporarily override the mode during the scheduled window (e.g. for an emergency compile or benchmark), the app must respect user intent without permanently breaking the routine schedule.

### 1.2 Design Goals
1. **Simple & Focused Configuration**: Focus on the primary user scenario—a single routine daily schedule with configurable start time, end time, scheduled mode, and fallback default mode.
2. **Robust Cross-Midnight Arithmetic**: Elegantly support schedules that span across midnight (e.g., 23:00 to 08:00) as well as intraday schedules (e.g., 13:00 to 17:00).
3. **Graceful Manual Override**: Allow temporary manual changes during an active schedule. The manual override stays in effect until the next boundary transition, whereupon normal scheduled operation automatically resumes.
4. **Seamless Priority Hierarchy**: Harmonize with existing safety policies:
   `Emergency Thermal Protection > Game Mode Auto-Linkage > Scheduled Mode > Default User Mode`.
5. **Native Apple HIG Ergonomics**: Embed directly within the `FanControlCard` view as an expandable Apple-style card with native time pickers, consistent with the existing Rules and Game Mode sections.

---

## 2. Architecture & Data Model

### 2.1 Configuration Model: `FanScheduleConfig`
```swift
public struct FanScheduleConfig: Codable, Equatable {
    public var isEnabled: Bool
    public var startHour: Int       // 0...23, default: 23
    public var startMinute: Int     // 0...59, default: 0
    public var endHour: Int         // 0...23, default: 8
    public var endMinute: Int       // 0...59, default: 0
    public var scheduledMode: FanMode // Mode inside window, default: .auto
    public var defaultMode: FanMode   // Mode outside window, default: .custom

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

### 2.2 Persistence
Configuration is serialized via JSON and persisted in `UserDefaults` under key `AeroPulse.FanScheduleConfig`.

---

## 3. Scheduling & State Coordination

### 3.1 Time Window Evaluation (`isInSchedule`)
Given clock minute offsets `start = startHour * 60 + startMinute`, `end = endHour * 60 + endMinute`, and `current = currentHour * 60 + currentMinute`:
- **Same-day schedule (`start < end`)**:
  `isInSchedule = (current >= start && current < end)`
- **Cross-midnight schedule (`start > end`)**:
  `isInSchedule = (current >= start || current < end)`
- **Zero-duration schedule (`start == end`)**:
  `isInSchedule = false`

### 3.2 State Machine & Boundary Transitions
The policy maintains three internal states:
1. `lastEvaluatedInSchedule: Bool?`
2. `isUserOverridden: Bool`

```
                      [Tick / Time Evaluation]
                                 │
                   Has Boundary Crossed? (A != B)
                                 │
                     ┌───────────┴───────────┐
                    YES                      NO
                     │                       │
           Reset isUserOverridden          Is User Overridden?
                     │                       │
          Apply Scheduled/Default       ┌────┴────┐
                   Mode                YES        NO
                                        │          │
                                   Keep Current  Keep Target
                                      Mode        Mode
```

#### Boundary Crossing
When `currentInSchedule != lastEvaluatedInSchedule`:
- A boundary was crossed (either entered or exited the schedule window).
- `isUserOverridden` is automatically cleared (`false`).
- Target mode is applied:
  - If `currentInSchedule == true`: apply `config.scheduledMode`.
  - If `currentInSchedule == false`: apply `config.defaultMode`.

#### Manual Override Handling
If the user clicks a fan mode button on the dashboard:
- If schedule is enabled and active: set `isUserOverridden = true`.
- The user's manually chosen mode remains active.
- When the next schedule boundary is crossed, `isUserOverridden` clears and normal routine resumes.

### 3.3 Sleep / Wake Reconciliation
Upon receiving `NSWorkspace.didWakeNotification`:
- Recalculate whether the system is currently within the schedule window.
- If the boundary status changed during sleep, clear manual override and apply the appropriate mode immediately.

---

## 4. Priority Coordination with Game Mode & Safety

Mode resolution priority order:
1. **Helper Tool Availability**: If helper tool is missing, non-Auto modes prompt installation or revert to Auto.
2. **Game Mode Linkage**: If a game is actively running and Game Mode Auto-Linkage is enabled, Game Mode overrides Scheduled Mode.
3. **Manual User Override**: If user explicitly clicks a mode, their choice takes precedence until next schedule boundary.
4. **Scheduled Fan Mode**: Active schedule window applies `scheduledMode`; inactive window applies `defaultMode`.
5. **System Default**: Routine fallback mode.

---

## 5. UI & Interaction Design

### 5.1 Location
Embedded at the bottom of [`FanControlCard.swift`](file:///Users/tom/Documents/Flux-MacOSNetworkFanSpeed/AeroPulse/Views/FanControlCard.swift) under a collapsible section titled **"Schedule" / "定时计划"**, adjacent to the Game Mode Linkage section.

### 5.2 Visual Elements
1. **Header Row**:
   - SF Symbol: `clock.badge.checkmark` (tinted `.blue`).
   - Title: `AppStrings.scheduleSectionTitle` ("Mode Schedule" / "模式定时计划").
   - Status Badge:
     - When active & in schedule: `🌙 23:00~08:00 · Auto`
     - When active & overridden: `🌙 23:00~08:00 · Manual Override`
   - Master Toggle switch.
2. **Expanded Content** (when enabled):
   - **Time Range Row**:
     - Start time picker: `DatePicker` (displayed as compact hour/minute).
     - End time picker: `DatePicker` (displayed as compact hour/minute).
     - Informational duration label (e.g. "9 hrs (Overnight)" / "9 小时 (跨午夜)").
   - **Mode Selection Row**:
     - "In Schedule" Mode Picker: Auto (recommended), Max, Manual, Rules.
     - "Out of Schedule" Mode Picker: Rules (recommended), Auto, Manual, Max.
3. **Visual Style**:
   - Card container with `Color.primary.opacity(0.045)` background, continuous corner radius (10pt), hairline border (`Color.primary.opacity(0.06)`).

---

## 6. Localization Strings

| Key | English (en) | Simplified Chinese (zh-Hans) |
| :--- | :--- | :--- |
| `scheduleTitle` | Mode Schedule | 模式定时计划 |
| `scheduleDesc` | Automatically switch modes at set times | 在指定时段自动切换风扇模式 |
| `scheduleStartTime` | Start Time | 开始时间 |
| `scheduleEndTime` | End Time | 结束时间 |
| `scheduledModeLabel` | In-Schedule Mode | 时段内模式 |
| `defaultModeLabel` | Out-of-Schedule Mode | 时段外模式 |
| `scheduleActiveBadge` | Scheduled | 计划生效中 |
| `scheduleOverriddenBadge` | Temporary Override | 临时手动接管 |
| `crossMidnightTag` | Overnight | 跨午夜 |

---

## 7. Testing Strategy

Unit tests in `AeroPulseSafetyTests`:
1. `testScheduleSameDayWindowDetection`: Verify correct `isInSchedule` determination for daytime windows (e.g., 09:00 - 18:00).
2. `testScheduleCrossMidnightWindowDetection`: Verify correct `isInSchedule` determination across midnight (e.g., 23:00 - 08:00 at 23:30, 04:00, 08:00, 12:00).
3. `testScheduleBoundaryTransitionTrigger`: Verify that mode changes trigger precisely when crossing the boundary.
4. `testScheduleManualOverridePreservedUntilNextBoundary`: Verify manual user intervention is preserved within window and cleared at the next boundary.
5. `testScheduleConfigSerialization`: Verify JSON encoding/decoding and UserDefaults persistence.
