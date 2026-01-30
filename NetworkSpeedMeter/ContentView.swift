//
//  ContentView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: NetworkViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Network Speed Dashboard")
                .font(.headline)

            HStack(spacing: 40) {
                SpeedMetricView(
                    title: "Download",
                    speed: viewModel.downloadSpeed,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                SpeedMetricView(
                    title: "Upload",
                    speed: viewModel.uploadSpeed,
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)

            Divider()

            SettingsView(viewModel: viewModel)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 450)
    }
}

struct SpeedMetricView: View {
    let title: String
    let speed: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(speed)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
        }
    }
}

#Preview {
    ContentView(viewModel: NetworkViewModel())
}
