# AeroPulse iFan-Style Fan Control Design

**Date:** 2026-08-27

**Status:** Approved in conversation; pending written-spec review

**Scope:** Complete fan telemetry, system/maximum/manual/custom fan modes, and temperature-threshold automation

## 1. Goal

Add a production-quality fan-control subsystem to AeroPulse that independently reproduces the observed behavior of iFan without copying its proprietary code or bundling its binaries.

The finished feature must:

- Display each fan's actual, minimum, maximum, and target RPM plus its real control mode.
- Support independent `System`, `Maximum`, `Manual`, and `Custom` modes per fan.
- Evaluate persisted temperature-threshold rules and convert matching rules into target RPM values.
- Perform all privileged SMC writes through a narrowly scoped, authenticated XPC LaunchDaemon.
- Restore system fan control after failures, stale telemetry, application exit, sleep, or loss of the controlling session.
- Support both Apple Silicon and Intel SMC representations used by the existing application.

## 2. Non-goals

- Pixel-for-pixel copying of iFan's interface.
- Reusing iFan's helper, SMC command-line executable, artwork, or proprietary implementation.
- Arbitrary SMC-key editing.
- Arbitrary command, shell, path, or process execution through the privileged helper.
- A separate always-on LaunchAgent. The existing menu-bar app owns rule evaluation.
- Automatically restoring `Manual` or `Maximum` after an app restart.

## 3. Current Project State

The repository already contains part of the required foundation:

- `SMCService` opens `AppleSMC`, reads key metadata and values, and decodes several SMC types.
- `FanMonitor` periodically reads fan and temperature telemetry.
- `FanControlClient` implements a write-control abstraction, but both methods are currently stubs.
- `FanPrivilegedHelper` contains an initial direct SMC writer and an XPC listener.
- `PrivilegedHelperInstaller` currently copies a helper and launchd plist with an administrator AppleScript.
- `FanViewModel` reports helper installation state but exposes no fan-control state.
- `FanMonitor` currently reports every fan as `.auto` rather than decoding its real mode.
- There is no rule engine or automated-test target for fan-control behavior.

The implementation will preserve the working read-only monitoring behavior while replacing the incomplete write and installation paths.

## 4. Chosen Architecture

Rule evaluation remains in the unprivileged app. The privileged helper is a small write executor.

```text
FanMonitor
  |-- fan telemetry: Actual / Min / Max / Target / Mode
  `-- temperature-sensor snapshot
             |
             v
FanControlCoordinator
  |-- System
  |-- Maximum
  |-- Manual RPM
  `-- Custom -> FanRuleEngine
             |
             v
FanControlClient -> authenticated XPC -> root helper -> AppleSMC
```

This boundary is preferred over placing the rule engine in the helper because it keeps persistence, policy, and UI decisions outside the root process. It is preferred over invoking an SMC CLI because no subprocess or shell is needed.

## 5. Component Boundaries

### 5.1 `SMCService`

Remains the unprivileged, read-focused AppleSMC connection used by the main app.

Responsibilities:

- Read four-character SMC keys.
- Decode `flt `, `fpe2`, `sp78`, `ui8 `, `ui16`, and `ui32` values.
- Report key metadata and read failures.
- Never serve as a fallback for fan writes.

Required corrections:

- Decode `FNum` through the value decoder instead of assuming its first byte contains the fan count.
- Add explicit fan-mode reading with cached `F{id}Md` / `F{id}md` case detection.
- Keep write support inaccessible to fan-control callers in the main app.

### 5.2 `FanMonitor`

Produces immutable snapshots for fans and sensors.

Each `FanInfo` includes:

- fan ID and display name;
- actual, minimum, maximum, and target RPM;
- decoded system/manual mode;
- sample timestamp and read-health state.

The monitor continues to refresh every two seconds while a detailed UI is visible and every four seconds in the background. A snapshot older than six seconds is stale for control decisions.

### 5.3 `FanRuleEngine`

A pure, side-effect-free component that accepts:

