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

    var symbolName: String {
        switch self {
        case .download:
            return AppImages.download
        case .upload:
            return AppImages.upload
        case .diskRead:
            return AppImages.diskRead
        case .diskWrite:
            return AppImages.diskWrite
        case .cpu:
            return AppImages.cpuUsage
        case .power:
            return AppImages.powerUsage
        case .chargingPower:
            return AppImages.chargingPower
        case .gpu:
            return AppImages.gpuUsage
        case .memory:
            return AppImages.memory
        case .fan:
            return AppImages.fan
        case .temperature:
            return AppImages.temperature
        }
    }

    var icon: Text {
        Text("\(Image(systemName: symbolName))")
    }
}
