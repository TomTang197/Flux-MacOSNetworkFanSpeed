//
//  SettingsView.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//  Modified for Read-Only monitoring on 14/02/26.
//

import SwiftUI

/// `SettingsView` provides a unified UI for configuring the app, used in both the menu bar and the main window.
struct SettingsView: View {
    let networkViewModel: NetworkViewModel
    let fanViewModel: FanViewModel
    let launchAtLoginManager: LaunchAtLoginManager
    var showWindowButton: Bool = true
    var preferredWidth: CGFloat? = 280
    var layoutWidth: CGFloat? = nil
    @Environment(\.openWindow) private var openWindow
    @State private var isShowingBugFeedback = false

    private var usesTwoColumnCards: Bool {
        preferredWidth == nil
    }

    private var cardColumnCount: Int {
        guard usesTwoColumnCards else { return 1 }
        let available = max((layoutWidth ?? 0) - 32, 0)
        if available >= 760 { return 3 }
        if available >= 460 { return 2 }
        return 1
    }

    private let cardActionButtonMinHeight: CGFloat = 24
    private let cardActionButtonFont = Font.system(size: 10, weight: .semibold)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            WaterfallColumnsLayout(columns: cardColumnCount, spacing: 12) {
                LiveTelemetrySettingsCard(
                    networkViewModel: networkViewModel,
                    fanViewModel: fanViewModel
                )

                FanControlCard(fanViewModel: fanViewModel)

                MenuBarMetricsSettingsCard(networkViewModel: networkViewModel)

                LaunchAtLoginSettingsCard(launchAtLoginManager: launchAtLoginManager)

                RefreshRateSettingsCard(networkViewModel: networkViewModel)

                VisualEffectsSettingsCard()

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
                            DispatchQueue.main.async {
                                SMCService.shared.reconnect()
                            }
                        } label: {
                            Text(AppStrings.retryConnection)
                                .font(cardActionButtonFont)
                                .frame(maxWidth: .infinity, minHeight: cardActionButtonMinHeight)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HelperSettingsCard(fanViewModel: fanViewModel)

                SettingsCard(
                    title: AppStrings.bugFeedback,
                    symbol: AppImages.bug,
                    tint: .orange
                ) {
                    HStack {
                        Text(AppStrings.bugFeedbackDescription)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack {
                        Text(AppStrings.bugFeedbackEmailLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(AppConfig.bugFeedbackEmail)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Button {
                        isShowingBugFeedback = true
                    } label: {
                        Text(AppStrings.bugFeedbackOpen)
                            .font(cardActionButtonFont)
                            .frame(maxWidth: .infinity, minHeight: cardActionButtonMinHeight)
                    }
                    .buttonStyle(.borderedProminent)
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
        .onAppear {
            DispatchQueue.main.async {
                launchAtLoginManager.refreshStatus()
                fanViewModel.refreshHelperStatus()
            }
        }
        .sheet(isPresented: $isShowingBugFeedback) {
            BugFeedbackSheet(recipientEmail: AppConfig.bugFeedbackEmail)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.systemMonitor)
                    .font(.system(size: 15, weight: .bold))
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

    private func openOrFocusDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

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

private struct BugFeedbackSheet: View {
    let recipientEmail: String

    @Environment(\.dismiss) private var dismiss
    @State private var issueTitle: String = ""
    @State private var issueDetails: String = ""
    @State private var contact: String = ""
    @State private var sendError: String?

    private var canSend: Bool {
        !issueDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(AppStrings.bugFeedback)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: AppImages.close)
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(AppStrings.bugFeedbackEmailLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(recipientEmail)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.bugFeedbackTitle)
                    .font(.system(size: 11, weight: .semibold))
                TextField(AppStrings.bugFeedbackTitlePlaceholder, text: $issueTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.bugFeedbackDetails)
                    .font(.system(size: 11, weight: .semibold))
                TextEditor(text: $issueDetails)
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if issueDetails.isEmpty {
                            Text(AppStrings.bugFeedbackDetailsPlaceholder)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.bugFeedbackContact)
                    .font(.system(size: 11, weight: .semibold))
                TextField(AppStrings.bugFeedbackContactPlaceholder, text: $contact)
                    .textFieldStyle(.roundedBorder)
            }

            if let sendError {
                Text(sendError)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.red)
            }

            HStack(spacing: 8) {
                Button(AppStrings.bugFeedbackCancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 10, weight: .semibold))

                Spacer()

                Button {
                    sendFeedbackByMail()
                } label: {
                    Text(AppStrings.bugFeedbackSend)
                        .font(.system(size: 10, weight: .semibold))
                        .frame(minWidth: 120, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canSend)
            }
        }
        .padding(18)
        .frame(width: 560, height: 500)
    }

    private func sendFeedbackByMail() {
        sendError = nil

        let trimmedTitle = issueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Bug Report" : trimmedTitle

        let title =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "--"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "--"
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let body = """
        Title:
        \(finalTitle)

        Details:
        \(issueDetails.trimmingCharacters(in: .whitespacesAndNewlines))

        Contact:
        \(contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "N/A" : contact.trimmingCharacters(in: .whitespacesAndNewlines))

        Diagnostics:
        - App: \(AppStrings.appName) \(title) (\(build))
        - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        - Time: \(timestamp)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[\(AppStrings.appName)] \(finalTitle)"),
            URLQueryItem(name: "body", value: body),
        ]

        guard let url = components.url, NSWorkspace.shared.open(url) else {
            sendError = AppStrings.bugFeedbackOpenMailFailed
            return
        }

        dismiss()
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundColor(tint)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.95)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(
            cornerRadius: 12,
            tint: tint,
            style: .regular,
            shadowOpacity: 0.08
        )
    }
}

private struct FanBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

private struct FanSpeedRow: View, Equatable {
    let fan: FanInfo

    static func == (lhs: FanSpeedRow, rhs: FanSpeedRow) -> Bool {
        lhs.fan == rhs.fan
    }

    private var utilization: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        let range = Double(fan.maxRPM - fan.minRPM)
        let normalized = Double(fan.currentRPM - fan.minRPM) / range
        return min(max(normalized, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(fan.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(fan.currentRPM) \(AppStrings.rpmUnit)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(minWidth: 96, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.indigo.opacity(0.92))
                        .frame(width: max(0, min(geo.size.width * CGFloat(utilization), geo.size.width)))
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(fan.minRPM) MIN")
                Spacer()
                Text("\(fan.maxRPM) MAX")
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

struct StatRow: View, Equatable {
    let icon: String
    let label: String
    let value: String
    let color: Color

    static func == (lhs: StatRow, rhs: StatRow) -> Bool {
        lhs.icon == rhs.icon
            && lhs.label == rhs.label
            && lhs.value == rhs.value
            && lhs.color == rhs.color
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 116, alignment: .trailing)
        }
        .frame(minHeight: 19)
    }
}
