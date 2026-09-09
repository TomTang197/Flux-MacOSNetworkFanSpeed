//
//  FanControlCard.swift
//  AeroPulse
//
//  Created by Bandan.K on 30/08/26.
//

import SwiftUI

struct FanControlCard: View {
    @ObservedObject var fanViewModel: FanViewModel
    var isDashboard: Bool = false
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var isAddingRule = false
    @State private var newRuleTemp: Double = 65
    @State private var newRulePercentage: Int = 60

    private var sortedFans: [FanInfo] {
        fanViewModel.fans.sorted { $0.id < $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: AppImages.fan)
                    .foregroundColor(.indigo)
                    .font(.system(size: 12, weight: .semibold))
                Text(isDashboard ? AppStrings.fanControl : AppStrings.fanControlUpper)
                    .font(.system(size: isDashboard ? 14 : 9, weight: .semibold))
                    .tracking(isDashboard ? 0 : 0.95)
                    .foregroundColor(isDashboard ? .primary : .secondary)
                Spacer()

                if !fanViewModel.helperInstalled {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        .help(fanViewModel.helperStatusMessage)
                }
            }

            if sortedFans.isEmpty {
                Text(AppStrings.noData)
                    .font(.system(size: isDashboard ? 12 : 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Mode Segmented Picker
                Picker(AppStrings.tr(en: "Mode", zh: "模式"), selection: Binding(
                    get: { fanViewModel.currentMode },
                    set: { newMode in
                        DispatchQueue.main.async {
                            fanViewModel.setFanMode(newMode, isUserInitiated: true)
                        }
                    }
                )) {
                    ForEach(FanMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(isDashboard ? .regular : .small)

                if isDashboard { controlStatus }

                // Fan list with RPM gauges
                VStack(spacing: 8) {
                    ForEach(sortedFans) { fan in
                        FanSpeedRowView(
                            fan: fan,
                            isDashboard: isDashboard,
                            isManual: fanViewModel.currentMode == .manual,
                            targetRPM: fanViewModel.manualTargetRPM[fan.id] ?? fan.currentRPM,
                            onTargetRPMChanged: { newRPM in
                                fanViewModel.setTargetRPM(fanIndex: fan.id, rpm: newRPM)
                            }
                        )
                    }
                }

                if sortedFans.count > 1 && fanViewModel.currentMode == .manual {
                    Toggle(AppStrings.syncAllFans, isOn: $fanViewModel.syncAllFans)
                        .font(.system(size: isDashboard ? 11 : 10, weight: .medium))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                // Custom Threshold-based Rules Editor
                if fanViewModel.currentMode == .custom {
                    Divider().opacity(0.3)
                    rulesSection
                }

                // Game Mode Auto Linkage Section
                Divider().opacity(0.3)
                gameModeSection

                if !fanViewModel.helperInstalled {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text(fanViewModel.helperStatusMessage)
                            .font(.system(size: isDashboard ? 11 : 10, weight: .medium))
                            .foregroundColor(.orange)
                        Spacer()
                        Button(AppStrings.helperInstall) {
                            fanViewModel.installHelper()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(isDashboard ? 4 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !isDashboard {
                Color.clear.liquidGlassCard(
                    cornerRadius: 12, tint: .indigo, style: .regular, shadowOpacity: 0.08
                )
            }
        }
    }

    private var controlStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(statusTitle).font(.system(size: 13, weight: .semibold))
            Text(statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusTitle: String {
        switch fanViewModel.currentMode {
        case .auto: return AppStrings.tr(en: "System automatic control", zh: "系统自动控制")
        case .fullBlast: return AppStrings.tr(en: "Maximum speed selected", zh: "已选择全速模式")
        case .manual: return AppStrings.tr(en: "Manual targets selected", zh: "已选择手动目标转速")
        case .custom: return AppStrings.tr(en: "Temperature rules selected", zh: "已选择温控规则")
        }
    }

    private var statusDetail: String {
        switch fanViewModel.currentMode {
        case .auto: return AppStrings.tr(en: "macOS manages fan speed. Live readings are shown below.", zh: "macOS 自动管理风扇转速。下方展示实时数据。")
        case .fullBlast: return AppStrings.tr(en: "Requests each fan’s maximum speed. Compare the live RPM below.", zh: "请求风扇以最大转速运行。可对比下方实时转速。")
        case .manual: return AppStrings.tr(en: "Adjust the target for each fan below. Live RPM may take time to reach the target.", zh: "在下方调整每个风扇的目标转速。实时转速可能需要几秒响应。")
        case .custom: return AppStrings.tr(
            en: "Rule input: \(fanViewModel.controlAverageTemp), the higher CPU / GPU average. Live RPM is shown below.",
            zh: "规则依据输入：\(fanViewModel.controlAverageTemp)，取 CPU / GPU 的较高均值。实时转速显示如下。"
        )
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isDashboard ? AppStrings.temperatureRules : AppStrings.temperatureRulesUpper)
                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                Spacer()
                Text("\(AppStrings.tr(en: "Control Avg", zh: "控制均温")): \(fanViewModel.controlAverageTemp)")
                    .font(.system(size: isDashboard ? 11 : 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 8) {
                Toggle(
                    AppStrings.delayDownshift,
                    isOn: Binding(
                        get: { fanViewModel.isRuleDownshiftDelayEnabled },
                        set: { fanViewModel.setRuleDownshiftDelayEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: isDashboard ? 11 : 9.5, weight: .semibold))

                Spacer()

                if fanViewModel.isRuleDownshiftDelayEnabled {
                    Stepper(
                        value: Binding(
                            get: { fanViewModel.ruleDownshiftDelaySeconds },
                            set: { fanViewModel.setRuleDownshiftDelaySeconds($0) }
                        ),
                        in: 1...60,
                        step: 1
                    ) {
                        Text("\(fanViewModel.ruleDownshiftDelaySeconds)s")
                            .font(.system(size: isDashboard ? 11 : 9.5, weight: .bold, design: .monospaced))
                            .frame(minWidth: 28, alignment: .trailing)
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.035)))

            if let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                    Text(AppStrings.tr(en: "Holding current speed · Downshift in \(remaining)s", zh: "维持当前转速 · \(remaining)秒后降速"))
                        .font(.system(size: isDashboard ? 11 : 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer()
                }
            } else if fanViewModel.isRulesAtMinimum {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text(AppStrings.rulesActiveHardwareMin)
                        .font(.system(size: isDashboard ? 11 : 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                }
            }

            VStack(spacing: 6) {
                ForEach(fanViewModel.rules) { rule in
                    RuleRowView(
                        rule: rule,
                        isDashboard: isDashboard,
                        isActive: fanViewModel.activeRule?.id == rule.id,
                        fans: sortedFans,
                        onUpdate: { updated in
                            fanViewModel.updateRule(updated)
                        },
                        onDelete: {
                            fanViewModel.deleteRule(id: rule.id)
                        }
                    )
                }
            }

            if isAddingRule {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text("\(AppStrings.trigger): ≥ \(Int(newRuleTemp))°C")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                            .frame(width: 90, alignment: .leading)
                        Slider(value: $newRuleTemp, in: 35...95, step: 1)
                            .controlSize(.mini)
                    }
                    HStack(spacing: 10) {
                        Text("\(AppStrings.speed): \(newRulePercentage)%")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                            .frame(width: 90, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(newRulePercentage) },
                            set: { newRulePercentage = Int($0) }
                        ), in: 10...100, step: 5)
                        .controlSize(.mini)
                    }
                    HStack {
                        Button(AppStrings.cancel) {
                            isAddingRule = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Spacer()

                        Button(AppStrings.saveRule) {
                            fanViewModel.addRule(temperature: newRuleTemp, speedPercentage: newRulePercentage)
                            isAddingRule = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            } else {
                HStack(spacing: 8) {
                    Button {
                        isAddingRule = true
                    } label: {
                        Label(AppStrings.addThreshold, systemImage: "plus.circle.fill")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Spacer()

                    Button(AppStrings.resetDefaults) {
                        fanViewModel.resetDefaultRules()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: AppImages.gameController)
                    .font(.system(size: isDashboard ? 11 : 10, weight: .bold))
                    .foregroundColor(.purple)
                Text(isDashboard ? AppStrings.gameModeLinkage : AppStrings.gameModeLinkage.uppercased())
                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                Spacer()

                if fanViewModel.isGameModeActive {
                    HStack(spacing: 4) {
                        Circle().fill(Color.purple).frame(width: 5, height: 5)
                        Text(AppStrings.tr(en: "Active · Rules", zh: "生效中 · 规则"))
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text(AppStrings.tr(en: "Cooldown \(remaining)s", zh: "冷却中 \(remaining)秒"))
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }

            HStack(spacing: 8) {
                Toggle(
                    AppStrings.autoRulesInGameMode,
                    isOn: Binding(
                        get: { fanViewModel.isGameModeLinkageEnabled },
                        set: { fanViewModel.setGameModeLinkageEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: isDashboard ? 11 : 9.5, weight: .semibold))

                Spacer()
            }

            if fanViewModel.isGameModeLinkageEnabled {
                HStack(spacing: 8) {
                    Text(AppStrings.gameModeExitDelay)
                        .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Stepper(
                        value: Binding(
                            get: { fanViewModel.gameModeExitDelaySeconds },
                            set: { fanViewModel.setGameModeExitDelaySeconds($0) }
                        ),
                        in: 5...600,
                        step: 5
                    ) {
                        Text("\(fanViewModel.gameModeExitDelaySeconds)s")
                            .font(.system(size: isDashboard ? 11 : 9.5, weight: .bold, design: .monospaced))
                            .frame(minWidth: 32, alignment: .trailing)
                    }
                    .controlSize(.mini)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.035)))

                if fanViewModel.isGameModeActive {
                    HStack(spacing: 5) {
                        Circle().fill(Color.purple).frame(width: 5, height: 5)
                        Text(AppStrings.gameModeActiveStatus)
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.purple)
                        Spacer()
                    }
                } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
                    HStack(spacing: 5) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text("\(AppStrings.gameModeCooldownStatusPrefix) \(remaining)s")
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct RuleRowView: View {
    let rule: FanThresholdRule
    var isDashboard: Bool = false
    let isActive: Bool
    let fans: [FanInfo]
    let onUpdate: (FanThresholdRule) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var temp: Double = 0
    @State private var percentage: Int = 0

    private var estimatedRPMText: String {
        guard let first = fans.first else { return "\(rule.speedPercentage)%" }
        let range = Double(first.maxRPM - first.minRPM)
        let rpm = first.minRPM + Int(range * Double(rule.speedPercentage) / 100.0)
        return "\(rule.speedPercentage)% (\(rpm) RPM)"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Active status badge
                Circle()
                    .fill(isActive ? Color.green : Color.clear)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(isActive ? Color.green : Color.secondary.opacity(0.3), lineWidth: 1))

                Text("≥ \(Int(rule.temperature))°C")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? .green : .primary)
                    .frame(minWidth: 50, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: isDashboard ? 11 : 8, weight: .bold))
                    .foregroundColor(.secondary)

                Text(estimatedRPMText)
                    .font(.system(size: isDashboard ? 11 : 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .green : .secondary)

                Spacer()

                if isActive {
                    Text(AppStrings.active)
                        .font(.system(size: 7.5, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                        .foregroundColor(.green)
                }

                Button {
                    temp = rule.temperature
                    percentage = rule.speedPercentage
                    isEditing.toggle()
                } label: {
                    Image(systemName: isEditing ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.7))
            }

            if isEditing {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(AppStrings.tr(en: "Temp", zh: "温度")): \(Int(temp))°C")
                            .font(.system(size: isDashboard ? 11 : 9, weight: .semibold))
                            .frame(width: 65, alignment: .leading)
                        Slider(value: $temp, in: 35...95, step: 1) { editing in
                            if !editing {
                                onUpdate(FanThresholdRule(id: rule.id, temperature: temp, speedPercentage: percentage))
                            }
                        }
                        .controlSize(.mini)
                    }
                    HStack(spacing: 6) {
                        Text("\(AppStrings.speed): \(percentage)%")
                            .font(.system(size: isDashboard ? 11 : 9, weight: .semibold))
                            .frame(width: 65, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(percentage) },
                            set: { percentage = Int($0) }
                        ), in: 10...100, step: 5) { editing in
                            if !editing {
                                onUpdate(FanThresholdRule(id: rule.id, temperature: temp, speedPercentage: percentage))
                            }
                        }
                        .controlSize(.mini)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color.green.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            temp = rule.temperature
            percentage = rule.speedPercentage
        }
    }
}

private struct FanSpeedRowView: View {
    let fan: FanInfo
    var isDashboard: Bool = false
    let isManual: Bool
    let targetRPM: Int
    let onTargetRPMChanged: (Int) -> Void

    @State private var localSliderValue: Double = 0
    @State private var isDragging: Bool = false

    private var utilization: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        let range = Double(fan.maxRPM - fan.minRPM)
        let normalized = Double(fan.currentRPM - fan.minRPM) / range
        return min(max(normalized, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(fan.name)
                    .font(.system(size: isDashboard ? 12 : 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(fan.currentRPM) \(AppStrings.rpmUnit)")
                    .font(.system(size: isDashboard ? 12 : 11, weight: .bold, design: .monospaced))
                    .frame(minWidth: 96, alignment: .trailing)
            }

            ProgressView(value: utilization)
                .progressViewStyle(.linear)
                .tint(.indigo.opacity(0.92))

            HStack {
                Text("\(fan.minRPM) \(AppStrings.min)")
                Spacer()
                if isManual {
                    Text("\(AppStrings.target): \(Int(isDragging ? localSliderValue : Double(targetRPM))) \(AppStrings.rpmUnit)")
                        .foregroundColor(.indigo)
                }
                Spacer()
                Text("\(fan.maxRPM) \(AppStrings.max)")
            }
            .font(.system(size: isDashboard ? 11 : 9, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)

            if isManual {
                Slider(
                    value: Binding(
                        get: { isDragging ? localSliderValue : Double(targetRPM) },
                        set: { localSliderValue = $0 }
                    ),
                    in: Double(fan.minRPM)...Double(fan.maxRPM),
                    step: 50
                ) { editing in
                    isDragging = editing
                    if !editing {
                        onTargetRPMChanged(Int(localSliderValue))
                    }
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.primary.opacity(0.045))
        )
        .onAppear {
            localSliderValue = Double(targetRPM > 0 ? targetRPM : fan.currentRPM)
        }
    }
}
