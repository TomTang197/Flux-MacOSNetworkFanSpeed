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

extension Notification.Name {
    static let fanControlLeaseLost = Notification.Name("com.bandan.me.AeroPulse.fanControlLeaseLost")
}

@objc protocol FanHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func heartbeat(withReply reply: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, withReply reply: @escaping (Int32) -> Void)
    func setFanTargetRPM(index: Int, rpm: Int, withReply reply: @escaping (Int32) -> Void)
    func setFanTargets(indices: [NSNumber], rpms: [NSNumber], withReply reply: @escaping (Int32) -> Void)
    func resetToAutomatic(withReply reply: @escaping (Int32) -> Void)
}

protocol FanControlProviding {
    func ping(completion: @escaping (Bool) -> Void)
    func setFanMode(index: Int, manual: Bool, completion: ((Bool) -> Void)?)
    func setFanTargetRPM(index: Int, rpm: Int, completion: ((Bool) -> Void)?)
    func setFanTargets(_ targets: [(index: Int, rpm: Int)], completion: ((Bool) -> Void)?)
    func resetToAutomatic(completion: ((Bool) -> Void)?)
}

final class FanControlClient: FanControlProviding {
    static let shared = FanControlClient()

    private let serviceIdentifier = "com.bandan.me.AeroPulse.FanService"
    private var connection: NSXPCConnection?
    private let connectionLock = NSLock()
    private let heartbeatLock = NSLock()
    private let heartbeatQueue = DispatchQueue(label: "com.bandan.me.AeroPulse.FanControlHeartbeat")
    private var heartbeatTimer: DispatchSourceTimer?
    private var heartbeatGeneration: UInt64 = 0
    private var controlEpoch: UInt64 = 0
    private var controlTemperatureDeadline: Date?
    private let heartbeatInterval: TimeInterval = 5
    private let logger = Logger(subsystem: "com.bandan.me.AeroPulse", category: "FanControlClient")

    private init() {}

