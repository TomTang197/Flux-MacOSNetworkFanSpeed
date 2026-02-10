import Foundation
import IOKit
import os.log

// MARK: - XPC protocol (app-side mirror)

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
}

protocol FanControlProviding {
    func setFanMode(index: Int, manual: Bool)
    func setFanTargetRPM(index: Int, rpm: Int)
    func checkHelperHealth(completion: @escaping (Bool) -> Void)
}

/// Current implementation: writes directly via `SMCService`.
/// Future implementation (partially wired here): prefer XPC to a privileged
/// helper that opens AppleSMC with IOServiceOpen type 2 and performs writes there.
final class FanControlClient: FanControlProviding {
    static let shared = FanControlClient()

    private let smc = SMCService.shared
    private let logger = Logger(subsystem: "com.bandan.me.MacOSNetworkFanSpeed", category: "FanControlClient")

    // Mach service name must match the helper's launchd plist.
    // You will use this in your SMJobBless/launchd configuration.
    private let machServiceName = "com.bandan.me.MacOSNetworkFanSpeed.FanService"

    private var connection: NSXPCConnection?
    private var helperRetryAfter: Date = .distantPast
    private var consecutiveHelperFailures: Int = 0
    private var helperPresenceKnownMissing = false
    private var helperPresenceRecheckAfter: Date = .distantPast
    private var hasLoggedMissingHelper = false
    private var lastHelperErrorLogAt: Date = .distantPast

    private init() {}

    // MARK: - Helper connection

    private func helperProxy(onError: @escaping () -> Void) -> FanHelperProtocol? {
        guard Date() >= helperRetryAfter else { return nil }
        guard helperIsInstalled() else { return nil }

        if let existing = connection {
            return existing.remoteObjectProxyWithErrorHandler { [weak self] error in
                self?.handleHelperFailure(error)
                onError()
            } as? FanHelperProtocol
        }

        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            self?.logger.debug("XPC connection invalidated")
            self?.markHelperUnavailable()
        }

        newConnection.interruptionHandler = { [weak self] in
            self?.logger.debug("XPC connection interrupted")
            self?.markHelperUnavailable()
        }

        newConnection.resume()
        connection = newConnection

        return newConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.handleHelperFailure(error)
            onError()
        } as? FanHelperProtocol
    }

    // MARK: - FanControlProviding

    func setFanMode(index: Int, manual: Bool) {
        if let helper = helperProxy(onError: { [weak self] in
            self?.smc.setFanMode(index, manual: manual)
        }) {
            helper.setFanMode(index: index, manual: manual) { [weak self] result in
                guard let self = self else { return }
                if result == kIOReturnSuccess {
                    self.markHelperAvailable()
                } else if self.isNonFatalHelperResult(result) {
                    self.logger.notice(
                        "Helper setFanMode unsupported on this model (code \(result)); continuing with target-only control."
                    )
                    self.markHelperAvailable()
                } else {
                    self.logger.error("Helper setFanMode failed with code \(result)")
                    self.markHelperUnavailable()
                    self.smc.setFanMode(index, manual: manual)
                }
            }
            return
        }

        // Fallback: direct write (works on Intel, will be kIOReturnNotPrivileged on Apple Silicon)
        smc.setFanMode(index, manual: manual)
    }

    func setFanTargetRPM(index: Int, rpm: Int) {
        if let helper = helperProxy(onError: { [weak self] in
            self?.smc.setFanTargetRPM(index, rpm: rpm)
        }) {
            helper.setFanTargetRPM(index: index, rpm: rpm) { [weak self] result in
                guard let self = self else { return }
                if result == kIOReturnSuccess {
                    self.markHelperAvailable()
                } else if self.isNonFatalHelperResult(result) {
                    self.logger.notice(
                        "Helper setFanTargetRPM not supported for fan \(index) (code \(result))."
                    )
                    self.markHelperAvailable()
                } else {
                    self.logger.error("Helper setFanTargetRPM failed with code \(result)")
                    self.markHelperUnavailable()
                    self.smc.setFanTargetRPM(index, rpm: rpm)
                }
            }
            return
        }

        // Fallback: direct write (works on Intel, will be kIOReturnNotPrivileged on Apple Silicon)
        smc.setFanTargetRPM(index, rpm: rpm)
    }

    func checkHelperHealth(completion: @escaping (Bool) -> Void) {
        guard helperIsInstalled() else {
            completion(false)
            return
        }

        let probeConnection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        probeConnection.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)

        let completionQueue = DispatchQueue(label: "com.bandan.me.FanHelperHealth")
        var didFinish = false
        let finish: (Bool) -> Void = { [weak self] healthy in
            completionQueue.sync {
                guard !didFinish else { return }
                didFinish = true
            }
            probeConnection.invalidationHandler = nil
            probeConnection.interruptionHandler = nil
            probeConnection.invalidate()

            DispatchQueue.main.async {
                if healthy {
                    self?.markHelperAvailable()
                }
                completion(healthy)
            }
        }

        probeConnection.invalidationHandler = {
            finish(false)
        }
        probeConnection.interruptionHandler = {
            finish(false)
        }

        probeConnection.resume()

        guard let helper = probeConnection.remoteObjectProxyWithErrorHandler({ _ in
            finish(false)
        }) as? FanHelperProtocol else {
            finish(false)
            return
        }

        helper.ping { healthy in
            finish(healthy)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
            finish(false)
        }
    }

    private func handleHelperFailure(_ error: Error) {
        let now = Date()
        if now.timeIntervalSince(lastHelperErrorLogAt) >= 10 {
            logger.error("XPC remote object error: \(error.localizedDescription, privacy: .public)")
            lastHelperErrorLogAt = now
        }
        markHelperUnavailable()
    }

    private func isNonFatalHelperResult(_ result: Int32) -> Bool {
        result == kIOReturnNotFound || result == kIOReturnUnsupported
    }

    private func markHelperAvailable() {
        consecutiveHelperFailures = 0
        helperRetryAfter = .distantPast
        helperPresenceKnownMissing = false
        hasLoggedMissingHelper = false
    }

    private func markHelperUnavailable() {
        connection = nil
        consecutiveHelperFailures = min(consecutiveHelperFailures + 1, 6)
        let retryDelay = min(pow(2.0, Double(consecutiveHelperFailures - 1)), 60.0)
        helperRetryAfter = Date().addingTimeInterval(retryDelay)
    }

    private func helperIsInstalled() -> Bool {
        let now = Date()
        if helperPresenceKnownMissing, now < helperPresenceRecheckAfter {
            return false
        }

        let fileManager = FileManager.default
        let hasBinary = fileManager.fileExists(atPath: "/Library/PrivilegedHelperTools/\(machServiceName)")
        let hasLaunchdPlist = fileManager.fileExists(
            atPath: "/Library/LaunchDaemons/\(machServiceName).plist"
        )
        let installed = hasBinary && hasLaunchdPlist

        if installed {
            helperPresenceKnownMissing = false
            return true
        }

        helperPresenceKnownMissing = true
        helperPresenceRecheckAfter = now.addingTimeInterval(30)
        if !hasLoggedMissingHelper {
            logger.notice(
                "Privileged helper not installed (expected \(self.machServiceName, privacy: .public) in /Library). Fan writes will use unprivileged fallback."
            )
            hasLoggedMissingHelper = true
        }
        return false
    }

    func forceHelperRecheck() {
        connection = nil
        helperRetryAfter = .distantPast
        helperPresenceKnownMissing = false
        helperPresenceRecheckAfter = .distantPast
        hasLoggedMissingHelper = false
        consecutiveHelperFailures = 0
    }
}
