import AppKit
import Combine
import SwiftUI

private struct WindowInteractionActiveKey: EnvironmentKey {
    static let defaultValue = false
}

private struct VisualEffectsReducedKey: EnvironmentKey {
    static let defaultValue = VisualEffectsPreferences.defaultValue
}

extension EnvironmentValues {
    var windowInteractionActive: Bool {
        get { self[WindowInteractionActiveKey.self] }
        set { self[WindowInteractionActiveKey.self] = newValue }
    }

    var visualEffectsReduced: Bool {
        get { self[VisualEffectsReducedKey.self] }
        set { self[VisualEffectsReducedKey.self] = newValue }
    }
}

/// Reduces compositor work while the dashboard window is moving or live-resizing.
@MainActor
final class WindowInteractionCoordinator: NSObject, ObservableObject {
    @Published private(set) var isInteracting = false

    private weak var window: NSWindow?
    private var policy = WindowInteractionPolicy()
    private var settleWorkItem: DispatchWorkItem?
    private var watchdogWorkItem: DispatchWorkItem?
    private var originalHasShadow = true
    private var permanentlyReducesEffects = false

    func attach(to window: NSWindow) {
        if self.window === window {
            return
        }

        detach()
        self.window = window
        originalHasShadow = window.hasShadow

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(windowWillMove(_:)),
            name: NSWindow.willMoveNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(windowWillStartLiveResize(_:)),
            name: NSWindow.willStartLiveResizeNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: window
        )
    }

    func detach() {
        cancelAllTimers()
        NotificationCenter.default.removeObserver(self)

        if let window, window.hasShadow != originalHasShadow {
            window.hasShadow = originalHasShadow
            window.invalidateShadow()
        }

        window = nil
        policy = WindowInteractionPolicy(settleDelay: policy.settleDelay)
        publishInteractionState()
    }

    func setPermanentlyReducedEffects(_ reduced: Bool) {
        permanentlyReducesEffects = reduced
    }

    @objc private func windowWillMove(_ notification: Notification) {
        beginInteraction()
        scheduleWatchdog()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        cancelWatchdog()
        scheduleSettle()
    }

    @objc private func windowWillStartLiveResize(_ notification: Notification) {
        cancelWatchdog()
        beginInteraction()
    }

    @objc private func windowDidEndLiveResize(_ notification: Notification) {
        scheduleSettle()
    }

    private func beginInteraction() {
        settleWorkItem?.cancel()
        settleWorkItem = nil
        _ = policy.beginInteraction()
        publishInteractionState()
    }

    private func scheduleWatchdog() {
        watchdogWorkItem?.cancel()
        let token = policy.beginInteraction()
        let item = DispatchWorkItem { [weak self] in
            // If no move notification was received within 300ms, user only clicked the title bar without moving.
            self?.finishInteraction(token: token, force: true)
        }
        watchdogWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func cancelWatchdog() {
        watchdogWorkItem?.cancel()
        watchdogWorkItem = nil
    }

    private func scheduleSettle() {
        settleWorkItem?.cancel()
        let token = policy.beginInteraction()
        publishInteractionState()

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishInteraction(token: token, force: false)
        }
        settleWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + policy.settleDelay,
            execute: workItem
        )
    }

    private func finishInteraction(token: UInt64, force: Bool) {
        // Prevent premature settling while the user is still actively live-resizing the window
        if !force, let window = self.window, window.inLiveResize {
            return
        }

        guard policy.finishInteraction(ifCurrent: token) else { return }
        settleWorkItem = nil
        watchdogWorkItem = nil
        publishInteractionState()
    }

    private func cancelAllTimers() {
        settleWorkItem?.cancel()
        settleWorkItem = nil
        watchdogWorkItem?.cancel()
        watchdogWorkItem = nil
    }

    private func publishInteractionState() {
        guard isInteracting != policy.isInteracting else { return }
        isInteracting = policy.isInteracting
    }
}
