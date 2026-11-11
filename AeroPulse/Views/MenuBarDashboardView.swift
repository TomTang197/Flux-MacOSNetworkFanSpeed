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
    @ObservedObject private var updaterViewModel = SparkleUpdaterViewModel.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var showsNetworkDetails = false
    @State private var showsProcessDetails = false
    @State private var showsStorageDetails = false
    @State private var panelHeight: CGFloat = 628

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AeroPulseTheme.hairline)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 8) {
                    if updaterViewModel.isUpdateAvailable {
                        updateBanner
                    }
                    MenuBarFanSection(fanViewModel: fanViewModel)
                    networkSection
                    systemSection
                    storageSection
                }
                .padding(12)
            }
            .scrollBounceBehavior(.basedOnSize)

            Rectangle()
                .fill(AeroPulseTheme.hairline)
                .frame(height: 1)

            footer
        }
        .frame(width: 380, height: panelHeight)
        .background {
            if reduceTransparency || reduceVisualEffects {
                AeroPulseTheme.pageBackground
            } else {
                AeroPulseTheme.pageBackground.opacity(0.84)
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
            Image(systemName: "wind")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AeroPulseTheme.accentInk)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(AppStrings.appName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AeroPulseTheme.textPrimary)

            Spacer()

            // Signature live status indicator: 6px solid dot + quiet mono text
            HStack(spacing: 4) {
                Circle()
                    .fill(SMCService.shared.isConnected ? AeroPulseTheme.positive : AeroPulseTheme.warning)
                    .frame(width: 6, height: 6)
                Text(SMCService.shared.isConnected ? AppStrings.tr(en: "Live", zh: "在线") : AppStrings.tr(en: "Offline", zh: "离线"))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AeroPulseTheme.textMuted)
            }

            Menu {
                if updaterViewModel.isUpdateAvailable {
                    Button {
                        updaterViewModel.checkForUpdates()
                    } label: {
                        Label(
                            "\(AppStrings.newVersionAvailable) (\(updaterViewModel.availableUpdateVersion ?? ""))",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }

                    Divider()
                }

                Toggle(AppStrings.launchAtLogin, isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { newValue in
                        DispatchQueue.main.async {
                            launchAtLoginManager.setEnabled(newValue)
                        }
                    }
                ))

                Divider()

                Button {
                    openSettingsWindow()
                } label: {
                    Label(AppStrings.settings, systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)

                Button {
                    DispatchQueue.main.async { refreshSnapshot() }
                } label: {
                    Label(AppStrings.launchAtLoginRefresh, systemImage: AppImages.refresh)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(AppStrings.quitApplication, systemImage: AppImages.power)
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(width: 24, height: 24)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(AppStrings.tr(en: "More options", zh: "更多选项"))
            .help(AppStrings.tr(en: "Refresh, login status and quit", zh: "刷新、登录启动状态与退出"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                    icon: AppImages.download
                )
                .equatable()
                MenuBarReadout(
                    title: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    icon: AppImages.upload
                )
                .equatable()
            }
            if showsNetworkDetails {
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Downloaded", zh: "累计下载"),
                    value: networkViewModel.downloadTotal,
                    icon: "arrow.down.to.line"
                )
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Uploaded", zh: "累计上传"),
                    value: networkViewModel.uploadTotal,
                    icon: "arrow.up.to.line"
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
                    progress: cpuFraction
                )
                .equatable()
                MenuBarReadout(
                    title: AppStrings.gpu,
                    value: networkViewModel.gpuUsage,
                    icon: AppImages.gpuUsage,
                    progress: gpuFraction
                )
                .equatable()
            }

            memorySectionRow

            if showsProcessDetails {
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                MenuBarProcessList(title: AppStrings.cpuUsage, lines: networkViewModel.topCPUProcesses)
                    .equatable()
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                MenuBarValueRow(
                    title: AppStrings.tr(en: "Memory usage", zh: "内存使用率"),
                    value: networkViewModel.memoryUsage,
                    icon: AppImages.memory
                )
                MenuBarProcessList(title: AppStrings.memory, lines: networkViewModel.topMemoryProcesses)
                    .equatable()
            }
        }
    }

    private func barFill(for fraction: Double) -> Color {
        if fraction >= 0.92 { return AeroPulseTheme.negative }
        if fraction >= 0.80 { return AeroPulseTheme.warning }
        return AeroPulseTheme.accentFill
    }

    private var memorySectionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: AppImages.memory)
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 14, height: 14)
                    Text(AppStrings.memory)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                }
                Spacer()
                Text("\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                if !networkViewModel.memoryUsage.isEmpty && networkViewModel.memoryUsage != "0%" {
                    Text(networkViewModel.memoryUsage)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }

            if let fraction = memoryFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AeroPulseTheme.textPrimary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(barFill(for: fraction))
                            .frame(width: max(0, min(proxy.size.width, proxy.size.width * fraction)))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.top, 4)
    }

    private var storageSection: some View {
        MenuBarSection {
            MenuBarSectionHeading(
                title: AppStrings.tr(en: "Storage & power", zh: "存储与供电"),
                detailTitle: AppStrings.tr(en: "Storage and power details", zh: "存储与供电详情"),
                isExpanded: $showsStorageDetails
            )

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(AppStrings.tr(en: "Read", zh: "读取"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer(minLength: 4)
                    Text(networkViewModel.diskReadSpeed)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .fill(AeroPulseTheme.raisedSurface)
                )

                HStack(spacing: 8) {
                    Text(AppStrings.tr(en: "Write", zh: "写入"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer(minLength: 4)
                    Text(networkViewModel.diskWriteSpeed)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .fill(AeroPulseTheme.raisedSurface)
                )
            }

            diskCapacityRow

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(AppStrings.powerUsage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer(minLength: 4)
                    Text(networkViewModel.powerUsage)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
                HStack(spacing: 4) {
                    Text(AppStrings.chargingPower)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer(minLength: 4)
                    Text(networkViewModel.chargingPowerUsage)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
            }
            .padding(.top, 4)

            if showsStorageDetails {
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                MenuBarValueRow(title: AppStrings.diskCapacity, value: networkViewModel.diskTotalCapacity, icon: AppImages.diskRead)
                MenuBarValueRow(title: AppStrings.diskUsed, value: networkViewModel.diskUsedPercent, icon: AppImages.diskCapacity)
                MenuBarValueRow(title: AppStrings.tr(en: "Total read", zh: "累计读取"), value: networkViewModel.diskReadTotal, icon: "arrow.down.to.line")
                MenuBarValueRow(title: AppStrings.tr(en: "Total written", zh: "累计写入"), value: networkViewModel.diskWriteTotal, icon: "arrow.up.to.line")
                if !networkViewModel.powerSubtitle.isEmpty {
                    Text(networkViewModel.powerSubtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var diskCapacityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: AppImages.diskCapacity)
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 14, height: 14)
                    Text(AppStrings.diskCapacity)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                }
                Spacer()
                Text("\(AppStrings.diskFree) \(networkViewModel.diskFreeCapacity)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                if !networkViewModel.diskTotalCapacity.isEmpty && networkViewModel.diskTotalCapacity != "--" {
                    Text("/ \(networkViewModel.diskTotalCapacity)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }

            if let fraction = diskUsedFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AeroPulseTheme.textPrimary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(barFill(for: fraction))
                            .frame(width: max(0, min(proxy.size.width, proxy.size.width * fraction)))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.top, 4)
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
                HStack(spacing: 8) {
                    Image(systemName: AppImages.window)
                        .font(.system(size: 12, weight: .regular))
                        .accessibilityHidden(true)
                    Text(AppStrings.openSystemHub)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .regular))
                        .accessibilityHidden(true)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(AeroPulseTheme.accentFill)
            .controlSize(.regular)

            Button {
                openSettingsWindow()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 24, height: 28)
                    if updaterViewModel.isUpdateAvailable {
                        Circle()
                            .fill(AeroPulseTheme.accentInk)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: 4)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(AppStrings.settings)

            Button {
                DispatchQueue.main.async { refreshSnapshot() }
            } label: {
                Image(systemName: AppImages.refresh)
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(AppStrings.launchAtLoginRefresh)
        }
        .padding(12)
    }

    private var updateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AeroPulseTheme.accentInk)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.newVersionAvailable)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                if let version = updaterViewModel.availableUpdateVersion {
                    Text(version)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }

            Spacer()

            Button {
                updaterViewModel.checkForUpdates()
            } label: {
                Text(AppStrings.updateNow)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AeroPulseTheme.accentFill)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.cardRadius, style: .continuous)
                .fill(AeroPulseTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AeroPulseTheme.cardRadius, style: .continuous)
                .strokeBorder(AeroPulseTheme.accentInk.opacity(0.36), lineWidth: 1)
        )
    }

    private var loginStatusText: String {
        launchAtLoginManager.localizedStatusText
    }

    private func updatePanelHeight() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let maxAvailable = (screen?.visibleFrame.height ?? 680) - 36
        panelHeight = min(628, maxAvailable)
    }

    private func refreshSnapshot() {
        SMCService.shared.reconnect()
        fanViewModel.startMonitoring()
        fanViewModel.refreshHelperStatus()
        launchAtLoginManager.refreshStatus()
        SparkleUpdaterViewModel.shared.startBackgroundCheck()
    }

    private func openDashboardAndDismiss() {
        let menuExtraPanel = NSApp.windows.first { window in
            (window is NSPanel || window.level != .normal) &&
            window.isVisible &&
            window.identifier?.rawValue != "dashboard"
        }

        DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
        DashboardWindowManager.shared.showDashboard()

        DispatchQueue.main.async {
            menuExtraPanel?.orderOut(nil)
        }
    }

    private func openSettingsWindow() {
        let menuExtraPanel = NSApp.windows.first { window in
            (window is NSPanel || window.level != .normal) &&
            window.isVisible &&
            window.identifier?.rawValue != "dashboard"
        }

        DashboardWindowManager.shared.transitionActivationPolicy(to: .regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()

        DispatchQueue.main.async {
            menuExtraPanel?.orderOut(nil)
        }
    }
}
