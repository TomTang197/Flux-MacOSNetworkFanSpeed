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
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showsSettings = false
    @StateObject private var windowInteraction = WindowInteractionCoordinator()
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @Environment(\.openWindow) private var openWindow
    private let defaultWindowSize = CGSize(width: 1380, height: 820)
    private let minimumWindowSize = CGSize(width: 1120, height: 680)
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
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(AppStrings.appName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                DashboardConnectionStatus(fanViewModel: fanViewModel)
                Button { showsSettings = true } label: {
                    Label(AppStrings.settings, systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(AppStrings.settingsHelp)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            GeometryReader { proxy in
                let usableWidth = max(0, proxy.size.width - 2)
                HStack(alignment: .top, spacing: 0) {
                    ScrollView(.vertical) {
                        DashboardOverviewView(networkViewModel: networkViewModel)
                            .padding(16)
                    }
                    .frame(width: usableWidth * 0.27)
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 1)
                    ThermalDetailView(
                        fanViewModel: fanViewModel,
                        isEmbedded: true,
                        layoutWidth: usableWidth * 0.38
                    )
                    .frame(width: usableWidth * 0.38, height: proxy.size.height)
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 1)
                    ScrollView(.vertical) {
                        FanControlCard(fanViewModel: fanViewModel, isDashboard: true)
                            .padding(16)
                    }
                    .frame(width: usableWidth * 0.35)
                }
                .frame(height: proxy.size.height, alignment: .top)
            }
        }
        .sheet(isPresented: $showsSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text(AppStrings.settings).font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button(AppStrings.done) { showsSettings = false }
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
            DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
            networkViewModel.setPresentationUpdatesPaused(false)
            networkViewModel.setDetailedSampling(true, source: .dashboardWindow)
            fanViewModel.setDetailedSampling(true, source: .dashboardWindow)
            DashboardWindowManager.shared.transitionActivationPolicy(to: .regular)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
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
            DashboardWindowManager.shared.unregisterDashboardWindow(nil)
            DashboardWindowManager.shared.transitionActivationPolicy(to: .accessory)
        }
    }

    private func setupWindow(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("dashboard")
        DashboardWindowManager.shared.registerDashboardWindow(window)
        window.title = AppStrings.appName

        guard !window.isMiniaturized else { return }

        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetWidth = min(defaultWindowSize.width, max(minimumWindowSize.width, visibleFrame.width - 40))
        let targetHeight = min(defaultWindowSize.height, max(minimumWindowSize.height, visibleFrame.height - 50))

        var frame = window.frame
        if frame.size.width < 1300 || frame.size.height < 750 {
            frame.size = CGSize(width: targetWidth, height: targetHeight)
            frame.origin.x = visibleFrame.origin.x + max(0, (visibleFrame.width - targetWidth) / 2)
            frame.origin.y = visibleFrame.origin.y + max(0, (visibleFrame.height - targetHeight) / 2)
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
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        nsView.onWindow = onWindow
    }
}

private final class WindowTrackingView: NSView {
    var onWindow: ((NSWindow) -> Void)?
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, window !== configuredWindow else { return }
        configuredWindow = window
        onWindow?(window)
    }
}

private struct DashboardConnectionStatus: View {
    @ObservedObject var fanViewModel: FanViewModel
    private let service = SMCService.shared
    @State private var connected = SMCService.shared.isConnected

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (connected ? Color.green : Color.orange).opacity(0.35), radius: 2)
            Text(connected ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if !connected {
                Button(AppStrings.retryConnection) {
                    service.reconnect()
                    connected = service.isConnected
                }
                .controlSize(.mini)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
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
