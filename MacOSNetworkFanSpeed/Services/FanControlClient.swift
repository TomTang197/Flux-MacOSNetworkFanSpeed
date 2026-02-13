//
//  FanControlClient.swift
//  MacOSNetworkFanSpeed
//
//  Created by BuBu (AI Assistant) on 14/02/26.
//

import Foundation
import IOKit
import os.log

protocol FanControlProviding {
    func setFanMode(index: Int, manual: Bool)
    func setFanTargetRPM(index: Int, rpm: Int)
}

/// Simplified FanControlClient for Read-Only monitoring.
/// Privileged Helper / XPC logic removed as write access is not currently required.
final class FanControlClient: FanControlProviding {
    static let shared = FanControlClient()

    private let smc = SMCService.shared
    private let logger = Logger(subsystem: "com.bandan.me.MacOSNetworkFanSpeed", category: "FanControlClient")

    private init() {}

    // MARK: - FanControlProviding (Stubbed/Legacy)

    func setFanMode(index: Int, manual: Bool) {
        logger.notice("setFanMode called but write access is disabled in this version.")
    }

    func setFanTargetRPM(index: Int, rpm: Int) {
        logger.notice("setFanTargetRPM called but write access is disabled in this version.")
    }
}
