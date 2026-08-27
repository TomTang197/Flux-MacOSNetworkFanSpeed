# AeroPulse iFan-Style Fan Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add complete fan telemetry, System/Maximum/Manual/Custom control modes, secure privileged SMC writes, and persisted temperature-threshold automation to AeroPulse.

**Architecture:** The main app continues to read AppleSMC and owns policy, persistence, and UI. A typed `FanControlCoordinator` evaluates pure threshold rules and sends only fixed fan-target or restore operations through an authenticated XPC connection. A root LaunchDaemon registered with `SMAppService` validates every request, writes only known fan keys, verifies readback, and restores abandoned control through a watchdog and root-owned lease.

**Tech Stack:** Swift 5, SwiftUI, Combine, Foundation, IOKit, Security, ServiceManagement, NSXPCConnection, XCTest, Xcode 26/macOS 26 SDK.

**Spec:** `docs/superpowers/specs/2026-08-27-ifan-style-fan-control-design.md`

## Global Constraints

- Target macOS 26 using the existing `AeroPulse.xcodeproj`; add no third-party dependencies.
- Never bundle or invoke iFan binaries, an SMC CLI, `/bin/sh`, AppleScript, or arbitrary commands for fan control.
- The main app may read AppleSMC but must never be a fallback for privileged fan writes.
- The helper accepts only fixed fan capability, session, target, and restore operations.
- Both XPC peers fail closed unless exact signing identifiers and the same nonempty Team ID are available.
- Manual inputs are clamped independently in UI, coordinator, and helper.
- No live fan write or maximum-speed test is authorized by this plan; automated verification remains read-only.
- Every task ends with a focused test run and a commit.

## File and Target Map

### Existing app files to modify

- `AeroPulse/Models/FanStats.swift` — distinguish hardware mode from requested control mode.
- `AeroPulse/Services/SMCService.swift` — use a testable decoder and conform to the telemetry-reader protocol.
- `AeroPulse/Services/FanMonitor.swift` — read real fan count, bounds, target, and mode.
- `AeroPulse/Services/FanControlClient.swift` — replace stubs with authenticated asynchronous XPC.
- `AeroPulse/Services/PrivilegedHelperInstaller.swift` — replace file copying with `SMAppService`.
- `AeroPulse/ViewModels/FanViewModel.swift` — own preferences, coordinator state, commands, and helper state.
- `AeroPulse/Views/ThermalDetailView.swift` — host per-fan control cards.
- `AeroPulse/Views/SettingsView.swift` — host rule editor and modern helper status.
- `AeroPulse/NetworkSpeedMeterApp.swift` — connect termination and sleep lifecycle restoration.
- `AeroPulse/Helpers/AppConstants.swift` — fan-control and helper-state strings/icons.
- `AeroPulse/Info.plist` — remove legacy `SMPrivilegedExecutables` configuration.
- `FanPrivilegedHelper/main.swift` — reduce to listener wiring and per-connection exported objects.
- `com.bandan.me.AeroPulse.FanService.plist` — use `BundleProgram` and modern bundle placement.
- `AeroPulse.xcodeproj/project.pbxproj` — add shared groups, test targets, target dependencies, products, and copy phases.
- `AeroPulse.xcodeproj/xcshareddata/xcschemes/AeroPulse.xcscheme` — run both test bundles.
- `scripts/release_external.sh` — verify helper bundle layout and signatures.
- `README.md` and `README_HelperSetup.md` — describe the supported control and approval flow.

### New app files

- `AeroPulse/Models/FanControlModels.swift` — requested modes, rules, preferences, and observable command state.
- `AeroPulse/Services/FanRuleEngine.swift` — pure threshold and hysteresis evaluation.
- `AeroPulse/Services/FanControlPreferencesStore.swift` — versioned validated UserDefaults persistence.
- `AeroPulse/Services/FanControlCoordinator.swift` — policy-to-command state machine.
- `AeroPulse/Services/FanLifecycleMonitor.swift` — termination, sleep, and wake events.
- `AeroPulse/Views/FanControlView.swift` — per-fan telemetry and controls.
- `AeroPulse/Views/FanRuleEditorView.swift` — threshold-rule editor.

### New shared files compiled into app and helper

- `SharedFanControl/FanControlConstants.swift` — bundle/service identifiers and fixed timing constants.
- `SharedFanControl/FanControlWireTypes.swift` — Codable helper capabilities and verified state.
- `SharedFanControl/FanHelperProtocol.swift` — Objective-C-compatible XPC protocol.
- `SharedFanControl/SMCValueCodec.swift` — pure SMC numeric encoding and decoding.

### New helper-core files

- `FanPrivilegedHelperCore/SMCTypes.swift` — SMC transport value types and errors.
- `FanPrivilegedHelperCore/AppleSMCTransport.swift` — root AppleSMC IOKit transport.
- `FanPrivilegedHelperCore/FanWritePlanner.swift` — pure platform-specific key/write planning.
- `FanPrivilegedHelperCore/FanSMCWriter.swift` — validated apply, retry, readback, and restore behavior.
- `FanPrivilegedHelperCore/FanLeaseStore.swift` — fixed-path `0600` lease persistence.
- `FanPrivilegedHelperCore/FanSessionManager.swift` — single-session heartbeat/watchdog state.
- `FanPrivilegedHelperCore/FanHelperService.swift` — XPC method implementation over session and writer protocols.

### New tests

- `AeroPulseTests/TestDoubles.swift`
- `AeroPulseTests/FanControlModelsTests.swift`
- `AeroPulseTests/SMCTelemetryTests.swift`
- `AeroPulseTests/FanRuleEngineTests.swift`
- `AeroPulseTests/FanControlPreferencesStoreTests.swift`
- `AeroPulseTests/FanControlCoordinatorTests.swift`
- `AeroPulseTests/FanControlClientTests.swift`
- `AeroPulseTests/PrivilegedHelperInstallerTests.swift`
- `AeroPulseTests/FanViewModelControlTests.swift`
- `FanPrivilegedHelperTests/TestDoubles.swift`
- `FanPrivilegedHelperTests/SMCValueCodecTests.swift`
- `FanPrivilegedHelperTests/FanWritePlannerTests.swift`
- `FanPrivilegedHelperTests/FanSMCWriterTests.swift`
- `FanPrivilegedHelperTests/FanLeaseStoreTests.swift`
- `FanPrivilegedHelperTests/FanSessionManagerTests.swift`
- `FanPrivilegedHelperTests/FanHelperServiceTests.swift`

---

### Task 1: Add test targets and fan-control domain models

**Files:**
- Create: `AeroPulse/Models/FanControlModels.swift`
- Create: `AeroPulseTests/FanControlModelsTests.swift`
- Create: `FanPrivilegedHelperTests/PlaceholderTests.swift`
- Modify: `AeroPulse/Models/FanStats.swift`
- Modify: `AeroPulse.xcodeproj/project.pbxproj`
- Modify: `AeroPulse.xcodeproj/xcshareddata/xcschemes/AeroPulse.xcscheme`

**Interfaces:**
- Produces: `FanHardwareMode`, `FanControlMode`, `FanRule`, `FanControlPreferences`, `FanControlOperationState`.
- Produces: hosted `AeroPulseTests` and unhosted `FanPrivilegedHelperTests` XCTest targets included in the `AeroPulse` scheme.

- [ ] **Step 1: Add both XCTest target shells and write failing model tests**

