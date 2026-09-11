import SwiftUI

struct ThermalDetailView: View {
    private static let physicalCPUTiers = CPUTopologyDiscovery.discoverTiers()
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    var isEmbedded: Bool = false
    var layoutWidth: CGFloat? = nil
    @State private var showsSystem = true

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

            if !cpuTopologyDescription.isEmpty {
                Text(cpuTopologyDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // Keep both summaries visible while the sensor matrix scrolls.
            HStack(alignment: .top, spacing: 16) {
                ThermalSummaryView(title: AppStrings.cpu, average: cpu, sensors: groups.cpu, isCPU: true)
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
                    ThermalMatrixSection(
                        title: AppStrings.diePackage,
                        sensors: groups.diePackageSensors + groups.gpu.filter { $0.gpuKind == .die }
                    )

                    if !groups.system.isEmpty {
                        DisclosureGroup(AppStrings.tr(en: "System sensors (\(groups.system.count))", zh: "系统传感器 (\(groups.system.count))"), isExpanded: $showsSystem) {
                            ThermalMatrixSection(title: "", sensors: groups.system)
                                .padding(.top, 10)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 560)
    }

    private var cpuTopologyDescription: String {
        let tiers = Self.physicalCPUTiers.filter { $0.physicalCount > 0 }.map { info in
            let label: String
            switch info.tier {
            case .superCore: label = AppStrings.tr(en: "super", zh: "超能核")
            case .performanceCore: label = AppStrings.tr(en: "performance", zh: "性能核")
            case .efficiencyCore: label = AppStrings.tr(en: "efficiency", zh: "能效核")
            default: label = AppStrings.tr(en: "cores", zh: "核心")
            }
            return "\(info.physicalCount) \(label)"
        }
        guard !tiers.isEmpty else { return "" }
        return AppStrings.tr(en: "Physical CPU cores: ", zh: "CPU 物理核心：") + tiers.joined(separator: " · ")
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

    static func displayName(_ sensor: SensorInfo) -> String {
        guard AppStrings.isZh else { return sensor.name }
        switch sensor.id {
        case "TCMb": return "CPU 芯片温度"
        case "TCMz": return "CPU 热点温度"
        case "TC0P": return sensor.cpuTier == .diePackage ? "CPU 封装温度" : "CPU 附近温度"
        case "mACC": return "CPU 核心均温"
        case "TGMb": return "GPU 芯片温度"
        case "TGMz": return "GPU 热点温度"
        case "Tb0R": return "电池内部"
        case "TB0T": return "电池附近"
        case "TA0p": return "环境温度"
        case "pSTR": return "掌托"
        case "TW0P": return "无线模块附近"
        case "Tm0P": return "主板附近"
        case "TM0P": return "内存附近"
        case "Ts0P": return "芯片区域"
        case "TH0x": return "SSD 控制器"
        case "TH0a": return "SSD 芯片 1"
        case "TH0b": return "SSD 芯片 2"
        case "TH0c": return "SSD 芯片 3"
        case "TH1A": return "闪存芯片"
        default: return sensor.name
        }
    }
}

private struct ThermalSummaryView: View {
    let title: String
    let average: Double?
    let sensors: [SensorInfo]
    var isCPU = false

    var body: some View {
        let valid = sensors.filter { ThermalPresentation.isValid($0) }
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(average.map { String(format: "%.0f°C", $0) } ?? "—°C")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(AppStrings.tr(en: "Available sensor average", zh: "可用传感器均温"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .help(isCPU ? AppStrings.tr(
                    en: "Uses core sensor averages when performance or super core readings are available; otherwise prefers die/package sensors over efficiency-only readings. Sensor channels do not correspond one-to-one with physical CPU cores, and some cores may have no readable sensor.",
                    zh: "有性能核或超能核读数时使用核心传感器均温；缺少这些读数时优先使用核心与封装通道，避免仅用能效核温度代表整个 CPU。传感器与物理核心并非一一对应，部分核心可能没有可读温度。"
                ) : AppStrings.tr(en: "Average of available GPU temperature channels.", zh: "当前可用 GPU 温度通道的平均值。"))
            Text(valid.map(\.temperature).max().map { String(format: AppStrings.tr(en: "Highest %.0f°C", zh: "最高 %.0f°C"), $0) } ?? AppStrings.tr(en: "Highest —", zh: "最高 —"))
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 3)
                .help(AppStrings.tr(en: "Highest current reading among valid sensors; not a historical peak.", zh: "当前有效传感器中的最高实时读数，非历史峰值。"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThermalMatrixSection: View {
    let title: String
    let sensors: [SensorInfo]
    private var sortedSensors: [SensorInfo] {
        sensors.sorted {
            let lhs = ThermalPresentation.displayName($0)
            let rhs = ThermalPresentation.displayName($1)
            return lhs == rhs ? $0.id < $1.id : lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                ForEach(sortedSensors) { sensor in
                    ThermalSensorTile(sensor: sensor, displayName: ThermalPresentation.displayName(sensor))
                        .equatable()
                }
            }
        }
    }
}

private struct ThermalSensorTile: View, Equatable {
    let sensor: SensorInfo
    let displayName: String

    var body: some View {
        HStack(spacing: 4) {
            Text(displayName)
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
        .help("\(displayName)\nSMC: \(sensor.id)\n\(ThermalPresentation.reading(sensor, precise: true))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName), \(ThermalPresentation.reading(sensor, precise: true))")
    }
}
