# Language Selection and Chinese Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic in-app language selection (System, English, Simplified Chinese) with complete Chinese localization across all UI surfaces without app restarts.

**Architecture:** Introduce `LanguageManager` observable singleton persisting to UserDefaults and detecting macOS system language. Decouple SMC sensor filtering keys from user-facing text, turn `AppStrings` into a dynamic translation dictionary driven by `LanguageManager`, add `LanguageSettingsCard` in settings, and observe `LanguageManager` across top-level views.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Combine, XCTest

---

### Task 1: Decouple SMC Sensor Match Tokens from User-Facing Text

**Files:**
- Modify: `AeroPulse/Helpers/AppConstants.swift:70-80`
- Modify: `AeroPulse/Services/FanMonitor.swift:435-452`

- [ ] **Step 1: Inspect FanMonitor's dependency on AppStrings for core sensor matching**

Check `AeroPulse/Services/FanMonitor.swift`:
```swift
sensor.name.contains(AppStrings.pCoreFilter)
sensor.name.contains(AppStrings.eCoreFilter)
```
These filter checks require the exact hardware substrings `"P-Core"` and `"E-Core"`.

- [ ] **Step 2: Add `SMCSensorFilters` constants in `AppConstants.swift`**

Add dedicated constant tokens to `AeroPulse/Helpers/AppConstants.swift`:
```swift
enum SMCSensorFilters {
    static let pCoreIdentifier = "P-Core"
    static let eCoreIdentifier = "E-Core"
}
```

- [ ] **Step 3: Update `FanMonitor.swift` to use `SMCSensorFilters`**

Replace `AppStrings.pCoreFilter` and `AppStrings.eCoreFilter` in `AeroPulse/Services/FanMonitor.swift` with `SMCSensorFilters.pCoreIdentifier` and `SMCSensorFilters.eCoreIdentifier`.

- [ ] **Step 4: Run unit tests to verify sensor grouping tests still pass**

Run: `swift test`
Expected: All 80 tests pass with 0 failures.

- [ ] **Step 5: Commit changes**

```bash
git add AeroPulse/Helpers/AppConstants.swift AeroPulse/Services/FanMonitor.swift
git commit -m "refactor: isolate SMC sensor matching filters from user-facing strings"
```

---

### Task 2: Implement `AppLanguage` and `LanguageManager` with Unit Tests

**Files:**
- Create: `AeroPulse/Models/AppLanguage.swift`
- Create: `AeroPulse/Services/LanguageManager.swift`
- Create: `Tests/AeroPulseSafetyTests/LanguageManagerTests.swift`
- Modify: `Package.swift:8-27`

- [ ] **Step 1: Write failing tests for `LanguageManager`**

Create `Tests/AeroPulseSafetyTests/LanguageManagerTests.swift`:
```swift
import XCTest
@testable import AeroPulsePerformanceCore

final class LanguageManagerTests: XCTestCase {
    func testLanguageResolutionForEnglishAndChinese() {
        let defaults = UserDefaults(suiteName: "test.language.resolution")!
        defaults.removePersistentDomain(forName: "test.language.resolution")
        
        let manager = LanguageManager(userDefaults: defaults, preferredLanguagesProvider: { ["zh-Hans-CN", "en-US"] })
        XCTAssertEqual(manager.selectedLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
        
        manager.setLanguage(.en)
        XCTAssertEqual(manager.selectedLanguage, .en)
        XCTAssertEqual(manager.effectiveLanguage, .en)
        
        manager.setLanguage(.zhHans)
        XCTAssertEqual(manager.selectedLanguage, .zhHans)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
    }

    func testSystemLanguageFallbackToEnglishWhenNotChinese() {
        let defaults = UserDefaults(suiteName: "test.language.fallback")!
        defaults.removePersistentDomain(forName: "test.language.fallback")
        
        let manager = LanguageManager(userDefaults: defaults, preferredLanguagesProvider: { ["ja-JP", "en"] })
        XCTAssertEqual(manager.effectiveLanguage, .en)
    }
}
```

- [ ] **Step 2: Update `Package.swift` to include `LanguageManager` in the testable target if needed**

Make sure `LanguageManager` and `AppLanguage` are accessible to `AeroPulseSafetyTests` (placed in `AeroPulse/Performance` or include target source file).

- [ ] **Step 3: Implement `AppLanguage.swift`**

Create `AeroPulse/Models/AppLanguage.swift`:
```swift
import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return LanguageManager.shared.effectiveLanguage == .zhHans ? "跟随系统" : "System"
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        }
    }
}
```

- [ ] **Step 4: Implement `LanguageManager.swift`**

