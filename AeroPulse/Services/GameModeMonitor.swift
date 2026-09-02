//
//  GameModeMonitor.swift
//  AeroPulse
//
//  Created on 02/09/26.
//

import AppKit
import Combine
import Foundation
import notify

final class GameModeMonitor: ObservableObject {
    @Published private(set) var isGameModeActive: Bool = false {
        didSet {
            if oldValue != isGameModeActive {
                onGameModeChanged?(isGameModeActive)
            }
        }
    }

    var onGameModeChanged: ((Bool) -> Void)?

    private var notifyTokens: [Int32] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private let notifyQueue = DispatchQueue(label: "com.bandan.me.AeroPulse.GameModeNotify", qos: .utility)
    private var isDarwinGamingSessionActive = false
    private var isForegroundGameActive = false

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        stopMonitoring()

        // 1. Register Darwin notifications from gamepolicyd
        registerDarwinNotification("com.apple.system.fullscreen_gaming_session_did_begin") { [weak self] _ in
            self?.updateDarwinGamingState(active: true)
        }

        registerDarwinNotification("com.apple.system.fullscreen_gaming_session_did_end") { [weak self] _ in
            self?.updateDarwinGamingState(active: false)
        }

        registerDarwinNotification("com.apple.system.game_mode_status_changed") { [weak self] token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            self?.updateDarwinGamingState(active: state > 0)
        }

        registerDarwinNotification("com.apple.system.fullscreen_gaming_session_changed") { [weak self] token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            self?.updateDarwinGamingState(active: state > 0)
        }

        // 2. Register NSWorkspace observers for foreground application changes
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let activateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.checkForegroundApplication(from: notification)
        }
        workspaceObservers.append(activateObserver)

        let terminateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkCurrentForegroundApplication()
        }
        workspaceObservers.append(terminateObserver)

        // Initial query
        checkInitialDarwinState()
        checkCurrentForegroundApplication()
    }

    func stopMonitoring() {
        for token in notifyTokens {
            notify_cancel(token)
        }
        notifyTokens.removeAll()

        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func registerDarwinNotification(_ name: String, handler: @escaping (Int32) -> Void) {
        var token: Int32 = 0
        let status = notify_register_dispatch(
            name,
            &token,
            notifyQueue
        ) { token in
            handler(token)
        }
        if status == NOTIFY_STATUS_OK {
            notifyTokens.append(token)
        }
    }

    private func checkInitialDarwinState() {
        var token: Int32 = 0
        let status = notify_register_check("com.apple.system.game_mode_status_changed", &token)
        if status == NOTIFY_STATUS_OK {
            var state: UInt64 = 0
            notify_get_state(token, &state)
            notify_cancel(token)
            if state > 0 {
                updateDarwinGamingState(active: true)
            }
        }
    }

    private func updateDarwinGamingState(active: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isDarwinGamingSessionActive = active
            self.evaluateCombinedState()
        }
    }

    private func checkForegroundApplication(from notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            evaluateAppIsGame(app)
        } else {
            checkCurrentForegroundApplication()
        }
    }

    private func checkCurrentForegroundApplication() {
        if let app = NSWorkspace.shared.frontmostApplication {
            evaluateAppIsGame(app)
        } else {
            isForegroundGameActive = false
            evaluateCombinedState()
        }
    }

    private func evaluateAppIsGame(_ app: NSRunningApplication) {
        let isGame = isGameApplication(app)
        if isForegroundGameActive != isGame {
            isForegroundGameActive = isGame
            evaluateCombinedState()
        }
    }

    private func isGameApplication(_ app: NSRunningApplication) -> Bool {
        guard let bundleURL = app.bundleURL,
              let bundle = Bundle(url: bundleURL) else {
            if let bundleID = app.bundleIdentifier?.lowercased() {
                if bundleID.contains("steam") || bundleID.contains("crossover") || bundleID.contains("whisky") {
                    return true
                }
            }
            return false
        }

        if let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
            if category.lowercased().contains("game") {
                return true
            }
        }

        if let bundleID = app.bundleIdentifier?.lowercased() {
            if bundleID.contains(".game") || bundleID.contains("steam_app_") || bundleID.hasPrefix("com.valvesoftware.steam") {
                return true
            }
        }

        return false
    }

    private func evaluateCombinedState() {
        let active = isDarwinGamingSessionActive || isForegroundGameActive
        if isGameModeActive != active {
            isGameModeActive = active
        }
    }
}
