import SwiftUI

/// Read-only presentation of the existing telemetry. No additional sampling.
struct DashboardOverviewView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.systemOverview)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .frame(minHeight: 24, alignment: .leading)

            // 1. Network Card
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: AppStrings.network, symbol: "network")
                HStack(alignment: .top, spacing: 12) {
                    reading(
                        AppStrings.download,
                        value: networkViewModel.downloadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.downloadTotal)"
                    )
                    Rectangle()
                        .fill(AeroPulseTheme.hairline)
                        .frame(width: 1, height: 44)
                    reading(
                        AppStrings.upload,
                        value: networkViewModel.uploadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.uploadTotal)"
                    )
                }
            }
            .padding(16)
            .aeroPulseCard()

            // 2. Storage / Disk Card
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: AppStrings.disk, symbol: AppImages.diskRead)
                HStack(alignment: .top, spacing: 12) {
                    reading(
                        AppStrings.read,
                        value: networkViewModel.diskReadSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.diskReadTotal)"
                    )
                    Rectangle()
                        .fill(AeroPulseTheme.hairline)
                        .frame(width: 1, height: 44)
                    reading(
                        AppStrings.write,
                        value: networkViewModel.diskWriteSpeed,
                        detail: "\(AppStrings.total) \(networkViewModel.diskWriteTotal)"
                    )
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(AppStrings.diskUsed)
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                        Spacer()
                        Text(networkViewModel.diskUsedPercent)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                    }
                    .font(.system(size: 12, weight: .regular))

                    if let fraction = diskUsedFraction {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(AeroPulseTheme.textPrimary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(diskFillColor(for: fraction))
                                    .frame(width: max(0, min(geo.size.width * fraction, geo.size.width)))
                            }
                        }
                        .frame(height: 4)
                        .accessibilityLabel("\(AppStrings.disk) \(AppStrings.diskUsed)")
                        .accessibilityValue(networkViewModel.diskUsedPercent)
                    }

                    HStack {
                        Text("\(AppStrings.diskFree) \(networkViewModel.diskFreeCapacity)")
                        Spacer(minLength: 8)
                        Text("\(AppStrings.total) \(networkViewModel.diskTotalCapacity)")
                    }
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }
            .padding(16)
            .aeroPulseCard()

            // 3. System Load Card
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: AppStrings.systemLoad, symbol: AppImages.cpu)
                VStack(alignment: .leading, spacing: 8) {
                    metricRow(AppStrings.cpu, value: networkViewModel.cpuUsage)
                    metricRow(AppStrings.systemGPUUsage, value: networkViewModel.gpuUsage)
                    Text(AppStrings.systemGPUDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle()
                        .fill(AeroPulseTheme.hairline)
                        .frame(height: 1)
                    metricRow(AppStrings.memory, value: networkViewModel.memoryUsage)
                    Text("\(AppStrings.memory) \(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }
            .padding(16)
            .aeroPulseCard()

            // 4. Power & Battery Card
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: AppStrings.power, symbol: AppImages.powerUsage)
                VStack(alignment: .leading, spacing: 8) {
                    metricRow(AppStrings.system, value: networkViewModel.powerUsage)
                    if !networkViewModel.powerSubtitle.isEmpty {
                        Text(networkViewModel.powerSubtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    metricRow(AppStrings.battery, value: networkViewModel.chargingPowerUsage)
                }
            }
            .padding(16)
            .aeroPulseCard()
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

    private func diskFillColor(for fraction: Double) -> Color {
        if fraction >= 0.92 { return AeroPulseTheme.negative }
        if fraction >= 0.80 { return AeroPulseTheme.warning }
        return AeroPulseTheme.accentFill
    }

    private func cardHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textMuted)
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AeroPulseTheme.textPrimary)
            Spacer()
        }
    }

    private func reading(
        _ label: String,
        value: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(value)
            Text(detail)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
        }
    }
}
