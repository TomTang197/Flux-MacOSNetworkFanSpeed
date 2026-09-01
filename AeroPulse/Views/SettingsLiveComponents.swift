import SwiftUI

struct LiveTelemetrySettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        SettingsCard(title: "Live Throughput", symbol: AppImages.gauge, tint: .blue) {
            VStack(spacing: 8) {
                StatRow(icon: AppImages.download, label: AppStrings.download, value: networkViewModel.downloadSpeed, color: .blue)
                StatRow(icon: AppImages.upload, label: AppStrings.upload, value: networkViewModel.uploadSpeed, color: .green)
                StatRow(icon: AppImages.diskRead, label: AppStrings.diskRead, value: networkViewModel.diskReadSpeed, color: .teal)
                StatRow(icon: AppImages.diskWrite, label: AppStrings.diskWrite, value: networkViewModel.diskWriteSpeed, color: .mint)
                StatRow(icon: AppImages.download, label: "\(AppStrings.download) \(AppStrings.total)", value: networkViewModel.downloadTotal, color: .blue)
                StatRow(icon: AppImages.upload, label: "\(AppStrings.upload) \(AppStrings.total)", value: networkViewModel.uploadTotal, color: .green)
                StatRow(icon: AppImages.diskRead, label: "\(AppStrings.diskRead) \(AppStrings.total)", value: networkViewModel.diskReadTotal, color: .teal)
                StatRow(icon: AppImages.diskWrite, label: "\(AppStrings.diskWrite) \(AppStrings.total)", value: networkViewModel.diskWriteTotal, color: .mint)
                StatRow(icon: AppImages.diskCapacity, label: AppStrings.diskCapacity, value: "\(networkViewModel.diskFreeCapacity) / \(networkViewModel.diskTotalCapacity)", color: .cyan)
                StatRow(icon: AppImages.cpuUsage, label: AppStrings.cpuUsage, value: networkViewModel.cpuUsage, color: .red)
                StatRow(icon: AppImages.powerUsage, label: AppStrings.powerUsage, value: networkViewModel.powerUsage, color: .yellow)
                StatRow(icon: AppImages.chargingPower, label: AppStrings.chargingPower, value: networkViewModel.chargingPowerUsage, color: .orange)
                StatRow(icon: AppImages.gpuUsage, label: AppStrings.systemGPUUsage, value: networkViewModel.gpuUsage, color: .pink)
                StatRow(icon: AppImages.memory, label: AppStrings.memory, value: "\(networkViewModel.memoryUsage) (\(networkViewModel.memoryUsed)/\(networkViewModel.memoryTotal))", color: .brown)
                Divider().opacity(0.22)
                StatRow(icon: AppImages.temperature, label: AppStrings.cpuTemp, value: fanViewModel.primaryTemp, color: .orange)
                StatRow(icon: AppImages.temperature, label: AppStrings.gpuTemp, value: fanViewModel.primaryGPUTemp, color: .blue)
            }
        }
    }
}

struct MenuBarMetricsSettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel

    var body: some View {
        SettingsCard(title: AppStrings.menuBarMetrics, symbol: AppImages.checklist, tint: .cyan) {
            let metrics = MetricType.allCases
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    metricChip(metric)
                        .gridCellColumns(metrics.count.isMultiple(of: 2) || index != metrics.count - 1 ? 1 : 2)
                }
            }
        }
    }

    private func metricChip(_ metric: MetricType) -> some View {
        let enabled = networkViewModel.enabledMetrics.contains(metric)

        return Button {
            DispatchQueue.main.async {
                if networkViewModel.enabledMetrics.contains(metric) {
                    networkViewModel.enabledMetrics.remove(metric)
                } else {
                    networkViewModel.enabledMetrics.insert(metric)
                }
            }
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(enabled ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: metric.symbolName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(enabled ? .white : .blue.opacity(0.9))
                            .symbolRenderingMode(.hierarchical)
                    }

                Text(metric.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 10)
                    .opacity(enabled ? 1 : 0)
            }
            .foregroundColor(enabled ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(enabled ? Color.blue.opacity(0.85) : Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(enabled ? Color.blue.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LaunchAtLoginSettingsCard: View {
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    var body: some View {
        SettingsCard(title: AppStrings.launchAtLogin, symbol: AppImages.launchAtLogin, tint: .blue) {
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppStrings.launchAtLogin)
                        .font(.system(size: 11, weight: .semibold))
                    Text(AppStrings.launchAtLoginDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            HStack(spacing: 6) {
                Circle()
                    .fill(launchAtLoginManager.statusIsWarning ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(launchAtLoginManager.statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(launchAtLoginManager.statusIsWarning ? .orange : .secondary)
                Spacer()
                Button(AppStrings.launchAtLoginRefresh) {
                    DispatchQueue.main.async {
                        launchAtLoginManager.refreshStatus()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 10, weight: .semibold))
                .frame(minHeight: 24)
            }
        }
    }
}

struct RefreshRateSettingsCard: View {
    @ObservedObject var networkViewModel: NetworkViewModel

    var body: some View {
        SettingsCard(title: AppStrings.refreshRate, symbol: AppImages.refresh, tint: .mint) {
            HStack {
                Text("Sampling")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $networkViewModel.refreshInterval) {
                    Text("0.5s").tag(0.5)
                    Text("1.0s").tag(1.0)
                    Text("2.0s").tag(2.0)
                    Text("5.0s").tag(5.0)
                }
                .pickerStyle(.menu)
                .frame(width: 78)
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
            symbol: AppImages.visualEffects,
            tint: .purple
        ) {
            Toggle(isOn: $reduceVisualEffects) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppStrings.reduceVisualEffects)
                        .font(.system(size: 11, weight: .semibold))
                    Text(AppStrings.reduceVisualEffectsDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
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
            symbol: AppImages.helper,
            tint: fanViewModel.helperInstalled ? .green : .orange
        ) {
            HStack(spacing: 6) {
                Circle()
                    .fill(fanViewModel.helperInstalled ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(fanViewModel.helperStatusMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(fanViewModel.helperInstalled ? .secondary : .orange)
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
                .font(.system(size: 10, weight: .semibold))
                .frame(minHeight: 24)
                .disabled(fanViewModel.isInstallingHelper)

                Button(AppStrings.launchAtLoginRefresh) {
                    DispatchQueue.main.async {
                        fanViewModel.refreshHelperStatus()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 10, weight: .semibold))
                .frame(minHeight: 24)
                .disabled(fanViewModel.isInstallingHelper)
            }
        }
    }
}
