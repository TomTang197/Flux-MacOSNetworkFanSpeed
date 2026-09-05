//
//  ContentView.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
    let networkViewModel: NetworkViewModel
    let fanViewModel: FanViewModel
    let launchAtLoginManager: LaunchAtLoginManager
    @StateObject private var windowInteraction = WindowInteractionCoordinator()
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    private let defaultWindowSize = CGSize(width: 1230, height: 650)
    private let minimumWindowSize = CGSize(width: 1040, height: 620)
    private let leftColumnMinWidth: CGFloat = 320
    private let thermalColumnMinWidth: CGFloat = 400
    private let settingsColumnMinWidth: CGFloat = 460
    private let dividerWidth: CGFloat = 2

    private var minimumContentWidth: CGFloat {
        leftColumnMinWidth + thermalColumnMinWidth + settingsColumnMinWidth + dividerWidth
    }

    @ViewBuilder
    private var dashboardBackground: some View {
        if windowInteraction.isInteracting || reduceVisualEffects {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color.blue.opacity(0.04),
                    Color(NSColor.controlBackgroundColor).opacity(0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = columnWidths(for: proxy.size.width)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    DashboardMetricsColumn(
                        networkViewModel: networkViewModel,
                        fanViewModel: fanViewModel
                    )
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
        .environment(\.windowInteractionActive, windowInteraction.isInteracting)
        .background(dashboardBackground)
        .background(DashboardThermalSheetPresenter(fanViewModel: fanViewModel))
        .background(WindowAccessor { window in
            setupWindow(window)
        })
        .transaction { transaction in
            if windowInteraction.isInteracting {
                transaction.animation = nil
            }
        }
        .onAppear {
            networkViewModel.setPresentationUpdatesPaused(false)
            networkViewModel.setDetailedSampling(true, source: .dashboardWindow)
            fanViewModel.setDetailedSampling(true, source: .dashboardWindow)
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onChange(of: windowInteraction.isInteracting) { _, isInteracting in
            networkViewModel.setPresentationUpdatesPaused(isInteracting)
        }
        .onChange(of: reduceVisualEffects) { _, reduced in
            windowInteraction.setPermanentlyReducedEffects(reduced)
        }
        .onDisappear {
            networkViewModel.setPresentationUpdatesPaused(false)
            networkViewModel.setDetailedSampling(false, source: .dashboardWindow)
            fanViewModel.setDetailedSampling(false, source: .dashboardWindow)
            windowInteraction.detach()
            DispatchQueue.main.async {
                let hasVisibleWindows = NSApp.windows.contains {
                    $0.isVisible && !($0 is NSPanel) && $0.level == .normal
                }
                if !hasVisibleWindows {
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
            }
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
        window.title = AppStrings.appName
        var frame = window.frame
        if frame.size.width < minimumWindowSize.width || frame.size.height < minimumWindowSize.height {
            frame.size = defaultWindowSize
            window.setFrame(frame, display: true, animate: false)
        }

        window.minSize = minimumWindowSize
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.styleMask.insert(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        windowInteraction.setPermanentlyReducedEffects(reduceVisualEffects)
        windowInteraction.attach(to: window)

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}

private struct DashboardMetricsColumn: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
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
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    icon: AppImages.upload,
                    color: .green,
                    subtitle: "\(AppStrings.total): \(networkViewModel.uploadTotal)",
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.diskRead,
                    value: networkViewModel.diskReadSpeed,
                    icon: AppImages.diskRead,
                    color: .teal,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskReadTotal)",
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.diskWrite,
                    value: networkViewModel.diskWriteSpeed,
                    icon: AppImages.diskWrite,
                    color: .mint,
                    subtitle: "\(AppStrings.total): \(networkViewModel.diskWriteTotal)",
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.cpuUsage,
                    value: networkViewModel.cpuUsage,
                    icon: AppImages.cpuUsage,
                    color: .red,
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.powerUsage,
                    value: networkViewModel.powerUsage,
                    icon: AppImages.powerUsage,
                    color: .yellow,
                    subtitle: networkViewModel.powerSubtitle,
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.chargingPower,
                    value: networkViewModel.chargingPowerUsage,
                    icon: AppImages.chargingPower,
                    color: .orange,
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.systemGPUUsage,
                    value: networkViewModel.gpuUsage,
                    icon: AppImages.gpuUsage,
                    color: .pink,
                    subtitle: AppStrings.systemGPUDescription,
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.memory,
                    value: networkViewModel.memoryUsage,
                    icon: AppImages.memory,
                    color: .brown,
                    subtitle: "\(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)",
                    compact: true
                ).equatable()
                DashboardMetricCard(
                    title: AppStrings.fan,
                    value: fanViewModel.primaryFanRPM,
                    icon: AppImages.fan,
                    color: .indigo,
                    compact: true
                ).equatable()
                Button {
                    fanViewModel.isShowingThermalDetails = true
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("AVERAGE TEMP", systemImage: AppImages.temperature)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        ForEach([AppStrings.cpu, AppStrings.gpu], id: \.self) { component in
                            HStack {
                                Text(component).font(.system(size: 11, weight: .medium))
                                Spacer(minLength: 2)
                                Text(component == AppStrings.cpu ? fanViewModel.primaryTemp : fanViewModel.primaryGPUTemp)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    .liquidGlassCard(cornerRadius: 16, tint: .orange, style: .regular, shadowOpacity: 0.1)
                }
                .buttonStyle(.plain)
                .help(AppStrings.viewThermalDetails)
                DashboardMetricCard(
                    title: AppStrings.diskCapacity,
                    value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)",
                    icon: AppImages.diskCapacity,
                    color: .cyan,
                    subtitle: "\(AppStrings.diskFree): \(networkViewModel.diskFreeCapacity) • \(AppStrings.diskUsed): \(networkViewModel.diskUsedPercent)",
                    compact: true
                ).equatable()
                .gridCellColumns(2)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical, 24)
    }
}

private struct DashboardThermalSheetPresenter: View {
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
                ThermalDetailView(fanViewModel: fanViewModel)
            }
    }
}

#Preview {
    ContentView(
        networkViewModel: NetworkViewModel(),
        fanViewModel: FanViewModel(),
        launchAtLoginManager: LaunchAtLoginManager()
    )
}