- the current rule collection;
- the most recent sensor snapshot;
- fan minimum and maximum RPM values;
- the previous per-rule activation state.

It returns a desired target per fan plus diagnostic information describing which rules matched.

The rule engine does not call XPC, persist data, or mutate UI state. This makes its complete behavior unit-testable.

### 5.4 `FanControlCoordinator`

Owns the effective per-fan control mode and arbitrates user actions versus custom rules.

Responsibilities:

- Resolve `System`, `Maximum`, `Manual`, and `Custom` into helper commands.
- Apply manual and maximum requests immediately.
- Evaluate custom mode whenever a fresh sensor snapshot arrives.
- Suppress duplicate writes unless the mode changes or the target differs by at least 50 RPM.
- Track pending, applied, failed, and restoring state per fan.
- Request readback after writes and expose the verified result to the UI.
- Restore all controlled fans on shutdown, sleep, session loss, or stale telemetry.

The coordinator depends on protocols for the monitor clock, preference store, and control client so tests can use deterministic fakes.

### 5.5 `FanControlClient`

Owns the privileged `NSXPCConnection` and provides asynchronous, typed operations to the coordinator.

It must:

- set a code-signing requirement for the helper before resuming the connection;
- establish one control session;
- send heartbeats every five seconds while any fan is controlled;
- translate XPC errors into domain-specific errors;
- invalidate and recreate interrupted connections;
- never fall back to `SMCService.writeKey`.

### 5.6 `FanPrivilegedHelper`

Runs as a root LaunchDaemon and contains only:

- XPC peer authentication;
- session/watchdog handling;
- fixed SMC capability discovery;
- validated fan-mode and fan-target writes;
- readback verification and system-mode restoration;
- root-owned lease recovery.

The current monolithic `main.swift` will be separated into the listener, protocol, session manager, SMC codec/transport, and fan writer so pure behavior can be tested without launching a root daemon.

## 6. User-Facing Modes

Each detected fan independently selects one of four modes.

### 6.1 System

The helper clears AeroPulse's manual control for that fan. This is the default and safe fallback.

### 6.2 Maximum

The helper enters manual mode and writes the fan's freshly read maximum RPM to its target key.

### 6.3 Manual

The user selects an integer RPM between the freshly read minimum and maximum. The UI offers both a slider and numeric field. The helper independently clamps and validates the value.

### 6.4 Custom

The rule engine computes a target from enabled threshold rules. If no rule matches, the fan returns to system mode rather than remaining at a previous manual target.

`Manual` and `Maximum` are never reactivated automatically after relaunch or wake. `Custom` may resume only after the helper is enabled and two consecutive fresh sensor snapshots have been received.

## 7. Rule Model and Evaluation

```text
FanRule
  id: UUID
  enabled: Bool
  sensorID: String?       // nil means any available sensor
  fanID: Int?             // nil means all fans
  thresholdCelsius: Double
  speedPercent: Int       // 0...100
```

Evaluation semantics:

1. A disabled rule never participates.
2. A concrete sensor rule uses that sensor's latest temperature.
3. An `Any Sensor` rule uses the highest valid temperature in the snapshot.
4. A rule activates at `temperature >= threshold`.
5. Once active, it remains active until `temperature < threshold - 3 °C`.
6. When multiple rules request a speed for one fan, the highest requested speed wins.
7. An `All Fans` rule applies only to fans whose selected mode is `Custom`; it does not override a fan explicitly set to System, Manual, or Maximum.
8. Percentage maps linearly into the fan's real range:

   `target = minRPM + (maxRPM - minRPM) * percent / 100`

9. The final target is rounded to an integer and clamped to `minRPM...maxRPM`.
10. Missing sensors leave their rules persisted but nonmatching and visibly marked unavailable.
11. Stale or wholly invalid sensor data causes affected custom fans to return to System.

## 8. Persistence

`FanControlPreferences` is versioned Codable data stored in UserDefaults and contains:

- all rules;
- enabled state;
- the selected persistent custom-mode flag for each fan;
- the most recent manual RPM as an editing convenience, but not permission to reactivate it;
- schema version.

