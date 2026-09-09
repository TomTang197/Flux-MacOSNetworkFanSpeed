# AeroPulse 语言选择与中文本地化设计规范 (Design Spec)

- **创建日期**: 2026-09-10
- **状态**: 已确认 (Approved)
- **目标版本**: AeroPulse v1.2+

---

## 1. 背景与目标 (Background & Goals)

### 1.1 背景
AeroPulse 是一款专注于 macOS 系统的轻量级网络、硬件传感器监控与智能风扇控制工具。目前应用内界面文本均为硬编码英文，中文用户在配置风扇温控规则、理解系统功耗和使用菜单栏指标时存在语言门槛。

### 1.2 目标
1. **多语言支持**：全面支持「简体中文 (Simplified Chinese)」与「英文 (English)」。
2. **应用内即时切换**：在设置面板提供语言选择控件，支持「跟随系统 (System Default)」、「English」与「简体中文」。切换后全局视图秒级响应刷新，无需重启应用。
3. **硬件隔离与向后兼容**：
   - 保证底层硬件传感器匹配逻辑（如 `FanMonitor` 中涉及的 `"P-Core"`, `"E-Core"` 等匹配特征）与展示层文本彻底解耦。
   - 保持所有持久化键值（`MetricType`、`FanMode` 等 UserDefaults 原始值）不变，避免破坏现有用户配置。
4. **高质量翻译**：涵盖菜单栏下拉视图、主控制台窗口、风扇模式与温控规则、游戏模式联动、特权辅助工具安装、硬件 SMC 状态、问题反馈等全部界面。

### 1.3 非目标 (Non-Goals)
- 暂时不引入外部多语言打包服务或云端下发文案。
- 传感器底层硬件名称（如来自 Apple SMC 的原始键 `"Tp09"` 或原始传感器标识 `"PMU tdev1"`）保持硬件原生输出，不作机械翻译；仅对传感器分类（CPU、GPU、系统、性能核、能效核）进行本地化展示。

---

## 2. 系统架构设计 (Architecture)

### 2.1 语言类型模型 (`AppLanguage`)
在 `AeroPulse/Models/AppLanguage.swift` 中定义：
```swift
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return AppStrings.languageSystem
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }
}
```

### 2.2 语言管理单例 (`LanguageManager`)
在 `AeroPulse/Services/LanguageManager.swift` 中实现：
- 采用 `@MainActor final class LanguageManager: ObservableObject`。
- `@Published var selectedLanguage: AppLanguage`：从 `UserDefaults` 读取（Key: `"AppLanguagePreference"`，默认 `.system`）。
- 计算属性 `effectiveLanguage: AppLanguage`：
  - 当 `selectedLanguage != .system` 时直接返回该语言；
  - 当 `selectedLanguage == .system` 时，检查 `Locale.preferredLanguages.first`：若以 `"zh"` 开头则返回 `.zhHans`，否则返回 `.en`。
- 监听 `NSLocale.currentLocaleDidChangeNotification`，在系统语言变更时自适应更新并触发重绘。
- 提供 `setLanguage(_ language: AppLanguage)` 方法，写入 `UserDefaults` 并触发 `objectWillChange.send()`。

### 2.3 动态多语言文案体系 (`AppStrings`)
重构 `AeroPulse/Helpers/AppConstants.swift` 中的 `AppStrings`：
- 内部实现静态辅助函数：
  ```swift
  private static func tr(en: String, zh: String) -> String {
      LanguageManager.shared.effectiveLanguage == .zhHans ? zh : en
  }
  ```
- 将 `AppStrings` 中的各属性调整为动态计算属性，根据当前有效语言返回对应文本。
- 将硬件匹配专用标识符（如 `pCoreMatchFilter = "P-Core"`, `eCoreMatchFilter = "E-Core"`）独立于用户文案，禁止将匹配逻辑依赖于翻译后的文字。

### 2.4 枚举展示本地化 (`MetricType` & `FanMode`)
保持 `MetricType` 与 `FanMode` 的 `rawValue`（用于 Codable 与 UserDefaults 存储）不变，新增 `localizedTitle` 计算属性：
- `FanMode.auto.localizedTitle` -> `"自动"` / `"Auto"`
- `FanMode.fullBlast.localizedTitle` -> `"全速"` / `"Max"`
- `FanMode.manual.localizedTitle` -> `"手动"` / `"Manual"`
- `FanMode.custom.localizedTitle` -> `"温控规则"` / `"Rules"`
- `MetricType` 中各指标（如 `download`, `upload`, `cpu`, `gpu`, `memory` 等）的 `localizedTitle` 映射为对应中文。

---

## 3. UI 界面与交互设计 (UI & Interactions)

