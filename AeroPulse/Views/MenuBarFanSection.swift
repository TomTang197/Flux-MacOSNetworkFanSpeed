import SwiftUI

struct MenuBarFanSection: View {
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @Namespace private var animationNamespace
    @State private var hoveredMode: FanMode? = nil

    var body: some View {
        MenuBarSection {
            HStack(spacing: 6) {
                Image(systemName: AppImages.fan)
                    .foregroundStyle(.teal)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text(AppStrings.tr(en: "Fans & Temperature", zh: "风扇与温度"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                statusBadge
            }
            .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 10) {
                MenuBarReadout(
                    title: AppStrings.tr(en: "Current speed", zh: "当前转速"),
                    value: fanViewModel.fans.isEmpty ? "— RPM" : fanViewModel.primaryFanRPM,
                    icon: AppImages.fan,
                    iconColor: .teal,
                    size: 21
                )
                .equatable()
                VStack(alignment: .trailing, spacing: 5) {
                    temperatureRow(title: "CPU", value: fanViewModel.primaryTemp, dotColor: .red)
                    temperatureRow(title: "GPU", value: fanViewModel.primaryGPUTemp, dotColor: .pink)
                }
                .help(AppStrings.tr(en: "Average CPU and GPU sensor temperatures", zh: "CPU 与 GPU 传感器平均温度"))
            }

            modePicker

            if fanViewModel.currentMode == .manual {
                if fanViewModel.fans.count > 1 && !fanViewModel.syncAllFans {
                    ForEach(fanViewModel.fans) { fan in
                        manualControl(fan: fan, label: fan.name)
                    }
                } else if let fan = fanViewModel.fans.first {
                    manualControl(fan: fan, label: fanViewModel.fans.count > 1 ? AppStrings.syncAllFans : nil)
                }

                if fanViewModel.fans.count > 1 {
                    HStack {
                        Spacer()
                        Toggle(AppStrings.syncAllFans, isOn: $fanViewModel.syncAllFans)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.top, 2)
                }
            } else if fanViewModel.currentMode == .custom {
                smartRulesInfo
            }

            noticeBanner
        }
        .animation(reduceMotion || reduceVisualEffects ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: fanViewModel.currentMode)
    }

    private func temperatureRow(title: String, value: String, dotColor: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.tr(en: "\(title) average temperature", zh: "\(title) 平均温度"))
        .accessibilityValue(value)
    }

