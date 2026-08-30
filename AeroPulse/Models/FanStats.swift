//
//  FanStats.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import Foundation

struct FanInfo: Identifiable, Equatable {
    let id: Int
    let name: String
    var currentRPM: Int
    var minRPM: Int
    var maxRPM: Int
    var targetRPM: Int?
    var mode: FanMode

    init(
        id: Int,
        name: String,
        currentRPM: Int,
        minRPM: Int,
        maxRPM: Int,
        targetRPM: Int? = nil,
        mode: FanMode = .auto
    ) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.targetRPM = targetRPM
        self.mode = mode
    }
}

enum FanMode: String, CaseIterable, Identifiable, Equatable {
    case auto = "Auto"
    case fullBlast = "Max"
    case manual = "Manual"
    case custom = "Rules"

    var id: String { rawValue }
}

struct FanThresholdRule: Identifiable, Codable, Equatable {
    var id: UUID
    var temperature: Double
    var speedPercentage: Int

    init(id: UUID = UUID(), temperature: Double, speedPercentage: Int) {
        self.id = id
        self.temperature = temperature
        self.speedPercentage = max(0, min(100, speedPercentage))
    }

    static let defaultRules: [FanThresholdRule] = [
        FanThresholdRule(temperature: 45, speedPercentage: 30),
        FanThresholdRule(temperature: 60, speedPercentage: 50),
        FanThresholdRule(temperature: 72, speedPercentage: 75),
        FanThresholdRule(temperature: 82, speedPercentage: 100),
    ]
}

struct SensorInfo: Identifiable, Equatable {
    let id: String
    let name: String
    var temperature: Double
    var isEnabled: Bool
}
