import AppKit
import SwiftUI

/// Coordinates dashboard window presentation, deminiaturization, and open-window action bridging.
@MainActor
final class DashboardWindowManager: NSObject {
    static let shared = DashboardWindowManager()

    private var openWindowAction: OpenWindowAction?
    private weak var registeredWindow: NSWindow?
    private var policy = DashboardWindowPolicy()

    override private init() {
        super.init()
    }

    func registerOpenWindowAction(_ action: OpenWindowAction) {
        self.openWindowAction = action
    }

    func registerDashboardWindow(_ window: NSWindow) {
        self.registeredWindow = window
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

    func showDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        let window = findDashboardWindow()
        let state = DashboardWindowState(
            isRegistered: window != nil,
            isVisible: window?.isVisible ?? false,
            isMiniaturized: window?.isMiniaturized ?? false
        )

        let action = policy.evaluateReopen(state: state, at: Date())

        switch action {
        case .deminiaturizeAndOrderFront:
            guard let window else { return }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

        case .orderFront:
            guard let window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

        case .openNewWindow:
            if let openWindow = openWindowAction {
                openWindow(id: "dashboard")
            } else {
                // Retry slightly later if action is not yet registered during early startup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.openWindowAction?(id: "dashboard")
                }
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
