//
//  ContentView.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    private let defaultWindowSize = CGSize(width: 1230, height: 650)
    private let minimumWindowSize = CGSize(width: 1040, height: 620)
    private let leftColumnMinWidth: CGFloat = 320
    private let thermalColumnMinWidth: CGFloat = 400
    private let settingsColumnMinWidth: CGFloat = 460
    private let dividerWidth: CGFloat = 2

    private var minimumContentWidth: CGFloat {
        leftColumnMinWidth + thermalColumnMinWidth + settingsColumnMinWidth + dividerWidth
    }

    private var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color.indigo.opacity(0.08),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 640
            )
        }
        .ignoresSafeArea()
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = columnWidths(for: proxy.size.width)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Left Column: Metrics Dashboard
                    VStack(spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppStrings.appName)
                                    .font(.title2)
                                    .fontWeight(.black)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                                        .frame(width: 6, height: 6)
                                    Text(
                                        SMCService.shared.isConnected
                                            ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected
                                    )
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14),
                            ],
                            spacing: 14
                        ) {
                            DashboardMetricCard(
                                title: AppStrings.download,
                                value: networkViewModel.downloadSpeed,
                                icon: AppImages.download,
                                color: .blue,
                                subtitle: "\(AppStrings.total): \(networkViewModel.downloadTotal)",
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.upload,
                                value: networkViewModel.uploadSpeed,
                                icon: AppImages.upload,
                                color: .green,
                                subtitle: "\(AppStrings.total): \(networkViewModel.uploadTotal)",
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.diskRead,
                                value: networkViewModel.diskReadSpeed,
                                icon: AppImages.diskRead,
                                color: .teal,
                                subtitle: "\(AppStrings.total): \(networkViewModel.diskReadTotal)",
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.diskWrite,
                                value: networkViewModel.diskWriteSpeed,
                                icon: AppImages.diskWrite,
                                color: .mint,
                                subtitle: "\(AppStrings.total): \(networkViewModel.diskWriteTotal)",
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.cpuUsage,
                                value: networkViewModel.cpuUsage,
                                icon: AppImages.cpuUsage,
                                color: .red,
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.memory,
                                value: networkViewModel.memoryUsage,
                                icon: AppImages.memory,
                                color: .brown,
                                subtitle: "\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)",
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.fan,
                                value: fanViewModel.primaryFanRPM,
                                icon: AppImages.fan,
                                color: .indigo,
                                compact: true
                            )
                            DashboardMetricCard(
                                title: AppStrings.systemTemp,
                                value: fanViewModel.primaryTemp,
                                icon: AppImages.temperature,
                                color: .orange,
                                compact: true,
                                showInfoButton: false,
                                action: {
                                    fanViewModel.isShowingThermalDetails = true
                                }
                            )
                            DashboardMetricCard(
                                title: AppStrings.diskCapacity,
                                value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)",
                                icon: AppImages.diskCapacity,
                                color: .cyan,
                                subtitle: "\(AppStrings.diskFree): \(networkViewModel.diskFreeCapacity) • \(AppStrings.diskUsed): \(networkViewModel.diskUsedPercent)",
                                compact: true
                            )
                            .gridCellColumns(2)
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .frame(width: columns.leftWidth)

                    Divider()

                    VStack(spacing: 0) {
                        ThermalDetailView(
                            fanViewModel: fanViewModel,
                            isEmbedded: true,
                            layoutWidth: columns.thermalWidth
                        )
                    }
                    .padding(.horizontal, 10)
                    .frame(width: columns.thermalWidth)

                    Divider()

                    VStack(spacing: 0) {
                        ScrollView {
                            SettingsView(
                                networkViewModel: networkViewModel,
                                fanViewModel: fanViewModel,
                                launchAtLoginManager: launchAtLoginManager,
                                showWindowButton: false,
                                preferredWidth: nil,
                                layoutWidth: columns.settingsWidth
                            )
                        }
                    }
                    .frame(width: columns.settingsWidth)
                }
                .frame(width: columns.totalWidth, alignment: .topLeading)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
        }
        .frame(minWidth: minimumWindowSize.width, minHeight: minimumWindowSize.height)
        .background(dashboardBackground)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    window.title = AppStrings.appName
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    NSApp.activate(ignoringOtherApps: true)
                    setupWindow(window)
                }
            }
        }
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
            ThermalDetailView(fanViewModel: fanViewModel)
        }
    }

    private func columnWidths(for availableWidth: CGFloat) -> (
        leftWidth: CGFloat,
        thermalWidth: CGFloat,
        settingsWidth: CGFloat,
        totalWidth: CGFloat
    ) {
        let clampedWidth = max(availableWidth, minimumContentWidth)

        let leftWidth = max(leftColumnMinWidth, min(410, clampedWidth * 0.29))
        let settingsWidth = max(settingsColumnMinWidth, min(760, clampedWidth * 0.42))
        let thermalWidth = max(
            thermalColumnMinWidth,
            clampedWidth - leftWidth - settingsWidth - dividerWidth
        )

        return (
            leftWidth: leftWidth,
            thermalWidth: thermalWidth,
            settingsWidth: settingsWidth,
            totalWidth: leftWidth + thermalWidth + settingsWidth + dividerWidth
        )
    }

    private func setupWindow(_ window: NSWindow) {
        var frame = window.frame
        frame.size = defaultWindowSize
        window.setFrame(frame, display: true, animate: false)

        window.minSize = minimumWindowSize
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.styleMask.insert(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }
}

#Preview {
    ContentView(
        networkViewModel: NetworkViewModel(),
        fanViewModel: FanViewModel(),
        launchAtLoginManager: LaunchAtLoginManager()
    )
}
