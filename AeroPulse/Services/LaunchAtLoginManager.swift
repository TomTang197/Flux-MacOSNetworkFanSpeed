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
