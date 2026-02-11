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
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    var showWindowButton: Bool = true
    var preferredWidth: CGFloat? = 280
    @Environment(\.openWindow) private var openWindow

    private var sortedFans: [FanInfo] {
        fanViewModel.fans.sorted { $0.id < $1.id }
    }

    private var averageFanRPM: Int {
        guard !sortedFans.isEmpty else { return 0 }
        let total = sortedFans.reduce(0) { $0 + $1.currentRPM }
        return total / sortedFans.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection

            SettingsCard(title: "Live Throughput", symbol: AppImages.gauge, tint: .blue) {
                VStack(spacing: 8) {
                    StatRow(
                        icon: AppImages.download,
                        label: AppStrings.download,
                        value: networkViewModel.downloadSpeed,
                        color: .blue
                    )
                    StatRow(
                        icon: AppImages.upload,
                        label: AppStrings.upload,
                        value: networkViewModel.uploadSpeed,
                        color: .green
                    )
                    StatRow(
                        icon: AppImages.diskRead,
                        label: AppStrings.diskRead,
                        value: networkViewModel.diskReadSpeed,
                        color: .teal
                    )
                    StatRow(
                        icon: AppImages.diskWrite,
                        label: AppStrings.diskWrite,
                        value: networkViewModel.diskWriteSpeed,
                        color: .mint
                    )
                    StatRow(
                        icon: AppImages.diskCapacity,
                        label: AppStrings.diskCapacity,
                        value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)",
                        color: .cyan
                    )
                    Divider().opacity(0.22)
                    StatRow(
                        icon: AppImages.temperature,
                        label: AppStrings.cpuTemp,
                        value: fanViewModel.primaryTemp,
                        color: .orange
                    )
                }
            }

            SettingsCard(title: "Fan RPM Monitor", symbol: AppImages.fan, tint: .indigo) {
                if sortedFans.isEmpty {
                    Text(AppStrings.noData)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    HStack(spacing: 10) {
                        FanBadge(title: "Fans", value: "\(sortedFans.count)")
                        FanBadge(title: "Average", value: "\(averageFanRPM) \(AppStrings.rpmUnit)")
                    }

                    VStack(spacing: 8) {
                        ForEach(sortedFans) { fan in
                            FanSpeedRow(fan: fan)
                        }
                    }
                }
            }

            SettingsCard(title: AppStrings.menuBarMetrics, symbol: AppImages.checklist, tint: .cyan) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    ForEach(MetricType.allCases) { metric in
                        metricChip(metric)
                    }
                }
            }

            SettingsCard(title: AppStrings.refreshRate, symbol: AppImages.refresh, tint: .mint) {
                HStack {
                    Text("Sampling")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $networkViewModel.refreshInterval) {
                        Text("0.5s").tag(0.5)
                        Text("1.0s").tag(1.0)
                        Text("2.0s").tag(2.0)
                        Text("5.0s").tag(5.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 78)
                }
            }

            SettingsCard(title: AppStrings.launchAtLogin, symbol: AppImages.launchAtLogin, tint: .blue) {
                Toggle(
                    isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppStrings.launchAtLogin)
                            .font(.system(size: 11, weight: .semibold))
                        Text(AppStrings.launchAtLoginDescription)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack(spacing: 6) {
                    Circle()
                        .fill(launchAtLoginManager.statusIsWarning ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text(launchAtLoginManager.statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(launchAtLoginManager.statusIsWarning ? .orange : .secondary)
                    Spacer()
                    Button(AppStrings.launchAtLoginRefresh) {
                        launchAtLoginManager.refreshStatus()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                }

                if let error = launchAtLoginManager.lastError, !error.isEmpty {
                    Text("\(AppStrings.launchAtLoginErrorPrefix) \(error)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(
                title: AppStrings.hardwareConnection,
                symbol: AppImages.cpu,
                tint: SMCService.shared.isConnected ? .blue : .red
            ) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                        .frame(width: 8, height: 8)
                    Text(
                        SMCService.shared.isConnected
                            ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SMCService.shared.isConnected ? .primary : .red)
                }

                if !SMCService.shared.isConnected {
                    Text(SMCService.shared.lastError ?? AppStrings.unknownConnectionError)
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

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
            }

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
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.red.opacity(0.82))
        }
        .padding(16)
        .frame(width: preferredWidth, alignment: .leading)
        .frame(maxWidth: preferredWidth == nil ? .infinity : preferredWidth, alignment: .leading)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.systemMonitor)
                    .font(.system(size: 16, weight: .bold))
                Text("Live telemetry and fan RPM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

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
        }
    }

    private func metricChip(_ metric: MetricType) -> some View {
        let enabled = networkViewModel.enabledMetrics.contains(metric)

        return Button {
            if enabled {
                networkViewModel.enabledMetrics.remove(metric)
            } else {
                networkViewModel.enabledMetrics.insert(metric)
            }
        } label: {
            HStack(spacing: 6) {
                metric.icon
                Text(metric.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(enabled ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        enabled
                            ? Color.blue.opacity(0.85)
                            : Color.primary.opacity(0.07)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func openOrFocusDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Close menu bar popover if it's the key window.
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

private struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .foregroundColor(tint)
                    .font(.system(size: 12, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.9)
                    .foregroundColor(.secondary)
                Spacer()
            }

            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(NSColor.controlBackgroundColor).opacity(0.65),
                            Color(NSColor.windowBackgroundColor).opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

private struct FanBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.7)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

private struct FanSpeedRow: View {
    let fan: FanInfo

    private var utilization: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        let range = Double(fan.maxRPM - fan.minRPM)
        let normalized = Double(fan.currentRPM - fan.minRPM) / range
        return min(max(normalized, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(fan.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(fan.currentRPM) \(AppStrings.rpmUnit)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            ProgressView(value: utilization)
                .progressViewStyle(.linear)
                .tint(.indigo.opacity(0.92))

            HStack {
                Text("MIN \(fan.minRPM)")
                Spacer()
                Text("MAX \(fan.maxRPM)")
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.primary.opacity(0.045))
        )
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
                .font(.system(size: 14, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
