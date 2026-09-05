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
    @State private var showsSettings = false
    @StateObject private var windowInteraction = WindowInteractionCoordinator()
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    private let defaultWindowSize = CGSize(width: 1230, height: 650)
    private let minimumWindowSize = CGSize(width: 1040, height: 620)
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
        VStack(spacing: 0) {
            HStack {
                Text(AppStrings.appName).font(.system(size: 18, weight: .semibold))
                Spacer()
                DashboardConnectionStatus(fanViewModel: fanViewModel)
                Button { showsSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("App preferences and hardware setup")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()

            GeometryReader { proxy in
                let usableWidth = max(0, proxy.size.width - 2)
                HStack(alignment: .top, spacing: 0) {
                    ScrollView(.vertical) {
                        DashboardOverviewView(networkViewModel: networkViewModel)
                            .padding(20)
                    }
                    .frame(width: usableWidth * 0.28)
                    Divider()
                    ThermalDetailView(
                        fanViewModel: fanViewModel,
                        isEmbedded: true,
                        layoutWidth: usableWidth * 0.35
                    )
                    .frame(width: usableWidth * 0.35, height: proxy.size.height)
                    Divider()
                    ScrollView(.vertical) {
                        FanControlCard(fanViewModel: fanViewModel, isDashboard: true)
                            .padding(16)
                    }
                    .frame(width: usableWidth * 0.37)
                }
                .frame(height: proxy.size.height, alignment: .top)
            }
        }
        .sheet(isPresented: $showsSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button("Done") { showsSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(20)
                Divider()
                ScrollView {
                    SettingsView(
                        networkViewModel: networkViewModel,
                        fanViewModel: fanViewModel,
                        launchAtLoginManager: launchAtLoginManager,
                        showWindowButton: false,
                        preferredWidth: nil,
                        layoutWidth: 600,
                        preferencesOnly: true
                    )
                }
            }
            .frame(width: 600, height: 580)
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

private struct DashboardConnectionStatus: View {
    @ObservedObject var fanViewModel: FanViewModel
    private let service = SMCService.shared
    @State private var connected = SMCService.shared.isConnected

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? Color.secondary : .orange)
                .frame(width: 6, height: 6)
            Text(connected ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if !connected {
                Button(AppStrings.retryConnection) {
                    service.reconnect()
                    connected = service.isConnected
                }
                    .controlSize(.small)
            }
        }
        .onReceive(fanViewModel.$fans) { _ in connected = service.isConnected }
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