### 3.1 语言设置卡片 (`LanguageSettingsCard`)
在 `AeroPulse/Views/SettingsLiveComponents.swift` 中新增 `LanguageSettingsCard`：
- **外观**：标准 `SettingsCard(title: AppStrings.language, symbol: "globe", tint: .indigo)`。
- **控件**：分段选择器（Segmented Picker）：
  - 选项：`跟随系统` | `English` | `简体中文`
- **动态状态说明**：当选定「跟随系统」时，显示次级提示文本（例如：`当前系统语言：简体中文` 或 `System language: English`）。
- **位置**：嵌入在 `SettingsView.swift` 的设置卡片列表中（紧随菜单栏布局或开机自启动卡片）。

### 3.2 响应式视图绑定
在主要容器视图中监听 `LanguageManager`：
- `ContentView.swift`
- `MenuBarDashboardView.swift`
- `SettingsView.swift`
- `FanControlCard.swift`
通过 `@ObservedObject private var languageManager = LanguageManager.shared`，确保用户点击切换的同一时间，所有可见卡片、按钮、弹窗的文本即时刷新。

---

## 4. 全量中英双语对照清单 (Localization Mapping)

| 键名 / 功能区 | 英文 (en) | 简体中文 (zh-Hans) |
|---|---|---|
| **常规与导航** | | |
| `language` | Language | 界面语言 |
| `languageSystem` | System | 跟随系统 |
| `languageCurrentSystemPrefix` | Current system language: | 当前系统语言： |
| `systemMonitor` | System Monitor | 系统监控 |
| `openSystemHub` | Open Dashboard | 打开控制台 |
| `quitApplication` | Quit AeroPulse | 退出 AeroPulse |
| `noData` | No data available | 暂无数据 |
| **遥测与指标** | | |
| `download` | Download | 下载 |
| `upload` | Upload | 上传 |
| `diskRead` | Disk Read | 磁盘读取 |
| `diskWrite` | Disk Write | 磁盘写入 |
| `diskCapacity` | Disk Capacity | 磁盘空间 |
| `diskFree` | Free | 可用 |
| `diskUsed` | Used | 已用 |
| `total` | Total | 总计 |
| `cpuUsage` | CPU Usage | CPU 使用率 |
| `powerUsage` | System Power | 整机功耗 |
| `systemPowerIn` | System Power In | 系统输入功耗 |
| `chargingPower` | Battery Power | 电池功耗 |
| `gpuUsage` | GPU Usage | GPU 使用率 |
| `systemGPUUsage` | System GPU | 系统 GPU |
| `systemGPUDescription` | Includes WindowServer and all apps | 包含 WindowServer 与所有应用 |
| `memory` | Memory | 内存 |
| `fan` | Fan | 风扇 |
| `systemTemp` | System Temp | 系统温度 |
| `cpuTemp` | CPU Temp | CPU 温度 |
| `gpuTemp` | GPU Temp | GPU 温度 |
| **风扇控制与模式** | | |
| `fanControl` | Fan Control | 风扇控制 |
| `fanControlUpper` | FAN CONTROL | 风扇控制 |
| `fanModeAuto` | Auto | 自动 |
| `fanModeMax` | Max | 全速 |
| `fanModeManual` | Manual | 手动 |
| `fanModeRules` | Rules | 温控规则 |
| `targetSpeed` | Target Speed | 目标转速 |
| `currentSpeed` | Current Speed | 当前转速 |
| `fanMinMaxFormat` | Min: %d RPM · Max: %d RPM | 最小: %d RPM · 最大: %d RPM |
| `fanRulesTitle` | Temperature Threshold Rules | 温度阈值规则 |
| `fanRulesAdd` | Add Rule | 添加规则 |
| `fanRulesSave` | Save Rules | 保存规则 |
| `fanRuleTriggerAbove` | Trigger at ≥ %.0f°C → %d%% fan speed | 当温度 ≥ %.0f°C 时 → 转速 %d%% |
| **游戏模式联动** | | |
| `gameModeLinkage` | Game Mode Linkage | 游戏模式联动 |
| `gameModeLinkageDescription` | Auto-switch to Rules mode in Game Mode; revert to Auto after exit delay | 进入游戏模式自动切换为温控规则；退出后延迟恢复自动模式 |
| `gameModeExitDelay` | Exit Delay | 退出恢复延迟 |
| `gameModeActiveStatus` | Game Mode Active · Rules mode | 游戏模式生效中 · 温控规则模式 |
| `gameModeCooldownStatusPrefix` | Game Mode Exited · Reverting to Auto in | 游戏模式已退出 · 将在 |
| `gameModeIdleStatus` | No active game detected | 未检测到运行中的游戏 |
| **特权辅助程序 (Helper)** | | |
| `privilegedHelper` | Privileged Helper | 特权辅助程序 |
| `helperInstalled` | Helper installed and service registered. | 辅助工具已安装，后台服务正常运行。 |
| `helperMissing` | Helper not installed. | 尚未安装特权辅助工具。 |
| `helperInstalling` | Requesting administrator permission... | 正在申请管理员权限... |
| `helperInstallSuccess` | Helper installed successfully. | 特权辅助工具安装成功。 |
| `helperInstallFailedPrefix` | Helper install failed: | 辅助工具安装失败： |
| `helperInstall` | Install Helper | 安装辅助工具 |
| `helperReinstall` | Reinstall | 重新安装 |
| **硬件桥接 (Hardware Bridge)** | | |
| `hardwareConnection` | Hardware Bridge | 硬件连接桥 |
| `hardwareConnected` | SMC Connected | SMC 硬件连接正常 |
| `hardwareDisconnected` | SMC Disconnected | SMC 连接中断 |
| `retryConnection` | Reconnect Bridge | 重新连接桥接 |
| `unknownConnectionError` | Unable to reach SMC service. | 无法连接至 SMC 服务。 |
| **热力传感器详情 (Thermal Detail)** | | |
| `thermalSensors` | Thermal Sensors | 热力传感器 |
| `thermalSensorsUpperCase` | THERMAL SENSORS | 热力传感器 |
| `sensorsDetected` | sensors detected | 个传感器已就绪 |
| `viewThermalDetails` | View thermal details | 查看传感器详情 |
| `pCoreFilterDisplay` | P-Cores | 性能核 (P-Core) |
| `eCoreFilterDisplay` | E-Cores | 能效核 (E-Core) |
| **设置偏好 (Settings Preferences)** | | |
| `menuBarMetrics` | Menu Bar Layout | 菜单栏展示指标 |
| `launchAtLogin` | Launch at Login | 开机自启动 |
| `launchAtLoginDescription` | Start status menu item when you sign in | 登录 macOS 时自动启动菜单栏监控 |
| `refreshRate` | Sampling Frequency | 采样刷新频率 |
| `reduceVisualEffects` | Reduce Visual Effects | 减少视觉效果 (Flat 模式) |
| `reduceVisualEffectsDescription` | Uses flat backgrounds and removes window/card shadows. Window movement enables this automatically. | 采用扁平背景并移除阴影效果以降低 GPU 负担。窗口拖拽时会自动启用。 |
| **反馈表单 (Bug Feedback)** | | |
| `bugFeedback` | Bug Feedback | 问题与建议反馈 |
| `bugFeedbackDescription` | Report issues or suggestions | 提交遇到的人工问题或功能建议 |
| `bugFeedbackOpen` | Open Feedback Form | 填写反馈 |
| `bugFeedbackEmailLabel` | Recipient | 接收邮箱 |
| `bugFeedbackTitle` | Title | 标题 |
| `bugFeedbackTitlePlaceholder` | Short summary | 简短描述遇到的问题 |
| `bugFeedbackDetails` | Details | 详细信息 |
| `bugFeedbackDetailsPlaceholder` | What happened? How can we reproduce it? What did you expect? | 发生了什么？如何复现？你期望的现象是什么？ |
| `bugFeedbackContact` | Contact (optional) | 联系方式（选填） |
| `bugFeedbackContactPlaceholder` | Email / Telegram / WeChat | 邮箱 / 微信 / 其他联系方式 |
| `bugFeedbackCancel` | Cancel | 取消 |
| `bugFeedbackSend` | Send by Mail | 发送邮件 |
| `bugFeedbackOpenMailFailed` | Unable to open Mail app. | 无法调起系统邮件应用。 |