Loading performs strict validation:

- unknown schema versions fail safe to no active control;
- invalid fan IDs are ignored until that fan exists;
- speed percentages clamp to `0...100`;
- nonfinite temperatures are rejected;
- corrupt data is quarantined and replaced with safe defaults.

## 9. User Interface

### 9.1 Fan Control Area

Add a `FanControlView` above the existing sensor categories in `ThermalDetailView`.

Each fan card displays:

- actual RPM;
- target RPM;
- minimum and maximum RPM;
- real SMC mode;
- AeroPulse's requested mode and application state;
- a System / Maximum / Manual / Custom segmented control.

Manual mode reveals a bounded slider and numeric field. Custom mode shows the current temperature source, matched rule, requested percentage, and calculated RPM.

Controls are disabled when the helper is unavailable, pending approval, or rejected. Telemetry remains available in all of those states.

### 9.2 Rule Editor

Add a fan-rule card to `SettingsView` with:

- enable toggle;
- sensor picker including `Any Sensor`;
- fan picker including `All Fans`;
- threshold field in Celsius;
- speed percentage field;
- add and delete actions;
- inline validation and unavailable-sensor warning;
- current match indicator when custom mode is active.

### 9.3 Helper Status

Replace the existing file-existence check with the real `SMAppService.Status`.

The UI distinguishes:

- not registered;
- registration requested but awaiting administrator approval;
- enabled;
- not found or incorrectly bundled;
- legacy helper conflict;
- XPC authentication or launch failure.

When approval is required, the user can open System Settings from the helper card.

## 10. Modern Helper Packaging

The project targets macOS 26, so helper registration uses `SMAppService.daemon(plistName:)` rather than `SMJobBless` or administrator AppleScript installation.

Bundle layout:

```text
AeroPulse.app/
  Contents/
    Resources/
      FanPrivilegedHelper
    Library/
      LaunchDaemons/
        com.bandan.me.AeroPulse.FanService.plist
```

The LaunchDaemon plist uses:

- `Label`: `com.bandan.me.AeroPulse.FanService`;
- `BundleProgram`: `Contents/Resources/FanPrivilegedHelper`;
- a Mach service with the same fixed label;
- `KeepAlive` so launchd restarts a crashed helper;
- no caller-controlled arguments.

The app calls `register()` once at the user's request and reads `status` thereafter. LaunchDaemon activation remains subject to administrator approval in System Settings.

The old `SMPrivilegedExecutables` entry and the AppleScript copy/install implementation are removed from the active path. A detected legacy installation at `/Library/PrivilegedHelperTools/com.bandan.me.AeroPulse.FanService` or `/Library/LaunchDaemons/com.bandan.me.AeroPulse.FanService.plist` is reported as a conflict with fixed-path cleanup guidance; the new app never silently deletes root-owned legacy files.

Release tooling must verify the new bundle locations before signing and notarization.

## 11. XPC Protocol and Authentication

The Objective-C-compatible shared protocol exposes only fixed fan operations:

```text
capabilities(reply)
beginSession(reply)
heartbeat(sessionID, reply)
setFanControl(sessionID, fanID, mode, targetRPM, reply)
restoreFan(sessionID, fanID, reply)
restoreAll(sessionID, reply)
```

No operation accepts an SMC key, executable path, command, environment, or arbitrary serialized object graph.

Both peers call `setCodeSigningRequirement` before `resume()`:

- helper requires the main app's exact signing identifier and Team ID;
- main app requires the helper's exact signing identifier and the same Team ID.

If a valid Team ID is unavailable, fan control fails closed. Debug fan-control testing therefore uses a Mac Development-signed app and helper rather than an ad-hoc root helper. The existing helper behavior that falls back to an identifier-only requirement is removed.

Each accepted connection receives a distinct session object. The helper validates the session ID on every mutating call and allows only one active controlling session. A new valid session first restores any abandoned lease before taking control.

## 12. SMC Write Semantics

The helper independently reads `FNum`, `F{id}Mn`, `F{id}Mx`, target metadata, and available mode keys before accepting control.

