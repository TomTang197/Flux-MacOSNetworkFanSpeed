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
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var showsNetworkDetails = false
    @State private var showsProcessDetails = false
    @State private var showsStorageDetails = false
    @State private var panelHeight: CGFloat = 630

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.35)

            ScrollView {
                VStack(spacing: 8) {
                    MenuBarFanSection(fanViewModel: fanViewModel)
                    networkSection
                    systemSection
                    storageSection
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()
                .opacity(0.35)

            footer
        }
        .frame(width: 380, height: panelHeight)
        .background {
            // MenuBarExtra supplies the system material. Use an opaque fallback
            // when the user asks to reduce effects, rather than nesting glass.
            if reduceTransparency || reduceVisualEffects {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .onAppear {
            updatePanelHeight()
            networkViewModel.setDetailedSampling(true, source: .menuBarPopover)
            fanViewModel.setDetailedSampling(true, source: .menuBarPopover)
            DispatchQueue.main.async {
                launchAtLoginManager.refreshStatus()
                fanViewModel.refreshHelperStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            updatePanelHeight()
        }
        .onDisappear {
            networkViewModel.setDetailedSampling(false, source: .menuBarPopover)
            fanViewModel.setDetailedSampling(false, source: .menuBarPopover)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(AppStrings.appName)
                .font(.system(size: 14, weight: .bold))

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(SMCService.shared.isConnected ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(SMCService.shared.isConnected ? AppStrings.tr(en: "Live", zh: "正常") : AppStrings.tr(en: "Offline", zh: "离线"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Menu {
                Button(AppStrings.launchAtLoginRefresh, systemImage: AppImages.refresh) {
                    DispatchQueue.main.async { refreshSnapshot() }
                }
                Section(AppStrings.launchAtLogin) {
                    Text(loginStatusText)
                }
                Divider()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(AppStrings.quitApplication, systemImage: AppImages.power)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(AppStrings.tr(en: "More options", zh: "更多选项"))
            .help(AppStrings.tr(en: "Refresh, login status and quit", zh: "刷新、登录启动状态与退出"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var networkSection: some View {
        MenuBarSection {
            MenuBarSectionHeading(
                title: AppStrings.tr(en: "Network", zh: "网络"),
                detailTitle: AppStrings.tr(en: "Transfer totals", zh: "累计流量"),
                isExpanded: $showsNetworkDetails
            )
            HStack(spacing: 12) {
                MenuBarReadout(
                    title: AppStrings.download,
                    value: networkViewModel.downloadSpeed,
                    icon: AppImages.download,
                    iconColor: .blue
                )
                .equatable()
                MenuBarReadout(
                    title: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    icon: AppImages.upload,
                    iconColor: .green
                )
                .equatable()
            }
            if showsNetworkDetails {
                Divider()
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Downloaded", zh: "累计下载"),
                    value: networkViewModel.downloadTotal,
                    icon: "arrow.down.to.line.compact",
                    iconColor: .blue
                )
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Uploaded", zh: "累计上传"),
                    value: networkViewModel.uploadTotal,
                    icon: "arrow.up.to.line.compact",
                    iconColor: .green
                )
            }
        }
    }

    private var systemSection: some View {
        MenuBarSection {
            MenuBarSectionHeading(
                title: AppStrings.tr(en: "System", zh: "系统"),
                detailTitle: AppStrings.tr(en: "Top processes", zh: "进程占用"),
                isExpanded: $showsProcessDetails
            )
            HStack(spacing: 12) {
                MenuBarReadout(
                    title: AppStrings.cpu,
                    value: networkViewModel.cpuUsage,
                    icon: AppImages.cpuUsage,
                    iconColor: .red,
                    progress: cpuFraction,
                    progressColors: [Color.orange.opacity(0.9), Color.red]
                )
                .equatable()
                MenuBarReadout(
                    title: AppStrings.gpu,
                    value: networkViewModel.gpuUsage,
                    icon: AppImages.gpuUsage,
                    iconColor: .pink,
                    progress: gpuFraction,
                    progressColors: [Color.pink.opacity(0.85), Color.purple]
                )
                .equatable()
            }

            memorySectionRow

            if showsProcessDetails {
                Divider()
                MenuBarProcessList(title: AppStrings.cpuUsage, lines: networkViewModel.topCPUProcesses)
                    .equatable()
                Divider()
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Memory usage", zh: "内存使用率"),
                    value: networkViewModel.memoryUsage,
                    icon: AppImages.memory,
                    iconColor: .purple
                )
                MenuBarProcessList(title: AppStrings.memory, lines: networkViewModel.topMemoryProcesses)
                    .equatable()
            }
        }
    }

    private var memorySectionRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Image(systemName: AppImages.memory)
                        .foregroundStyle(.purple)
                        .font(.system(size: 10))
                    Text(AppStrings.memory)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)")
                    .fontWeight(.medium)
                    .monospacedDigit()
                if !networkViewModel.memoryUsage.isEmpty && networkViewModel.memoryUsage != "0%" {
                    Text("(\(networkViewModel.memoryUsage))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .font(.system(size: 11))

            if let fraction = memoryFraction {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.85), Color.indigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(proxy.size.width, proxy.size.width * fraction)))
                        }
                    }
            }
        }
        .padding(.top, 2)
    }

    private var storageSection: some View {
        MenuBarSection {
            MenuBarSectionHeading(
                title: AppStrings.tr(en: "Storage & Power", zh: "存储与供电"),
                detailTitle: AppStrings.tr(en: "Storage and power details", zh: "存储与供电详情"),
                isExpanded: $showsStorageDetails
            )

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: AppImages.diskRead)
                        .foregroundStyle(.teal)
                        .font(.system(size: 10.5))
                    Text(AppStrings.tr(en: "Read", zh: "读取"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(networkViewModel.diskReadSpeed)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.system(size: 10.5))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                HStack(spacing: 4) {
                    Image(systemName: AppImages.diskWrite)
                        .foregroundStyle(.mint)
                        .font(.system(size: 10.5))
                    Text(AppStrings.tr(en: "Write", zh: "写入"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(networkViewModel.diskWriteSpeed)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.system(size: 10.5))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            diskCapacityRow

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: AppImages.powerUsage)
                        .foregroundStyle(.yellow)
                        .font(.system(size: 10.5))
                    Text(AppStrings.powerUsage)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(networkViewModel.powerUsage)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                HStack(spacing: 4) {
                    Image(systemName: AppImages.chargingPower)
                        .foregroundStyle(.orange)
                        .font(.system(size: 10.5))
                    Text(AppStrings.chargingPower)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(networkViewModel.chargingPowerUsage)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            .font(.system(size: 10.5))
            .padding(.top, 1)

            if showsStorageDetails {
                Divider()
                MenuBarValueRow(title: AppStrings.diskCapacity, value: networkViewModel.diskTotalCapacity, icon: "internaldrive", iconColor: .cyan)
                MenuBarValueRow(title: AppStrings.diskUsed, value: networkViewModel.diskUsedPercent, icon: "chart.pie", iconColor: .teal)
                MenuBarValueRow(title: AppStrings.tr(en: "Total read", zh: "累计读取"), value: networkViewModel.diskReadTotal, icon: "arrow.down.to.line", iconColor: .teal)
                MenuBarValueRow(title: AppStrings.tr(en: "Total written", zh: "累计写入"), value: networkViewModel.diskWriteTotal, icon: "arrow.up.to.line", iconColor: .mint)
                if !networkViewModel.powerSubtitle.isEmpty {
                    Text(networkViewModel.powerSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var diskCapacityRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Image(systemName: AppImages.diskCapacity)
                        .foregroundStyle(.cyan)
                        .font(.system(size: 10))
                    Text(AppStrings.diskCapacity)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(AppStrings.diskFree) \(networkViewModel.diskFreeCapacity)")
                    .fontWeight(.medium)
                    .monospacedDigit()
                if !networkViewModel.diskTotalCapacity.isEmpty && networkViewModel.diskTotalCapacity != "--" {
                    Text("/ \(networkViewModel.diskTotalCapacity)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .font(.system(size: 11))

            if let fraction = diskUsedFraction {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.teal, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(proxy.size.width, proxy.size.width * fraction)))
                        }
                    }
            }
        }
        .padding(.top, 2)
    }

    private var cpuFraction: Double? {
        let cleaned = networkViewModel.cpuUsage
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Double(cleaned), val.isFinite, (0...100).contains(val) else {
            return nil
        }
        return val / 100.0
    }

    private var gpuFraction: Double? {
        let cleaned = networkViewModel.gpuUsage
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Double(cleaned), val.isFinite, (0...100).contains(val) else {
            return nil
        }
        return val / 100.0
    }

    private var memoryFraction: Double? {
        let cleaned = networkViewModel.memoryUsage
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Double(cleaned), val.isFinite, (0...100).contains(val) else {
            return nil
        }
        return val / 100.0
    }

    private var diskUsedFraction: Double? {
        let cleaned = networkViewModel.diskUsedPercent
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Double(cleaned), val.isFinite, (0...100).contains(val) else {
            return nil
        }
        return val / 100.0
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                DispatchQueue.main.async { openDashboardAndDismiss() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: AppImages.window)
                        .accessibilityHidden(true)
                    Text(AppStrings.openSystemHub)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .accessibilityHidden(true)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button {
                DispatchQueue.main.async { refreshSnapshot() }
            } label: {
                Image(systemName: AppImages.refresh)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(AppStrings.launchAtLoginRefresh)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var loginStatusText: String {
        // The service exposes English status values; localize their presentation
        // here without changing the service's state or registration behavior.
        switch launchAtLoginManager.statusText {
        case "Enabled": return AppStrings.tr(en: "Enabled", zh: "已启用")
        case "Disabled": return AppStrings.tr(en: "Disabled", zh: "已关闭")
        case "Waiting for approval in System Settings":
            return AppStrings.tr(en: "Waiting for approval in System Settings", zh: "等待在系统设置中批准")
        case "App service not found": return AppStrings.tr(en: "App service not found", zh: "未找到应用服务")
        case "Not configured": return AppStrings.tr(en: "Not configured", zh: "尚未配置")
        default: return AppStrings.tr(en: "Unknown status", zh: "未知状态")
        }
    }

    private func updatePanelHeight() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let maxAvailable = (screen?.visibleFrame.height ?? 680) - 36
        panelHeight = min(630, maxAvailable)
    }

    private func refreshSnapshot() {
        SMCService.shared.reconnect()
        fanViewModel.startMonitoring()
        fanViewModel.refreshHelperStatus()
        launchAtLoginManager.refreshStatus()
    }

    private func openDashboardAndDismiss() {
        let menuWindow = NSApp.keyWindow
        DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
        DashboardWindowManager.shared.showDashboard()

        DispatchQueue.main.async {
            menuWindow?.orderOut(nil)
            menuWindow?.close()
        }
    }
}
