//
//  MenuBarDashboardView.swift
//  AeroPulse
//

import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]
    private let actionButtonHeight: CGFloat = 28
    private let actionButtonFont = Font.system(size: 10, weight: .semibold)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            fanQuickControlSection

            LazyVGrid(columns: columns, spacing: 10) {
                MetricCard(
                    title: AppStrings.download,
                    value: networkViewModel.downloadSpeed,
                    icon: AppImages.download,
                    color: .blue,
                    subtitle: "\(AppStrings.total): \(networkViewModel.downloadTotal)"
                ).equatable()
                MetricCard(
                    title: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    icon: AppImages.upload,
                    color: .green,
                    subtitle: "\(AppStrings.total): \(networkViewModel.uploadTotal)"
                ).equatable()
                MetricCard(
                    title: AppStrings.diskRead,
                    value: networkViewModel.diskReadSpeed,
                    icon: AppImages.diskRead,
                    color: .teal,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskReadTotal)"
                ).equatable()
                MetricCard(
                    title: AppStrings.diskWrite,
                    value: networkViewModel.diskWriteSpeed,
                    icon: AppImages.diskWrite,
                    color: .mint,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskWriteTotal)"
                ).equatable()
                MetricCard(
                    title: AppStrings.diskCapacity,
                    value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)",
                    icon: AppImages.diskCapacity,
                    color: .cyan,
                    subtitle: "\(AppStrings.diskFree): \(networkViewModel.diskFreeCapacity) • \(AppStrings.diskUsed): \(networkViewModel.diskUsedPercent)"
                ).equatable()
                MetricCard(
                    title: AppStrings.gpuUsage,
                    value: networkViewModel.gpuUsage,
                    icon: AppImages.gpuUsage,
                    color: .pink
                ).equatable()
                MetricCard(
                    title: AppStrings.cpuUsage,
                    value: networkViewModel.cpuUsage,
                    icon: AppImages.cpuUsage,
                    color: .red,
                    processLines: networkViewModel.topCPUProcesses
                ).equatable()
                MetricCard(
                    title: AppStrings.memory,
                    value: networkViewModel.memoryUsage,
                    icon: AppImages.memory,
                    color: .brown,
                    subtitle: "\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)",
                    processLines: networkViewModel.topMemoryProcesses
                ).equatable()
                MetricCard(
                    title: AppStrings.powerUsage,
                    value: networkViewModel.powerUsage,
                    icon: AppImages.powerUsage,
                    color: .yellow
                ).equatable()
                MetricCard(
                    title: AppStrings.chargingPower,
                    value: networkViewModel.chargingPowerUsage,
                    icon: AppImages.chargingPower,
                    color: .orange,
                    subtitle: networkViewModel.chargingPowerSubtitle
                ).equatable()
            }

            HStack(spacing: 8) {
                Button {
                    DispatchQueue.main.async {
                        openDashboardAndDismiss()
                    }
                } label: {
                    Label(AppStrings.openSystemHub, systemImage: AppImages.window)
                        .font(actionButtonFont)
                        .frame(maxWidth: .infinity, minHeight: actionButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    DispatchQueue.main.async {
                        refreshSnapshot()
                    }
                } label: {
                    Image(systemName: AppImages.refresh)
                        .font(actionButtonFont)
                        .frame(width: 32, height: actionButtonHeight)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(launchAtLoginManager.statusIsWarning ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(launchAtLoginManager.statusText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(AppStrings.quitApplication, systemImage: AppImages.power)
                        .font(actionButtonFont)
                        .frame(minHeight: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red.opacity(0.82))
            }
        }
        .padding(13)
        .frame(width: 368)
        .onAppear {
            networkViewModel.setDetailedSampling(true, source: .menuBarPopover)
            fanViewModel.setDetailedSampling(true, source: .menuBarPopover)
            DispatchQueue.main.async {
                launchAtLoginManager.refreshStatus()
                fanViewModel.refreshHelperStatus()
            }
        }
        .onDisappear {
            networkViewModel.setDetailedSampling(false, source: .menuBarPopover)
            fanViewModel.setDetailedSampling(false, source: .menuBarPopover)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.systemMonitor)
                    .font(.system(size: 15, weight: .bold))
                Text(AppStrings.appName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Circle()
                .fill(SMCService.shared.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
    }

    private var fanQuickControlSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: AppImages.fan)
                        .foregroundColor(.indigo)
                        .font(.system(size: 11, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("FAN MODE")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.secondary)
                            .tracking(0.6)
                        Text("\(fanViewModel.primaryFanRPM) • \(fanViewModel.primaryTemp)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Picker("", selection: Binding(
                    get: { fanViewModel.currentMode },
                    set: { newMode in
                        DispatchQueue.main.async {
                            fanViewModel.setFanMode(newMode)
                        }
                    }
                )) {
                    ForEach(FanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(maxWidth: 190)
            }

            if fanViewModel.currentMode == .manual, let firstFan = fanViewModel.fans.first {
                let currentTarget = fanViewModel.manualTargetRPM[firstFan.id] ?? firstFan.currentRPM
                HStack(spacing: 8) {
                    Text("RPM")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(currentTarget) },
                            set: { fanViewModel.setTargetRPM(fanIndex: firstFan.id, rpm: Int($0)) }
                        ),
                        in: Double(firstFan.minRPM)...Double(firstFan.maxRPM),
                        step: 50
                    )
                    .controlSize(.mini)
                    Text("\(currentTarget)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.indigo)
                        .frame(minWidth: 34, alignment: .trailing)
                }
                .padding(.top, 1)
            } else if fanViewModel.currentMode == .custom, let activeRule = fanViewModel.activeRule {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text("Triggered: ≥ \(Int(activeRule.temperature))°C → \(activeRule.speedPercentage)%")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.top, 1)
            } else if fanViewModel.currentMode == .custom, fanViewModel.isRulesStandby {
                HStack(spacing: 4) {
                    Circle().fill(Color.secondary).frame(width: 5, height: 5)
                    Text("Rules Standby · Below minimum threshold")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 1)
            }
        }
        .padding(9)
        .liquidGlassCard(cornerRadius: 10, tint: .indigo, style: .regular, shadowOpacity: 0.08)
    }

    private func refreshSnapshot() {
        SMCService.shared.reconnect()
        fanViewModel.startMonitoring()
        fanViewModel.refreshHelperStatus()
    }

    private func openDashboardAndDismiss() {
        let menuWindow = NSApp.keyWindow

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let dashboardWindow = dashboardWindow() {
            dashboardWindow.makeKeyAndOrderFront(nil)
            dashboardWindow.orderFrontRegardless()
        } else {
            openWindow(id: "dashboard")

            DispatchQueue.main.async {
                if let createdWindow = dashboardWindow() {
                    createdWindow.makeKeyAndOrderFront(nil)
                    createdWindow.orderFrontRegardless()
                }
            }
        }

        DispatchQueue.main.async {
            let keepWindow = dashboardWindow()

            menuWindow?.orderOut(nil)
            menuWindow?.close()

            for window in NSApp.windows where window !== keepWindow && window.isVisible {
                let className = String(describing: type(of: window))
                if className.contains("Panel")
                    || className.contains("Popover")
                    || className.contains("Status")
                    || window.level != .normal
                {
                    window.orderOut(nil)
                }
            }
        }
    }

    private func dashboardWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.title == AppStrings.appName
                || window.identifier?.rawValue == "dashboard"
        }
    }
}

private struct MetricCard: View, Equatable {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var processLines: [NetworkViewModel.ProcessUsageLine] = []

    static func == (lhs: MetricCard, rhs: MetricCard) -> Bool {
        lhs.title == rhs.title
            && lhs.value == rhs.value
            && lhs.icon == rhs.icon
            && lhs.color == rhs.color
            && lhs.subtitle == rhs.subtitle
            && lhs.processLines == rhs.processLines
    }

    private var cardMinHeight: CGFloat {
        if processLines.isEmpty {
            return 88
        }
        return 124
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 12)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.9)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if processLines.isEmpty {
                Text(" ")
                    .font(.system(size: 9, weight: .semibold))
                    .hidden()
            }

            if !processLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(processLines.prefix(3))) { line in
                        HStack(spacing: 6) {
                            Text(line.name)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(line.value)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .frame(minWidth: 34, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .liquidGlassCard(cornerRadius: 11, tint: color, style: .regular, shadowOpacity: 0.08)
    }
}