---

## 5. 测试与验证计划 (Testing & Verification)

### 5.1 自动化测试
1. **`LanguageManagerTests`**（新增于 `Tests/AeroPulseSafetyTests` 或独立测试模块）：
   - 验证默认 `.system` 状态下能根据系统 preferredLanguage 解析出对应 `.zhHans` 或 `.en`；
   - 验证手动切换至 `.en` 与 `.zhHans` 时，`effectiveLanguage` 立即更新并能持久化存取；
   - 验证中英文动态字典映射在切换时返回预期的翻译文本。
2. **回归测试**：
   - 执行 `swift test`，保证现有全部 80 项单元测试（风扇安全限制、温度新鲜度、传感器分组、M4 传感器规整等）100% 绿色通过。

### 5.2 手动功能与界面验证
1. 打开菜单栏设置卡片，查看新增的「界面语言 / Language」设置卡片。
2. 依次点击「English」与「简体中文」，观察：
   - 菜单栏监控面板所有指标与说明是否即时中英切换；
   - 主控制台（Dashboard）所有卡片、图表指标是否即时中英切换；
   - 风扇控制卡片中的模式切换器（自动 / 全速 / 手动 / 温控规则）是否正确显示；
   - 游戏模式联动状态与描述是否正常翻译；
   - 悬停气泡提示（`.help`）是否同步刷新。
3. 选择「跟随系统」，验证当前系统为中文或英文时显示正确的系统语言。