Configure `AeroPulseTests` as a macOS unit-test bundle with `TEST_HOST = $(BUILT_PRODUCTS_DIR)/AeroPulse.app/Contents/MacOS/AeroPulse`, `BUNDLE_LOADER = $(TEST_HOST)`, and `@testable import AeroPulse`. Configure `FanPrivilegedHelperTests` as an unhosted macOS unit-test bundle. Add both to the scheme TestAction.

Create this focused test first:

```swift
import XCTest
@testable import AeroPulse

final class FanControlModelsTests: XCTestCase {
    func testPreferencesRoundTripPreservesRulesAndCustomFans() throws {
        let rule = FanRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            enabled: true,
            sensorID: "TC0P",
            fanID: 0,
            thresholdCelsius: 70,
            speedPercent: 65
        )
        let input = FanControlPreferences(
            schemaVersion: 1,
            rules: [rule],
            customFanIDs: [0],
            lastManualRPM: [0: 2500]
        )

        let data = try JSONEncoder().encode(input)
        XCTAssertEqual(try JSONDecoder().decode(FanControlPreferences.self, from: data), input)
    }

    func testManualAndMaximumAreNotPersistentRequestedModes() {
        XCTAssertTrue(FanControlMode.manual.requiresExplicitActivation)
        XCTAssertTrue(FanControlMode.maximum.requiresExplicitActivation)
        XCTAssertFalse(FanControlMode.custom.requiresExplicitActivation)
    }
}
```

- [ ] **Step 2: Run tests to verify the new test target works and models are missing**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/FanControlModelsTests test
```

Expected: test bundle builds, then FAILS because `FanRule`, `FanControlPreferences`, and the new enums do not exist.

- [ ] **Step 3: Implement the minimal domain types and refactor `FanInfo`**

Use these exact public shapes inside the app module:

```swift
enum FanHardwareMode: String, Codable, Equatable {
    case automatic
    case manual
    case unknown
}

enum FanControlMode: String, Codable, CaseIterable, Equatable {
    case system
    case maximum
    case manual
    case custom

    var requiresExplicitActivation: Bool {
        self == .manual || self == .maximum
    }
}

struct FanRule: Identifiable, Codable, Equatable {
    let id: UUID
    var enabled: Bool
    var sensorID: String?
    var fanID: Int?
    var thresholdCelsius: Double
    var speedPercent: Int
}

struct FanControlPreferences: Codable, Equatable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int = currentSchemaVersion
    var rules: [FanRule] = []
    var customFanIDs: Set<Int> = []
    var lastManualRPM: [Int: Int] = [:]
}

enum FanControlOperationState: Equatable {
    case idle
    case applying
    case applied(targetRPM: Int?)
    case restoring
    case failed(message: String)
}
```

Replace the existing `FanMode` field on `FanInfo` with `hardwareMode: FanHardwareMode` and update its initializer/default.

- [ ] **Step 4: Run the focused tests and the existing app build**

Run the command from Step 2, then:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control build
```

Expected: focused tests PASS and app/helper dependencies build successfully.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Models AeroPulseTests FanPrivilegedHelperTests \
  AeroPulse.xcodeproj/project.pbxproj \
  AeroPulse.xcodeproj/xcshareddata/xcschemes/AeroPulse.xcscheme
git commit -m "test: add fan control domain and test targets"
```

### Task 2: Make fan telemetry complete and testable

**Files:**
- Create: `SharedFanControl/SMCValueCodec.swift`
- Create: `AeroPulseTests/SMCTelemetryTests.swift`
- Modify: `AeroPulse/Services/SMCService.swift`
- Modify: `AeroPulse/Services/FanMonitor.swift`
- Modify: `AeroPulse.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `SMCValueCodec.decode(bytes:type:size:) -> Double?`.
- Produces: `SMCReading.number(forKey:) -> Double?` and `temperature(forKey:) -> Double?`.
- Produces: `FanMonitor.init(smc:)` and complete `FanInfo` snapshots.

- [ ] **Step 1: Write failing codec and telemetry tests**

```swift
import XCTest
@testable import AeroPulse

private final class FakeSMCReader: SMCReading {
    var values: [String: Double]
    init(_ values: [String: Double]) { self.values = values }
    func number(forKey key: String) -> Double? { values[key] }
    func temperature(forKey key: String) -> Double? { values[key] }
}

final class SMCTelemetryTests: XCTestCase {
    func testFloatFanCountDecodesAsTwo() {
        let bytes = withUnsafeBytes(of: Float(2)) { Array($0) }
        XCTAssertEqual(SMCValueCodec.decode(bytes: bytes, type: "flt ", size: 4), 2)
    }

    func testMonitorReadsAllFanFieldsAndRealMode() {
        let smc = FakeSMCReader([
            "FNum": 1,
            "F0Ac": 1800,
            "F0Mn": 1200,
            "F0Mx": 6000,
            "F0Tg": 2000,
            "F0Md": 1,
        ])

        let fans = FanMonitor(smc: smc).getFans()
        XCTAssertEqual(fans.count, 1)
        XCTAssertEqual(fans[0].currentRPM, 1800)
        XCTAssertEqual(fans[0].minRPM, 1200)
        XCTAssertEqual(fans[0].maxRPM, 6000)
        XCTAssertEqual(fans[0].targetRPM, 2000)
        XCTAssertEqual(fans[0].hardwareMode, .manual)
    }

    func testLowercaseModeKeyFallback() {
        let smc = FakeSMCReader([
            "FNum": 1, "F0Ac": 1500, "F0Mn": 1200, "F0Mx": 5000,
            "F0Tg": 1500, "F0md": 0,
        ])
        XCTAssertEqual(FanMonitor(smc: smc).getFans()[0].hardwareMode, .automatic)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/SMCTelemetryTests test
```

Expected: FAIL because `SMCValueCodec`, `SMCReading`, and injectable `FanMonitor` do not exist.

- [ ] **Step 3: Implement codec extraction and telemetry protocol**

Implement the codec as a pure namespace. It must decode big-endian fixed/integer formats and native little-endian `flt ` bytes:

```swift
enum SMCValueCodec {
    static func decode(bytes: [UInt8], type: String, size: Int) -> Double? {
        guard size > 0, bytes.count >= size else { return nil }
        switch type {
        case "flt ":
            guard size >= 4 else { return nil }
            var value: Float = 0
            withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes.prefix(4)) }
            return value.isFinite ? Double(value) : nil
        case "fpe2":
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "sp78":
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case "ui8 ": return Double(bytes[0])
        case "ui16": return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 |
                          UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        default: return nil
        }
    }
}
```

Introduce:

```swift
protocol SMCReading: AnyObject {
    func number(forKey key: String) -> Double?
    func temperature(forKey key: String) -> Double?
}
```

Make `SMCService` conform using its existing key read and the shared codec. Inject `SMCReading` into `FanMonitor`. Read `FNum` numerically, probe `F{id}Md` then `F{id}md`, and remove the hardcoded `.auto` mode.

- [ ] **Step 4: Run telemetry tests and full read-only app tests**

Run the focused command from Step 2, then:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control test
```

Expected: all current tests PASS. No write methods are called.

- [ ] **Step 5: Commit**

```bash
git add SharedFanControl AeroPulse/Services/SMCService.swift \
  AeroPulse/Services/FanMonitor.swift AeroPulseTests/SMCTelemetryTests.swift \
  AeroPulse.xcodeproj/project.pbxproj
