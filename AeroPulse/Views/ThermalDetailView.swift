import SwiftUI

struct ThermalDetailView: View {
    private static let physicalCPUTiers = CPUTopologyDiscovery.discoverTiers()
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    var isEmbedded: Bool = false
    var layoutWidth: CGFloat? = nil

    var body: some View {
        let groups = ThermalSensorGroups(sensors: fanViewModel.sensors)
        let cpu = ThermalSensorProcessing.primaryCPUTemperature(from: fanViewModel.sensors)
        let gpu = ThermalSensorProcessing.primaryGPUTemperature(from: fanViewModel.sensors)

        VStack(spacing: 0) {
            HStack {
                Text(AppStrings.thermalSensors)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                    .frame(minHeight: 24, alignment: .leading)
                Spacer()
                if !isEmbedded {
                    Button { dismiss() } label: {
                        Image(systemName: AppImages.close)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.closeThermalDetails)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, cpuTopologyDescription.isEmpty ? 12 : 4)

            if !cpuTopologyDescription.isEmpty {
                Text(cpuTopologyDescription)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Keep both summaries visible while the sensor matrix scrolls.
            HStack(alignment: .top, spacing: 12) {
                ThermalSummaryView(
                    title: AppStrings.cpu,
                    icon: AppImages.cpu,
                    average: cpu,
                    sensors: groups.cpu,
                    isCPU: true
                )
                ThermalSummaryView(
                    title: AppStrings.gpu,
                    icon: AppImages.gpuUsage,
                    average: gpu,
                    sensors: groups.gpu
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)

            MetricTrendChartView(
                title: AppStrings.tr(en: "CPU", zh: "CPU 温度"),
                points: fanViewModel.cpuTemperatureHistory,
                unit: "°C",
                secondaryPoints: fanViewModel.gpuTemperatureHistory,
                secondaryTitle: AppStrings.tr(en: "GPU", zh: "GPU"),
                metricKey: "cpu_temp",
                secondaryMetricKey: "gpu_temp"
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: AppImages.fan)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)
                Text(AppStrings.tr(en: "Control input", zh: "控制输入"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer(minLength: 8)
                Text("\(fanViewModel.controlAverageTemp) · \(controlSource(cpu: cpu, gpu: gpu))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .help(AppStrings.tr(
                en: "Temperature input for fan rules: the higher of the CPU and GPU averages. Individual sensor peaks are for display only.",
                zh: "风扇温控规则输入温度：取 CPU 与 GPU 均值中的较高者。单个传感器极值仅供展示。"
            ))

            Rectangle()
                .fill(AeroPulseTheme.hairline)
                .frame(height: 1)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ThermalMatrixSection(
                        title: AppStrings.diePackage,
                        sensors: groups.diePackageSensors + groups.gpu.filter { $0.gpuKind == .die }
                    )

                    if !groups.system.isEmpty {
                        ThermalMatrixSection(
                            title: AppStrings.tr(en: "System sensors", zh: "系统传感器"),
                            sensors: groups.system
                        )
                    }
                }
                .padding(16)
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 560)
        .background(isEmbedded ? Color.clear : AeroPulseTheme.pageBackground)
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
    enum Severity {
        case unavailable
        case normal
        case elevated
        case critical
    }

    static func isValid(_ sensor: SensorInfo) -> Bool {
        sensor.isEnabled && sensor.temperature.isFinite && sensor.temperature > 0 && sensor.temperature < 150
    }

    static func reading(_ sensor: SensorInfo, precise: Bool = false) -> String {
        guard sensor.isEnabled else { return AppStrings.tr(en: "Off", zh: "关闭") }
        guard isValid(sensor) else { return "—" }
        return String(format: precise ? "%.1f°C" : "%.0f°C", sensor.temperature)
    }

    static func severity(_ sensor: SensorInfo) -> Severity {
        guard isValid(sensor) else { return .unavailable }
        if sensor.temperature >= 80 { return .critical }
        if sensor.temperature >= 60 { return .elevated }
        return .normal
    }

    static func severityForTemperature(_ value: Double) -> Severity {
        if value >= 80 { return .critical }
        if value >= 60 { return .elevated }
        return .normal
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
    let icon: String
    let average: Double?
    let sensors: [SensorInfo]
    var isCPU = false

    private func dotColor(for maxTemp: Double) -> Color {
        switch ThermalPresentation.severityForTemperature(maxTemp) {
        case .critical: return AeroPulseTheme.negative
        case .elevated: return AeroPulseTheme.warning
        case .normal, .unavailable: return AeroPulseTheme.positive
        }
    }

    var body: some View {
        let valid = sensors.filter { ThermalPresentation.isValid($0) }
        let maxTemp = valid.map(\.temperature).max()

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
                if let maxTemp {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dotColor(for: maxTemp))
                            .frame(width: 6, height: 6)
                        Text(String(format: "%@ %.0f°C", AppStrings.trendMax, maxTemp))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textMuted)
                    }
                    .help(AppStrings.tr(en: "Highest current reading among valid sensors", zh: "当前有效传感器中的最高实时读数"))
                }
            }

            Text(average.map { String(format: "%.0f°C", $0) } ?? "—°C")
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(AppStrings.tr(en: "Available sensor average", zh: "可用传感器均温"))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textMuted)
                .lineLimit(1)
                .help(isCPU ? AppStrings.tr(
                    en: "Uses core sensor averages when performance or super core readings are available; otherwise prefers die/package sensors over efficiency-only readings. Sensor channels do not correspond one-to-one with physical CPU cores, and some cores may have no readable sensor.",
                    zh: "有性能核或超能核读数时使用核心传感器均温；缺少这些读数时优先使用核心与封装通道，避免仅用能效核温度代表整个 CPU。传感器与物理核心并非一一对应，部分核心可能没有可读温度。"
                ) : AppStrings.tr(en: "Average of available GPU temperature channels", zh: "当前可用 GPU 温度通道的平均值"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .aeroPulseCard()
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
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                    Spacer()
                    Text("\(sensors.count)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }
            if sensors.isEmpty {
                Text(AppStrings.noData)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .padding(.vertical, 8)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
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
        let severity = ThermalPresentation.severity(sensor)
        let valueColor: Color = {
            switch severity {
            case .critical: return AeroPulseTheme.negative
            case .elevated: return AeroPulseTheme.warning
            case .normal: return AeroPulseTheme.textPrimary
            case .unavailable: return AeroPulseTheme.textMuted
            }
        }()
        let borderColor: Color = {
            switch severity {
            case .critical: return AeroPulseTheme.negative.opacity(0.36)
            case .elevated: return AeroPulseTheme.warning.opacity(0.28)
            case .normal, .unavailable: return AeroPulseTheme.hairline
            }
        }()

        HStack(spacing: 8) {
            if severity == .critical || severity == .elevated {
                Circle()
                    .fill(valueColor)
                    .frame(width: 6, height: 6)
            }
            Text(displayName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(ThermalPresentation.reading(sensor))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .fill(AeroPulseTheme.cardSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .help("\(displayName)\nSMC: \(sensor.id)\n\(ThermalPresentation.reading(sensor, precise: true))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName), \(ThermalPresentation.reading(sensor, precise: true))")
    }
}
