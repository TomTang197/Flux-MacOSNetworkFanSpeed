import SwiftUI

struct ThermalDetailView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    var isEmbedded: Bool = false
    var layoutWidth: CGFloat? = nil
    @State private var showsSystem = true
    @State private var showsDetails = false

    var body: some View {
        let groups = ThermalSensorGroups(sensors: fanViewModel.sensors)
        let cpu = ThermalSensorProcessing.primaryCPUTemperature(from: fanViewModel.sensors)
        let gpu = ThermalSensorProcessing.primaryGPUTemperature(from: fanViewModel.sensors)

        VStack(spacing: 0) {
            HStack {
                Text(AppStrings.thermalSensors)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !isEmbedded {
                    Button { dismiss() } label: {
                        Image(systemName: AppImages.close)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.closeThermalDetails)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isEmbedded ? 24 : 16)
            .padding(.bottom, 14)

            // Keep both summaries visible while the sensor matrix scrolls.
            HStack(alignment: .top, spacing: 16) {
                ThermalSummaryView(title: AppStrings.cpu, average: cpu, sensors: groups.cpu)
                Divider()
                ThermalSummaryView(title: AppStrings.gpu, average: gpu, sensors: groups.gpu)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: AppImages.fan)
                Text("\(AppStrings.tr(en: "Control input", zh: "控制输入")): \(fanViewModel.controlAverageTemp) · \(controlSource(cpu: cpu, gpu: gpu))")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .help(AppStrings.tr(
                en: "Temperature input for fan rules: the higher of the CPU and GPU averages. Individual sensor peaks are for display only.",
                zh: "风扇温控规则输入温度：取 CPU 与 GPU 均值中的较高者。单个传感器极值仅供展示。"
            ))

            Divider().padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ThermalMatrixSection(title: AppStrings.tr(en: "CPU sensors", zh: "CPU 传感器"), sensors: groups.cpu, groupsCPU: true)
                    ThermalMatrixSection(title: AppStrings.tr(en: "GPU sensors", zh: "GPU 传感器"), sensors: groups.gpu)

                    if !groups.system.isEmpty {
                        DisclosureGroup(AppStrings.tr(en: "System sensors (\(groups.system.count))", zh: "系统传感器 (\(groups.system.count))"), isExpanded: $showsSystem) {
                            ThermalMatrixSection(title: "", sensors: groups.system)
                                .padding(.top, 10)
                        }
                    }
                    Divider()
                    DisclosureGroup(AppStrings.tr(en: "Full sensor details", zh: "全部传感器明细"), isExpanded: $showsDetails) {
                        VStack(spacing: 0) {
                            ForEach(groups.cpu + groups.gpu + groups.system) { sensor in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sensor.name).font(.system(size: 12, weight: .medium))
                                        Text(sensor.id).font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text(ThermalPresentation.reading(sensor, precise: true))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 560)
    }

    private func controlSource(cpu: Double?, gpu: Double?) -> String {
        switch (cpu, gpu) {
        case let (.some(cpu), .some(gpu)):
            return cpu == gpu
                ? AppStrings.tr(en: "CPU / GPU averages", zh: "CPU / GPU 均值相同")
                : (cpu > gpu ? AppStrings.tr(en: "CPU average", zh: "CPU 均值") : AppStrings.tr(en: "GPU average", zh: "GPU 均值"))
        case (.some, .none): return AppStrings.tr(en: "CPU average", zh: "CPU 均值")
        case (.none, .some): return AppStrings.tr(en: "GPU average", zh: "GPU 均值")
        case (.none, .none): return AppStrings.tr(en: "No valid readings", zh: "无有效读数")
        }
    }
}

// Presentation-only helpers. The fan controller continues to use ThermalSensorProcessing.
private enum ThermalPresentation {
    static func isValid(_ sensor: SensorInfo) -> Bool {
        sensor.isEnabled && sensor.temperature.isFinite && sensor.temperature > 0 && sensor.temperature < 150
    }

    static func reading(_ sensor: SensorInfo, precise: Bool = false) -> String {
        guard sensor.isEnabled else { return AppStrings.tr(en: "Off", zh: "关闭") }
        guard isValid(sensor) else { return "—" }
        return String(format: precise ? "%.1f°C" : "%.0f°", sensor.temperature)
    }

    static func color(_ sensor: SensorInfo) -> Color {
        guard isValid(sensor) else { return .secondary }
        if sensor.temperature >= 80 { return .red }
        if sensor.temperature >= 60 { return .orange }
        return .teal
    }

    static func shortName(_ sensor: SensorInfo) -> String {
        for (prefix, label) in [
            ("GPU Core Sensor ", "G"), ("GPU Sensor ", "G"), ("GPU Cluster ", "Cl"),
            ("CPU Core ", "C"), ("P-Core Sensor ", "P"),
            ("E-Core Sensor ", "E"), ("S-Core Sensor ", "S")
        ] where sensor.name.hasPrefix(prefix) {
            return label + sensor.name.dropFirst(prefix.count)
        }
        return sensor.name
    }
}

private struct ThermalSummaryView: View {
    let title: String
    let average: Double?
    let sensors: [SensorInfo]

    var body: some View {
        let valid = sensors.filter { ThermalPresentation.isValid($0) }
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(average.map { String(format: "%.0f°C", $0) } ?? "—°C")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(AppStrings.tr(en: "Average temperature", zh: "平均温度"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Text(valid.map(\.temperature).max().map { String(format: AppStrings.tr(en: "Highest %.0f°C", zh: "最高 %.0f°C"), $0) } ?? AppStrings.tr(en: "Highest —", zh: "最高 —"))
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 3)
                .help(AppStrings.tr(en: "Highest current reading among valid sensors; not a historical peak.", zh: "当前有效传感器中的最高实时读数，非历史峰值。"))
            Text("\(valid.count) / \(sensors.count) \(AppStrings.tr(en: "valid sensors", zh: "个有效传感器"))")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThermalMatrixSection: View {
    let title: String
    let sensors: [SensorInfo]
    var groupsCPU = false

    private var sections: [(title: String, sensors: [SensorInfo])] {
        let sorted = sensors.sorted {
            $0.name == $1.name ? $0.id < $1.id : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        guard groupsCPU else { return [("", sorted)] }
        let definitions = [
            ("P-Core Sensor ", AppStrings.pCoreFilterDisplay),
            ("E-Core Sensor ", AppStrings.eCoreFilterDisplay),
            ("S-Core Sensor ", "S-Core")
        ]
        var result = definitions.map { prefix, title in
            (title: title, sensors: sorted.filter { $0.name.hasPrefix(prefix) })
        }
        result.append((title: AppStrings.tr(en: "Other CPU sensors", zh: "其他 CPU 传感器"), sensors: sorted.filter { sensor in
            !definitions.contains { sensor.name.hasPrefix($0.0) }
        }))
        return result.filter { !$0.sensors.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(sensors.count)").foregroundStyle(.secondary)
                }
            }
            if sensors.isEmpty {
                Text(AppStrings.noData).foregroundStyle(.secondary).padding(.vertical, 6)
            }
            ForEach(sections, id: \.title) { section in
                if !section.title.isEmpty {
                    Text(section.title).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: section.sensors.contains {
                    ThermalPresentation.shortName($0).count > 5
                } ? 140 : 72), spacing: 6)], spacing: 6) {
                    ForEach(section.sensors) { sensor in
                        ThermalSensorTile(sensor: sensor).equatable()
                    }
                }
            }
        }
    }
}

private struct ThermalSensorTile: View, Equatable {
    let sensor: SensorInfo

    var body: some View {
        HStack(spacing: 4) {
            Text(ThermalPresentation.shortName(sensor))
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(ThermalPresentation.reading(sensor))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(ThermalPresentation.color(sensor).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .help("\(sensor.name)\nSMC: \(sensor.id)\n\(ThermalPresentation.reading(sensor, precise: true))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sensor.name), \(ThermalPresentation.reading(sensor, precise: true))")
    }
}
