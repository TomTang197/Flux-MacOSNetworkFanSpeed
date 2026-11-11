import SwiftUI

struct LiveTelemetrySettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        SettingsCard(title: AppStrings.systemMonitor, symbol: AppImages.gauge) {
            VStack(spacing: 8) {
                StatRow(icon: AppImages.download, label: AppStrings.download, value: networkViewModel.downloadSpeed)
                StatRow(icon: AppImages.upload, label: AppStrings.upload, value: networkViewModel.uploadSpeed)
                StatRow(icon: AppImages.diskRead, label: AppStrings.diskRead, value: networkViewModel.diskReadSpeed)
                StatRow(icon: AppImages.diskWrite, label: AppStrings.diskWrite, value: networkViewModel.diskWriteSpeed)
                StatRow(icon: AppImages.download, label: "\(AppStrings.download) \(AppStrings.total)", value: networkViewModel.downloadTotal)
                StatRow(icon: AppImages.upload, label: "\(AppStrings.upload) \(AppStrings.total)", value: networkViewModel.uploadTotal)
                StatRow(icon: AppImages.diskRead, label: "\(AppStrings.diskRead) \(AppStrings.total)", value: networkViewModel.diskReadTotal)
                StatRow(icon: AppImages.diskWrite, label: "\(AppStrings.diskWrite) \(AppStrings.total)", value: networkViewModel.diskWriteTotal)
                StatRow(icon: AppImages.diskCapacity, label: AppStrings.diskCapacity, value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)")
                StatRow(icon: AppImages.cpuUsage, label: AppStrings.cpuUsage, value: networkViewModel.cpuUsage)
                StatRow(icon: AppImages.powerUsage, label: AppStrings.powerUsage, value: networkViewModel.powerUsage)
                StatRow(icon: AppImages.chargingPower, label: AppStrings.chargingPower, value: networkViewModel.chargingPowerUsage)
                StatRow(icon: AppImages.gpuUsage, label: AppStrings.systemGPUUsage, value: networkViewModel.gpuUsage)
                StatRow(icon: AppImages.memory, label: AppStrings.memory, value: "\(networkViewModel.memoryUsage) (\(networkViewModel.memoryUsed)/\(networkViewModel.memoryTotal))")
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                StatRow(icon: AppImages.temperature, label: AppStrings.cpuTemp, value: fanViewModel.primaryTemp)
                StatRow(icon: AppImages.temperature, label: AppStrings.gpuTemp, value: fanViewModel.primaryGPUTemp)
            }
        }
    }
}

