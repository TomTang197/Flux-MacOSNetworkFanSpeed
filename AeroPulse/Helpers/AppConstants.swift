import Foundation

struct AppConfig {
    static let bugFeedbackEmail = "ct197waikato@icloud.com"
}

enum VisualEffectsPreferences {
    static let storageKey = "ReduceVisualEffects"
    static let defaultValue = false
}

enum SMCSensorFilters {
    static let pCoreIdentifier = "P-Core"
    static let eCoreIdentifier = "E-Core"
}


struct AppStrings {
    static var isZh: Bool {
        LanguageManager.shared.effectiveLanguage == .zhHans
    }

    static func tr(en: String, zh: String) -> String {
        isZh ? zh : en
    }

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "AeroPulse"
    }

    static var language: String { tr(en: "Language", zh: "界面语言") }
    static var languageSystem: String { tr(en: "System", zh: "跟随系统") }
    static var languageCurrentSystemPrefix: String { tr(en: "Current system language:", zh: "当前系统语言：") }

    static var systemMonitor: String { tr(en: "System Monitor", zh: "系统监控") }

    static var download: String { tr(en: "Download", zh: "下载") }
    static var upload: String { tr(en: "Upload", zh: "上传") }
    static var diskRead: String { tr(en: "Disk Read", zh: "磁盘读取") }
    static var diskWrite: String { tr(en: "Disk Write", zh: "磁盘写入") }
    static var diskCapacity: String { tr(en: "Disk Capacity", zh: "磁盘空间") }
    static var diskFree: String { tr(en: "Free", zh: "可用") }
    static var diskUsed: String { tr(en: "Used", zh: "已用") }
    static var total: String { tr(en: "Total", zh: "总计") }
    static var cpuUsage: String { tr(en: "CPU Usage", zh: "CPU 使用率") }
    static var powerUsage: String { tr(en: "System Power", zh: "整机功耗") }
    static var systemPowerIn: String { tr(en: "System Power In", zh: "系统输入功耗") }
    static var chargingPower: String { tr(en: "Battery Power", zh: "电池功耗") }
    static var gpuUsage: String { tr(en: "GPU Usage", zh: "GPU 使用率") }
    static var systemGPUUsage: String { tr(en: "System GPU", zh: "系统 GPU") }
    static var systemGPUDescription: String {
        tr(en: "Includes WindowServer and all apps", zh: "包含 WindowServer 与所有应用")
    }
    static var memory: String { tr(en: "Memory", zh: "内存") }
    static var fan: String { tr(en: "Fan", zh: "风扇") }
    static var systemTemp: String { tr(en: "System Temp", zh: "系统温度") }
    static var cpuTemp: String { tr(en: "CPU Temp", zh: "CPU 温度") }
    static var gpuTemp: String { tr(en: "GPU Temp", zh: "GPU 温度") }

    static var rpmUnit: String { tr(en: "RPM", zh: "RPM") }
    static var temperatureFormat: String { tr(en: "%.1f\u{00B0}C", zh: "%.1f\u{00B0}C") }

    static var menuBarMetrics: String { tr(en: "Menu Bar Layout", zh: "菜单栏展示指标") }
    static var launchAtLogin: String { tr(en: "Launch at Login", zh: "开机自启动") }
    static var launchAtLoginDescription: String {
        tr(en: "Start status menu item when you sign in", zh: "登录 macOS 时自动启动菜单栏监控")
    }
    static var launchAtLoginRefresh: String { tr(en: "Refresh", zh: "刷新") }
    static var launchAtLoginErrorPrefix: String { tr(en: "Error:", zh: "错误：") }
    static var refreshRate: String { tr(en: "Sampling Frequency", zh: "采样刷新频率") }
    static var reduceVisualEffects: String { tr(en: "Reduce Visual Effects", zh: "减少视觉效果") }
    static var reduceVisualEffectsDescription: String {
        tr(
            en: "Uses flat backgrounds and removes window/card shadows. Window movement enables this automatically.",
            zh: "采用扁平背景并移除阴影效果以降低 GPU 负担。窗口拖拽时会自动启用。"
        )
    }
    static var privilegedHelper: String { tr(en: "Privileged Helper", zh: "特权辅助程序") }
    static var helperInstalled: String { tr(en: "Helper installed and service registered.", zh: "辅助工具已安装，后台服务正常运行。") }
    static var helperMissing: String { tr(en: "Helper not installed.", zh: "尚未安装特权辅助工具。") }
    static var helperInstalling: String { tr(en: "Requesting administrator permission...", zh: "正在申请管理员权限...") }
    static var helperInstallSuccess: String { tr(en: "Helper installed successfully.", zh: "特权辅助工具安装成功。") }
    static var helperInstallFailedPrefix: String { tr(en: "Helper install failed:", zh: "辅助工具安装失败：") }
    static var helperInstall: String { tr(en: "Install Helper", zh: "安装辅助工具") }
    static var helperReinstall: String { tr(en: "Reinstall", zh: "重新安装") }

    static var hardwareConnection: String { tr(en: "Hardware Bridge", zh: "硬件连接桥") }
    static var hardwareConnected: String { tr(en: "SMC Connected", zh: "SMC 硬件连接正常") }
    static var hardwareDisconnected: String { tr(en: "SMC Disconnected", zh: "SMC 连接中断") }
    static var retryConnection: String { tr(en: "Reconnect Bridge", zh: "重新连接桥接") }
    static var unknownConnectionError: String { tr(en: "Unable to reach SMC service.", zh: "无法连接至 SMC 服务。") }

    static var thermalSensors: String { tr(en: "Thermal Sensors", zh: "热力传感器") }
    static var thermalSensorsUpperCase: String { tr(en: "THERMAL SENSORS", zh: "热力传感器") }
    static var sensorsDetected: String { tr(en: "sensors detected", zh: "个传感器已就绪") }
    static var viewThermalDetails: String { tr(en: "View thermal details", zh: "查看传感器详情") }
    static var cpu: String { "CPU" }
    static var gpu: String { "GPU" }
    static var system: String { tr(en: "System", zh: "系统") }
    static var pCoreFilterDisplay: String { tr(en: "P-Cores", zh: "性能核 (P-Core)") }
    static var eCoreFilterDisplay: String { tr(en: "E-Cores", zh: "能效核 (E-Core)") }
    static var pCoreFilter: String { "P-Core" }
    static var eCoreFilter: String { "E-Core" }

    static var noData: String { tr(en: "No data available", zh: "暂无数据") }
    static var openSystemHub: String { tr(en: "Open Dashboard", zh: "打开控制台") }
    static var quitApplication: String { tr(en: "Quit AeroPulse", zh: "退出 AeroPulse") }
    static var bugFeedback: String { tr(en: "Bug Feedback", zh: "问题与建议反馈") }
    static var bugFeedbackDescription: String { tr(en: "Report issues or suggestions", zh: "提交遇到的人工问题或功能建议") }
    static var bugFeedbackOpen: String { tr(en: "Open Feedback Form", zh: "填写反馈") }
    static var bugFeedbackEmailLabel: String { tr(en: "Recipient", zh: "接收邮箱") }
    static var bugFeedbackTitle: String { tr(en: "Title", zh: "标题") }
    static var bugFeedbackTitlePlaceholder: String { tr(en: "Short summary", zh: "简短描述遇到的问题") }
    static var bugFeedbackDetails: String { tr(en: "Details", zh: "详细信息") }
    static var bugFeedbackDetailsPlaceholder: String {
        tr(en: "What happened? How can we reproduce it? What did you expect?", zh: "发生了什么？如何复现？你期望的现象是什么？")
    }
    static var bugFeedbackContact: String { tr(en: "Contact (optional)", zh: "联系方式（选填）") }
    static var bugFeedbackContactPlaceholder: String { tr(en: "Email / Telegram / WeChat", zh: "邮箱 / 微信 / 其他联系方式") }
    static var bugFeedbackCancel: String { tr(en: "Cancel", zh: "取消") }
    static var bugFeedbackSend: String { tr(en: "Send by Mail", zh: "发送邮件") }
    static var bugFeedbackOpenMailFailed: String { tr(en: "Unable to open Mail app.", zh: "无法调起系统邮件应用。") }

    static var gameModeLinkage: String { tr(en: "Game Mode Linkage", zh: "游戏模式联动") }
    static var gameModeLinkageDescription: String {
        tr(
            en: "Auto-switch to Rules mode in Game Mode; revert to Auto after exit delay",
            zh: "进入游戏模式自动切换为温控规则；退出后延迟恢复自动模式"
        )
    }
    static var gameModeExitDelay: String { tr(en: "Exit Delay", zh: "退出恢复延迟") }
    static var gameModeActiveStatus: String { tr(en: "Game Mode Active · Rules mode", zh: "游戏模式生效中 · 温控规则模式") }
    static var gameModeCooldownStatusPrefix: String { tr(en: "Game Mode Exited · Reverting to Auto in", zh: "游戏模式已退出 · 将在") }
    static var gameModeIdleStatus: String { tr(en: "No active game detected", zh: "未检测到运行中的游戏") }
    static var fanControl: String { tr(en: "Fan Control", zh: "风扇控制") }
    static var fanControlUpper: String { tr(en: "FAN CONTROL", zh: "风扇控制") }

    static var settings: String { tr(en: "Settings", zh: "设置") }
    static var settingsHelp: String { tr(en: "App preferences and hardware setup", zh: "偏好设置与硬件配置") }
    static var done: String { tr(en: "Done", zh: "完成") }
    static var closeThermalDetails: String { tr(en: "Close thermal details", zh: "关闭传感器详情") }

    static var systemOverview: String { tr(en: "System overview", zh: "系统概览") }
    static var network: String { tr(en: "Network", zh: "网络") }
    static var disk: String { tr(en: "Disk", zh: "磁盘") }
    static var read: String { tr(en: "Read", zh: "读取") }
    static var write: String { tr(en: "Write", zh: "写入") }
    static var systemLoad: String { tr(en: "System load", zh: "系统负载") }
    static var power: String { tr(en: "Power", zh: "功耗") }
    static var battery: String { tr(en: "Battery", zh: "电池") }

    static var fanMode: String { tr(en: "Fan Mode", zh: "风扇模式") }
    static var fanModeUpper: String { tr(en: "FAN MODE", zh: "风扇模式") }
    static var syncAllFans: String { tr(en: "Sync All Fans", zh: "同步所有风扇") }
    static var temperatureRules: String { tr(en: "Temperature rules", zh: "温控规则") }
    static var temperatureRulesUpper: String { tr(en: "TEMPERATURE THRESHOLD RULES", zh: "温控阈值规则") }
    static var delayDownshift: String { tr(en: "Delay Downshift", zh: "降速平滑延迟") }
    static var rulesActiveHardwareMin: String { tr(en: "Rules Active · Hardware minimum speed", zh: "规则生效中 · 硬件最低转速") }
    static var addThreshold: String { tr(en: "Add Threshold", zh: "添加阈值") }
    static var resetDefaults: String { tr(en: "Reset Defaults", zh: "恢复默认") }
    static var saveRule: String { tr(en: "Save Rule", zh: "保存规则") }
    static var cancel: String { tr(en: "Cancel", zh: "取消") }
    static var active: String { tr(en: "ACTIVE", zh: "生效") }
    static var speed: String { tr(en: "Speed", zh: "转速") }
    static var trigger: String { tr(en: "Trigger", zh: "触发") }
    static var min: String { tr(en: "MIN", zh: "最小") }
    static var max: String { tr(en: "MAX", zh: "最大") }
    static var target: String { tr(en: "TARGET", zh: "目标") }
    static var autoRulesInGameMode: String { tr(en: "Auto Rules in Game Mode", zh: "游戏模式下自动启用规则") }
    static var all: String { tr(en: "All", zh: "全部") }

    static var softwareUpdate: String { tr(en: "Software Update", zh: "软件更新") }
    static var checkForUpdates: String { tr(en: "Check for Updates…", zh: "检查更新…") }
    static var autoCheckForUpdates: String { tr(en: "Automatically check for updates", zh: "自动检查更新") }
    static var currentVersionPrefix: String { tr(en: "Current Version: ", zh: "当前版本：") }
}

struct AppImages {
    static let rocket = "rocket.fill"
    static let download = "arrow.down.circle.fill"
    static let upload = "arrow.up.circle.fill"
    static let diskRead = "internaldrive"
    static let diskWrite = "internaldrive.fill"
    static let diskCapacity = "chart.pie.fill"
    static let cpuUsage = "cpu"
    static let powerUsage = "bolt.fill"
    static let chargingPower = "battery.100.bolt"
    static let gpuUsage = "circle.grid.2x2"
    static let memory = "memorychip.fill"
    static let fan = "fanblades.fill"
    static let temperature = "thermometer.medium"
    static let gauge = "gauge.with.needle"
    static let checklist = "checklist"
    static let launchAtLogin = "person.badge.key.fill"
    static let helper = "lock.shield.fill"
    static let refresh = "arrow.clockwise"
    static let visualEffects = "sparkles"
    static let cpu = "cpu"
    static let power = "power.circle.fill"
    static let window = "macwindow"
    static let info = "info.circle.fill"
    static let close = "xmark.circle.fill"
    static let bug = "exclamationmark.bubble.fill"
    static let gameController = "gamecontroller.fill"
}
