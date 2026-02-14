//
//  ThermalDetailView.swift
//  AeroPulse
//
//  Created by Bandan.K on 03/02/26.
//

import SwiftUI

struct ThermalDetailView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @Environment(\.dismiss) var dismiss
    var isEmbedded: Bool = false
    var layoutWidth: CGFloat? = nil

    private var cpuSensors: [SensorInfo] {
        fanViewModel.sensors.filter { isCPUSensor($0) }
    }

    private var gpuSensors: [SensorInfo] {
        let sensors = fanViewModel.sensors.filter { isGPUSensor($0) }
        return sortGPUSensors(sensors)
    }

    private var otherSensors: [SensorInfo] {
        fanViewModel.sensors.filter {
            !isCPUSensor($0) && !isGPUSensor($0)
        }
    }

    private var hasNormalizedCPUCores: Bool {
        fanViewModel.sensors.contains {
            $0.name.hasPrefix("P-Core Sensor ") || $0.name.hasPrefix("E-Core Sensor ")
        }
    }

    private var hasNormalizedGPUCores: Bool {
        fanViewModel.sensors.contains {
            $0.name.hasPrefix("GPU Core Sensor ")
        }
    }

    private var thermalColumnCount: Int {
        let widthBaseline = layoutWidth ?? (isEmbedded ? 0 : 700)
        let available = max(widthBaseline - 20, 0)
        return available >= 500 ? 2 : 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbedded {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.thermalSensors)
                            .font(.headline)
                        Text("\(fanViewModel.sensors.count) \(AppStrings.sensorsDetected)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: AppImages.close)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()
            } else {
                Text(AppStrings.thermalSensorsUpperCase)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 15)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    WaterfallColumnsLayout(columns: thermalColumnCount, spacing: 10) {
                        sensorCategoryCard(
                            title: "\(AppStrings.cpu) (\(cpuSensors.count))",
                            sensors: cpuSensors,
                            color: .orange
                        )
                        sensorCategoryCard(
                            title: "\(AppStrings.gpu) (\(gpuSensors.count))",
                            sensors: gpuSensors,
                            color: .blue
                        )
                    }

                    sensorCategoryCard(
                        title: "\(AppStrings.system) (\(otherSensors.count))",
                        sensors: otherSensors,
                        color: .green
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 500)
    }

    private func isCPUSensor(_ sensor: SensorInfo) -> Bool {
        if hasNormalizedCPUCores {
            return sensor.name.hasPrefix("P-Core Sensor ")
                || sensor.name.hasPrefix("E-Core Sensor ")
        }

        return sensor.name.contains(AppStrings.pCoreFilter)
            || sensor.name.contains(AppStrings.eCoreFilter)
            || sensor.name.contains("CPU")
    }

    private func isGPUSensor(_ sensor: SensorInfo) -> Bool {
        if hasNormalizedGPUCores {
            return sensor.name.hasPrefix("GPU Core Sensor ")
        }

        return sensor.id.hasPrefix("Tg")
            || sensor.id.hasPrefix("TG")
            || sensor.id == "vACC"
            || sensor.name.contains("GPU")
    }

    private func sortGPUSensors(_ sensors: [SensorInfo]) -> [SensorInfo] {
        sensors.sorted { lhs, rhs in
            let leftIndex = gpuCoreIndex(from: lhs.name)
            let rightIndex = gpuCoreIndex(from: rhs.name)

            switch (leftIndex, rightIndex) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func gpuCoreIndex(from name: String) -> Int? {
        let prefix = "GPU Core Sensor "
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    @ViewBuilder
    private func sensorCategoryCard(
        title: String,
        sensors: [SensorInfo],
        color: Color
    ) -> some View {
        SensorCategoryColumn(
            title: title,
            sensors: sensors,
            color: color
        )
        .liquidGlassCard(
            cornerRadius: 12,
            tint: color,
            style: .regular,
            shadowOpacity: 0.08
        )
    }
}

struct SensorCategoryColumn: View {
    let title: String
    let sensors: [SensorInfo]
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))

            if sensors.isEmpty {
                Text(AppStrings.noData)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(sensors) { sensor in
                    HStack {
                        Text(sensor.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)
                        Spacer(minLength: 6)
                        Text(String(format: AppStrings.temperatureFormat, sensor.temperature))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
