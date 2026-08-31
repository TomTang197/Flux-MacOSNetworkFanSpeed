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
    private var originalHasShadow = true
    private var permanentlyReducesEffects = false

    func attach(to window: NSWindow) {
        if self.window === window {
            applyWindowShadow()
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

        applyWindowShadow()
    }

    func detach() {
        settleWorkItem?.cancel()
        settleWorkItem = nil
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
        guard permanentlyReducesEffects != reduced else { return }
        permanentlyReducesEffects = reduced
        applyWindowShadow()
    }

    @objc private func windowWillMove(_ notification: Notification) {
        beginInteraction()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        scheduleSettle()
    }

    @objc private func windowWillStartLiveResize(_ notification: Notification) {
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
        applyWindowShadow()
    }

    private func scheduleSettle() {
        settleWorkItem?.cancel()
        let token = policy.beginInteraction()
        publishInteractionState()
        applyWindowShadow()

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishInteraction(token: token)
        }
        settleWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + policy.settleDelay,
            execute: workItem
        )
    }

    private func finishInteraction(token: UInt64) {
        guard policy.finishInteraction(ifCurrent: token) else { return }
        settleWorkItem = nil
        publishInteractionState()
        applyWindowShadow()
    }

    private func publishInteractionState() {
        guard isInteracting != policy.isInteracting else { return }
        isInteracting = policy.isInteracting
    }

    private func applyWindowShadow() {
        guard let window else { return }
        let shouldShowShadow =
            originalHasShadow && !permanentlyReducesEffects && !policy.isInteracting

        guard window.hasShadow != shouldShowShadow else { return }
        window.hasShadow = shouldShowShadow
        window.invalidateShadow()
    }
}