### 12.1 Compatibility

- Probe and cache `F{id}md` and `F{id}Md` for per-fan mode.
- Use the available per-fan mode key first.
- Use the legacy Intel `FS! ` bitmask only when per-fan mode keys are unavailable and `FS! ` exists.
- Encode RPM according to the target key's actual type, including `flt ` and `fpe2`.
- Touch `Ftst` only as part of an Apple Silicon manual-control transition when the key exists; do not write it merely because the helper started.

### 12.2 Manual / Maximum / Custom Apply

1. Validate `0 <= fanID < FNum`.
2. Read and validate Min/Max and target-key metadata.
3. Clamp target RPM.
4. Enable manual mode using the detected mechanism.
5. Write `F{id}Tg`.
6. Retry transient writes up to ten times with a 50 ms interval.
7. Read mode and target back.
8. If target apply or verification fails, restore that fan to System and return a typed failure.

### 12.3 System Restore

1. Clear the per-fan manual-mode key or the fan's `FS! ` bit.
2. Clear the target key when supported.
3. Read back the mode.
4. During `restoreAll`, clear `Ftst` only after all controlled fans have left manual mode and only where that key is part of the platform's control path.

All SMC operations execute on one serial helper queue.

## 13. Watchdog and Lease Recovery

While AeroPulse controls at least one fan:

- the app sends a heartbeat every five seconds;
- the helper expires the session after fifteen seconds without a heartbeat;
- expiry restores only the fans in that session;
- normal app termination, XPC invalidation, and system sleep request `restoreAll` immediately.

Before entering manual control, the helper writes a root-owned lease file at a fixed path under `/Library/Application Support/AeroPulse`. It contains only the active session ID, controlled fan IDs, and timestamp and has mode `0600`.

On helper startup:

1. If no lease exists, it waits for a client.
2. If a lease exists, it restores the listed fans to System.
3. It removes the lease only after successful restoration.
4. If restoration fails, it retains the lease, logs the error, and retries with bounded backoff.

This avoids resetting fans owned by other software while recovering AeroPulse's abandoned state.

## 14. Error Handling

The app exposes typed errors for:

- helper not registered;
- helper awaiting approval;
- code-signing requirement failure;
- XPC interruption or timeout;
- unsupported fan or control key;
- invalid fan/RPM request;
- SMC open, read, write, or verification failure;
- stale sensor data;
- unavailable rule sensor;
- restoration pending or failed.

UI rules:

- pending operations show progress and prevent conflicting edits;
- success is shown only after helper readback;
- failure leaves a visible message and the coordinator requests System restore;
- telemetry continues even if control fails;
- a restoration failure remains prominent until readback proves system control has returned.

Logs contain fan IDs, operation categories, and IOKit result codes but no unnecessary user data.

## 15. Concurrency

- `FanViewModel` publishes UI state on the main actor.
- Sensor and fan reads remain off the main thread.
- `FanControlCoordinator` serializes policy transitions.
- `FanControlClient` owns one connection and one heartbeat task.
- The helper has a single serial SMC queue plus a watchdog timer.
- A generation ID on each request prevents stale replies from overwriting a newer user selection.

## 16. Testing Strategy

### 16.1 SMC Codec and Planner Tests

- Encode/decode `flt `, `fpe2`, `sp78`, `ui8 `, `ui16`, and `ui32`.
- Decode `FNum` correctly for byte and float representations.
- Select upper- and lower-case mode keys.
- Calculate and update Intel `FS! ` masks without changing other fans.
- Clamp targets and map percentages across nonzero Min/Max ranges.
- Generate apply, rollback, and restore write plans.

### 16.2 Rule Engine Tests

- Threshold activation and 3 °C deactivation hysteresis.
- Concrete sensor and `Any Sensor` evaluation.
- Concrete fan and `All Fans` targeting.
- Highest-speed winner across simultaneous matches.
- Disabled rules, unavailable sensors, stale samples, and corrupt preferences.
- Custom-to-System transition when no rule matches.

