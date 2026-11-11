import SwiftUI

struct MenuBarFanSection: View {
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @Namespace private var animationNamespace
    @State private var hoveredMode: FanMode? = nil

    private var sectionAnimation: Animation? {
        (reduceMotion || reduceVisualEffects) ? nil : AeroPulseTheme.motionPanel
    }

    var body: some View {
        MenuBarSection {
            HStack(spacing: 8) {
                Image(systemName: AppImages.fan)
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(AppStrings.tr(en: "Fans & temperature", zh: "风扇与温度"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
                statusIndicator
            }
            .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 12) {
                MenuBarReadout(
                    title: AppStrings.tr(en: "Current speed", zh: "当前转速"),
                    value: fanViewModel.fans.isEmpty ? "— RPM" : fanViewModel.primaryFanRPM,
                    size: 20
                )
                .equatable()

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    temperatureRow(title: "CPU", value: fanViewModel.primaryTemp)
                    temperatureRow(title: "GPU", value: fanViewModel.primaryGPUTemp)
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
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                    }
                    .padding(.top, 4)
                }
            } else if fanViewModel.currentMode == .custom {
                smartRulesInfo
            }

            noticeBanner
        }
        .animation(sectionAnimation, value: fanViewModel.currentMode)
    }

    private func temperatureColor(for formattedValue: String) -> Color {
        let numeric = formattedValue
            .replacingOccurrences(of: "°C", with: "")
            .replacingOccurrences(of: "°", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let temp = Double(numeric), temp.isFinite else { return AeroPulseTheme.textPrimary }
        if temp >= 80 { return AeroPulseTheme.negative }
        if temp >= 60 { return AeroPulseTheme.warning }
        return AeroPulseTheme.textPrimary
    }

    private func temperatureRow(title: String, value: String) -> some View {
        let valueTone = temperatureColor(for: value)
        return HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(valueTone)
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                .fill(AeroPulseTheme.raisedSurface)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.tr(en: "\(title) average temperature", zh: "\(title) 平均温度"))
        .accessibilityValue(value)
    }

    private var smartRulesInfo: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppStrings.tr(en: "Control average", zh: "控制基准均温"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer()
                Text(fanViewModel.controlAverageTemp)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
            }

            if let rule = fanViewModel.activeRule {
                HStack(alignment: .firstTextBaseline) {
                    Text(AppStrings.tr(en: "Active tier", zh: "当前档位"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer()
                    Text("≥ \(Int(rule.temperature))°C → \(rule.speedPercentage)%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.accentInk)
                }
            } else if fanViewModel.isRulesAtMinimum {
                HStack(alignment: .firstTextBaseline) {
                    Text(AppStrings.tr(en: "Active tier", zh: "当前档位"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                    Spacer()
                    Text(AppStrings.tr(en: "Hardware minimum", zh: "硬件最低转速"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
            }

            Button {
                DashboardWindowManager.shared.showDashboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .frame(width: 16, height: 16)
                    Text(AppStrings.tr(en: "Configure rules in Dashboard", zh: "在控制台中配置规则"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .fill(AeroPulseTheme.raisedSurface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(FanMode.allCases, id: \.self) { mode in
                let isSelected = fanViewModel.currentMode == mode

                Button {
                    withAnimation(reduceMotion || reduceVisualEffects ? nil : AeroPulseTheme.motionFast) {
                        fanViewModel.setFanMode(mode, isUserInitiated: true)
                    }
                } label: {
                    Text(mode.localizedTitle)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(
                            isSelected
                                ? AeroPulseTheme.textPrimary
                                : (hoveredMode == mode ? AeroPulseTheme.textPrimary : AeroPulseTheme.textSecondary)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    hoveredMode = isHovered ? mode : nil
                }
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                            .fill(AeroPulseTheme.raisedSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                                    .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                            }
                            .matchedGeometryEffect(id: "selected_fan_mode", in: animationNamespace)
                    }
                }
                .accessibilityLabel(mode.localizedTitle)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .fill(AeroPulseTheme.deepestSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                }
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
                .tint(AeroPulseTheme.accentFill)
                .accessibilityLabel(AppStrings.tr(en: "Target fan speed", zh: "风扇目标转速"))
                .accessibilityValue("\(target) RPM")
            } else {
                Text(AppStrings.tr(en: "Speed range unavailable", zh: "转速范围暂不可用"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
            }
        }
        .padding(.top, 4)
    }

    /// Signature status indicator: 6px solid semantic dot + quiet monospaced label, no Capsule pill.
    @ViewBuilder
    private var statusIndicator: some View {
        if let remaining = fanViewModel.modeSwitchTransitionRemainingSeconds, let mode = fanViewModel.transitioningMode {
            statusTag("\(mode.localizedTitle) · \(remaining)s", dotColor: AeroPulseTheme.accentInk)
        } else if fanViewModel.fans.isEmpty {
            statusTag(AppStrings.tr(en: "Unavailable", zh: "无数据"), dotColor: AeroPulseTheme.textMuted)
        } else if fanViewModel.isInstallingHelper {
            statusTag(AppStrings.tr(en: "Installing…", zh: "安装中…"), dotColor: AeroPulseTheme.warning)
        } else if !fanViewModel.helperInstalled {
            statusTag(AppStrings.tr(en: "Setup required", zh: "待设置"), dotColor: AeroPulseTheme.warning)
        } else if fanViewModel.isGameModeActive && fanViewModel.isGameModeUserOverridden {
            statusTag(AppStrings.tr(en: "Overridden", zh: "已接管"), dotColor: AeroPulseTheme.warning)
        } else if fanViewModel.isGameModeActive {
            statusTag(AppStrings.tr(en: "Game Mode", zh: "游戏模式"), dotColor: AeroPulseTheme.positive)
        } else if fanViewModel.isScheduleOverridden {
            statusTag(AppStrings.tr(en: "Overridden", zh: "计划已接管"), dotColor: AeroPulseTheme.warning)
        } else if fanViewModel.isScheduleActive {
            statusTag(AppStrings.tr(en: "Scheduled", zh: "定时计划"), dotColor: AeroPulseTheme.positive)
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            statusTag("\(remaining)s", dotColor: AeroPulseTheme.warning)
        } else if fanViewModel.currentMode == .custom, let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
            statusTag("↓ \(remaining)s", dotColor: AeroPulseTheme.warning)
        } else if fanViewModel.currentMode == .custom, let rule = fanViewModel.activeRule {
            statusTag("\(rule.speedPercentage)%", dotColor: AeroPulseTheme.positive)
        } else {
            statusTag(modeBadgeText, dotColor: AeroPulseTheme.positive)
        }
    }

    private func statusTag(_ text: String, dotColor: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textMuted)
        }
    }

    private var modeBadgeText: String {
        switch fanViewModel.currentMode {
        case .auto: return AppStrings.tr(en: "Auto", zh: "系统自动")
        case .fullBlast: return AppStrings.tr(en: "Full speed", zh: "全速散热")
        case .manual: return AppStrings.tr(en: "Manual", zh: "手动控制")
        case .custom: return AppStrings.tr(en: "Rules", zh: "智能温控")
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let remaining = fanViewModel.modeSwitchTransitionRemainingSeconds, let mode = fanViewModel.transitioningMode {
            statusLine(
                AppStrings.tr(
                    en: "Applying \(mode.localizedTitle) · Ramping in \(remaining)s",
                    zh: "正在切换至「\(mode.localizedTitle)」· 过渡中（\(remaining)s）"
                ),
                dotColor: AeroPulseTheme.accentInk
            )
        } else if fanViewModel.fans.isEmpty {
            statusLine(AppStrings.tr(en: "Fan data unavailable", zh: "暂无风扇数据"), dotColor: AeroPulseTheme.textMuted)
        } else if fanViewModel.isInstallingHelper {
            statusLine(fanViewModel.helperStatusMessage, dotColor: AeroPulseTheme.warning)
        } else if !fanViewModel.helperInstalled {
            statusLine(
                AppStrings.tr(en: "Select a mode to set up fan control", zh: "选择模式以设置风扇控制"),
                dotColor: AeroPulseTheme.warning
            )
        } else if fanViewModel.isGameModeActive && fanViewModel.isGameModeUserOverridden {
            HStack(spacing: 8) {
                Circle()
                    .fill(AeroPulseTheme.warning)
                    .frame(width: 6, height: 6)
                Text(AppStrings.tr(en: "Game active · Manual override", zh: "游戏运行中 · 已手动接管"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer()
                Button(AppStrings.tr(en: "Resume", zh: "恢复联动")) {
                    fanViewModel.resumeGameModeLinkage()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        } else if fanViewModel.isScheduleOverridden {
            HStack(spacing: 8) {
                Circle()
                    .fill(AeroPulseTheme.warning)
                    .frame(width: 6, height: 6)
                Text(AppStrings.tr(en: "Schedule active · Manual override", zh: "定时计划时段 · 已手动接管"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                Spacer()
                Button(AppStrings.tr(en: "Resume", zh: "恢复计划")) {
                    fanViewModel.resetScheduleOverride()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            statusLine(
                AppStrings.tr(en: "Game ended · Auto in \(remaining)s", zh: "游戏已退出 · \(remaining) 秒后切回自动"),
                dotColor: AeroPulseTheme.warning
            )
        } else if fanViewModel.currentMode == .custom, let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
            let current = fanViewModel.activeRule?.speedPercentage ?? 0
            let pending = fanViewModel.pendingRuleDownshiftSpeedPercentage ?? 0
            let pendingStr = pending == 0 ? AppStrings.tr(en: "min", zh: "最低转速") : "\(pending)%"
            statusLine(
                AppStrings.tr(
                    en: "Holding \(current)% · \(pendingStr) in \(remaining)s",
                    zh: "维持 \(current)% · \(remaining) 秒后降至 \(pendingStr)"
                ),
                dotColor: AeroPulseTheme.warning
            )
        }
    }

    private func statusLine(_ text: String, dotColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
