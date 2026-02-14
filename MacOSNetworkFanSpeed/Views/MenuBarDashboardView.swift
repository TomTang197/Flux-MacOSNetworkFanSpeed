//
//  MenuBarDashboardView.swift
//  MacOSNetworkFanSpeed
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            LazyVGrid(columns: columns, spacing: 10) {
                MetricCard(
                    title: AppStrings.download,
                    value: networkViewModel.downloadSpeed,
                    icon: AppImages.download,
                    color: .blue,
                    subtitle: "\(AppStrings.total): \(networkViewModel.downloadTotal)"
                )
                MetricCard(
                    title: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    icon: AppImages.upload,
                    color: .green,
                    subtitle: "\(AppStrings.total): \(networkViewModel.uploadTotal)"
                )
                MetricCard(
                    title: AppStrings.diskRead,
                    value: networkViewModel.diskReadSpeed,
                    icon: AppImages.diskRead,
                    color: .teal,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskReadTotal)"
                )
                MetricCard(
                    title: AppStrings.diskWrite,
                    value: networkViewModel.diskWriteSpeed,
                    icon: AppImages.diskWrite,
                    color: .mint,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskWriteTotal)"
                )
                MetricCard(
                    title: AppStrings.cpuUsage,
                    value: networkViewModel.cpuUsage,
                    icon: AppImages.cpuUsage,
                    color: .red
                )
                MetricCard(
                    title: AppStrings.memory,
                    value: networkViewModel.memoryUsage,
                    icon: AppImages.memory,
                    color: .brown,
                    subtitle: "\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)"
                )
                MetricCard(
                    title: AppStrings.fan,
                    value: fanViewModel.primaryFanRPM,
                    icon: AppImages.fan,
                    color: .indigo
                )
                MetricCard(
                    title: AppStrings.systemTemp,
                    value: fanViewModel.primaryTemp,
                    icon: AppImages.temperature,
                    color: .orange
                )
            }

            HStack(spacing: 8) {
                Button {
                    openDashboardAndDismiss()
                } label: {
                    Label(AppStrings.openSystemHub, systemImage: AppImages.window)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    refreshSnapshot()
                } label: {
                    Image(systemName: AppImages.refresh)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(launchAtLoginManager.statusIsWarning ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(launchAtLoginManager.statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(AppStrings.quitApplication, systemImage: AppImages.power)
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 368)
        .onAppear {
            fanViewModel.refreshHelperStatus()
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

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(" ")
                    .font(.system(size: 9, weight: .semibold))
                    .hidden()
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .liquidGlassCard(cornerRadius: 12, tint: color, style: .regular, shadowOpacity: 0.08)
    }
}
