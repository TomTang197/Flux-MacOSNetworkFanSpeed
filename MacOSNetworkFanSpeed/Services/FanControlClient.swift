import Foundation
import os.log

// MARK: - XPC protocol (app-side mirror)

@objc protocol FanHelperProtocol {
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
}

protocol FanControlProviding {
    func setFanMode(index: Int, manual: Bool)
    func setFanTargetRPM(index: Int, rpm: Int)
}

/// Current implementation: writes directly via `SMCService`.
/// Future implementation (partially wired here): prefer XPC to a privileged
/// helper that opens AppleSMC with IOServiceOpen type 2 and performs writes there.
final class FanControlClient: FanControlProviding {
    static let shared = FanControlClient()

    private let smc = SMCService.shared
    private let logger = Logger(subsystem: "cam.bandan.me.MacOSNetworkFanSpeed", category: "FanControlClient")

    // Mach service name must match the helper's launchd plist.
    // You will use this in your SMJobBless/launchd configuration.
    private let machServiceName = "cam.bandan.me.MacOSNetworkFanSpeed.FanService"

    private var connection: NSXPCConnection?

    private init() {}

    // MARK: - Helper connection

    private func helperProxy() -> FanHelperProtocol? {
        if let existing = connection {
            return existing.remoteObjectProxyWithErrorHandler { [weak self] error in
                self?.logger.error("XPC remote object error: \(error.localizedDescription, privacy: .public)")
            } as? FanHelperProtocol
        }

        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            self?.logger.debug("XPC connection invalidated")
            self?.connection = nil
        }

        newConnection.resume()
        connection = newConnection

        return newConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC remote object error: \(error.localizedDescription, privacy: .public)")
        } as? FanHelperProtocol
    }

    // MARK: - FanControlProviding

    func setFanMode(index: Int, manual: Bool) {
        if let helper = helperProxy() {
            helper.setFanMode(index: index, manual: manual) { [weak self] result in
                if result != kIOReturnSuccess {
                    self?.logger.error("Helper setFanMode failed with code \(result)")
                }
            }
            return
        }

        // Fallback: direct write (works on Intel, will be kIOReturnNotPrivileged on Apple Silicon)
        smc.setFanMode(index, manual: manual)
    }

    func setFanTargetRPM(index: Int, rpm: Int) {
        if let helper = helperProxy() {
            helper.setFanTargetRPM(index: index, rpm: rpm) { [weak self] result in
                if result != kIOReturnSuccess {
                    self?.logger.error("Helper setFanTargetRPM failed with code \(result)")
                }
            }
            return
        }

        // Fallback: direct write (works on Intel, will be kIOReturnNotPrivileged on Apple Silicon)
        smc.setFanTargetRPM(index, rpm: rpm)
    }
}
