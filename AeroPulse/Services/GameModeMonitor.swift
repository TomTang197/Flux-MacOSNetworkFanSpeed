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
    private var heartbeatTimer: Timer?

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
            self?.handleDarwinSessionEvent(active: true)
        }

        registerDarwinNotification("com.apple.system.fullscreen_gaming_session_did_end") { [weak self] _ in
            self?.handleDarwinSessionEvent(active: false)
        }

        registerDarwinNotification("com.apple.system.fullscreen_gaming_session_changed") { [weak self] token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            if state == 0 {
                self?.handleDarwinSessionEvent(active: false)
            } else {
                self?.handleDarwinSessionEvent(active: true)
            }
        }

        registerDarwinNotification("com.apple.system.game_mode_status_changed") { [weak self] _ in
            DispatchQueue.main.async {
                self?.evaluateCombinedState()
            }
        }

        registerDarwinNotification("com.apple.gamepolicy.GameExited") { [weak self] _ in
            DispatchQueue.main.async {
                self?.evaluateCombinedState()
            }
        }

        // 2. Register NSWorkspace observers for foreground application changes and process termination
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
            self?.evaluateCombinedState()
        }
        workspaceObservers.append(terminateObserver)

        // Initial query
        checkInitialDarwinState()
        checkCurrentForegroundApplication()
    }

    func stopMonitoring() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

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
        // Never assume game mode is active at startup unless there is actually a running game
        guard hasRunningGameApplication() else {
            isDarwinGamingSessionActive = false
            return
        }

        var token: Int32 = 0
        let status = notify_register_check("com.apple.system.fullscreen_gaming_session_changed", &token)
        if status == NOTIFY_STATUS_OK {
            var state: UInt64 = 0
            notify_get_state(token, &state)
            notify_cancel(token)
            if state > 0 {
                isDarwinGamingSessionActive = true
            }
        }
    }

    private func handleDarwinSessionEvent(active: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if active {
                if self.hasRunningGameApplication() {
                    self.isDarwinGamingSessionActive = true
                }
            } else {
                self.isDarwinGamingSessionActive = false
            }
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

    func hasRunningGameApplication() -> Bool {
        return NSWorkspace.shared.runningApplications.contains { app in
            isGameApplication(app)
        }
    }

    func isGameApplication(_ app: NSRunningApplication) -> Bool {
        // Background helpers/daemons should not be treated as games
        if app.activationPolicy == .prohibited {
            return false
        }

        if let bundleURL = app.bundleURL,
           let bundle = Bundle(url: bundleURL) {
            if let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
                if category.lowercased().contains("game") {
                    return true
                }
            }
        }

        if let bundleID = app.bundleIdentifier?.lowercased() {
            let knownGamePrefixesOrSubstrings = [
                ".game",
                "steam_app_",
                "com.valvesoftware.steam",
                "com.blizzard.",
                "net.battle.",
                "com.epicgames.",
                "com.riotgames.",
                "com.gog.",
                "com.ea.",
                "com.ubisoft.",
                "crossover",
                "whisky",
                "wine",
                "heroic",
                "retroarch",
                "dolphin-emu",
                "ryujinx"
            ]
            for pattern in knownGamePrefixesOrSubstrings {
                if bundleID.contains(pattern) || bundleID.hasPrefix(pattern) {
                    return true
                }
            }
        }

        if let path = app.bundleURL?.path.lowercased() {
            if path.contains("/steamapps/common/") || path.contains("/games/") {
                return true
            }
        }

        return false
    }

    private func evaluateCombinedState() {
        let hasRunningGame = hasRunningGameApplication()
        if !hasRunningGame {
            isDarwinGamingSessionActive = false
            isForegroundGameActive = false
        }

        let active = hasRunningGame && (isDarwinGamingSessionActive || isForegroundGameActive)
        if isGameModeActive != active {
            isGameModeActive = active
        }
        updateHeartbeatTimer()
    }

    private func updateHeartbeatTimer() {
        if isGameModeActive {
            if heartbeatTimer == nil {
                heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    self?.evaluateCombinedState()
                }
            }
        } else {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
        }
    }
}