### 16.3 Coordinator Tests

- All four user modes and transitions between them.
- Fifty-RPM write suppression.
- Out-of-order completion protection.
- Readback mismatch and rollback.
- Custom resumption only after two fresh samples.
- Exit, sleep, XPC interruption, heartbeat timeout, and helper failure restoration.

### 16.4 XPC and Packaging Tests

- Protocol secure-coding allowlists.
- Valid signed app/helper peers connect.
- A client with the wrong signing identity is rejected.
- Helper rejects invalid session IDs, fan IDs, modes, and RPM values.
- Built app contains the helper and daemon plist at the required locations.
- Plist label, Mach service, and `BundleProgram` are correct.
- App and helper signatures have the expected identifiers and Team ID.
- `SMAppService` status maps correctly into UI state.

### 16.5 Integration Verification

Automated and read-only verification may run without changing hardware state:

- build all targets;
- run all unit tests;
- inspect bundle layout and signatures;
- register/status-check the service where already approved;
- compare fan telemetry against direct read-only SMC results.

A live write test requires separate user confirmation. The safe procedure is:

1. Choose one fan.
2. Request a target close to its current RPM and within its normal range.
3. Verify mode and target readback.
4. Immediately restore System.
5. Verify automatic mode readback.

Maximum-speed verification is not run automatically.

## 17. Acceptance Criteria

The feature is complete only when all of the following are proven:

1. Every detected fan displays actual, minimum, maximum, target, and real mode data.
2. System, Maximum, Manual, and Custom are available independently per fan.
3. Manual input is bounded in both UI and helper.
4. Threshold rules can be added, edited, enabled, disabled, deleted, persisted, and reloaded.
5. Rule evaluation follows the exact matching, hysteresis, highest-wins, and no-match behavior in this document.
6. Custom control uses fresh sensor data and returns to System when data is stale or unavailable.
7. App exit, sleep, XPC loss, watchdog expiry, and abandoned-helper restart each have a tested restoration path.
8. The helper exposes no shell, arbitrary path, arbitrary process, or arbitrary SMC-key operation.
9. XPC rejects peers that do not satisfy the configured signing requirement.
10. `SMAppService` replaces the active AppleScript installation path and reports authorization state accurately.
11. Main app, helper, and tests build successfully with zero test failures.
12. Bundle structure and code signatures pass automated inspection.
13. No live fan write occurs during development verification without explicit user authorization.

## 18. Expected Source Changes

Existing files to modify:

- `AeroPulse/Services/SMCService.swift`
- `AeroPulse/Services/FanMonitor.swift`
- `AeroPulse/Services/FanControlClient.swift`
- `AeroPulse/Services/PrivilegedHelperInstaller.swift`
- `AeroPulse/ViewModels/FanViewModel.swift`
- `AeroPulse/Models/FanStats.swift`
- `AeroPulse/Views/ThermalDetailView.swift`
- `AeroPulse/Views/SettingsView.swift`
- `AeroPulse/Helpers/AppConstants.swift`
- `FanPrivilegedHelper/main.swift` or its replacement files
- `com.bandan.me.AeroPulse.FanService.plist`
- `AeroPulse/Info.plist`
- `AeroPulse.xcodeproj/project.pbxproj`
- release and helper documentation/scripts affected by the bundle-layout change

Expected new focused files:

- shared XPC protocol and value definitions;
- `FanControlMode` and preference models;
- `FanRule` and `FanRuleEngine`;
- `FanControlCoordinator`;
- `FanControlView` and rule-editor views;
- helper session, lease, SMC codec, and fan-writer components;
- `AeroPulseTests` test cases and fixtures.

## 19. References

- Apple, `SMAppService`: https://developer.apple.com/documentation/servicemanagement/smappservice
- Apple, `daemon(plistName:)`: https://developer.apple.com/documentation/servicemanagement/smappservice/daemon%28plistname%3A%29
- Apple, updating helper executables: https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos
- Apple, XPC code-signing requirements: https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement%28_%3A%29
- Apple TN3127, code-signing requirements: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