    private var smartRulesInfo: some View {
        VStack(spacing: 4) {
            HStack {
                Text(AppStrings.tr(en: "Control Avg", zh: "控制基准均温"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fanViewModel.controlAverageTemp)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
            if let rule = fanViewModel.activeRule {
                HStack {
                    Text(AppStrings.tr(en: "Active Tier", zh: "当前档位"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("≥\(Int(rule.temperature))°C → \(rule.speedPercentage)%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.teal)
                }
            }
            Button {
                DashboardWindowManager.shared.showDashboard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                    Text(AppStrings.tr(en: "Configure Rules in Dashboard…", zh: "在控制台中配置规则…"))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
        }
        .padding(.top, 2)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(FanMode.allCases.enumerated()), id: \.element) { index, mode in
                let isSelected = fanViewModel.currentMode == mode
                let isPrevSelected = index > 0 && FanMode.allCases[index - 1] == fanViewModel.currentMode

                if index > 0 && !isSelected && !isPrevSelected {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 12)
                }

                Button {
                    withAnimation(reduceMotion || reduceVisualEffects ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                        fanViewModel.setFanMode(mode, isUserInitiated: true)
                    }
                } label: {
                    Text(mode.localizedTitle)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : (hoveredMode == mode ? .primary : .secondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    hoveredMode = isHovered ? mode : nil
                }
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.10), radius: 1.5, x: 0, y: 1)
                            .matchedGeometryEffect(id: "selected_fan_mode", in: animationNamespace)
                    }
                }
                .accessibilityLabel(mode.localizedTitle)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.45))
        )
        .frame(maxWidth: .infinity)
        .disabled(fanViewModel.fans.isEmpty || fanViewModel.isInstallingHelper)
        .accessibilityLabel(AppStrings.fanMode)
    }

    @ViewBuilder
    private func manualControl(fan: FanInfo, label: String? = nil) -> some View {
        let target = fanViewModel.manualTargetRPM[fan.id] ?? fan.currentRPM
        let lowerBound = max(0, fan.minRPM)
        let upperBound = fan.maxRPM
        VStack(spacing: 4) {
            MenuBarValueRow(
                title: label ?? AppStrings.tr(en: "Target speed", zh: "目标转速"),
                value: "\(target) RPM"
            )
            if upperBound > lowerBound {
                Slider(
                    value: Binding(
                        get: {
                            Double(min(upperBound, max(lowerBound, fanViewModel.manualTargetRPM[fan.id] ?? fan.currentRPM)))
                        },
                        set: { fanViewModel.setTargetRPM(fanIndex: fan.id, rpm: Int($0)) }
                    ),
                    in: Double(lowerBound)...Double(upperBound),
                    step: 50
                )
                .controlSize(.regular)
                .accessibilityLabel(AppStrings.tr(en: "Target fan speed", zh: "风扇目标转速"))
                .accessibilityValue("\(target) RPM")
            } else {
                Text(AppStrings.tr(en: "Speed range unavailable", zh: "转速范围暂不可用"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if fanViewModel.fans.isEmpty {
            badgePill(AppStrings.tr(en: "Unavailable", zh: "无数据"), icon: "exclamationmark.circle", color: .secondary)
        } else if fanViewModel.isInstallingHelper {
            badgePill(AppStrings.tr(en: "Installing…", zh: "安装组件中…"), icon: "clock", color: .orange)
        } else if !fanViewModel.helperInstalled {
            badgePill(AppStrings.tr(en: "Setup required", zh: "待设置"), icon: "info.circle", color: .orange)
        } else if fanViewModel.isGameModeActive && fanViewModel.isGameModeUserOverridden {
            badgePill(AppStrings.tr(en: "Overridden", zh: "已接管"), icon: "hand.raised", color: .orange)
        } else if fanViewModel.isGameModeActive {
            badgePill(AppStrings.tr(en: "Game Mode", zh: "游戏模式"), icon: "gamecontroller", color: .green)
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            badgePill("\(remaining)s", icon: "clock", color: .orange)
        } else if fanViewModel.currentMode == .custom, let rule = fanViewModel.activeRule {
            badgePill("\(rule.speedPercentage)%", icon: "speedometer", color: .teal)
        } else {
            badgePill(modeBadgeText, icon: "checkmark.circle", color: .secondary)
        }
    }

    private func badgePill(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8.5))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.08), in: Capsule())
    }

    private var modeBadgeText: String {
        switch fanViewModel.currentMode {
        case .auto: return AppStrings.tr(en: "Auto", zh: "macOS 自动")
        case .fullBlast: return AppStrings.tr(en: "Full Speed", zh: "全速散热")
        case .manual: return AppStrings.tr(en: "Manual", zh: "手动控制")
        case .custom: return AppStrings.tr(en: "Smart Rules", zh: "智能温控")
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if fanViewModel.fans.isEmpty {
            statusLine(AppStrings.tr(en: "Fan data unavailable", zh: "暂无风扇数据"), icon: "info.circle")
        } else if fanViewModel.isInstallingHelper {
            statusLine(fanViewModel.helperStatusMessage, icon: "clock", color: .orange)
        } else if !fanViewModel.helperInstalled {
            statusLine(
                AppStrings.tr(en: "Select a mode to set up fan control", zh: "选择模式以设置风扇控制"),
                icon: "info.circle",
                color: .orange
            )
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            statusLine(
                AppStrings.tr(en: "Game ended · Auto in \(remaining)s", zh: "游戏已退出 · \(remaining) 秒后切回自动"),
                icon: "clock",
                color: .orange
            )
        } else if fanViewModel.currentMode == .custom, let rule = fanViewModel.activeRule, let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
            statusLine(
                AppStrings.tr(en: "Holding \(rule.speedPercentage)% · Downshift in \(remaining)s", zh: "维持 \(rule.speedPercentage)% · \(remaining) 秒后降速"),
                icon: "clock",
                color: .orange
            )
        }
    }

    private func statusLine(_ text: String, icon: String, color: Color = .secondary) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
