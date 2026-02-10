//
//  FanStats.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Foundation

struct FanInfo: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    var currentRPM: Int
    var minRPM: Int
    var maxRPM: Int
    var targetRPM: Int?
    var mode: FanMode
}

enum FanMode: String, Codable, Equatable {
    case auto = "Auto"
    case manual = "Manual"
    case fullBlast = "Full Blast"
}

struct SensorInfo: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var temperature: Double
    var isEnabled: Bool
}