git commit -m "feat: report complete fan telemetry"
```

### Task 3: Add validated preference persistence

**Files:**
- Create: `AeroPulse/Services/FanControlPreferencesStore.swift`
- Create: `AeroPulseTests/FanControlPreferencesStoreTests.swift`
- Modify: `AeroPulse/Models/FanControlModels.swift`

**Interfaces:**
- Produces: `FanControlPreferencesStoring.load() -> FanControlPreferences`.
- Produces: `save(_:)`, `quarantinedData`, and deterministic validation through `FanControlPreferences.validated()`.

- [ ] **Step 1: Write failing validation and corruption tests**

```swift
import XCTest
@testable import AeroPulse

final class FanControlPreferencesStoreTests: XCTestCase {
    func testValidationClampsPercentAndDropsNonfiniteThreshold() {
        let invalid = FanControlPreferences(rules: [
            FanRule(id: UUID(), enabled: true, sensorID: "TC0P", fanID: 0,
                    thresholdCelsius: 70, speedPercent: 140),
            FanRule(id: UUID(), enabled: true, sensorID: "TG0P", fanID: nil,
                    thresholdCelsius: .nan, speedPercent: 50),
        ])
        let valid = invalid.validated()
        XCTAssertEqual(valid.rules.count, 1)
        XCTAssertEqual(valid.rules[0].speedPercent, 100)
    }

    func testCorruptDataReturnsSafeDefaultsAndIsQuarantined() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(Data("broken".utf8), forKey: "fanControlPreferences")
        let store = UserDefaultsFanControlPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), FanControlPreferences())
        XCTAssertNotNil(store.quarantinedData)
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/FanControlPreferencesStoreTests test
```

Expected: FAIL because validation and store types are missing.

- [ ] **Step 3: Implement versioned validated storage**

Define:

```swift
protocol FanControlPreferencesStoring: AnyObject {
    func load() -> FanControlPreferences
    func save(_ preferences: FanControlPreferences) throws
}

final class UserDefaultsFanControlPreferencesStore: FanControlPreferencesStoring {
    static let key = "fanControlPreferences"
    private let defaults: UserDefaults
    private(set) var quarantinedData: Data?

    func load() -> FanControlPreferences {
        guard let data = defaults.data(forKey: Self.key) else {
            return FanControlPreferences()
        }
        do {
            let decoded = try JSONDecoder().decode(FanControlPreferences.self, from: data)
            guard decoded.schemaVersion == FanControlPreferences.currentSchemaVersion else {
                quarantinedData = data
                return FanControlPreferences()
            }
            return decoded.validated()
        } catch {
            quarantinedData = data
            return FanControlPreferences()
        }
    }

    func save(_ preferences: FanControlPreferences) throws {
        let data = try JSONEncoder().encode(preferences.validated())
        defaults.set(data, forKey: Self.key)
    }
}
```

`validated()` must reject a noncurrent schema, remove nonfinite thresholds, clamp percentage to `0...100`, remove negative fan IDs, and remove negative manual RPM values.

- [ ] **Step 4: Run focused and model tests**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/FanControlPreferencesStoreTests \
  -only-testing:AeroPulseTests/FanControlModelsTests test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Models/FanControlModels.swift \
  AeroPulse/Services/FanControlPreferencesStore.swift \
  AeroPulseTests/FanControlPreferencesStoreTests.swift
git commit -m "feat: persist validated fan control preferences"
```

### Task 4: Implement the pure temperature-threshold rule engine

**Files:**
- Create: `AeroPulse/Services/FanRuleEngine.swift`
- Create: `AeroPulseTests/FanRuleEngineTests.swift`
- Modify: `AeroPulse/Models/FanControlModels.swift`

**Interfaces:**
- Consumes: `FanRule`, `FanInfo`, `SensorInfo`.
- Produces: `FanTelemetrySnapshot`, `FanRuleDecision`, `FanRuleEvaluation`.
- Produces: `FanRuleEngine.evaluate(rules:customFanIDs:snapshot:previousActivation:now:)`.

- [ ] **Step 1: Write failing threshold, hysteresis, and highest-wins tests**

```swift
import XCTest
@testable import AeroPulse

final class FanRuleEngineTests: XCTestCase {
    private let fan = FanInfo(id: 0, name: "Fan 0", currentRPM: 1500,
                              minRPM: 1000, maxRPM: 5000, targetRPM: 1500,
                              hardwareMode: .automatic)

    func testHighestMatchingRuleWinsAndMapsPercentIntoRange() {
        let rules = [
            FanRule(id: UUID(), enabled: true, sensorID: "CPU", fanID: 0,
                    thresholdCelsius: 60, speedPercent: 50),
            FanRule(id: UUID(), enabled: true, sensorID: "CPU", fanID: 0,
                    thresholdCelsius: 70, speedPercent: 80),
        ]
        let snapshot = FanTelemetrySnapshot(
            sampledAt: Date(timeIntervalSince1970: 100), fans: [fan],
            sensors: [SensorInfo(id: "CPU", name: "CPU", temperature: 75, isEnabled: true)]
        )
        let result = FanRuleEngine().evaluate(
            rules: rules, customFanIDs: [0], snapshot: snapshot,
            previousActivation: [:], now: Date(timeIntervalSince1970: 101)
        )
        XCTAssertEqual(result.decisions[0]?.targetRPM, 4200)
    }

    func testActiveRuleUsesThreeDegreeHysteresis() {
        let id = UUID()
        let rule = FanRule(id: id, enabled: true, sensorID: "CPU", fanID: 0,
                           thresholdCelsius: 70, speedPercent: 50)
        let snapshot = FanTelemetrySnapshot(
            sampledAt: Date(timeIntervalSince1970: 100), fans: [fan],
            sensors: [SensorInfo(id: "CPU", name: "CPU", temperature: 68, isEnabled: true)]
        )
        let result = FanRuleEngine().evaluate(
            rules: [rule], customFanIDs: [0], snapshot: snapshot,
            previousActivation: [id: true], now: Date(timeIntervalSince1970: 101)
        )
        XCTAssertNotNil(result.decisions[0])
    }

    func testStaleSnapshotReturnsSystemDecision() {
        let snapshot = FanTelemetrySnapshot(
            sampledAt: Date(timeIntervalSince1970: 90), fans: [fan], sensors: []
        )
        let result = FanRuleEngine().evaluate(
            rules: [], customFanIDs: [0], snapshot: snapshot,
            previousActivation: [:], now: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(result.systemFanIDs, [0])
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/FanRuleEngineTests test
```

Expected: FAIL because snapshot/evaluation types and engine are missing.

- [ ] **Step 3: Implement pure evaluation**

Use these exact outputs:

```swift
struct FanTelemetrySnapshot: Equatable {
    let sampledAt: Date
    let fans: [FanInfo]
    let sensors: [SensorInfo]
}

struct FanRuleDecision: Equatable {
    let fanID: Int
    let targetRPM: Int
    let speedPercent: Int
    let matchedRuleIDs: [UUID]
    let sourceTemperature: Double
}

struct FanRuleEvaluation: Equatable {
    let decisions: [Int: FanRuleDecision]
    let systemFanIDs: Set<Int>
    let activation: [UUID: Bool]
    let unavailableRuleIDs: Set<UUID>
}
```

Implement eleven rule semantics from spec section 7 exactly, including `Any Sensor`, `All Fans`, highest speed, 3 °C hysteresis, six-second staleness, and no-match System output.

