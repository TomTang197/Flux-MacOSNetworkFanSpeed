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

    private var thermalColumnCount: Int {
        let widthBaseline = layoutWidth ?? (isEmbedded ? 0 : 700)
        return ThermalSensorProcessing.thermalDetailColumnCount(
            availableWidth: Double(widthBaseline)
        )
    }

    var body: some View {
        let sensorGroups = ThermalSensorGroups(sensors: fanViewModel.sensors)

        VStack(spacing: 0) {
            if !isEmbedded {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.thermalSensors)
                            .font(.system(size: 15, weight: .bold))
                        Text("\(fanViewModel.sensors.count) \(AppStrings.sensorsDetected)")
                            .font(.system(size: 10, weight: .semibold))
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
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(0.95)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 15)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sensorCategoryCard(
                        title: categoryTitle(
                            name: AppStrings.cpu,
                            sensors: sensorGroups.cpu,
                            average: ThermalSensorProcessing.averageCPUTemperatureSample(
                                from: fanViewModel.sensors
                            )?.value
                        ),
                        sensors: sensorGroups.cpu,
                        color: .orange,
                        columnCount: thermalColumnCount
                    )

                    sensorCategoryCard(
                        title: categoryTitle(
                            name: AppStrings.gpu,
                            sensors: sensorGroups.gpu,
                            average: ThermalSensorProcessing.averageGPUTemperatureSample(
                                from: fanViewModel.sensors
                            )?.value
                        ),
                        sensors: sensorGroups.gpu,
                        color: .blue,
                        columnCount: thermalColumnCount
                    )

                    sensorCategoryCard(
                        title: "\(AppStrings.system) (\(sensorGroups.system.count))",
                        sensors: sensorGroups.system,
                        color: .green,
                        columnCount: thermalColumnCount
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 500)
    }

    @ViewBuilder
    private func sensorCategoryCard(
        title: String,
        sensors: [SensorInfo],
        color: Color,
        columnCount: Int
    ) -> some View {
        SensorCategoryColumn(
            title: title,
            sensors: sensors,
            color: color,
            columnCount: columnCount
        )
        .liquidGlassCard(
            cornerRadius: 12,
            tint: color,
            style: .regular,
            shadowOpacity: 0.08
        )
    }

    private func categoryTitle(
        name: String,
        sensors: [SensorInfo],
        average: Double?
    ) -> String {
        guard let average else { return "\(name) (\(sensors.count))" }
        return "\(name) (\(sensors.count)) • AVG \(String(format: "%.1f°C", average))"
    }
}

struct SensorCategoryColumn: View, Equatable {
    let title: String
    let sensors: [SensorInfo]
    let color: Color
    let columnCount: Int

    static func == (lhs: SensorCategoryColumn, rhs: SensorCategoryColumn) -> Bool {
        lhs.title == rhs.title
            && lhs.color == rhs.color
            && lhs.sensors == rhs.sensors
            && lhs.columnCount == rhs.columnCount
    }

    private var gridColumns: [GridItem] {
        if columnCount >= 2 && sensors.count > 3 {
            return [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(color)
                    .tracking(0.9)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))

            if sensors.isEmpty {
                Text(AppStrings.noData)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 5) {
                    ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                        SensorRowView(index: index, sensor: sensor, accentColor: color)
                            .equatable()
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SensorRowView: View, Equatable {
    let index: Int
    let sensor: SensorInfo
    let accentColor: Color

    static func == (lhs: SensorRowView, rhs: SensorRowView) -> Bool {
        lhs.index == rhs.index
            && lhs.sensor == rhs.sensor
            && lhs.accentColor == rhs.accentColor
    }

    private var displayName: String {
        if sensor.name.hasPrefix("GPU Core Sensor ") {
            return "GPU \(sensor.name.dropFirst(16))"
        }
        if sensor.name.hasPrefix("S-Core Sensor ") {
            return "S-Core \(sensor.name.dropFirst(14))"
        }
        if sensor.name.hasPrefix("P-Core Sensor ") {
            return "P-Core \(sensor.name.dropFirst(14))"
        }
        if sensor.name.hasPrefix("E-Core Sensor ") {
            return "E-Core \(sensor.name.dropFirst(14))"
        }
        return sensor.name
    }

    private var tempColor: Color {
        if sensor.temperature >= 80 {
            return .red
        } else if sensor.temperature >= 60 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tempColor)
                .frame(width: 4.5, height: 4.5)

            Text(displayName)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.primary.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Spacer(minLength: 2)

            Text(String(format: "%.0f°C", sensor.temperature))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
    }
}
