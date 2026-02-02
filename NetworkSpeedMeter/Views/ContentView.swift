//
//  ContentView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Hub")
                        .font(.title2)
                        .fontWeight(.black)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                            .frame(width: 6, height: 6)
                        Text(SMCService.shared.isConnected ? "Hardware Connected" : "Hardware Disconnected")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }

                }
                Spacer()
                if fanViewModel.isMonitoring {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("MONITORING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 30)

            // Single line metric dashboard
            HStack(spacing: 20) {
                DashboardMetricCard(
                    title: "Download",
                    value: networkViewModel.downloadSpeed,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                DashboardMetricCard(
                    title: "Upload",
                    value: networkViewModel.uploadSpeed,
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
                DashboardMetricCard(
                    title: "Fan Speed",
                    value: fanViewModel.primaryFanRPM,
                    icon: "fanblades.fill",
                    color: .indigo
                )
                Button {
                    fanViewModel.isShowingThermalDetails = true
                } label: {
                    DashboardMetricCard(
                        title: "System Temp",
                        value: fanViewModel.primaryTemp,
                        icon: "thermometer.medium",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 30)

            Divider().opacity(0.3).padding(.horizontal, 30)

            // Settings Section
            SettingsView(networkViewModel: networkViewModel, fanViewModel: fanViewModel)
        }
        .padding(.vertical, 30)
        .frame(minWidth: 900, minHeight: 500)
        .onAppear {
            // Show Dock icon when window appears
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // Hide Dock icon when window closes (becomes an accessory app)
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
            ThermalDetailView(fanViewModel: fanViewModel)
        }
    }
}

struct ThermalDetailView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @Environment(\.dismiss) var dismiss

    var performanceCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains("P-Core") }
    }

    var efficiencyCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains("E-Core") }
    }

    var otherSensors: [SensorInfo] {
        fanViewModel.sensors.filter {
            !$0.name.contains("P-Core") && !$0.name.contains("E-Core")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thermal Sensors")
                        .font(.headline)
                    Text("\(fanViewModel.sensors.count) sensors detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Categorized Sensor Columns
            ScrollView {
                HStack(alignment: .top, spacing: 1) {
                    // Performance Cores Column
                    SensorCategoryColumn(
                        title: "P-Core Sensors",
                        sensors: performanceCores,
                        color: .orange
                    )

                    Divider()

                    // Efficiency Cores Column
                    SensorCategoryColumn(
                        title: "E-Core Sensors",
                        sensors: efficiencyCores,
                        color: .green
                    )

                    Divider()

                    // GPU/SSD/System Column
                    SensorCategoryColumn(
                        title: "GPU / SSD / System",
                        sensors: otherSensors,
                        color: .purple
                    )
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

struct SensorCategoryColumn: View {
    let title: String
    let sensors: [SensorInfo]
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))

            if sensors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "thermometer.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No sensors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(sensors) { sensor in
                    HStack {
                        Label {
                            Text(sensor.name)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: iconForSensor(sensor.name))
                                .foregroundColor(colorForSensor(sensor.name))
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%.1f°C", sensor.temperature))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(temperatureColor(sensor.temperature))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.02))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconForSensor(_ name: String) -> String {
        if name.contains("CPU") || name.contains("Performance") || name.contains("Efficiency") {
            return "cpu"
        }
        if name.contains("GPU") { return "memorychip" }
        if name.contains("Airport") { return "wifi" }
        if name.contains("SSD") || name.contains("APPLE SSD") { return "internaldrive" }
        if name.contains("Battery") { return "battery.100" }
        if name.contains("Ambient") { return "sun.max" }
        if name.contains("Power") { return "bolt.fill" }
        return "thermometer"
    }

    private func colorForSensor(_ name: String) -> Color {
        if name.contains("Performance") { return .orange }
        if name.contains("Efficiency") { return .green }
        if name.contains("GPU") { return .purple }
        if name.contains("SSD") || name.contains("APPLE SSD") { return .cyan }
        if name.contains("Airport") { return .blue }
        if name.contains("Power") { return .yellow }
        return .secondary
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp > 80 { return .red }
        if temp > 60 { return .orange }
        return .primary
    }
}

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    ContentView(networkViewModel: NetworkViewModel(), fanViewModel: FanViewModel())
}
