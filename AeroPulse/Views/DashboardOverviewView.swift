import SwiftUI

/// Read-only presentation of the existing telemetry. No additional sampling.
struct DashboardOverviewView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.systemOverview).font(.system(size: 14, weight: .semibold))
            metricGroup(AppStrings.network, symbol: "network") {
                HStack(alignment: .top, spacing: 12) {
                    reading(AppStrings.download, value: networkViewModel.downloadSpeed, detail: "\(AppStrings.total) \(networkViewModel.downloadTotal)")
                    reading(AppStrings.upload, value: networkViewModel.uploadSpeed, detail: "\(AppStrings.total) \(networkViewModel.uploadTotal)")
                }
            }
            Divider()
            metricGroup(AppStrings.disk, symbol: AppImages.diskRead) {
                HStack(alignment: .top, spacing: 12) {
                    reading(AppStrings.read, value: networkViewModel.diskReadSpeed, detail: "\(AppStrings.total) \(networkViewModel.diskReadTotal)")
                    reading(AppStrings.write, value: networkViewModel.diskWriteSpeed, detail: "\(AppStrings.total) \(networkViewModel.diskWriteTotal)")
                }
                HStack {
                    Text(AppStrings.diskUsed)
                    Spacer()
                    Text(networkViewModel.diskUsedPercent).monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium))
                if let fraction = diskUsedFraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .accessibilityLabel("\(AppStrings.disk) \(AppStrings.diskUsed)")
                        .accessibilityValue(networkViewModel.diskUsedPercent)
                }
                HStack {
                    Text("\(AppStrings.diskFree) \(networkViewModel.diskFreeCapacity)")
                    Spacer(minLength: 4)
                    Text("\(AppStrings.total) \(networkViewModel.diskTotalCapacity)")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            metricGroup(AppStrings.systemLoad, symbol: AppImages.cpu) {
                metricRow(AppStrings.cpu, value: networkViewModel.cpuUsage)
                metricRow(AppStrings.systemGPUUsage, value: networkViewModel.gpuUsage)
                Text(AppStrings.systemGPUDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                metricRow(AppStrings.memory, value: networkViewModel.memoryUsage)
                Text("\(AppStrings.memory) \(networkViewModel.memoryUsed) / \(networkViewModel.memoryTotal)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            metricGroup(AppStrings.power, symbol: AppImages.powerUsage) {
                metricRow(AppStrings.system, value: networkViewModel.powerUsage)
                if !networkViewModel.powerSubtitle.isEmpty {
                    Text(networkViewModel.powerSubtitle)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                metricRow(AppStrings.battery, value: networkViewModel.chargingPowerUsage)
            }
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

    private func metricGroup<Content: View>(
        _ title: String, symbol: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func reading(_ label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .help(value)
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12))
            Spacer(minLength: 8)
            Text(value).font(.system(size: 18, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(1)
        }
    }
}
