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

    private var cardCornerRadius: CGFloat {
        compact ? 18 : 22
    }

    private var cardPadding: CGFloat {
        compact ? 14 : 20
    }

    private var minimumCardHeight: CGFloat {
        compact ? 122 : 164
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(compact ? .system(size: 15, weight: .bold) : .title3)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: compact ? 9 : 10, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text(value)
                        .font(.system(size: compact ? 21 : 30, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: compact ? 10 : 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else if compact {
                        Text(" ")
                            .font(.system(size: 10, weight: .semibold))
                            .hidden()
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
        .padding(cardPadding)
        .frame(maxWidth: .infinity, minHeight: minimumCardHeight, alignment: .topLeading)
        .liquidGlassCard(
            cornerRadius: cardCornerRadius,
            tint: color,
            style: .regular,
            shadowOpacity: compact ? 0.12 : 0.16
        )
    }
}
