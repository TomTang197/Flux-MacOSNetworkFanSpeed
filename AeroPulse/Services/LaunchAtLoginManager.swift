//
//  LaunchAtLoginManager.swift
//  AeroPulse
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var statusText: String = "Not configured"
    @Published private(set) var statusIsWarning: Bool = false
    @Published private(set) var lastError: String?

    var localizedStatusText: String {
        switch statusText {
        case "Enabled":
            return AppStrings.tr(en: "Enabled", zh: "已启用")
        case "Disabled":
            return AppStrings.tr(en: "Disabled", zh: "已关闭")
        case "Waiting for approval in System Settings":
            return AppStrings.tr(en: "Waiting for approval in System Settings", zh: "等待在系统设置中批准")
        case "App service not found":
            return AppStrings.tr(en: "App service not found", zh: "未找到应用服务")
        case "Not configured":
            return AppStrings.tr(en: "Not configured", zh: "尚未配置")
        default:
            return AppStrings.tr(en: "Unknown status", zh: "未知状态")
        }
    }

    init() {
        // Querying SMAppService status on every app launch can trigger noisy
        // system permission logs on newer macOS builds. We only refresh on demand.
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            if lastError != nil {
                lastError = nil
            }
        } catch {
            let message = error.localizedDescription
            if lastError != message {
                lastError = message
            }
        }

        refreshStatus()
    }

    func refreshStatus() {
        let nextState: (isEnabled: Bool, statusText: String, statusIsWarning: Bool)
        switch SMAppService.mainApp.status {
        case .enabled:
            nextState = (true, "Enabled", false)
        case .requiresApproval:
            nextState = (false, "Waiting for approval in System Settings", true)
        case .notFound:
            nextState = (false, "App service not found", true)
        case .notRegistered:
            nextState = (false, "Disabled", false)
        @unknown default:
            nextState = (false, "Unknown status", true)
        }

        if isEnabled != nextState.isEnabled {
            isEnabled = nextState.isEnabled
        }
        if statusText != nextState.statusText {
            statusText = nextState.statusText
        }
        if statusIsWarning != nextState.statusIsWarning {
            statusIsWarning = nextState.statusIsWarning
        }
    }
}