- [ ] **Step 4: Add missing edge-case tests and run the suite**

Add tests for disabled rules, unavailable concrete sensors, `Any Sensor` maximum temperature, `All Fans` respecting only custom-mode fans, `0% -> minRPM`, and `100% -> maxRPM`. Run the focused command and expect all PASS.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Models/FanControlModels.swift \
  AeroPulse/Services/FanRuleEngine.swift AeroPulseTests/FanRuleEngineTests.swift
git commit -m "feat: evaluate temperature fan rules"
```

### Task 5: Build the fan-control coordinator state machine

**Files:**
- Create: `AeroPulse/Services/FanControlCoordinator.swift`
- Create: `AeroPulseTests/FanControlCoordinatorTests.swift`
- Modify: `AeroPulse/Models/FanControlModels.swift`

**Interfaces:**
- Consumes: `FanRuleEngine`, `FanControlPreferencesStoring`, `FanTelemetrySnapshot`.
- Produces: `FanControlTransport` async protocol.
- Produces: injectable `FanControlCoordinating` and `@MainActor FanControlCoordinator` with `selectMode`, `setManualRPM`, `consume`, and `restoreAll`.

- [ ] **Step 1: Write failing coordinator tests with a fake transport**

```swift
import XCTest
@testable import AeroPulse

private actor FakeFanControlTransport: FanControlTransport {
    enum Call: Equatable {
        case control(fanID: Int, mode: FanControlMode, targetRPM: Int)
        case restore(Int)
        case restoreAll
    }
    private var calls: [Call] = []

    func setControl(fanID: Int, mode: FanControlMode,
                    targetRPM: Int) async throws -> FanVerifiedState {
        calls.append(.control(fanID: fanID, mode: mode, targetRPM: targetRPM))
        let rpm = targetRPM
        return FanVerifiedState(fanID: fanID, hardwareMode: .manual, targetRPM: rpm)
    }
    func restoreFan(fanID: Int) async throws { calls.append(.restore(fanID)) }
    func restoreAll() async throws { calls.append(.restoreAll) }
    func recordedCalls() -> [Call] { calls }
}

private final class InMemoryFanPreferencesStore: FanControlPreferencesStoring {
    var value: FanControlPreferences
    init(_ value: FanControlPreferences = FanControlPreferences()) { self.value = value }
    func load() -> FanControlPreferences { value }
    func save(_ preferences: FanControlPreferences) throws { value = preferences }
}

@MainActor
final class FanControlCoordinatorTests: XCTestCase {
    func testMaximumUsesFreshFanMaximum() async throws {
        let transport = FakeFanControlTransport()
        let coordinator = FanControlCoordinator(transport: transport,
            preferencesStore: InMemoryFanPreferencesStore())
        let fan = FanInfo(id: 0, name: "Fan", currentRPM: 1500,
                          minRPM: 1000, maxRPM: 5000, targetRPM: 1500,
                          hardwareMode: .automatic)
        await coordinator.selectMode(.maximum, fan: fan)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [.control(fanID: 0, mode: .maximum, targetRPM: 5000)])
    }

    func testTargetChangesBelowFiftyRPMAreSuppressed() async {
        let transport = FakeFanControlTransport()
        let coordinator = FanControlCoordinator(transport: transport,
            preferencesStore: InMemoryFanPreferencesStore())
        let fan = FanInfo(id: 0, name: "Fan", currentRPM: 1500,
                          minRPM: 1000, maxRPM: 5000, targetRPM: 1500,
                          hardwareMode: .automatic)
        await coordinator.setManualRPM(2500, fan: fan)
        await coordinator.setManualRPM(2530, fan: fan)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [.control(fanID: 0, mode: .manual, targetRPM: 2500)])
    }

    func testNoMatchingCustomRuleRestoresFan() async {
        let transport = FakeFanControlTransport()
        let coordinator = FanControlCoordinator(transport: transport,
            preferencesStore: InMemoryFanPreferencesStore())
        let fan = FanInfo(id: 0, name: "Fan", currentRPM: 1500,
                          minRPM: 1000, maxRPM: 5000, targetRPM: 1500,
                          hardwareMode: .automatic)
        await coordinator.selectMode(.custom, fan: fan)
        await coordinator.consume(FanTelemetrySnapshot(
            sampledAt: Date(), fans: [fan],
            sensors: [SensorInfo(id: "CPU", name: "CPU", temperature: 50,
                                 isEnabled: true)]
        ))
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [.restore(0)])
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:AeroPulseTests/FanControlCoordinatorTests test
```

Expected: FAIL because transport, verified state, in-memory store, and coordinator are missing.

- [ ] **Step 3: Implement the transport abstraction and coordinator**

```swift
struct FanVerifiedState: Equatable {
    let fanID: Int
    let hardwareMode: FanHardwareMode
    let targetRPM: Int?
}

protocol FanControlTransport: AnyObject {
    func setControl(fanID: Int, mode: FanControlMode,
                    targetRPM: Int) async throws -> FanVerifiedState
    func restoreFan(fanID: Int) async throws
    func restoreAll() async throws
}

@MainActor
protocol FanControlCoordinating: AnyObject {
    var selectedModes: [Int: FanControlMode] { get }
    var operationStates: [Int: FanControlOperationState] { get }
    var ruleDecisions: [Int: FanRuleDecision] { get }
    func selectMode(_ mode: FanControlMode, fan: FanInfo) async
    func setManualRPM(_ rpm: Int, fan: FanInfo) async
    func consume(_ snapshot: FanTelemetrySnapshot) async
    func restoreAll() async
}

@MainActor
final class FanControlCoordinator: ObservableObject, FanControlCoordinating {
    @Published private(set) var selectedModes: [Int: FanControlMode] = [:]
    @Published private(set) var operationStates: [Int: FanControlOperationState] = [:]
    @Published private(set) var ruleDecisions: [Int: FanRuleDecision] = [:]

    func selectMode(_ mode: FanControlMode, fan: FanInfo) async
    func setManualRPM(_ rpm: Int, fan: FanInfo) async
    func consume(_ snapshot: FanTelemetrySnapshot) async
    func restoreAll() async
}
```

Clamp manual values, persist custom selection and last edit value, keep manual/maximum activation runtime-only, use monotonically increasing per-fan generations, and only publish success after `FanVerifiedState` returns.

- [ ] **Step 4: Add failure, ordering, resume, and restoration tests**

Test transport failure, out-of-order replies, 50-RPM suppression, two-fresh-sample custom resume, stale snapshot restore, explicit System, and restore-all state clearing. Run the focused suite and expect PASS.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Models/FanControlModels.swift \
  AeroPulse/Services/FanControlCoordinator.swift \
  AeroPulseTests/FanControlCoordinatorTests.swift
git commit -m "feat: coordinate fan control modes"
```

### Task 6: Refactor and verify the helper SMC core

