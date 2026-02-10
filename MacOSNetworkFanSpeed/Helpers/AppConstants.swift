//
//  AppConstants.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 03/02/26.
//

import Foundation

struct AppStrings {
    // General
    static var appName: String {
        // $(TARGET_NAME)
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "FluxBar"
    }
    static let systemMonitor = "System Monitor"

    // Metrics
    static let download = "Download"
    static let upload = "Upload"
    static let diskRead = "Disk Read"
    static let diskWrite = "Disk Write"
    static let fan = "Fan"
    static let systemTemp = "System Temp"
    static let cpuTemp = "CPU Temp"

    // Status
    static let hardwareConnected = "Hardware Connected"
    static let hardwareDisconnected = "Hardware Disconnected"
    static let unknownConnectionError = "Unknown connection error"
    static let smcInterfaceActive = "✅ SMC Interface Active"
    static let noData = "No data"

    // Actions
    static let retryConnection = "Retry Connection"
    static let quitApplication = "Quit Application"
    static let viewThermalDetails = "View Thermal Details"
    static let openSystemHub = "Open System Hub"
    static let installHelper = "Install Helper"
    static let reinstallHelper = "Reinstall"
    static let refresh = "Refresh"
    static let installing = "Installing..."

    // Settings
    static let menuBarMetrics = "Menu Bar Metrics"
    static let refreshRate = "Refresh Rate"
    static let fanControlPreset = "Fan Control Preset"
    static let hardwareConnection = "Hardware Connection"
    static let privilegedHelper = "Privileged Helper"
    static let helperInstalled = "Helper installed and launchd service registered."
    static let helperMissing = "Helper missing. Fan writes on Apple Silicon will stay read-only."
    static let helperUnhealthy = "Helper installed but not responding. Click Reinstall."
    static let helperInstalling = "Requesting administrator permission to install helper..."
    static let helperInstallSuccess = "Helper installed. Manual/Full Blast should now work."
    static let helperInstallFailedPrefix = "Helper install failed:"

    // Modes & Presets
    static let modeMini = "Mini"
    static let modeStandard = "Standard"
    static let modePro = "Pro"

    static let presetAutomatic = "Automatic"
    static let presetManual = "Manual"
    static let presetFullBlast = "Full Blast"

    // Thermal View
    static let thermalSensors = "Thermal Sensors"
    static let sensorsDetected = "sensors detected"
    static let thermalSensorsUpperCase = "THERMAL SENSORS"
    static let pCores = "P-Cores"
    static let eCores = "E-Cores"
    static let cpu = "CPU"
    static let gpu = "GPU"
    static let system = "System"
    static let pCoreFilter = "P-Core"
    static let eCoreFilter = "E-Core"

    // Formatting
    static let temperatureFormat = "%.1f°C"
    static let rpmUnit = "RPM"
}

struct AppImages {
    // Metric Icons
    static let download = "arrow.down.circle.fill"
    static let upload = "arrow.up.circle.fill"
    static let diskRead = "internaldrive"
    static let diskWrite = "internaldrive.fill"
    static let fan = "fanblades.fill"
    static let temperature = "thermometer.medium"

    // UI Icons
    static let modeMini = "rectangle.portrait"
    static let modeStandard = "rectangle"
    static let modeExpanded = "rectangle.split.3x1"

    static let info = "info.circle.fill"
    static let close = "xmark.circle.fill"
    static let checklist = "checklist"
    static let refresh = "arrow.clockwise.circle"
    static let fanSettings = "fan.fill"
    static let cpu = "cpu"
    static let helper = "lock.shield"
    static let power = "power.circle.fill"
    static let window = "macwindow"
    static let gauge = "gauge.with.dots.needle.bottom.50percent"
    static let rocket = "rocket.fill"
}
