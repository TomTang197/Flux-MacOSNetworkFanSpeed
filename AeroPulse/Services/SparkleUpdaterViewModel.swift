import Combine
import Foundation
import Sparkle

/// Manages interaction with the Sparkle updater, observing state and providing an interface for SwiftUI views.
@MainActor
final class SparkleUpdaterViewModel: NSObject, ObservableObject {
    static let shared = SparkleUpdaterViewModel()

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        super.init()

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
}
