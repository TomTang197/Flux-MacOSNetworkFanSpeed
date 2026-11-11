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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var isAddingRule = false
    @State private var newRuleTemp: Double = 65
    @State private var newRulePercentage: Int = 60

    private var sortedFans: [FanInfo] {
        fanViewModel.fans.sorted { $0.id < $1.id }
    }

    private var panelAnimation: Animation? {
        (reduceMotion || reduceVisualEffects) ? nil : AeroPulseTheme.motionPanel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if !isDashboard {
                    Image(systemName: AppImages.fan)
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .font(.system(size: 13, weight: .regular))
                        .frame(width: 16, height: 16)
                }
                Text(AppStrings.fanControl)
                    .font(.system(size: isDashboard ? 15 : 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                    .frame(minHeight: isDashboard ? 24 : 20, alignment: .leading)
                Spacer()

                if !fanViewModel.helperInstalled {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.warning)
                        .help(fanViewModel.helperStatusMessage)
                }
            }

            if sortedFans.isEmpty {
                Text(AppStrings.noData)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Mode Segmented Picker
                Picker(AppStrings.tr(en: "Mode", zh: "模式"), selection: Binding(
                    get: { fanViewModel.currentMode },
                    set: { newMode in
                        withAnimation(panelAnimation) {
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

                ambientStatusBar

                if isDashboard, let firstFan = sortedFans.first {
                    let history = fanViewModel.fanRPMHistory[firstFan.id] ?? []
                    let secondFan = sortedFans.count > 1 ? sortedFans[1] : nil
                    let secondHistory = secondFan.flatMap { fanViewModel.fanRPMHistory[$0.id] }
                    MetricTrendChartView(
                        title: sortedFans.count > 1 ? firstFan.name : AppStrings.fanRPMTrend,
                        points: history,
                        unit: AppStrings.rpmUnit,
                        secondaryPoints: secondHistory,
                        secondaryTitle: secondFan?.name,
                        metricKey: "fan_rpm_\(firstFan.id)",
                        secondaryMetricKey: secondFan.map { "fan_rpm_\($0.id)" }
                    )
                }

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
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                // Custom Threshold-based Rules Editor
                if fanViewModel.currentMode == .custom {
                    Rectangle()
                        .fill(AeroPulseTheme.hairline)
                        .frame(height: 1)
                    rulesSection
                }

                // Game Mode Auto Linkage Section
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                gameModeSection

                // Scheduled Fan Mode Section
                Rectangle()
                    .fill(AeroPulseTheme.hairline)
                    .frame(height: 1)
                scheduleSection

                if !fanViewModel.helperInstalled {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AeroPulseTheme.warning)
                            .frame(width: 6, height: 6)
                        Text(fanViewModel.helperStatusMessage)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.warning)
                        Spacer()
                        Button(AppStrings.helperInstall) {
                            fanViewModel.installHelper()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(isDashboard ? 0 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !isDashboard {
                Color.clear.aeroPulseCard()
            }
        }
        .animation(panelAnimation, value: fanViewModel.currentMode)
        .animation(panelAnimation, value: fanViewModel.modeSwitchTransitionRemainingSeconds != nil)
        .animation(panelAnimation, value: fanViewModel.isScheduleOverridden)
        .animation(panelAnimation, value: fanViewModel.isGameModeUserOverridden)
        .animation(panelAnimation, value: fanViewModel.gameModeCooldownRemainingSeconds != nil)
        .animation(panelAnimation, value: fanViewModel.ruleDownshiftRemainingSeconds != nil)
        .animation(panelAnimation, value: fanViewModel.isGameModeLinkageEnabled)
        .animation(panelAnimation, value: fanViewModel.fanScheduleConfig.isEnabled)
    }

    @ViewBuilder
    private var ambientStatusBar: some View {
        if let remaining = fanViewModel.modeSwitchTransitionRemainingSeconds, let mode = fanViewModel.transitioningMode {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)
                Text(AppStrings.tr(
                    en: "Applying \(mode.localizedTitle) · Ramping (\(remaining)s)",
                    zh: "正在应用「\(mode.localizedTitle)」· 响应过渡中（\(remaining)s）"
                ))
                .font(.system(size: 12, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius, highlighted: true)
            .transition(.opacity)
        } else if fanViewModel.isGameModeActive && fanViewModel.isGameModeUserOverridden {
            warningBanner(
                text: AppStrings.tr(en: "Manual override active during Game Mode", zh: "游戏模式期间已手动接管"),
                actionTitle: AppStrings.tr(en: "Resume", zh: "恢复联动")
            ) {
                withAnimation(panelAnimation) {
                    fanViewModel.resumeGameModeLinkage()
                }
            }
        } else if fanViewModel.isScheduleOverridden {
            warningBanner(
                text: AppStrings.tr(en: "Schedule overridden · Resumes at next boundary", zh: "计划时段已手动接管 · 下个节点恢复"),
                actionTitle: AppStrings.tr(en: "Resume", zh: "恢复计划")
            ) {
                withAnimation(panelAnimation) {
                    fanViewModel.resetScheduleOverride()
                }
            }
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            warningBanner(
                text: AppStrings.tr(en: "Game closed · Auto in \(remaining)s", zh: "游戏已退出 · \(remaining) 秒后恢复自动")
            )
        } else if fanViewModel.currentMode == .custom, let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
            let current = fanViewModel.activeRule?.speedPercentage ?? 0
            let pending = fanViewModel.pendingRuleDownshiftSpeedPercentage ?? 0
            let pendingStr = pending == 0 ? AppStrings.tr(en: "hardware minimum", zh: "硬件最低转速") : "\(pending)%"
            warningBanner(
                text: AppStrings.tr(
                    en: "Holding \(current)% · \(pendingStr) in \(remaining)s",
                    zh: "降速缓冲中：维持 \(current)% · \(remaining) 秒后切至 \(pendingStr)"
                )
            )
        } else if isDashboard {
            Text(quietModeSummary)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func warningBanner(text: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AeroPulseTheme.warning)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .fill(AeroPulseTheme.raisedSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .strokeBorder(AeroPulseTheme.warning.opacity(0.32), lineWidth: 1)
        }
        .transition(.opacity)
    }

    private var quietModeSummary: String {
        switch fanViewModel.currentMode {
        case .auto:
            return AppStrings.tr(en: "macOS manages fan speed based on thermal sensors", zh: "macOS 根据各传感器温度自动调节风扇转速")
        case .fullBlast:
            return AppStrings.tr(en: "All fans running at maximum RPM", zh: "所有风扇以最大转速运转")
        case .manual:
            return AppStrings.tr(en: "Fixed target RPM per fan", zh: "为各风扇指定固定目标转速")
        case .custom:
            return AppStrings.tr(en: "Dynamic curve tracking control temperature (\(fanViewModel.controlAverageTemp))", zh: "依据控制基准均温动态调速（\(fanViewModel.controlAverageTemp)）")
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppStrings.temperatureRules)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
                Text("\(AppStrings.tr(en: "Control", zh: "控制均温")) \(fanViewModel.controlAverageTemp)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textSecondary)
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)

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
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                            .frame(minWidth: 28, alignment: .trailing)
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius)

            VStack(spacing: 8) {
                ForEach(fanViewModel.rules) { rule in
                    let isPending = fanViewModel.ruleDownshiftRemainingSeconds != nil &&
                        fanViewModel.pendingRuleDownshiftSpeedPercentage == rule.speedPercentage
                    RuleRowView(
                        rule: rule,
                        isDashboard: isDashboard,
                        isActive: fanViewModel.activeRule?.id == rule.id,
                        isPending: isPending,
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
                    HStack(spacing: 12) {
                        Text("\(AppStrings.trigger) ≥ \(Int(newRuleTemp))°C")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                            .frame(width: 96, alignment: .leading)
                        Slider(value: $newRuleTemp, in: 35...95, step: 1)
                            .controlSize(.mini)
                    }
                    HStack(spacing: 12) {
                        Text("\(AppStrings.speed) \(newRulePercentage)%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                            .frame(width: 96, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(newRulePercentage) },
                            set: { newRulePercentage = Int($0) }
                        ), in: 10...100, step: 5)
                            .controlSize(.mini)
                    }
                    HStack(spacing: 8) {
                        Button(AppStrings.cancel) {
                            isAddingRule = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button(AppStrings.saveRule) {
                            fanViewModel.addRule(temperature: newRuleTemp, speedPercentage: newRulePercentage)
                            isAddingRule = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AeroPulseTheme.accentFill)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius)
            } else {
                HStack(spacing: 8) {
                    Button {
                        isAddingRule = true
                    } label: {
                        Label(AppStrings.addThreshold, systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button(AppStrings.resetDefaults) {
                        fanViewModel.resetDefaultRules()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: AppImages.gameController)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)
                Text(AppStrings.gameModeLinkage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()

                if fanViewModel.isGameModeActive {
                    if fanViewModel.isGameModeUserOverridden {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AeroPulseTheme.warning)
                                    .frame(width: 6, height: 6)
                                Text(AppStrings.tr(en: "Overridden", zh: "已手动接管"))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AeroPulseTheme.warning)
                            }
                            Button(AppStrings.tr(en: "Resume", zh: "恢复联动")) {
                                fanViewModel.resumeGameModeLinkage()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AeroPulseTheme.positive)
                                .frame(width: 6, height: 6)
                            Text(AppStrings.tr(en: "Active · Rules", zh: "生效中 · 规则"))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                        }
                    }
                } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AeroPulseTheme.warning)
                            .frame(width: 6, height: 6)
                        Text(AppStrings.tr(en: "Cooldown \(remaining)s", zh: "冷却中 \(remaining)s"))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.warning)
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)

                Spacer()
            }

            if fanViewModel.isGameModeLinkageEnabled {
                HStack(spacing: 8) {
                    Text(AppStrings.gameModeExitDelay)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)

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
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                            .frame(minWidth: 32, alignment: .trailing)
                    }
                    .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius)
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                comps.hour = fanViewModel.fanScheduleConfig.startHour
                comps.minute = fanViewModel.fanScheduleConfig.startMinute
                return cal.date(from: comps) ?? Date()
            },
            set: { newDate in
                let cal = Calendar.current
                let h = cal.component(.hour, from: newDate)
                let m = cal.component(.minute, from: newDate)
                var config = fanViewModel.fanScheduleConfig
                config.startHour = h
                config.startMinute = m
                fanViewModel.fanScheduleConfig = config
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                comps.hour = fanViewModel.fanScheduleConfig.endHour
                comps.minute = fanViewModel.fanScheduleConfig.endMinute
                return cal.date(from: comps) ?? Date()
            },
            set: { newDate in
                let cal = Calendar.current
                let h = cal.component(.hour, from: newDate)
                let m = cal.component(.minute, from: newDate)
                var config = fanViewModel.fanScheduleConfig
                config.endHour = h
                config.endMinute = m
                fanViewModel.fanScheduleConfig = config
            }
        )
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: AppImages.schedule)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)
                Text(AppStrings.scheduleSectionTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()

                if fanViewModel.fanScheduleConfig.isEnabled {
                    if fanViewModel.isScheduleOverridden {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AeroPulseTheme.warning)
                                    .frame(width: 6, height: 6)
                                Text(AppStrings.scheduleOverriddenBadge)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AeroPulseTheme.warning)
                            }
                            Button(AppStrings.tr(en: "Resume", zh: "恢复计划")) {
                                fanViewModel.resetScheduleOverride()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else if fanViewModel.isScheduleActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AeroPulseTheme.positive)
                                .frame(width: 6, height: 6)
                            Text("\(AppStrings.scheduleActiveBadge) · \(fanViewModel.fanScheduleConfig.scheduledMode.localizedTitle)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                        }
                    } else {
                        Text(String(format: "%02d:%02d–%02d:%02d", fanViewModel.fanScheduleConfig.startHour, fanViewModel.fanScheduleConfig.startMinute, fanViewModel.fanScheduleConfig.endHour, fanViewModel.fanScheduleConfig.endMinute))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textMuted)
                    }
                }
            }

            HStack(spacing: 8) {
                Toggle(
                    AppStrings.scheduleDesc,
                    isOn: $fanViewModel.fanScheduleConfig.isEnabled
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textSecondary)

                Spacer()
            }

            if fanViewModel.fanScheduleConfig.isEnabled {
                let startOffset = fanViewModel.fanScheduleConfig.startHour * 60 + fanViewModel.fanScheduleConfig.startMinute
                let endOffset = fanViewModel.fanScheduleConfig.endHour * 60 + fanViewModel.fanScheduleConfig.endMinute
                let isCrossMidnight = startOffset > endOffset
                let durationMinutes = endOffset >= startOffset ? (endOffset - startOffset) : (24 * 60 - startOffset + endOffset)
                let durationHours = durationMinutes / 60
                let durationMins = durationMinutes % 60
                let durationString = durationMins == 0 ? "\(durationHours)h" : "\(durationHours)h \(durationMins)m"

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(AppStrings.scheduleStartTime)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                            DatePicker("", selection: startDateBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .controlSize(.mini)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)

                        HStack(spacing: 4) {
                            Text(AppStrings.scheduleEndTime)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                            DatePicker("", selection: endDateBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .controlSize(.mini)
                        }

                        Spacer()

                        Text(isCrossMidnight ? "\(AppStrings.crossMidnightTag) · \(durationString)" : durationString)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textMuted)
                    }

                    Rectangle()
                        .fill(AeroPulseTheme.hairline)
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(AppStrings.scheduledModeLabel)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                            Picker("", selection: $fanViewModel.fanScheduleConfig.scheduledMode) {
                                ForEach(ScheduledFanTarget.allCases) { target in
                                    Text(target.localizedTitle).tag(target)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.mini)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text(AppStrings.defaultModeLabel)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AeroPulseTheme.textSecondary)
                            Picker("", selection: $fanViewModel.fanScheduleConfig.defaultMode) {
                                ForEach(ScheduledFanTarget.allCases) { target in
                                    Text(target.localizedTitle).tag(target)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(12)
                .aeroPulseRaised(cornerRadius: AeroPulseTheme.controlRadius)
            }
        }
    }
}

