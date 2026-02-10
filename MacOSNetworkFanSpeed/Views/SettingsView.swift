//
//  SettingsView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

/// `SettingsView` provides a unified UI for configuring the app, used in both the menu bar and the main window.
struct SettingsView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    var showWindowButton: Bool = true
    var preferredWidth: CGFloat? = 280
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(AppStrings.systemMonitor)
                    .font(.headline)
                Spacer()

                // Open main app window
                if showWindowButton {
                    Button {
                        openOrFocusDashboard()
                    } label: {
                        Image(systemName: AppImages.window)
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.openSystemHub)
                }

                Image(systemName: AppImages.gauge)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Real-time stats display (Network & Fan)
            VStack(spacing: 0) {
                StatRow(
                    icon: AppImages.download,
                    label: AppStrings.download,
                    value: networkViewModel.downloadSpeed,
                    color: .blue
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.upload,
                    label: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    color: .green
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.diskRead,
                    label: AppStrings.diskRead,
                    value: networkViewModel.diskReadSpeed,
                    color: .teal
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.diskWrite,
                    label: AppStrings.diskWrite,
                    value: networkViewModel.diskWriteSpeed,
                    color: .mint
                )
                .padding(.vertical, 4)

                Divider().opacity(0.3)

                StatRow(
                    icon: AppImages.temperature,
                    label: AppStrings.cpuTemp,
                    value: fanViewModel.primaryTemp,
                    color: .orange
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.fan,
                    label: fanViewModel.fans.first?.name ?? AppStrings.fan,
                    value: fanViewModel.primaryFanRPM,
                    color: .blue
                )
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Menu Bar Metrics Selection
            VStack(alignment: .leading, spacing: 8) {
                Label(AppStrings.menuBarMetrics, systemImage: AppImages.checklist)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    ForEach(MetricType.allCases) { metric in
                        Toggle(
                            isOn: Binding(
                                get: { networkViewModel.enabledMetrics.contains(metric) },
                                set: { isEnabled in
                                    if isEnabled {
                                        networkViewModel.enabledMetrics.insert(metric)
                                    } else {
                                        networkViewModel.enabledMetrics.remove(metric)
                                    }
                                }
                            )
                        ) {
                            HStack {
                                Text("\(metric.icon)")
                                Text(metric.rawValue)
                                    .font(.system(size: 12))
                            }
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
            }

            HStack {
                Label(AppStrings.refreshRate, systemImage: AppImages.refresh)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $networkViewModel.refreshInterval) {
                    Text("0.5s").tag(0.5)
                    Text("1.0s").tag(1.0)
                    Text("2.0s").tag(2.0)
                    Text("5.0s").tag(5.0)
                }
                .pickerStyle(.menu)
                .frame(width: 70)
            }

            Divider().opacity(0.3)

            // Fan Control Presets
            VStack(alignment: .leading, spacing: 8) {
                Label(AppStrings.fanControlPreset, systemImage: AppImages.fanSettings)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker(
                    "",
                    selection: Binding(
                        get: { fanViewModel.activePreset },
                        set: { fanViewModel.setActivePreset($0) }
                    )
                ) {
                    Text(AppStrings.presetAutomatic).tag("Automatic")
                    Text(AppStrings.presetManual).tag("Manual")
                    Text(AppStrings.presetFullBlast).tag("Full Blast")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if fanViewModel.activePreset == "Manual" {
                    ForEach(fanViewModel.fans) { fan in
                        ManualFanControlRow(
                            fan: fan,
                            initialRPM: fanViewModel.manualDisplayRPM(for: fan.id, fallback: fan.currentRPM)
                        ) { rpm in
                            fanViewModel.setManualRPM(fanID: fan.id, rpm: rpm)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Divider().opacity(0.3)

            // Hardware Diagnostics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(AppStrings.hardwareConnection, systemImage: AppImages.cpu)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Circle()
                        .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                        .frame(width: 8, height: 8)
                }

                if !SMCService.shared.isConnected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SMCService.shared.lastError ?? AppStrings.unknownConnectionError)
                            .font(.system(size: 9))
                            .foregroundColor(.red.opacity(0.8))

                        Button {
                            SMCService.shared.reconnect()
                        } label: {
                            Text(AppStrings.retryConnection)
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                } else {
                    Text(AppStrings.smcInterfaceActive)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.2)

                HStack {
                    Label(AppStrings.privilegedHelper, systemImage: AppImages.helper)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Circle()
                        .fill(fanViewModel.helperInstalled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }

                Text(fanViewModel.helperStatusMessage)
                    .font(.system(size: 9))
                    .foregroundColor(fanViewModel.helperInstalled ? .secondary : .orange)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        fanViewModel.installHelper()
                    } label: {
                        if fanViewModel.isInstallingHelper {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(AppStrings.installing)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text(fanViewModel.helperInstalled ? AppStrings.reinstallHelper : AppStrings.installHelper)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(fanViewModel.isInstallingHelper)

                    Button {
                        fanViewModel.refreshHelperStatus()
                    } label: {
                        Text(AppStrings.refresh)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(fanViewModel.isInstallingHelper)
                }
            }

            Divider().opacity(0.3)

            Button(
                role: .destructive,
                action: {
                    NSApplication.shared.terminate(nil)
                }
            ) {
                HStack {
                    Image(systemName: AppImages.power)
                    Text(AppStrings.quitApplication)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.red.opacity(0.8))
        }
        .padding(16)
        .frame(width: preferredWidth, alignment: .leading)
        .frame(maxWidth: preferredWidth == nil ? .infinity : preferredWidth, alignment: .leading)
    }

    private func openOrFocusDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Close menu bar popover if it's the key window
        NSApp.keyWindow?.close()

        if let window = NSApp.windows.first(where: {
            $0.title == AppStrings.appName
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            openWindow(id: "dashboard")
        }
    }
}

private struct ManualFanControlRow: View {
    let fan: FanInfo
    let onRPMChange: (Int) -> Void
    @State private var sliderRPM: Double

    init(fan: FanInfo, initialRPM: Int, onRPMChange: @escaping (Int) -> Void) {
        self.fan = fan
        self.onRPMChange = onRPMChange
        let clampedInitial = min(max(initialRPM, fan.minRPM), fan.maxRPM)
        _sliderRPM = State(initialValue: Double(clampedInitial))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fan.name)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(sliderRPM)) \(AppStrings.rpmUnit)")
                    .font(.system(size: 10, design: .monospaced))
            }

            Slider(
                value: Binding(
                    get: { sliderRPM },
                    set: { newValue in
                        let clamped = min(max(newValue, Double(fan.minRPM)), Double(fan.maxRPM))
                        sliderRPM = clamped
                        onRPMChange(Int(clamped.rounded()))
                    }
                ),
                in: Double(fan.minRPM)...Double(fan.maxRPM),
                step: 100
            )
            .controlSize(.small)
        }
    }
}

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(label)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