struct LanguageSettingsCard: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        SettingsCard(
            title: AppStrings.language,
            symbol: "globe"
        ) {
            Picker(AppStrings.language, selection: Binding(
                get: { languageManager.selectedLanguage },
                set: { languageManager.setLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if languageManager.selectedLanguage == .system {
                HStack(spacing: 4) {
                    Text(AppStrings.languageCurrentSystemPrefix)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                    Text(languageManager.effectiveLanguage == .zhHans ? "简体中文" : "English")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }
}

struct MenuBarMetricsSettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects

    var body: some View {
        SettingsCard(title: AppStrings.menuBarMetrics, symbol: AppImages.checklist) {
            let metrics = MetricType.allCases
            let pairedCount = metrics.count - (metrics.count % 2)
            VStack(spacing: 8) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(metrics.prefix(pairedCount)) { metric in
                        metricChip(metric)
                    }
                }
                if !metrics.count.isMultiple(of: 2), let lastMetric = metrics.last {
                    metricChip(lastMetric)
                }
            }
        }
    }

    /// Active state is a quiet surface step with a Cobalt hairline highlight — no loud solid blocks.
    private func metricChip(_ metric: MetricType) -> some View {
        let enabled = networkViewModel.enabledMetrics.contains(metric)

        return Button {
            DispatchQueue.main.async {
                withAnimation((reduceMotion || reduceVisualEffects) ? nil : AeroPulseTheme.motionFast) {
                    if networkViewModel.enabledMetrics.contains(metric) {
                        networkViewModel.enabledMetrics.remove(metric)
                    } else {
                        networkViewModel.enabledMetrics.insert(metric)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: metric.symbolName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(enabled ? AeroPulseTheme.accentInk : AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)

                Text(metric.localizedTitle)
                    .font(.system(size: 12, weight: enabled ? .medium : .regular))
                    .foregroundStyle(enabled ? AeroPulseTheme.textPrimary : AeroPulseTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.accentInk)
                    .frame(width: 12)
                    .opacity(enabled ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                    .fill(enabled ? AeroPulseTheme.raisedSurface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                    .strokeBorder(
                        enabled ? AeroPulseTheme.accentInk.opacity(0.45) : AeroPulseTheme.hairline,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LaunchAtLoginSettingsCard: View {
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    var body: some View {
        SettingsCard(title: AppStrings.launchAtLogin, symbol: AppImages.launchAtLogin) {
            Toggle(
                isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { newValue in
                        DispatchQueue.main.async {
                            launchAtLoginManager.setEnabled(newValue)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.launchAtLogin)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                    Text(AppStrings.launchAtLoginDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }
            .toggleStyle(.switch)

            HStack(spacing: 8) {
                Circle()
                    .fill(launchAtLoginManager.statusIsWarning ? AeroPulseTheme.warning : AeroPulseTheme.positive)
                    .frame(width: 6, height: 6)
                Text(launchAtLoginManager.localizedStatusText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(launchAtLoginManager.statusIsWarning ? AeroPulseTheme.warning : AeroPulseTheme.textSecondary)
                Spacer()
                Button(AppStrings.launchAtLoginRefresh) {
                    DispatchQueue.main.async {
                        launchAtLoginManager.refreshStatus()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 11, weight: .medium))
                .frame(minHeight: 24)
            }
        }
    }
}

struct RefreshRateSettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel

    var body: some View {
        SettingsCard(title: AppStrings.refreshRate, symbol: AppImages.refresh) {
            HStack {
                Text(AppStrings.samplingInterval)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer()
                Picker("", selection: $networkViewModel.refreshInterval) {
                    Text("0.5s").tag(0.5)
                    Text("1.0s").tag(1.0)
                    Text("2.0s").tag(2.0)
                    Text("5.0s").tag(5.0)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 80)
            }
        }
    }
}

struct VisualEffectsSettingsCard: View {
    @AppStorage(VisualEffectsPreferences.storageKey) private var reduceVisualEffects =
        VisualEffectsPreferences.defaultValue

    var body: some View {
        SettingsCard(
            title: AppStrings.reduceVisualEffects,
            symbol: AppImages.visualEffects
        ) {
            Toggle(isOn: $reduceVisualEffects) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.reduceVisualEffects)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                    Text(AppStrings.reduceVisualEffectsDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
        }
    }
}

struct HelperSettingsCard: View {
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        SettingsCard(
            title: AppStrings.privilegedHelper,
            symbol: AppImages.helper
        ) {
            HStack(spacing: 8) {
                Circle()
                    .fill(fanViewModel.helperInstalled ? AeroPulseTheme.positive : AeroPulseTheme.warning)
                    .frame(width: 6, height: 6)
                Text(fanViewModel.helperStatusMessage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(fanViewModel.helperInstalled ? AeroPulseTheme.textSecondary : AeroPulseTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(fanViewModel.helperInstalled ? AppStrings.helperReinstall : AppStrings.helperInstall) {
                    DispatchQueue.main.async {
                        fanViewModel.installHelper()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 11, weight: .medium))
                .frame(minHeight: 24)
                .disabled(fanViewModel.isInstallingHelper)

                Button(AppStrings.launchAtLoginRefresh) {
                    DispatchQueue.main.async {
                        fanViewModel.refreshHelperStatus()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 11, weight: .medium))
                .frame(minHeight: 24)
                .disabled(fanViewModel.isInstallingHelper)
            }
        }
    }
}
