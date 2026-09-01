import Foundation

enum PowerTelemetryProcessing {
    static func watts(fromMilliwatts rawMilliwatts: Double) -> Double? {
        guard rawMilliwatts.isFinite else { return nil }
        return rawMilliwatts / 1_000
    }

    static func systemPowerWatts(
        systemLoadWatts: Double?,
        systemPowerInWatts: Double?,
        batteryPowerWatts: Double?
    ) -> Double? {
        if let systemLoadWatts,
           systemLoadWatts.isFinite,
           systemLoadWatts >= 0 {
            return systemLoadWatts
        }

        if let systemPowerInWatts,
           let batteryPowerWatts {
            let derivedWatts = systemPowerInWatts - batteryPowerWatts
            if derivedWatts.isFinite, derivedWatts > 0 {
                return derivedWatts
            }
        }

        return nil
    }

    static func formatSystemPowerWatts(_ watts: Double) -> String {
        guard watts.isFinite, watts >= 0 else { return "-- W" }
        if watts < 0.000_5 { return "0.000 W" }
        if watts < 1 { return String(format: "%.3f W", watts) }
        if watts < 10 { return String(format: "%.2f W", watts) }
        if watts < 100 { return String(format: "%.1f W", watts) }
        return String(format: "%.0f W", watts)
    }
}
