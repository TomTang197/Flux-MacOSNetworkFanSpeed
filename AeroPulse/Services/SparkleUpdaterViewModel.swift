import AppKit
import Combine
import Foundation
import Sparkle

/// Manages interaction with the Sparkle updater, observing state and providing an interface for SwiftUI views.
@MainActor
final class SparkleUpdaterViewModel: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = SparkleUpdaterViewModel()

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private var updaterController: SPUStandardUpdaterController!
    private var cancellables = Set<AnyCancellable>()
    private var hasInstalledUpdate = false

    override private init() {
        super.init()

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        self.updaterController = controller
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
            .store(in: &cancellables)

        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] autoCheck in
                guard let self else { return }
                if self.automaticallyChecksForUpdates != autoCheck {
                    self.automaticallyChecksForUpdates = autoCheck
                }
            }
            .store(in: &cancellables)
    }

    var appVersionDisplay: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(shortVersion) (\(buildNumber))"
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        return true
    }

    nonisolated func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        UserDefaults.standard.set(true, forKey: "AeroPulse.RelaunchAfterUpdate")
        Task { @MainActor in
            for window in NSApp.windows {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        UserDefaults.standard.set(true, forKey: "AeroPulse.RelaunchAfterUpdate")
        Task { @MainActor in
            self.hasInstalledUpdate = true
        }
    }

    // MARK: - SPUStandardUserDriverDelegate

    nonisolated func standardUserDriverWillShowModalAlert() {
        Task { @MainActor in
            DashboardWindowManager.shared.transitionActivationPolicy(to: .regular)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    nonisolated func standardUserDriverDidShowModalAlert() {
        Task { @MainActor in
            if self.hasInstalledUpdate {
                self.relaunchApplication()
            }
        }
    }

    private func relaunchApplication() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
