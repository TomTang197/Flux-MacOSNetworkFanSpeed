//
//  MetricType.swift
//  MacOSNetworkFanSpeed
//

import SwiftUI

/// Represents individual metrics that can be displayed in the menu bar.
enum MetricType: String, CaseIterable, Identifiable, Codable {
    case download = "Download"
    case upload = "Upload"
    case diskRead = "Disk Read"
    case diskWrite = "Disk Write"
    case temperature = "Temp"
    case fan = "Fan"

    var id: String { self.rawValue }

    var emoji: String {
        switch self {
        case .download: return "⏬"
        case .upload: return "⏫"
        case .diskRead: return "💾"
        case .diskWrite: return "💽"
        case .temperature: return "🌡️"
        case .fan: return "🌀"
        }
    }

    var icon: Text {
        switch self {
        case .download:
            return Text("\(Image(systemName: "arrow.down.circle"))")
        case .upload:
            return Text("\(Image(systemName: "arrow.up.circle"))")
        case .diskRead:
            return Text("\(Image(systemName: "internaldrive"))")
        case .diskWrite:
            return Text("\(Image(systemName: "internaldrive.fill"))")
        case .fan:
            return Text("\(Image(systemName: "fanblades"))")
        case .temperature:
            return Text("\(Image(systemName: "thermometer"))")
        }
    }
}