Create `AeroPulse/Services/LanguageManager.swift`:
```swift
import Foundation
import Combine

public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()
    
    public static let userDefaultsKey = "AppLanguagePreference"
    
    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var selectedLanguage: AppLanguage
    @Published public private(set) var effectiveLanguage: AppLanguage

    public init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider
        
        let savedRaw = userDefaults.string(forKey: Self.userDefaultsKey) ?? AppLanguage.system.rawValue
        let initialSelection = AppLanguage(rawValue: savedRaw) ?? .system
        self.selectedLanguage = initialSelection
        self.effectiveLanguage = Self.computeEffectiveLanguage(
            selection: initialSelection,
            preferredLanguages: preferredLanguagesProvider()
        )

        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshEffectiveLanguage()
            }
            .store(in: &cancellables)
    }

    public func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        userDefaults.set(language.rawValue, forKey: Self.userDefaultsKey)
        refreshEffectiveLanguage()
    }

    private func refreshEffectiveLanguage() {
        let newEffective = Self.computeEffectiveLanguage(
            selection: selectedLanguage,
            preferredLanguages: preferredLanguagesProvider()
        )
        if effectiveLanguage != newEffective {
            effectiveLanguage = newEffective
        }
        objectWillChange.send()
    }

    private static func computeEffectiveLanguage(
        selection: AppLanguage,
        preferredLanguages: [String]
    ) -> AppLanguage {
        switch selection {
        case .en:
            return .en
        case .zhHans:
            return .zhHans
        case .system:
            let primary = preferredLanguages.first ?? "en"
            if primary.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run: `swift test`
Expected: All tests pass including `LanguageManagerTests`.

- [ ] **Step 6: Commit changes**

```bash
git add AeroPulse/Models/AppLanguage.swift AeroPulse/Services/LanguageManager.swift Tests/AeroPulseSafetyTests/LanguageManagerTests.swift Package.swift
git commit -m "feat: add AppLanguage and LanguageManager with dynamic system fallback"
```

---

### Task 3: Comprehensive Dynamic Dictionary in `AppStrings`, `FanMode`, and `MetricType`

**Files:**
- Modify: `AeroPulse/Helpers/AppConstants.swift`
- Modify: `AeroPulse/Models/FanStats.swift`
- Modify: `AeroPulse/Models/MetricType.swift`

- [ ] **Step 1: Update `FanMode` with `localizedTitle`**

In `AeroPulse/Models/FanStats.swift`:
Add computed property `localizedTitle`:
```swift
var localizedTitle: String {
    let isZh = LanguageManager.shared.effectiveLanguage == .zhHans
    switch self {
    case .auto: return isZh ? "自动" : "Auto"
    case .fullBlast: return isZh ? "全速" : "Max"
    case .manual: return isZh ? "手动" : "Manual"
    case .custom: return isZh ? "温控规则" : "Rules"
    }
}
```

- [ ] **Step 2: Update `MetricType` with `localizedTitle`**

In `AeroPulse/Models/MetricType.swift`:
Add computed property `localizedTitle`:
```swift
var localizedTitle: String {
    let isZh = LanguageManager.shared.effectiveLanguage == .zhHans
    switch self {
    case .download: return isZh ? "下载" : "Download"
    case .upload: return isZh ? "上传" : "Upload"
    case .diskRead: return isZh ? "磁盘读" : "Disk Read"
    case .diskWrite: return isZh ? "磁盘写" : "Disk Write"
    case .cpu: return "CPU"
    case .power: return isZh ? "整机功耗" : "Power"
    case .chargingPower: return isZh ? "电池功耗" : "Charge"
    case .gpu: return "GPU"
    case .memory: return isZh ? "内存" : "Memory"
    case .temperature: return isZh ? "温度" : "Temp"
    case .fan: return isZh ? "风扇" : "Fan"
    }
}
```

- [ ] **Step 3: Update `AppStrings` in `AppConstants.swift` with dynamic `tr(en:zh:)`**

Transform all static properties into dynamic properties reading from `LanguageManager.shared.effectiveLanguage == .zhHans`:
- Add `language`, `languageSystem`, `languageCurrentSystemPrefix`, `languageDescription`
- Localize all telemetry labels, fan modes, rules, game mode linkage, bug feedback, hardware connection, and helper messages matching the design spec table.

- [ ] **Step 4: Verify build with `xcodebuild` and `swift test`**

Run: `swift test && xcodebuild -scheme AeroPulse -configuration Debug -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED=NO`
Expected: Build and tests succeed.

- [ ] **Step 5: Commit changes**

```bash
git add AeroPulse/Helpers/AppConstants.swift AeroPulse/Models/FanStats.swift AeroPulse/Models/MetricType.swift
git commit -m "feat: implement localized strings and display titles for FanMode and MetricType"
```

---

### Task 4: Create `LanguageSettingsCard` and Integrate into `SettingsView`

**Files:**
- Modify: `AeroPulse/Views/SettingsLiveComponents.swift`
- Modify: `AeroPulse/Views/SettingsView.swift`

- [ ] **Step 1: Implement `LanguageSettingsCard` in `SettingsLiveComponents.swift`**

```swift
struct LanguageSettingsCard: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        SettingsCard(
            title: AppStrings.language,
            symbol: "globe",
            tint: .indigo
        ) {
            Picker(AppStrings.language, selection: Binding(
                get: { languageManager.selectedLanguage },
                set: { languageManager.setLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if languageManager.selectedLanguage == .system {
                HStack(spacing: 4) {
                    Text(AppStrings.languageCurrentSystemPrefix)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                    Text(languageManager.effectiveLanguage == .zhHans ? "简体中文" : "English")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }
}
```

- [ ] **Step 2: Embed `LanguageSettingsCard` into `SettingsView.swift`**

In `SettingsView.swift`:
- Add `@ObservedObject private var languageManager = LanguageManager.shared`.
- Add `LanguageSettingsCard()` right after `MenuBarMetricsSettingsCard` (or right after `LaunchAtLoginSettingsCard`).

- [ ] **Step 3: Update `MenuBarMetricsSettingsCard` in `SettingsLiveComponents.swift`**

Update metric chip label to use `metric.localizedTitle` instead of `metric.rawValue`:
```swift
Text(metric.localizedTitle)
    .font(.system(size: 11, weight: .semibold))
```

- [ ] **Step 4: Verify build with `xcodebuild`**

Run: `xcodebuild -scheme AeroPulse -configuration Debug -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED=NO`
Expected: Build succeeds.

- [ ] **Step 5: Commit changes**

```bash
git add AeroPulse/Views/SettingsLiveComponents.swift AeroPulse/Views/SettingsView.swift
git commit -m "feat: add LanguageSettingsCard and update metric chips in Settings"
```

---

### Task 5: Integrate Dynamic Localization Across Main Views

**Files:**
- Modify: `AeroPulse/Views/ContentView.swift`
- Modify: `AeroPulse/Views/MenuBarDashboardView.swift`
- Modify: `AeroPulse/Views/FanControlCard.swift`
- Modify: `AeroPulse/Views/DashboardOverviewView.swift`
- Modify: `AeroPulse/Views/ThermalDetailView.swift`

- [ ] **Step 1: Update `FanControlCard.swift`**

- Add `@ObservedObject private var languageManager = LanguageManager.shared`.
- Update fan mode picker text:
  ```swift
  ForEach(FanMode.allCases) { mode in
      Text(mode.localizedTitle).tag(mode)
  }
  ```
- Replace any hardcoded "Fan control" / "FAN CONTROL", "Mode", "Rules", "Speed" with `AppStrings`.

- [ ] **Step 2: Update `MenuBarDashboardView.swift` and `ContentView.swift`**

- Add `@ObservedObject private var languageManager = LanguageManager.shared` so that view re-evaluates automatically on language change.
- Verify all section headers and buttons use `AppStrings`.

- [ ] **Step 3: Update `DashboardOverviewView.swift` & `ThermalDetailView.swift`**

- Localize tab filters: "All", "P-Core", "E-Core", "GPU", "System".
- Localize card descriptions and summary headers.

- [ ] **Step 4: Build and test**

Run: `swift test && xcodebuild -scheme AeroPulse -configuration Debug -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED=NO`
Expected: All tests pass, build succeeds.

- [ ] **Step 5: Commit changes**

```bash
git add AeroPulse/Views/ContentView.swift AeroPulse/Views/MenuBarDashboardView.swift AeroPulse/Views/FanControlCard.swift AeroPulse/Views/DashboardOverviewView.swift AeroPulse/Views/ThermalDetailView.swift
git commit -m "feat: connect LanguageManager reactivity across all dashboard and fan views"
```

---

### Task 6: End-to-End Verification & Walkthrough

**Files:**
- Test files and application run

- [ ] **Step 1: Execute all unit tests**

Run: `swift test`
Verify that all tests pass without errors.

- [ ] **Step 2: Launch application for visual and interactive sanity check**

Launch application binary or test run to verify that switching from English to 简体中文 updates:
- Settings cards
- Fan mode buttons
- Menu bar telemetry cards
- Dashboard cards
- Tooltips and feedback modal

- [ ] **Step 3: Verify system fallback logic**

Verify that selecting "跟随系统" dynamically adapts to macOS system locale.

- [ ] **Step 4: Final commit and cleanup**

Commit any final polish and prepare completion summary.
