import Foundation

struct AppStrings {
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Flux"
    }

    static let systemMonitor = "System Monitor"

    static let download = "Download"
    static let upload = "Upload"
    static let diskRead = "Disk Read"
    static let diskWrite = "Disk Write"
    static let diskCapacity = "Disk Capacity"
    static let diskFree = "Free"
    static let diskUsed = "Used"
    static let total = "Total"
    static let cpuUsage = "CPU Usage"
    static let memory = "Memory"
    static let fan = "Fan"
    static let systemTemp = "System Temp"
    static let cpuTemp = "CPU Temp"

    static let rpmUnit = "RPM"
    static let temperatureFormat = "%.1f\u{00B0}C"

    static let menuBarMetrics = "Menu Bar Layout"
    static let launchAtLogin = "Launch at Login"
    static let launchAtLoginDescription = "Start status menu item when you sign in"
    static let launchAtLoginRefresh = "Refresh"
    static let launchAtLoginErrorPrefix = "Error:"
    static let refreshRate = "Sampling Frequency"
    static let privilegedHelper = "Privileged Helper"
    static let helperInstalled = "Helper installed and service registered."
    static let helperMissing = "Helper not installed."
    static let helperInstalling = "Requesting administrator permission..."
    static let helperInstallSuccess = "Helper installed successfully."
    static let helperInstallFailedPrefix = "Helper install failed:"
    static let helperInstall = "Install Helper"
    static let helperReinstall = "Reinstall"

    static let hardwareConnection = "Hardware Bridge"
    static let hardwareConnected = "SMC Connected"
    static let hardwareDisconnected = "SMC Disconnected"
    static let retryConnection = "Reconnect Bridge"
    static let unknownConnectionError = "Unable to reach SMC service."

    static let thermalSensors = "Thermal Sensors"
    static let thermalSensorsUpperCase = "THERMAL SENSORS"
    static let sensorsDetected = "sensors detected"
    static let viewThermalDetails = "View thermal details"
    static let cpu = "CPU"
    static let gpu = "GPU"
    static let system = "System"
    static let pCoreFilter = "P-Core"
    static let eCoreFilter = "E-Core"

    static let noData = "No data available"
    static let openSystemHub = "Open Dashboard"
    static let quitApplication = "Quit Flux"
}

struct AppImages {
    static let rocket = "rocket.fill"
    static let download = "arrow.down.circle.fill"
    static let upload = "arrow.up.circle.fill"
    static let diskRead = "internaldrive"
    static let diskWrite = "internaldrive.fill"
    static let diskCapacity = "chart.pie.fill"
    static let cpuUsage = "cpu"
    static let memory = "memorychip.fill"
    static let fan = "fanblades.fill"
    static let temperature = "thermometer.medium"
    static let gauge = "gauge.with.needle"
    static let checklist = "checklist"
    static let launchAtLogin = "person.badge.key.fill"
    static let helper = "lock.shield.fill"
    static let refresh = "arrow.clockwise"
    static let cpu = "cpu"
    static let power = "power.circle.fill"
    static let window = "macwindow"
    static let info = "info.circle.fill"
    static let close = "xmark.circle.fill"
}