**Files:**
- Create: `SharedFanControl/FanControlConstants.swift`
- Create: `SharedFanControl/FanControlWireTypes.swift`
- Create: `FanPrivilegedHelperCore/SMCTypes.swift`
- Create: `FanPrivilegedHelperCore/AppleSMCTransport.swift`
- Create: `FanPrivilegedHelperCore/FanWritePlanner.swift`
- Create: `FanPrivilegedHelperCore/FanSMCWriter.swift`
- Create: `FanPrivilegedHelperTests/SMCValueCodecTests.swift`
- Create: `FanPrivilegedHelperTests/FanWritePlannerTests.swift`
- Create: `FanPrivilegedHelperTests/FanSMCWriterTests.swift`
- Modify: `FanPrivilegedHelper/main.swift`
- Modify: `AeroPulse.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: shared `SMCValueCodec`.
- Produces: `SMCTransport`, `FanWritePlanning`, `FanWriting`.
- Produces: `FanSMCWriter.capabilities()`, `setControl`, `restoreFan`, and `restoreAll`.

- [ ] **Step 1: Write failing pure planner and writer tests**

```swift
import XCTest

final class FanWritePlannerTests: XCTestCase {
    func testAppleSiliconManualPlanTouchesFtstModeThenTarget() throws {
        let capability = FanCapability(
            fanID: 0, minRPM: 1200, maxRPM: 6000,
            targetKey: "F0Tg", targetType: "flt ", modeMechanism: .perFan(key: "F0Md"),
            hasFtst: true
        )
        XCTAssertEqual(
            FanWritePlanner().manualPlan(capability: capability, targetRPM: 2500),
            [.writeByte(key: "Ftst", value: 1),
             .writeByte(key: "F0Md", value: 1),
             .writeRPM(key: "F0Tg", type: "flt ", value: 2500)]
        )
    }

    func testLegacyRestoreClearsOnlySelectedFSBit() throws {
        let capability = FanCapability(
            fanID: 1, minRPM: 1200, maxRPM: 6000,
            targetKey: "F1Tg", targetType: "fpe2", modeMechanism: .forceMask,
            hasFtst: false
        )
        XCTAssertEqual(FanWritePlanner().restoredForceMask(current: 0b11,
                                                            fanID: 1), 0b01)
    }
}
```

Writer tests use `FakeSMCTransport` to prove clamping, ten 50-ms retries through an injected sleeper, target readback, and automatic rollback after a rejected target write.

- [ ] **Step 2: Run helper tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:FanPrivilegedHelperTests/FanWritePlannerTests \
  -only-testing:FanPrivilegedHelperTests/FanSMCWriterTests test
```

Expected: FAIL because helper-core types do not exist.

- [ ] **Step 3: Implement focused helper core types**

Define:

```swift
protocol SMCTransport: AnyObject {
    func read(_ key: String) throws -> SMCValue
    func write(_ key: String, value: SMCValue) throws
}

enum FanModeMechanism: Equatable, Codable {
    case perFan(key: String)
    case forceMask
    case unavailable
}

struct FanCapability: Equatable, Codable {
    let fanID: Int
    let minRPM: Int
    let maxRPM: Int
    let targetKey: String
    let targetType: String
    let modeMechanism: FanModeMechanism
    let hasFtst: Bool
}

enum FanWireHardwareMode: Int, Codable, Equatable {
    case automatic = 0
    case manual = 1
    case unknown = -1
}

enum FanWireControlMode: Int, Codable, Equatable {
    case manual = 1
    case maximum = 2
    case custom = 3
}

struct FanWireCapability: Codable, Equatable {
    let fanID: Int
    let minRPM: Int
    let maxRPM: Int
    let supportsControl: Bool
}

struct FanWireVerifiedState: Codable, Equatable {
    let fanID: Int
    let hardwareMode: FanWireHardwareMode
    let targetRPM: Int?
}

protocol FanWriting: AnyObject {
    func capabilities() throws -> [FanCapability]
    func setControl(fanID: Int, mode: FanWireControlMode,
                    targetRPM: Int) throws -> FanWireVerifiedState
    func restoreFan(fanID: Int) throws
    func restoreAll(fanIDs: Set<Int>) throws
}
```

Move IOKit transport out of `main.swift`. Remove `unlockDiagnosticsIfAvailable()` from initialization. Probe lower/upper mode keys, fall back to `FS! ` only if per-fan keys are unavailable, clamp against freshly read bounds, serialize calls, retry transient write failures, verify mode/target, and restore after failure.

`FanWireControlMode.maximum` ignores the caller's RPM and uses the freshly read maximum. Manual and Custom clamp the supplied RPM independently. Any other raw mode is rejected before an SMC write. Put the wire enums and structs in `SharedFanControl/FanControlWireTypes.swift`; keep the key-bearing `FanCapability` helper-internal.

- [ ] **Step 4: Run helper tests and both product builds**

Run the focused tests, then:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme FanPrivilegedHelper \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control build
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AeroPulseDerivedData-fan-control build
```

Expected: tests and both builds PASS. No test opens AppleSMC for writing.

- [ ] **Step 5: Commit**

```bash
git add SharedFanControl FanPrivilegedHelperCore FanPrivilegedHelper \
  FanPrivilegedHelperTests AeroPulse.xcodeproj/project.pbxproj
git commit -m "refactor: isolate verified fan SMC writer"
```

### Task 7: Add authenticated XPC sessions, watchdog, and lease recovery

**Files:**
- Create: `SharedFanControl/FanHelperProtocol.swift`
- Create: `FanPrivilegedHelperCore/FanLeaseStore.swift`
- Create: `FanPrivilegedHelperCore/FanSessionManager.swift`
- Create: `FanPrivilegedHelperCore/FanHelperService.swift`
- Create: `FanPrivilegedHelperTests/FanLeaseStoreTests.swift`
- Create: `FanPrivilegedHelperTests/FanSessionManagerTests.swift`
- Create: `FanPrivilegedHelperTests/FanHelperServiceTests.swift`
- Modify: `FanPrivilegedHelper/main.swift`

**Interfaces:**
- Consumes: `FanWriting`.
- Produces: fixed `FanHelperProtocol` methods from the spec.
- Produces: `FanLeaseStoring` and `FanSessionManaging`.

- [ ] **Step 1: Write failing lease and watchdog tests**

```swift
import XCTest

final class FanSessionManagerTests: XCTestCase {
    func testExpiredSessionRestoresOnlyLeasedFans() throws {
        let clock = TestClock(now: Date(timeIntervalSince1970: 0))
        let writer = FakeFanWriter()
        let lease = InMemoryFanLeaseStore()
        let manager = FanSessionManager(writer: writer, leaseStore: lease,
                                        clock: clock, timeout: 15)
        let session = try manager.beginSession()
        try manager.markControlled(fanID: 1, sessionID: session)
        clock.now = Date(timeIntervalSince1970: 16)
        manager.expireIfNeeded()
        XCTAssertEqual(writer.restoredFanIDs, [1])
        XCTAssertNil(lease.load())
    }
}

final class FanLeaseStoreTests: XCTestCase {
    func testLeaseIsWrittenWithOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = FileFanLeaseStore(directoryURL: directory)
        try store.save(FanLease(sessionID: UUID(), fanIDs: [0], updatedAt: Date()))
        let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, 0o600)
    }
}
```

- [ ] **Step 2: Run focused helper tests and verify failure**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control \
  -only-testing:FanPrivilegedHelperTests/FanLeaseStoreTests \
  -only-testing:FanPrivilegedHelperTests/FanSessionManagerTests \
  -only-testing:FanPrivilegedHelperTests/FanHelperServiceTests test
```

Expected: FAIL because session, lease, and service types are missing.

- [ ] **Step 3: Implement the fixed XPC protocol and safe session manager**

The shared Objective-C protocol must use only `NSData`, `NSUUID`, primitive integers, and reply blocks:

