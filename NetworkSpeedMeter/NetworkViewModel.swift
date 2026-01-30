import Combine
import SwiftUI

/// Display modes for the menu bar and dashboard.
enum DisplayMode: String, CaseIterable, Identifiable {
    case download = "Download"
    case upload = "Upload"
    case both = "Download + Upload"
    case combined = "Combined"

    var id: String { self.rawValue }
}

/// `NetworkViewModel` manages the state of the network speed meter, coordinates updates, and persists settings.
final class NetworkViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var combinedSpeed: String = "0 KB/s"

    @Published var rawDownload: Double = 0
    @Published var rawUpload: Double = 0

    @Published var displayMode: DisplayMode = .both {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "DisplayMode") }
    }

    @Published var refreshInterval: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "RefreshInterval")
            restartTimer()
        }
    }

    // MARK: - Private Properties

    private let monitor = NetworkMonitor()
    private var lastStats: NetworkMonitor.InterfaceStats?
    private var lastTimestamp: Date?
    private var timer: AnyCancellable?

    // MARK: - Initializer

    init() {
        // Load persisted settings
        if let modeString = UserDefaults.standard.string(forKey: "DisplayMode"),
            let mode = DisplayMode(rawValue: modeString)
        {
            self.displayMode = mode
        }

        let interval = UserDefaults.standard.double(forKey: "RefreshInterval")
        self.refreshInterval = interval > 0 ? interval : 1.0

        startMonitoring()
    }

    // MARK: - Monitoring Logic

    func startMonitoring() {
        restartTimer()
    }

    private func restartTimer() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSpeed()
            }
    }

    private func updateSpeed() {
        let currentStats = monitor.getNetworkUsage()
        let currentTimestamp = Date()

        if let lastStats = self.lastStats, let lastTimestamp = self.lastTimestamp {
            let timeInterval = currentTimestamp.timeIntervalSince(lastTimestamp)

            // Speed = (Current Bytes - Last Bytes) / Time Interval
            // We use max(0, ...) to handle potential overflows or counter resets (rare).
            let diffIn = Double(
                currentStats.bytesIn >= lastStats.bytesIn ? currentStats.bytesIn - lastStats.bytesIn : 0
            )
            let diffOut = Double(
                currentStats.bytesOut >= lastStats.bytesOut ? currentStats.bytesOut - lastStats.bytesOut : 0
            )

            let downBps = diffIn / timeInterval
            let upBps = diffOut / timeInterval

            self.rawDownload = downBps
            self.rawUpload = upBps

            self.downloadSpeed = formatSpeed(downBps)
            self.uploadSpeed = formatSpeed(upBps)
            self.combinedSpeed = formatSpeed(downBps + upBps)
        }

        self.lastStats = currentStats
        self.lastTimestamp = currentTimestamp
    }

    /// Formats raw bytes per second into human-readable strings.
    /// KB/s, MB/s, GB/s according to magnitude.
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1.0 {
            return String(format: "%.2f GB/s", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB/s", mb)
        } else if kb >= 1.0 {
            return String(format: "%.1f KB/s", kb)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
