//
//  DashboardMetricCard.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 03/02/26.
//

import SwiftUI

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var compact: Bool = false
    var showInfoButton: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(compact ? .system(size: 16, weight: .bold) : .title3)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text(value)
                        .font(.system(size: compact ? 20 : 28, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: compact ? 10 : 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: 2)

                if showInfoButton {
                    Button {
                        action?()
                    } label: {
                        Image(systemName: AppImages.info)
                            .font(.system(size: 14))
                            .foregroundColor(color.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(AppStrings.viewThermalDetails)
                }
            }
        }
        .padding(compact ? 14 : 20)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .background(.ultraThinMaterial)
        .cornerRadius(compact ? 16 : 20)
        .shadow(color: Color.black.opacity(0.1), radius: compact ? 10 : 15, x: 0, y: compact ? 5 : 8)
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 16 : 20)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
