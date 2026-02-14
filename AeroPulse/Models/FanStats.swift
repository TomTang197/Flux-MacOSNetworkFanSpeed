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

enum FanMode: String, Equatable {
    case auto = "Auto"
    case manual = "Manual"
    case fullBlast = "Full Blast"
}

struct SensorInfo: Identifiable, Equatable {
    let id: String
    let name: String
    var temperature: Double
    var isEnabled: Bool
}
