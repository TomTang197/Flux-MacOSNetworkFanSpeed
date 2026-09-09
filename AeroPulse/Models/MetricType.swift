//
//  MetricType.swift
//  AeroPulse
//

import SwiftUI

/// Represents individual metrics that can be displayed in the menu bar.
enum MetricType: String, CaseIterable, Identifiable, Codable {
    case download = "Download"
    case upload = "Upload"
    case diskRead = "Disk Read"
    case diskWrite = "Disk Write"
    case cpu = "CPU"
    case power = "Power"
    case chargingPower = "Charge"
    case gpu = "GPU"
    case memory = "Memory"
    case temperature = "Temp"
    case fan = "Fan"

    var id: String { self.rawValue }

    var localizedTitle: String {
        let isZh = LanguageManager.shared.effectiveLanguage == .zhHans
        switch self {
        case .download: return isZh ? "下载" : "Download"
        case .upload: return isZh ? "上传" : "Upload"
        case .diskRead: return isZh ? "磁盘读" : "Disk Read"
        case .diskWrite: return isZh ? "磁盘写" : "Disk Write"
        case .cpu: return "CPU"
        case .power: return isZh ? "整机功耗" : "Power"
        case .chargingPower: return isZh ? "电池功耗" : "Charge"
        case .gpu: return "GPU"
        case .memory: return isZh ? "内存" : "Memory"
        case .temperature: return isZh ? "温度" : "Temp"
        case .fan: return isZh ? "风扇" : "Fan"
        }
    }

    var emoji: String {
        switch self {
        case .download: return "⏬"
        case .upload: return "⏫"
        case .diskRead: return "💾"
        case .diskWrite: return "💽"
        case .cpu: return "🖥️"
        case .power: return "⚡"
        case .chargingPower: return "🔋"
        case .gpu: return "🎮"
        case .memory: return "🧠"
        case .temperature: return "🌡️"
        case .fan: return "🌀"
        }
    }

    var symbolName: String {
        switch self {
        case .download:
            return "arrow.down.circle"
        case .upload:
            return "arrow.up.circle"
        case .diskRead:
            return "internaldrive"
        case .diskWrite:
            return "internaldrive.fill"
        case .cpu:
            return "cpu"
        case .power:
            return AppImages.powerUsage
        case .chargingPower:
            return AppImages.chargingPower
        case .gpu:
            return AppImages.gpuUsage
        case .memory:
            return "memorychip"
        case .fan:
            return "fanblades"
        case .temperature:
            return "thermometer"
        }
    }

    var icon: Text {
        Text("\(Image(systemName: symbolName))")
    }
}