```swift
@objc protocol FanHelperProtocol {
    func capabilities(withReply reply: @escaping (NSData?, Int32) -> Void)
    func beginSession(withReply reply: @escaping (NSUUID?, Int32) -> Void)
    func heartbeat(sessionID: NSUUID, withReply reply: @escaping (Int32) -> Void)
    func setFanControl(sessionID: NSUUID, fanID: Int, mode: Int, targetRPM: Int,
                       withReply reply: @escaping (NSData?, Int32) -> Void)
    func restoreFan(sessionID: NSUUID, fanID: Int,
                    withReply reply: @escaping (Int32) -> Void)
    func restoreAll(sessionID: NSUUID, withReply reply: @escaping (Int32) -> Void)
}
```

`FanSessionManager` allows one active session, persists controlled fan IDs before writes, updates heartbeat timestamps, expires at 15 seconds, and restores an abandoned lease on startup before accepting a new session. `FanControlConstants` fixes heartbeat at five seconds, timeout at fifteen seconds, lease directory at `/Library/Application Support/AeroPulse`, and a non-user-selectable lease filename. Startup recovery retains the lease after failure and retries with a capped backoff sequence of 1, 2, 4, 8, and 15 seconds.

- [ ] **Step 4: Replace listener wiring and enforce client signing before resume**

Build the requirement only from fixed constants and the helper's nonempty Team ID:

```swift
let requirement = "anchor apple generic and identifier \"com.bandan.me.AeroPulse\" " +
    "and certificate leaf[subject.OU] = \"\(teamID)\""
connection.setCodeSigningRequirement(requirement)
connection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
connection.exportedObject = FanHelperService(...)
connection.invalidationHandler = { service.connectionInvalidated() }
connection.resume()
```

Return `false` if Team ID resolution fails. Remove the current identifier-only fallback and UID-only acceptance check. Add explicit NSSecureCoding class allowlists for `NSData`, `NSUUID`, and `NSNumber` arguments/replies. Add service tests proving invalid session IDs, raw control modes, fan IDs, and RPM values fail before writer calls; connection invalidation restores the active lease immediately; timeout restores only its fan IDs; and a failed startup restoration retains the lease for retry.

- [ ] **Step 5: Run helper tests and build the signed Debug helper**

Run the focused tests and helper build. Inspect:

```bash
codesign -dvv --entitlements :- \
  /tmp/AeroPulseDerivedData-fan-control/Build/Products/Debug/FanPrivilegedHelper
```

Expected: all tests PASS; helper has the expected signing identifier and a nonempty TeamIdentifier. If the build is ad-hoc, change Debug signing to Mac Development before proceeding; do not weaken the requirement.

- [ ] **Step 6: Commit**

```bash
git add SharedFanControl FanPrivilegedHelperCore FanPrivilegedHelper \
  FanPrivilegedHelperTests AeroPulse.xcodeproj/project.pbxproj
git commit -m "feat: secure privileged fan control sessions"
```

### Task 8: Implement the app XPC client and code-signing checks

**Files:**
- Create: `AeroPulseTests/FanControlClientTests.swift`
- Modify: `AeroPulse/Services/FanControlClient.swift`
- Modify: `SharedFanControl/FanControlConstants.swift`

**Interfaces:**
- Consumes: `FanHelperProtocol` and wire states.
- Produces: production conformance to `FanControlTransport`.
- Produces: `FanPeerRequirementBuilder.requirement(identifier:teamID:)`.

- [ ] **Step 1: Write failing requirement and proxy-error tests**

```swift
import XCTest
@testable import AeroPulse

final class FanControlClientTests: XCTestCase {
    func testHelperRequirementIncludesExactIdentifierAndTeam() throws {
        XCTAssertEqual(
            try FanPeerRequirementBuilder.requirement(
                identifier: "com.bandan.me.AeroPulse.FanService", teamID: "PVNL55D2Y2"),
            "anchor apple generic and identifier \"com.bandan.me.AeroPulse.FanService\" " +
            "and certificate leaf[subject.OU] = \"PVNL55D2Y2\""
        )
    }

    func testEmptyTeamFailsClosed() {
        XCTAssertThrowsError(try FanPeerRequirementBuilder.requirement(
            identifier: "com.bandan.me.AeroPulse.FanService", teamID: ""))
    }

    func testVerifiedReplyMapsIntoCoordinatorState() async throws {
        let proxy = FakeFanHelperProxy(targetReply: FanWireVerifiedState(
            fanID: 0, hardwareMode: .manual, targetRPM: 2400))
        let client = FanControlClient(proxyFactory: FakeProxyFactory(proxy: proxy),
                                      teamIDProvider: { "PVNL55D2Y2" })
        let state = try await client.setControl(
            fanID: 0, mode: .manual, targetRPM: 2400
        )
        XCTAssertEqual(state.targetRPM, 2400)
        XCTAssertEqual(proxy.lastRawMode, FanWireControlMode.manual.rawValue)
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run the focused `FanControlClientTests`; expect FAIL because the production client and injected factories are missing.

- [ ] **Step 3: Implement asynchronous XPC transport**

Create the privileged connection with:

```swift
let connection = NSXPCConnection(
    machServiceName: FanControlConstants.serviceIdentifier,
    options: .privileged
)
connection.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
connection.setCodeSigningRequirement(helperRequirement)
connection.interruptionHandler = { [weak self] in
    self?.handleConnectionLoss(.interrupted)
}
connection.invalidationHandler = { [weak self] in
    self?.handleConnectionLoss(.invalidated)
}
connection.resume()
```

Wrap reply blocks with checked continuations. Begin one session lazily, heartbeat every five seconds only while controlled fan IDs are nonempty, convert `.manual`, `.maximum`, and `.custom` to the matching `FanWireControlMode`, and reject `.system` as a target operation. Map nonzero helper status plus NSXPC errors into `FanControlError`. The production initializer remains internal; tests inject a proxy factory and Team ID provider. Connection loss cancels heartbeat, clears the session, and notifies the coordinator to publish a restoration-pending failure while the helper performs its immediate restore.

- [ ] **Step 4: Run client, coordinator, and full app tests**

Run `FanControlClientTests`, `FanControlCoordinatorTests`, then the whole AeroPulse test action. Expected: PASS with no live Mach-service dependency in unit tests.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Services/FanControlClient.swift \
  AeroPulseTests/FanControlClientTests.swift SharedFanControl
git commit -m "feat: connect fan controls over authenticated XPC"
```

### Task 9: Migrate helper registration to SMAppService

**Files:**
- Create: `AeroPulseTests/PrivilegedHelperInstallerTests.swift`
- Modify: `AeroPulse/Services/PrivilegedHelperInstaller.swift`
- Modify: `AeroPulse/Info.plist`
- Modify: `com.bandan.me.AeroPulse.FanService.plist`
- Modify: `AeroPulse.xcodeproj/project.pbxproj`
- Modify: `scripts/release_external.sh`

**Interfaces:**
- Produces: `HelperRegistrationState` and `PrivilegedHelperManaging`.
- Produces: `register()`, `unregister()`, `refreshState()`, and `openApprovalSettings()`.

- [ ] **Step 1: Write failing state-mapping and legacy-conflict tests**

