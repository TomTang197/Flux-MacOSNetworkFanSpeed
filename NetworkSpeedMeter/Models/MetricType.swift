//
//  MetricType.swift
//  NetworkSpeedMeter
//

import SwiftUI

/// Represents individual metrics that can be displayed in the menu bar.
enum MetricType: String, CaseIterable, Identifiable, Codable {
    case download = "Download"
    case upload = "Upload"
    case fan = "Fan"
    case temperature = "Temp"

    var id: String { self.rawValue }

    var emoji: String {
        switch self {
        case .download: return "⏬"
        case .upload: return "⏫"
        case .fan: return "🌀"
        case .temperature: return "🌡️"
        }
    }
    
    var icon: Text {
        switch self {
        case .download:
            return Text("\(Image(systemName: "arrow.down.circle"))")
        case .upload:
            return Text("\(Image(systemName: "arrow.up.circle"))")
        case .fan:
            return Text("\(Image(systemName: "fanblades"))")
        case .temperature:
            return Text("\(Image(systemName: "thermometer"))")
        }
    }
}
