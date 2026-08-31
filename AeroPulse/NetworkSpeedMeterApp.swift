//
//  NetworkSpeedMeterApp.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

@main
struct NetworkSpeedMeterApp: App {
    @StateObject private var networkViewModel = NetworkViewModel()
    @StateObject private var fanViewModel = FanViewModel()
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    @AppStorage(VisualEffectsPreferences.storageKey) private var reduceVisualEffects =
        VisualEffectsPreferences.defaultValue

    init() {
        // Set as accessory app (no dock icon, menu bar only)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Window(AppStrings.appName, id: "dashboard") {
            ContentView(
                networkViewModel: networkViewModel,
                fanViewModel: fanViewModel,
                launchAtLoginManager: launchAtLoginManager
            )
            .environment(\.visualEffectsReduced, reduceVisualEffects)
        }
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarDashboardView(
                networkViewModel: networkViewModel,
                fanViewModel: fanViewModel,
                launchAtLoginManager: launchAtLoginManager
            )
            .environment(\.visualEffectsReduced, reduceVisualEffects)
        } label: {
            MenuBarView(networkViewModel: networkViewModel, fanViewModel: fanViewModel)
        }

        .menuBarExtraStyle(.window)
    }
}
