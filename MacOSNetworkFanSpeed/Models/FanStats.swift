//
//  FanStats.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Foundation

struct FanInfo: Identifiable {
    let id: Int
    let name: String
    var currentRPM: Int
    var minRPM: Int
    var maxRPM: Int
    var isManual: Bool
}
