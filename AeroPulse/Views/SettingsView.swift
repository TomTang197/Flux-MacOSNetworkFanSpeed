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
    var preferencesOnly: Bool = false
    @Environment(\.openWindow) private var openWindow
    @State private var isShowingBugFeedback = false
    @ObservedObject private var languageManager = LanguageManager.shared

    private var usesTwoColumnCards: Bool {
        preferredWidth == nil
    }

    private var cardColumnCount: Int {
        guard !preferencesOnly, usesTwoColumnCards else { return 1 }
        let available = max((layoutWidth ?? 0) - 32, 0)
        if available >= 760 { return 3 }
        if available >= 460 { return 2 }
        return 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !preferencesOnly { headerSection }

            WaterfallColumnsLayout(columns: cardColumnCount, spacing: 12) {
                if !preferencesOnly {
                    LiveTelemetrySettingsCard(
                        networkViewModel: networkViewModel,
                        fanViewModel: fanViewModel
                    )

                    FanControlCard(fanViewModel: fanViewModel)
                }

                LanguageSettingsCard()

                MenuBarMetricsSettingsCard(networkViewModel: networkViewModel)

                LaunchAtLoginSettingsCard(launchAtLoginManager: launchAtLoginManager)

                RefreshRateSettingsCard(networkViewModel: networkViewModel)

                VisualEffectsSettingsCard()

                SettingsCard(
                    title: AppStrings.hardwareConnection,
                    symbol: AppImages.cpu
                ) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(SMCService.shared.isConnected ? AeroPulseTheme.positive : AeroPulseTheme.negative)
                            .frame(width: 6, height: 6)
                        Text(
                            SMCService.shared.isConnected
                                ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected
                        )
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SMCService.shared.isConnected ? AeroPulseTheme.textSecondary : AeroPulseTheme.negative)
                    }

                    if !SMCService.shared.isConnected {
                        Text(SMCService.shared.lastError ?? AppStrings.unknownConnectionError)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.negative)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            DispatchQueue.main.async {
                                SMCService.shared.reconnect()
                            }
                        } label: {
                            Text(AppStrings.retryConnection)
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HelperSettingsCard(fanViewModel: fanViewModel)

                UpdateSettingsCard()

                SettingsCard(
                    title: AppStrings.bugFeedback,
                    symbol: AppImages.bug
                ) {
                    Text(AppStrings.bugFeedbackDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(AppStrings.bugFeedbackEmailLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)
                        Spacer()
                        Text(AppConfig.bugFeedbackEmail)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Button {
                        isShowingBugFeedback = true
                    } label: {
                        Text(AppStrings.bugFeedbackOpen)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !preferencesOnly {
                Button(
                    role: .destructive,
                    action: {
                        NSApplication.shared.terminate(nil)
                    }
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: AppImages.power)
                            .font(.system(size: 12, weight: .regular))
                        Text(AppStrings.quitApplication)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(AeroPulseTheme.negative)
            }
        }
        .padding(20)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.systemMonitor)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Text(AppStrings.systemMonitorSubtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
            }

            Spacer()

            if showWindowButton {
                Button {
                    openOrFocusDashboard()
                } label: {
                    Image(systemName: AppImages.window)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(AppStrings.openSystemHub)
            }
        }
    }

    private func openOrFocusDashboard() {
        DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
        DashboardWindowManager.shared.showDashboard()
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppStrings.bugFeedback)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: AppImages.close)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(AppStrings.bugFeedbackEmailLabel)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                Text(recipientEmail)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.bugFeedbackTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                TextField(AppStrings.bugFeedbackTitlePlaceholder, text: $issueTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.bugFeedbackDetails)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                TextEditor(text: $issueDetails)
                    .frame(minHeight: 148)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                            .fill(AeroPulseTheme.raisedSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                            .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if issueDetails.isEmpty {
                            Text(AppStrings.bugFeedbackDetailsPlaceholder)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AeroPulseTheme.textMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.bugFeedbackContact)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                TextField(AppStrings.bugFeedbackContactPlaceholder, text: $contact)
                    .textFieldStyle(.roundedBorder)
            }

            if let sendError {
                Text(sendError)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.negative)
            }

            HStack(spacing: 8) {
                Button(AppStrings.bugFeedbackCancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button {
                    sendFeedbackByMail()
                } label: {
                    Text(AppStrings.bugFeedbackSend)
                        .font(.system(size: 12, weight: .medium))
                        .frame(minWidth: 112)
                }
                .buttonStyle(.borderedProminent)
                .tint(AeroPulseTheme.accentFill)
                .controlSize(.regular)
                .disabled(!canSend)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 560, height: 500)
        .background(AeroPulseTheme.pageBackground)
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
    var tint: Color = AeroPulseTheme.accentInk
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aeroPulseCard()
    }
}

struct StatRow: View, Equatable {
    let icon: String
    let label: String
    let value: String
    var color: Color = AeroPulseTheme.textMuted

    static func == (lhs: StatRow, rhs: StatRow) -> Bool {
        lhs.icon == rhs.icon
            && lhs.label == rhs.label
            && lhs.value == rhs.value
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AeroPulseTheme.textMuted)
                .font(.system(size: 12, weight: .regular))
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 116, alignment: .trailing)
        }
        .frame(minHeight: 20)
    }
}

private struct UpdateSettingsCard: View {
    @ObservedObject private var updaterViewModel = SparkleUpdaterViewModel.shared

    var body: some View {
        SettingsCard(
            title: AppStrings.softwareUpdate,
            symbol: "arrow.triangle.2.circlepath"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AppStrings.currentVersionPrefix)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer()
                Text(updaterViewModel.appVersionDisplay)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
            }

            if updaterViewModel.isUpdateAvailable, let newVersion = updaterViewModel.availableUpdateVersion {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AeroPulseTheme.accentInk)
                        .frame(width: 6, height: 6)
                    Text("\(AppStrings.newVersionAvailable) · \(newVersion)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
            }

            Toggle(
                AppStrings.autoCheckForUpdates,
                isOn: $updaterViewModel.automaticallyChecksForUpdates
            )
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(AeroPulseTheme.textSecondary)

            Toggle(
                AppStrings.showUpdateInMenuBar,
                isOn: $updaterViewModel.showUpdateInMenuBar
            )
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(AeroPulseTheme.textSecondary)

            if updaterViewModel.isUpdateAvailable {
                Button {
                    updaterViewModel.checkForUpdates()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .regular))
                        Text("\(AppStrings.updateNow)\(updaterViewModel.availableUpdateVersion.map { " (\($0))" } ?? "")")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(AeroPulseTheme.accentFill)
                .controlSize(.small)
                .disabled(!updaterViewModel.canCheckForUpdates)
            } else {
                Button {
                    updaterViewModel.checkForUpdates()
                } label: {
                    Text(AppStrings.checkForUpdates)
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            #if DEBUG
            Button {
                updaterViewModel.toggleDebugSimulatedUpdate()
            } label: {
                Text(
                    updaterViewModel.isUpdateAvailable
                        ? AppStrings.resetSimulatedUpdateButton
                        : AppStrings.simulateUpdateButton
                )
                .font(.system(size: 11, weight: .regular))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            #endif
        }
    }
}
