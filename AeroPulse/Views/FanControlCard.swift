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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                        title: sortedFans.count > 1 ? "\(firstFan.name)" : AppStrings.fanRPMTrend,
                        points: history,
                        unit: AppStrings.rpmUnit,
                        tintColor: .teal,
                        secondaryPoints: secondHistory,
                        secondaryColor: .cyan,
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

                // Scheduled Fan Mode Section
                Divider().opacity(0.3)
                scheduleSection

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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.currentMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.modeSwitchTransitionRemainingSeconds != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.isScheduleOverridden)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.isGameModeUserOverridden)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.gameModeCooldownRemainingSeconds != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.ruleDownshiftRemainingSeconds != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.isGameModeLinkageEnabled)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fanViewModel.fanScheduleConfig.isEnabled)
    }

    @ViewBuilder
    private var ambientStatusBar: some View {
        if let remaining = fanViewModel.modeSwitchTransitionRemainingSeconds, let mode = fanViewModel.transitioningMode {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.65)
                Text(AppStrings.tr(
                    en: "Applying \(mode.localizedTitle) · Fan speed ramping (\(remaining)s)",
                    zh: "正在应用「\(mode.localizedTitle)」· 风扇响应中（\(remaining)s）"
                ))
                .font(.system(size: isDashboard ? 11.5 : 10, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.18), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if fanViewModel.isGameModeActive && fanViewModel.isGameModeUserOverridden {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 9.5))
                Text(AppStrings.tr(en: "Manual override active during Game Mode", zh: "游戏模式期间已手动接管"))
                    .font(.system(size: isDashboard ? 11.5 : 10, weight: .medium))
                Spacer()
                Button(AppStrings.tr(en: "Resume", zh: "恢复联动")) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        fanViewModel.resumeGameModeLinkage()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if fanViewModel.isScheduleOverridden {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 9.5))
                Text(AppStrings.tr(en: "Schedule overridden · Resumes at next boundary", zh: "计划时段内已手动接管 · 下个计划点自动恢复"))
                    .font(.system(size: isDashboard ? 11.5 : 10, weight: .medium))
                Spacer()
                Button(AppStrings.tr(en: "Resume", zh: "恢复计划")) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        fanViewModel.resetScheduleOverride()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .semibold))
                Text(AppStrings.tr(en: "Game closed · Auto in \(remaining)s", zh: "游戏已退出 · \(remaining) 秒后恢复系统自动"))
                    .font(.system(size: isDashboard ? 11.5 : 10, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if fanViewModel.currentMode == .custom, let remaining = fanViewModel.ruleDownshiftRemainingSeconds {
            let current = fanViewModel.activeRule?.speedPercentage ?? 0
            let pending = fanViewModel.pendingRuleDownshiftSpeedPercentage ?? 0
            let pendingStr = pending == 0 ? AppStrings.tr(en: "hardware minimum speed", zh: "硬件最低转速") : "\(pending)%"
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .semibold))
                Text(AppStrings.tr(
                    en: "Downshift holding current speed · \(pendingStr) in \(remaining)s",
                    zh: "降速缓冲生效中：维持 \(current)% · \(remaining) 秒后切至 \(pendingStr)"
                ))
                .font(.system(size: isDashboard ? 11.5 : 10, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if isDashboard {
            HStack(spacing: 5) {
                Text(quietModeSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.top, 1)
        }
    }

    private var quietModeSummary: String {
        switch fanViewModel.currentMode {
        case .auto:
            return AppStrings.tr(en: "macOS automatically manages fan speed based on thermal sensors.", zh: "macOS 系统根据各传感器温度自动调节风扇转速。")
        case .fullBlast:
            return AppStrings.tr(en: "All fans forced to maximum RPM for peak cooling.", zh: "所有风扇强制以最大转速运转，全力散热。")
        case .manual:
            return AppStrings.tr(en: "Fixed target RPM per fan.", zh: "由下方滑块为各风扇指定固定目标转速。")
        case .custom:
            return AppStrings.tr(en: "Dynamic curves based on control temperature (\(fanViewModel.controlAverageTemp)).", zh: "依据硬件温度动态调速（控制基准均温：\(fanViewModel.controlAverageTemp)）。")
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

            VStack(spacing: 6) {
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
                    if fanViewModel.isGameModeUserOverridden {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                                Text(AppStrings.tr(en: "Overridden", zh: "已手动接管"))
                                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            Button(AppStrings.tr(en: "Resume", zh: "恢复联动")) {
                                fanViewModel.resumeGameModeLinkage()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 5, height: 5)
                            Text(AppStrings.tr(en: "Active · Rules", zh: "生效中 · 规则"))
                                .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                        }
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: AppImages.schedule)
                    .font(.system(size: isDashboard ? 11 : 10, weight: .bold))
                    .foregroundColor(.teal)
                Text(isDashboard ? AppStrings.scheduleSectionTitle : AppStrings.scheduleSectionTitle.uppercased())
                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                Spacer()

                if fanViewModel.fanScheduleConfig.isEnabled {
                    if fanViewModel.isScheduleOverridden {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                                Text(AppStrings.scheduleOverriddenBadge)
                                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            Button(AppStrings.tr(en: "Resume", zh: "恢复计划")) {
                                fanViewModel.resetScheduleOverride()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else if fanViewModel.isScheduleActive {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal).frame(width: 5, height: 5)
                            Text("\(AppStrings.scheduleActiveBadge) · \(fanViewModel.fanScheduleConfig.scheduledMode.localizedTitle)")
                                .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.teal)
                        }
                    } else {
                        Text(String(format: "%02d:%02d-%02d:%02d", fanViewModel.fanScheduleConfig.startHour, fanViewModel.fanScheduleConfig.startMinute, fanViewModel.fanScheduleConfig.endHour, fanViewModel.fanScheduleConfig.endMinute))
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
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
                .font(.system(size: isDashboard ? 11 : 9.5, weight: .semibold))

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

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(AppStrings.scheduleStartTime)
                                .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                                .foregroundColor(.secondary)
                            DatePicker("", selection: startDateBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .controlSize(.mini)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))

                        HStack(spacing: 4) {
                            Text(AppStrings.scheduleEndTime)
                                .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                                .foregroundColor(.secondary)
                            DatePicker("", selection: endDateBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .controlSize(.mini)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            if isCrossMidnight {
                                HStack(spacing: 2) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 8))
                                    Text(AppStrings.crossMidnightTag)
                                        .font(.system(size: isDashboard ? 10 : 8.5, weight: .semibold))
                                }
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.12), in: Capsule())
                            }

                            Text("(\(durationString))")
                                .font(.system(size: isDashboard ? 10 : 8.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider().opacity(0.2)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(AppStrings.scheduledModeLabel)
                                .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                                .foregroundColor(.secondary)
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
                                .font(.system(size: isDashboard ? 11 : 9, weight: .medium))
                                .foregroundColor(.secondary)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.035)))
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
        return "\(rule.speedPercentage)% (\(rpm) RPM)"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Active status badge
                Circle()
                    .fill(isActive ? Color.green : (isPending ? Color.orange : Color.clear))
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(isActive ? Color.green : (isPending ? Color.orange : Color.secondary.opacity(0.3)), lineWidth: 1))

                Text("≥ \(Int(rule.temperature))°C")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? .green : (isPending ? .orange : .primary))
                    .frame(minWidth: 50, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: isDashboard ? 11 : 8, weight: .bold))
                    .foregroundColor(.secondary)

                Text(estimatedRPMText)
                    .font(.system(size: isDashboard ? 11 : 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .green : (isPending ? .orange : .secondary))

                Spacer()

                if isActive {
                    Text(AppStrings.active)
                        .font(.system(size: 7.5, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                        .foregroundColor(.green)
                } else if isPending {
                    HStack(spacing: 2) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 6.5))
                        Text(AppStrings.tr(en: "PENDING", zh: "待生效"))
                            .font(.system(size: 7.5, weight: .black))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                    .foregroundColor(.orange)
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
                .fill(isActive ? Color.green.opacity(0.08) : (isPending ? Color.orange.opacity(0.06) : Color.primary.opacity(0.035)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Color.green.opacity(0.3) : (isPending ? Color.orange.opacity(0.3) : Color.clear), lineWidth: 1)
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
                    .font(.system(size: isDashboard ? 12.5 : 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(utilization > 0.85 ? Color.orange : Color.primary)
                    .frame(minWidth: 96, alignment: .trailing)
            }

            ProgressView(value: utilization)
                .progressViewStyle(.linear)
                .tint(utilization > 0.85 ? .orange : .indigo)

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isManual)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .onAppear {
            localSliderValue = Double(targetRPM > 0 ? targetRPM : fan.currentRPM)
        }
    }
}