```swift
import XCTest
@testable import AeroPulse

final class PrivilegedHelperInstallerTests: XCTestCase {
    func testRequiresApprovalMapsToPendingState() {
        let service = FakeAppService(status: .requiresApproval)
        let manager = PrivilegedHelperInstaller(service: service,
            legacyFileExists: { _ in false })
        XCTAssertEqual(manager.refreshState(), .requiresApproval)
    }

    func testLegacyFilesFailBeforeRegistration() async {
        let service = FakeAppService(status: .notRegistered)
        let manager = PrivilegedHelperInstaller(service: service,
            legacyFileExists: { _ in true })
        do {
            try await manager.register()
            XCTFail("Expected legacyConflict")
        } catch PrivilegedHelperError.legacyConflict {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(service.registerCallCount, 0)
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Expected: FAIL because service abstraction and registration states are missing.

- [ ] **Step 3: Implement modern service management**

Use:

```swift
enum HelperRegistrationState: Equatable {
    case notRegistered
    case requiresApproval
    case enabled
    case notFound
    case legacyConflict
    case failed(String)
}

let service = SMAppService.daemon(
    plistName: FanControlConstants.launchDaemonPlistName
)
```

Map `SMAppService.Status`, call `register()`/`unregister()`, and expose `SMAppService.openSystemSettingsLoginItems()`. Delete the AppleScript command builder, Process invocation, file-copy checks, and legacy `SMPrivilegedExecutables` dictionary.

- [ ] **Step 4: Change bundle layout and plist**

Copy `FanPrivilegedHelper` to `Contents/Resources`. Copy the plist to `Contents/Library/LaunchDaemons`. Its executable entry must be:

```xml
<key>BundleProgram</key>
<string>Contents/Resources/FanPrivilegedHelper</string>
```

Keep fixed `Label`, `MachServices`, and `KeepAlive`; remove absolute `ProgramArguments` and `RunAtLoad` if redundant with KeepAlive. Add release-script checks for both paths and exact plist values before archive packaging.

- [ ] **Step 5: Run tests, build, and inspect the product**

Run installer tests and build AeroPulse. Then inspect without registering:

```bash
APP=/tmp/AeroPulseDerivedData-fan-control/Build/Products/Debug/AeroPulse.app
test -x "$APP/Contents/Resources/FanPrivilegedHelper"
test -f "$APP/Contents/Library/LaunchDaemons/com.bandan.me.AeroPulse.FanService.plist"
plutil -p "$APP/Contents/Library/LaunchDaemons/com.bandan.me.AeroPulse.FanService.plist"
codesign --verify --deep --strict "$APP"
```

Expected: tests/build/checks PASS; no files are written under `/Library`.

- [ ] **Step 6: Commit**

```bash
git add AeroPulse/Services/PrivilegedHelperInstaller.swift \
  AeroPulseTests/PrivilegedHelperInstallerTests.swift AeroPulse/Info.plist \
  com.bandan.me.AeroPulse.FanService.plist AeroPulse.xcodeproj/project.pbxproj \
  scripts/release_external.sh
git commit -m "feat: register fan helper with SMAppService"
```

### Task 10: Wire control state and lifecycle restoration into the ViewModel

**Files:**
- Create: `AeroPulse/Services/FanLifecycleMonitor.swift`
- Create: `AeroPulseTests/FanViewModelControlTests.swift`
- Modify: `AeroPulse/ViewModels/FanViewModel.swift`
- Modify: `AeroPulse/NetworkSpeedMeterApp.swift`

**Interfaces:**
- Consumes: coordinator, preferences store, helper manager, telemetry snapshots.
- Produces: `FanMonitoring`, ViewModel mode selection, manual RPM, rule editing, helper actions, and lifecycle restoration methods.

- [ ] **Step 1: Write failing ViewModel control and lifecycle tests**

```swift
@MainActor
final class FanViewModelControlTests: XCTestCase {
    func testSampleIsForwardedToCoordinator() async {
        let coordinator = SpyFanControlCoordinator()
        let model = FanViewModel(monitor: FakeFanMonitor(), coordinator: coordinator,
                                 helperManager: FakeHelperManager())
        await model.refreshNow()
        XCTAssertEqual(coordinator.consumedSnapshots.count, 1)
    }

