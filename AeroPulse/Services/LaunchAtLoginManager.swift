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
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        refreshStatus()
    }

    func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            statusText = "Enabled"
            statusIsWarning = false
        case .requiresApproval:
            isEnabled = false
            statusText = "Waiting for approval in System Settings"
            statusIsWarning = true
        case .notFound:
            isEnabled = false
            statusText = "App service not found"
            statusIsWarning = true
        case .notRegistered:
            isEnabled = false
            statusText = "Disabled"
            statusIsWarning = false
        @unknown default:
            isEnabled = false
            statusText = "Unknown status"
            statusIsWarning = true
        }
    }
}
