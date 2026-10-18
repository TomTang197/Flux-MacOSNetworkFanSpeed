import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopenAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize updater early so Sparkle background checks run
        _ = SparkleUpdaterViewModel.shared

        // Trigger probing check after network has a moment to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            SparkleUpdaterViewModel.shared.startBackgroundCheck()
        }

        if UserDefaults.standard.bool(forKey: "AeroPulse.RelaunchAfterUpdate") {
            UserDefaults.standard.removeObject(forKey: "AeroPulse.RelaunchAfterUpdate")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DashboardWindowManager.shared.showDashboard()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DashboardWindowManager.shared.showDashboard()
        return true
    }

    @objc private func handleReopenAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        Task { @MainActor in
            DashboardWindowManager.shared.showDashboard()
        }
    }
}
