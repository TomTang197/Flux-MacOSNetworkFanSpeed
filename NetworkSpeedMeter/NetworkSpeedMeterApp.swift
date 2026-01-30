//
//  NetworkSpeedMeterApp.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

@main
struct NetworkSpeedMeterApp: App {
    @StateObject private var sharedViewModel = NetworkViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: sharedViewModel)
        }

        MenuBarExtra {
            SettingsView(viewModel: sharedViewModel)
        } label: {
            MenuBarView(viewModel: sharedViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
