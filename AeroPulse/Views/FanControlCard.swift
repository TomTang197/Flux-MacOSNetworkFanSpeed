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
                Text(isDashboard ? "Fan control" : "FAN CONTROL")
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
                Picker("Mode", selection: Binding(
                    get: { fanViewModel.currentMode },
                    set: { newMode in
                        DispatchQueue.main.async {
                            fanViewModel.setFanMode(newMode, isUserInitiated: true)
                        }
                    }
                )) {
                    ForEach(FanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
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
                    Toggle("Sync All Fans", isOn: $fanViewModel.syncAllFans)
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
        case .auto: return "System automatic control"
        case .fullBlast: return "Maximum speed selected"
        case .manual: return "Manual targets selected"
        case .custom: return "Temperature rules selected"
        }
    }

    private var statusDetail: String {
        switch fanViewModel.currentMode {
        case .auto: return "macOS manages fan speed. Live readings are shown below."
        case .fullBlast: return "Requests each fan’s maximum speed. Compare the live RPM below."
        case .manual: return "Adjust the target for each fan below. Live RPM may take time to reach the target."
        case .custom: return "Rule input: \(fanViewModel.controlAverageTemp), the higher CPU / GPU average. Live RPM is shown below."
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isDashboard ? "Temperature rules" : "TEMPERATURE THRESHOLD RULES")
                    .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                Spacer()
                Text("Control Avg: \(fanViewModel.controlAverageTemp)")
                    .font(.system(size: isDashboard ? 11 : 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 8) {
                Toggle(
                    "Delay Downshift",
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
                    Text("Holding current speed · Downshift in \(remaining)s")
                        .font(.system(size: isDashboard ? 11 : 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer()
                }
            } else if fanViewModel.isRulesAtMinimum {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("Rules Active · Hardware minimum speed")
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
                        Text("Trigger: ≥ \(Int(newRuleTemp))°C")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                            .frame(width: 90, alignment: .leading)
                        Slider(value: $newRuleTemp, in: 35...95, step: 1)
                            .controlSize(.mini)
                    }
                    HStack(spacing: 10) {
                        Text("Speed: \(newRulePercentage)%")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                            .frame(width: 90, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(newRulePercentage) },
                            set: { newRulePercentage = Int($0) }
                        ), in: 10...100, step: 5)
                        .controlSize(.mini)
                    }
                    HStack {
                        Button("Cancel") {
                            isAddingRule = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Spacer()

                        Button("Save Rule") {
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
                        Label("Add Threshold", systemImage: "plus.circle.fill")
                            .font(.system(size: isDashboard ? 11 : 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Spacer()

                    Button("Reset Defaults") {
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
                        Text("Active · Rules")
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                } else if let remaining = fanViewModel.gameModeCooldownRemainingSeconds {
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text("Cooldown \(remaining)s")
                            .font(.system(size: isDashboard ? 11 : 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }

            HStack(spacing: 8) {
                Toggle(
                    "Auto Rules in Game Mode",
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
                    Text("ACTIVE")
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
                        Text("Temp: \(Int(temp))°C")
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
                        Text("Speed: \(percentage)%")
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
                Text("\(fan.minRPM) MIN")
                Spacer()
                if isManual {
                    Text("TARGET: \(Int(isDragging ? localSliderValue : Double(targetRPM))) RPM")
                        .foregroundColor(.indigo)
                }
                Spacer()
                Text("\(fan.maxRPM) MAX")
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