private struct RuleRowView: View {
    let rule: FanThresholdRule
    var isDashboard: Bool = false
    let isActive: Bool
    var isPending: Bool = false
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
        return "\(rule.speedPercentage)% · \(rpm) RPM"
    }

    var body: some View {
        let statusColor: Color = isActive ? AeroPulseTheme.positive : (isPending ? AeroPulseTheme.warning : AeroPulseTheme.textMuted)

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive || isPending ? statusColor : Color.clear)
                    .frame(width: 6, height: 6)
                    .overlay {
                        if !isActive && !isPending {
                            Circle().strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                        }
                    }

                Text("≥ \(Int(rule.temperature))°C")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                    .frame(minWidth: 52, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)

                Text(estimatedRPMText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? AeroPulseTheme.textPrimary : AeroPulseTheme.textSecondary)

                Spacer()

                if isActive {
                    Text(AppStrings.active)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AeroPulseTheme.positive)
                } else if isPending {
                    Text(AppStrings.tr(en: "Pending", zh: "待生效"))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AeroPulseTheme.warning)
                }

                Button {
                    temp = rule.temperature
                    percentage = rule.speedPercentage
                    isEditing.toggle()
                } label: {
                    Image(systemName: isEditing ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AeroPulseTheme.textMuted)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AeroPulseTheme.textMuted)
            }

            if isEditing {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("\(AppStrings.tr(en: "Temp", zh: "温度")) \(Int(temp))°C")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $temp, in: 35...95, step: 1) { editing in
                            if !editing {
                                onUpdate(FanThresholdRule(id: rule.id, temperature: temp, speedPercentage: percentage))
                            }
                        }
                        .controlSize(.mini)
                    }
                    HStack(spacing: 8) {
                        Text("\(AppStrings.speed) \(percentage)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .fill(isActive ? AeroPulseTheme.raisedSurface : AeroPulseTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .strokeBorder(
                    isActive
                        ? AeroPulseTheme.positive.opacity(0.36)
                        : (isPending ? AeroPulseTheme.warning.opacity(0.32) : AeroPulseTheme.hairline),
                    lineWidth: 1
                )
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var localSliderValue: Double = 0
    @State private var isDragging: Bool = false

    private var utilization: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        let range = Double(fan.maxRPM - fan.minRPM)
        let normalized = Double(fan.currentRPM - fan.minRPM) / range
        return min(max(normalized, 0), 1)
    }

    var body: some View {
        let isHighLoad = utilization > 0.85

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(fan.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(fan.currentRPM) \(AppStrings.rpmUnit)")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isHighLoad ? AeroPulseTheme.warning : AeroPulseTheme.textPrimary)
                    .frame(minWidth: 96, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AeroPulseTheme.textPrimary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isHighLoad ? AeroPulseTheme.warning : AeroPulseTheme.accentFill)
                        .frame(width: max(0, min(geo.size.width * CGFloat(utilization), geo.size.width)))
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(fan.minRPM) \(AppStrings.min)")
                Spacer()
                if isManual {
                    Text("\(AppStrings.target) \(Int(isDragging ? localSliderValue : Double(targetRPM))) \(AppStrings.rpmUnit)")
                        .foregroundStyle(AeroPulseTheme.accentInk)
                }
                Spacer()
                Text("\(fan.maxRPM) \(AppStrings.max)")
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(AeroPulseTheme.textMuted)

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
                .tint(AeroPulseTheme.accentFill)
                .transition(.opacity)
            }
        }
        .animation((reduceMotion || reduceVisualEffects) ? nil : AeroPulseTheme.motionPanel, value: isManual)
        .padding(isDashboard ? 16 : 12)
        .background(
            RoundedRectangle(
                cornerRadius: isDashboard ? AeroPulseTheme.cardRadius : AeroPulseTheme.controlRadius,
                style: .continuous
            )
            .fill(isDashboard ? AeroPulseTheme.cardSurface : AeroPulseTheme.raisedSurface)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: isDashboard ? AeroPulseTheme.cardRadius : AeroPulseTheme.controlRadius,
                style: .continuous
            )
            .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
        }
        .onAppear {
            localSliderValue = Double(targetRPM > 0 ? targetRPM : fan.currentRPM)
        }
    }
}