    func testSleepAndTerminationRestoreAll() async {
        let coordinator = SpyFanControlCoordinator()
        let lifecycle = FanLifecycleMonitor()
        _ = FanViewModel(monitor: FakeFanMonitor(), coordinator: coordinator,
                         helperManager: FakeHelperManager(), lifecycle: lifecycle)
        lifecycle.send(.willSleep)
        lifecycle.send(.willTerminate)
        await coordinator.waitForCalls(2)
        XCTAssertEqual(coordinator.restoreAllCallCount, 2)
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Expected: FAIL because dependency injection, lifecycle events, and coordinator forwarding are absent.

- [ ] **Step 3: Refactor `FanViewModel` around snapshots and coordinator**

Mark published UI mutations `@MainActor`. After each monitoring pass, build one `FanTelemetrySnapshot`, update the visible arrays, and call coordinator `consume`. Expose:

```swift
protocol FanMonitoring: AnyObject {
    func getFans() -> [FanInfo]
    func getSensors() -> [SensorInfo]
}

func refreshNow() async
func selectMode(_ mode: FanControlMode, for fan: FanInfo)
func setManualRPM(_ rpm: Int, for fan: FanInfo)
func addRule()
func updateRule(_ rule: FanRule)
func deleteRule(id: UUID)
func registerHelper()
func openHelperApprovalSettings()
```

Use the helper manager's actual state rather than file existence. On wake, require two fresh samples before custom resumes. On will-sleep/will-terminate, send best-effort restore immediately; the helper watchdog remains the backup.

Make `FanMonitor` conform to `FanMonitoring`, inject `any FanMonitoring`, `any FanControlCoordinating`, `any PrivilegedHelperManaging`, and `FanLifecycleMonitor` into the ViewModel, and have timers call the same `refreshNow()` path used by tests. The production initializer supplies the shared concrete dependencies.

- [ ] **Step 4: Run ViewModel, coordinator, and full tests**

Run focused tests, then all AeroPulse tests. Expected: PASS without launching the UI or touching SMC writes.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Services/FanLifecycleMonitor.swift \
  AeroPulse/ViewModels/FanViewModel.swift AeroPulse/NetworkSpeedMeterApp.swift \
  AeroPulseTests/FanViewModelControlTests.swift
git commit -m "feat: connect fan policy to app lifecycle"
```

### Task 11: Add per-fan control UI

**Files:**
- Create: `AeroPulse/Views/FanControlView.swift`
- Modify: `AeroPulse/Views/ThermalDetailView.swift`
- Modify: `AeroPulse/Helpers/AppConstants.swift`

**Interfaces:**
- Consumes: `FanViewModel.fans`, selected modes, operation states, and rule decisions.
- Produces: fan cards with System/Maximum/Manual/Custom selection and bounded manual input.

- [ ] **Step 1: Add failing ViewModel binding assertions**

Extend `FanViewModelControlTests`:

```swift
func testManualRPMIsClampedBeforeCoordinatorCall() async {
    let fan = FanInfo(id: 0, name: "Fan", currentRPM: 1500,
                      minRPM: 1200, maxRPM: 5000, targetRPM: 1500,
                      hardwareMode: .automatic)
    model.setManualRPM(9000, for: fan)
    await coordinator.waitForCalls(1)
    XCTAssertEqual(coordinator.lastManualRPM, 5000)
}
```

Run the test and expect FAIL until the exposed UI action clamps correctly.

- [ ] **Step 2: Implement `FanControlView` and fan cards**

Use a segmented picker bound to `FanControlMode.allCases`. Each card displays actual/target/min/max and hardware mode. For manual mode, bind both controls to the same integer value:

```swift
Slider(value: Binding(
    get: { Double(manualRPM) },
    set: { manualRPM = Int($0.rounded()) }
), in: Double(fan.minRPM)...Double(fan.maxRPM), step: 1)

TextField("RPM", value: $manualRPM, format: .number)
    .onSubmit { fanViewModel.setManualRPM(manualRPM, for: fan) }
```

Disable controls unless helper state is `.enabled`, and disable conflicting actions while `.applying` or `.restoring`. Show custom decision source temperature, percent, and target when available.

- [ ] **Step 3: Embed control UI in thermal detail and build**

Place `FanControlView` above the existing CPU/GPU/System sensor cards. Keep the existing responsive one/two-column sensor layout. Add localized English constants through the existing `AppStrings` style.

Run tests and a Debug build; expect PASS.

- [ ] **Step 4: Open the built app for visual inspection without using controls**

Launch the Debug app only after confirming helper controls are disabled when unregistered. Inspect dashboard resizing, one- and two-fan cards, long error text, and manual field bounds. Do not register the helper or issue writes.

- [ ] **Step 5: Commit**

```bash
git add AeroPulse/Views/FanControlView.swift \
  AeroPulse/Views/ThermalDetailView.swift AeroPulse/Helpers/AppConstants.swift \
  AeroPulseTests/FanViewModelControlTests.swift
git commit -m "feat: add per-fan control interface"
```

### Task 12: Add rule editor, finalize helper UI, docs, and verification

**Files:**
- Create: `AeroPulse/Views/FanRuleEditorView.swift`
- Modify: `AeroPulse/Views/SettingsView.swift`
- Modify: `AeroPulse/Helpers/AppConstants.swift`
- Modify: `README.md`
- Modify: `README_HelperSetup.md`
- Modify: `docs/superpowers/specs/2026-08-27-ifan-style-fan-control-design.md`
- Test: all existing app/helper test files.

**Interfaces:**
- Consumes: ViewModel rules, sensors, fans, and helper state.
- Produces: complete rule editing and accurate registration/approval UI.

- [ ] **Step 1: Add failing rule-editor ViewModel tests**

```swift
@MainActor
func testAddUpdateDeleteRulePersistsValidatedCollection() throws {
    model.addRule()
    var rule = try XCTUnwrap(model.rules.first)
    rule.sensorID = "TC0P"
    rule.fanID = nil
    rule.thresholdCelsius = 72
    rule.speedPercent = 75
    model.updateRule(rule)
    XCTAssertEqual(preferencesStore.saved.rules.first?.speedPercent, 75)
    model.deleteRule(id: rule.id)
    XCTAssertTrue(preferencesStore.saved.rules.isEmpty)
}
```

Run and expect FAIL until editing APIs persist through the validated store.

- [ ] **Step 2: Implement `FanRuleEditorView`**

Each row must have an enable toggle, sensor picker with `Any Sensor`, fan picker with `All Fans`, Celsius threshold field, `0...100` percentage field, match indicator, unavailable-sensor warning, and delete button. Add creates this safe disabled default:

```swift
FanRule(id: UUID(), enabled: false, sensorID: nil, fanID: nil,
        thresholdCelsius: 70, speedPercent: 50)
```

Do not add ordering controls because rule order has no evaluation meaning.

- [ ] **Step 3: Replace helper settings card with real states**

Show distinct copy/actions for not registered, requires approval, enabled, not found, legacy conflict, and failed. `requiresApproval` offers the System Settings button; enabled offers unregister only after warning that controlled fans first restore to System.

- [ ] **Step 4: Update documentation and spec status**

Document the four modes, threshold semantics, helper approval, safe restoration, legacy conflict handling, and the fact that live writes require explicit test authorization. Mark the design status `Implemented` only after every acceptance check below passes.

- [ ] **Step 5: Run complete automated verification**

Run:

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control test
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/AeroPulseDerivedData-fan-control build
```

Then run read-only artifact checks:

```bash
APP=/tmp/AeroPulseDerivedData-fan-control/Build/Products/Release/AeroPulse.app
codesign --verify --deep --strict "$APP"
codesign -dvv "$APP" 2>&1
codesign -dvv "$APP/Contents/Resources/FanPrivilegedHelper" 2>&1
plutil -lint "$APP/Contents/Library/LaunchDaemons/com.bandan.me.AeroPulse.FanService.plist"
otool -L "$APP/Contents/Resources/FanPrivilegedHelper" | rg IOKit
! strings "$APP/Contents/Resources/FanPrivilegedHelper" | \
  rg '/bin/sh|setLaunchPath:|setArguments:'
```

Expected: all tests/builds/signature/plist/dependency checks PASS and forbidden shell strings are absent.

- [ ] **Step 6: Perform an acceptance-criteria source audit**

For each of the 13 criteria in spec section 17, record the exact test, build output, source location, or artifact check that proves it. Mark live-write behavior as `not executed—awaiting explicit authorization`; do not treat it as passed from mocks alone.

- [ ] **Step 7: Commit**

```bash
git add AeroPulse/Views/FanRuleEditorView.swift AeroPulse/Views/SettingsView.swift \
  AeroPulse/Helpers/AppConstants.swift README.md README_HelperSetup.md \
  docs/superpowers/specs/2026-08-27-ifan-style-fan-control-design.md \
  AeroPulseTests FanPrivilegedHelperTests
git commit -m "feat: complete temperature-based fan control"
```

## Execution Notes

- Do not merge tasks to save time; each task is a review and rollback boundary.
- If an Apple API signature differs under the installed SDK, consult the matching SDK interface or official Apple documentation and update the plan's call site without weakening the security requirement.
- If a test requires a real Mach service, replace it with an injected proxy in automated tests. Registration and live SMC writes are separate integration gates.
- The CoreSimulator version warning currently printed by `xcodebuild` is unrelated to the macOS destination; judge commands by their exit status and macOS build/test result.

## Acceptance-Criteria Traceability

1. Complete telemetry: Task 2 decoder/monitor tests and Task 11 fan cards.
2. Four independent modes: Task 5 transition tests and Task 11 segmented controls.
3. Bounded manual input: Task 5 coordinator clamping, Task 6 helper clamping, and Task 11 ViewModel/UI tests.
4. Rule CRUD and persistence: Tasks 3 and 12.
5. Exact rule semantics: Task 4 edge-case suite and Task 5 no-match transitions.
6. Fresh-data safety: Task 4 stale evaluation plus Tasks 5 and 10 two-sample resume/restoration tests.
7. Exit/sleep/XPC/watchdog/restart restoration: Tasks 7, 8, and 10.
8. Narrow helper surface: Tasks 6 and 7 protocol tests plus Task 12 forbidden-string/source audit.
9. Peer rejection: Tasks 7 and 8 requirement tests and signed-product inspection; record an actual wrong-identity connection check only when a development-signed fixture is available.
10. Modern registration: Task 9 unit, plist, bundle, and release-script checks.
11. Zero build/test failures: Task 12 complete Debug test and Release build.
12. Bundle/signature validity: Tasks 9 and 12 artifact checks.
13. No unauthorized live write: the global execution constraint and Task 12 audit; any real-hardware test remains a separately confirmed gate.
