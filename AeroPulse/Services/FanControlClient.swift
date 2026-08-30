//
//  FanControlClient.swift
//  AeroPulse
//
//  Created by Bandan.K on 14/02/26.
//  Updated with active XPC client on 30/08/26.
//

import Foundation
import IOKit
import os.log

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
    func resetToAutomatic(withReply reply: @escaping (Int32) -> Void)
}

protocol FanControlProviding {
    func ping(completion: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, completion: ((Bool) -> Void)?)
    func setFanTargetRPM(index: Int, rpm: Int, completion: ((Bool) -> Void)?)
    func resetToAutomatic(completion: ((Bool) -> Void)?)
}

final class FanControlClient: FanControlProviding {
    static let shared = FanControlClient()

    private let serviceIdentifier = "com.bandan.me.AeroPulse.FanService"
    private var connection: NSXPCConnection?
    private let connectionLock = NSLock()
    private let logger = Logger(subsystem: "com.bandan.me.AeroPulse", category: "FanControlClient")

    private init() {}

    private func getProxy(errorHandler: ((Error) -> Void)? = nil) -> FanHelperProtocol? {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if connection == nil {
            let conn = NSXPCConnection(machServiceName: serviceIdentifier)
            conn.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                self?.connectionLock.lock()
                self?.connection = nil
                self?.connectionLock.unlock()
            }
            conn.interruptionHandler = { [weak self] in
                self?.connectionLock.lock()
                self?.connection = nil
                self?.connectionLock.unlock()
            }
            conn.resume()
            self.connection = conn
        }

        return connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC remote proxy error: \(error.localizedDescription, privacy: .public)")
            errorHandler?(error)
        } as? FanHelperProtocol
    }

    func ping(completion: @escaping (Bool) -> Void) {
        guard let proxy = getProxy(errorHandler: { _ in completion(false) }) else {
            completion(false)
            return
        }
        proxy.ping { isAlive in
            completion(isAlive)
        }
    }

    func setFanMode(index: Int, manual: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.setFanMode(index: index, manual: manual) { result in
            completion?(result == kIOReturnSuccess)
        }
    }

    func setFanTargetRPM(index: Int, rpm: Int, completion: ((Bool) -> Void)? = nil) {
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.setFanTargetRPM(index: index, rpm: rpm) { result in
            completion?(result == kIOReturnSuccess)
        }
    }

    func resetToAutomatic(completion: ((Bool) -> Void)? = nil) {
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.resetToAutomatic { result in
            completion?(result == kIOReturnSuccess)
        }
    }
}