    private func getProxy(errorHandler: ((Error) -> Void)? = nil) -> FanHelperProtocol? {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if connection == nil {
            let conn = NSXPCConnection(machServiceName: serviceIdentifier)
            conn.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
            conn.invalidationHandler = { [weak self, weak conn] in
                guard let conn else { return }
                self?.handleConnectionEnded(conn)
            }
            conn.interruptionHandler = { [weak self, weak conn] in
                guard let conn else { return }
                self?.handleConnectionEnded(conn)
            }
            conn.resume()
            self.connection = conn
        }

        return connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC remote proxy error: \(error.localizedDescription, privacy: .public)")
            errorHandler?(error)
        } as? FanHelperProtocol
    }

    private func handleConnectionEnded(_ endedConnection: NSXPCConnection) {
        connectionLock.lock()
        let wasCurrent = connection === endedConnection
        if wasCurrent {
            connection = nil
        }
        connectionLock.unlock()

        guard wasCurrent else { return }
        reportLeaseLost()
    }

    private func currentControlEpoch() -> UInt64 {
        heartbeatLock.lock()
        defer { heartbeatLock.unlock() }
        return controlEpoch
    }

    private func isCurrentControlEpoch(_ epoch: UInt64) -> Bool {
        heartbeatLock.lock()
        defer { heartbeatLock.unlock() }
        return controlEpoch == epoch
    }

    private func startHeartbeat(for epoch: UInt64) {
        heartbeatLock.lock()
        guard epoch == controlEpoch else {
            heartbeatLock.unlock()
            return
        }
        guard heartbeatTimer == nil else {
            heartbeatLock.unlock()
            return
        }

        heartbeatGeneration &+= 1
        let generation = heartbeatGeneration
        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(
            deadline: .now() + heartbeatInterval,
            repeating: heartbeatInterval,
            leeway: .milliseconds(500)
        )
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat(generation: generation)
        }
        heartbeatTimer = timer
        heartbeatLock.unlock()
        timer.resume()
    }

    @discardableResult
    private func stopHeartbeat(
        invalidateCommands: Bool,
        ifGenerationMatches expectedGeneration: UInt64? = nil
    ) -> Bool {
        heartbeatLock.lock()
        if let expectedGeneration,
           heartbeatGeneration != expectedGeneration || heartbeatTimer == nil {
            heartbeatLock.unlock()
            return false
        }
        let timer = heartbeatTimer
        heartbeatTimer = nil
        heartbeatGeneration &+= 1
        if invalidateCommands {
            controlEpoch &+= 1
            controlTemperatureDeadline = nil
        }
        heartbeatLock.unlock()
        timer?.cancel()
        return true
    }

    private func isCurrentHeartbeat(_ generation: UInt64) -> Bool {
        heartbeatLock.lock()
        defer { heartbeatLock.unlock() }
        return heartbeatTimer != nil && heartbeatGeneration == generation
    }

    private func hasExpiredControlTemperatureDeadline(for generation: UInt64) -> Bool {
        heartbeatLock.lock()
        defer { heartbeatLock.unlock() }
        guard heartbeatTimer != nil, heartbeatGeneration == generation,
              let deadline = controlTemperatureDeadline else { return false }
        return Date() >= deadline
    }

    func setControlTemperatureDeadline(_ deadline: Date?) {
        heartbeatLock.lock()
        controlTemperatureDeadline = deadline
        heartbeatLock.unlock()
    }

    private func reportLeaseLost(heartbeatGeneration generation: UInt64? = nil) {
        guard stopHeartbeat(
            invalidateCommands: true,
            ifGenerationMatches: generation
        ) else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fanControlLeaseLost, object: nil)
        }
    }

    private func sendHeartbeat(generation: UInt64) {
        guard isCurrentHeartbeat(generation) else { return }
        if hasExpiredControlTemperatureDeadline(for: generation) {
            expireCustomControl(heartbeatGeneration: generation)
            return
        }
        guard let proxy = getProxy(errorHandler: { [weak self] _ in
            self?.reportLeaseLost(heartbeatGeneration: generation)
        }) else {
            reportLeaseLost(heartbeatGeneration: generation)
            return
        }

        proxy.heartbeat { [weak self] leaseIsActive in
            if !leaseIsActive {
                self?.reportLeaseLost(heartbeatGeneration: generation)
            }
        }
    }

    private func expireCustomControl(heartbeatGeneration generation: UInt64) {
        guard stopHeartbeat(
            invalidateCommands: true,
            ifGenerationMatches: generation
        ) else { return }

        guard let proxy = getProxy(errorHandler: { [weak self] _ in
            self?.reportLeaseLost()
        }) else {
            reportLeaseLost()
            return
        }
        proxy.resetToAutomatic { [weak self] result in
            self?.logger.notice("Custom temperature expiry reset completed with result \(result)")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fanControlLeaseLost, object: nil)
        }
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
        let epoch = currentControlEpoch()
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.setFanMode(index: index, manual: manual) { result in
            if result == kIOReturnSuccess, manual {
                self.startHeartbeat(for: epoch)
            }
            completion?(result == kIOReturnSuccess)
        }
    }

    func setFanTargetRPM(index: Int, rpm: Int, completion: ((Bool) -> Void)? = nil) {
        let epoch = currentControlEpoch()
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.setFanTargetRPM(index: index, rpm: rpm) { result in
            if result == kIOReturnSuccess {
                self.startHeartbeat(for: epoch)
            }
            completion?(result == kIOReturnSuccess)
        }
    }

    func setFanTargets(
        _ targets: [(index: Int, rpm: Int)],
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !targets.isEmpty else {
            completion?(true)
            return
        }

        let epoch = currentControlEpoch()
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.setFanTargets(
            indices: targets.map { NSNumber(value: $0.index) },
            rpms: targets.map { NSNumber(value: $0.rpm) }
        ) { result in
            if result == kIOReturnSuccess {
                self.startHeartbeat(for: epoch)
            } else if self.isCurrentControlEpoch(epoch) {
                self.resetToAutomatic()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .fanControlLeaseLost, object: nil)
                }
            }
            completion?(result == kIOReturnSuccess)
        }
    }

    func resetToAutomatic(completion: ((Bool) -> Void)? = nil) {
        stopHeartbeat(invalidateCommands: true)
        guard let proxy = getProxy(errorHandler: { _ in completion?(false) }) else {
            completion?(false)
            return
        }
        proxy.resetToAutomatic { result in
            completion?(result == kIOReturnSuccess)
        }
    }
}
