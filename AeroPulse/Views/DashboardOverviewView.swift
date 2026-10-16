import SwiftUI

/// Read-only presentation of the existing telemetry. No additional sampling.
struct DashboardOverviewView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.systemOverview)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 2)

            // 1. Network Card
            VStack(alignment: .leading, spacing: 10) {
                cardHeader(title: AppStrings.network, symbol: "network", tint: .blue)
                HStack(alignment: .top, spacing: 10) {
                    reading(
                        AppStrings.download,
                        value: networkViewModel.downloadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.downloadTotal)",
                        icon: "arrow.down",
                        iconColor: .blue
                    )
                    Divider().frame(height: 38)
                    reading(
                        AppStrings.upload,
                        value: networkViewModel.uploadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.uploadTotal)",
                        icon: "arrow.up",
                        iconColor: .teal
                    )
                }
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, tint: .blue, shadowOpacity: 0.06)

            // 2. Storage / Disk Card
            VStack(alignment: .leading, spacing: 10) {
                cardHeader(title: AppStrings.disk, symbol: "internaldrive.fill", tint: .indigo)
                HStack(alignment: .top, spacing: 10) {
                    reading(
                        AppStrings.read,
                        value: networkViewModel.diskReadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.diskReadTotal)",
                        icon: "arrow.down",
                        iconColor: .indigo
                    )
                    Divider().frame(height: 38)
                    reading(
                        AppStrings.write,
                        value: networkViewModel.diskWriteSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.diskWriteTotal)",
                        icon: "arrow.up",
                        iconColor: .purple
                    )
                }
                VStack(spacing: 5) {
                    HStack {
                        Text(AppStrings.diskUsed)
                        Spacer()
                        Text(networkViewModel.diskUsedPercent).monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))

                    if let fraction = diskUsedFraction {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                            .tint(.indigo)
                            .accessibilityLabel("\(AppStrings.disk) \(AppStrings.diskUsed)")
                            .accessibilityValue(networkViewModel.diskUsedPercent)
                    }

                    HStack {
                        Text("\(AppStrings.diskFree) \(networkViewModel.diskFreeCapacity)")
                        Spacer(minLength: 4)
                        Text("\(AppStrings.total) \(networkViewModel.diskTotalCapacity)")
                    }
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, tint: .indigo, shadowOpacity: 0.06)

            // 3. System Load Card
            VStack(alignment: .leading, spacing: 8) {
                cardHeader(title: AppStrings.systemLoad, symbol: "cpu.fill", tint: .orange)
                metricRow(AppStrings.cpu, value: networkViewModel.cpuUsage)
                metricRow(AppStrings.systemGPUUsage, value: networkViewModel.gpuUsage)
                Text(AppStrings.systemGPUDescription)
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                metricRow(AppStrings.memory, value: networkViewModel.memoryUsage)
                Text("\(AppStrings.memory) \(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, tint: .orange, shadowOpacity: 0.06)

            // 4. Power & Battery Card
            VStack(alignment: .leading, spacing: 8) {
                cardHeader(title: AppStrings.power, symbol: "bolt.fill", tint: .green)
                metricRow(AppStrings.system, value: networkViewModel.powerUsage)
                if !networkViewModel.powerSubtitle.isEmpty {
                    Text(networkViewModel.powerSubtitle)
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                metricRow(AppStrings.battery, value: networkViewModel.chargingPowerUsage)
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, tint: .green, shadowOpacity: 0.06)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diskUsedFraction: Double? {
        let percent = networkViewModel.diskUsedPercent
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(percent), value.isFinite, (0...100).contains(value) else {
            return nil
        }
        return value / 100
    }

    private func cardHeader(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func reading(
        _ label: String,
        value: String,
        detail: String,
        icon: String? = nil,
        iconColor: Color = .secondary
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(value)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium))
            Spacer(minLength: 8)
            Text(value).font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1)
        }
    }
}
