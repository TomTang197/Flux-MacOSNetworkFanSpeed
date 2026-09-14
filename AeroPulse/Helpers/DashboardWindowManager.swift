import AppKit
import SwiftUI

/// Coordinates dashboard window presentation, deminiaturization, and open-window action bridging.
@MainActor
final class DashboardWindowManager: NSObject {
    static let shared = DashboardWindowManager()

    private var openWindowAction: OpenWindowAction?
    private weak var registeredWindow: NSWindow?
    private var policy = DashboardWindowPolicy()
    private var isOpeningInProgress = false
    private var pendingAccessorySwitchWorkItem: DispatchWorkItem?

    override private init() {
        super.init()
    }

    func registerOpenWindowAction(_ action: OpenWindowAction) {
        self.openWindowAction = action
    }

    func registerDashboardWindow(_ window: NSWindow) {
        self.registeredWindow = window
        self.isOpeningInProgress = false
        window.identifier = NSUserInterfaceItemIdentifier("dashboard")
    }

    func unregisterDashboardWindow(_ window: NSWindow? = nil) {
        if let window {
            if self.registeredWindow === window {
                self.registeredWindow = nil
            }
        } else {
            self.registeredWindow = nil
        }
    }

    /// Safely transitions activation policy to avoid race conditions when reopening rapidly after Cmd+W.
    func transitionActivationPolicy(to target: NSApplication.ActivationPolicy) {
        pendingAccessorySwitchWorkItem?.cancel()
        pendingAccessorySwitchWorkItem = nil

        if target == .regular {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let hasActiveDashboard = self.registeredWindow != nil || self.isOpeningInProgress
                let hasOtherWindows = NSApp.windows.contains {
                    $0.isVisible && !($0 is NSPanel) && $0.level == .normal && $0.identifier?.rawValue != "dashboard"
                }
                if !hasActiveDashboard && !hasOtherWindows {
                    if NSApp.activationPolicy() != .accessory {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
            self.pendingAccessorySwitchWorkItem = workItem
            DispatchQueue.main.async(execute: workItem)
        }
    }

    func showDashboard() {
        transitionActivationPolicy(to: .regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        let window = findDashboardWindow()
        let state = DashboardWindowState(
            isRegistered: window != nil,
            isVisible: window?.isVisible ?? false,
            isMiniaturized: window?.isMiniaturized ?? false,
            isAppHidden: NSApp.isHidden,
            isOpeningInProgress: isOpeningInProgress
        )

        let action = policy.evaluateReopen(state: state)

        switch action {
        case .deminiaturizeAndOrderFront:
            guard let window else { return }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)

        case .unhideAndOrderFront:
            NSApp.unhide(nil)
            window?.makeKeyAndOrderFront(nil)

        case .orderFront:
            guard let window else { return }
            window.makeKeyAndOrderFront(nil)

        case .openNewWindow:
            isOpeningInProgress = true
            if let openWindow = openWindowAction {
                openWindow(id: "dashboard")
            } else {
                // Retry slightly later if action is not yet registered during early startup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.openWindowAction?(id: "dashboard")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isOpeningInProgress = false
            }

        case .ignoreThrottled:
            break
        }
    }

    func findDashboardWindow() -> NSWindow? {
        if let registered = registeredWindow {
            return registered
        }

        return NSApp.windows.first { window in
            guard !(window is NSPanel) else { return false }
            guard window.level == .normal else { return false }
            return window.identifier?.rawValue == "dashboard"
                || window.title == AppStrings.appName
        }
    }
}
