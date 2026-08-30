//
//  DashboardMetricCard.swift
//  AeroPulse
//
//  Created by Bandan.K on 03/02/26.
//

import SwiftUI

struct DashboardMetricCard: View, Equatable {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var compact: Bool = false
    var showInfoButton: Bool = false
    var action: (() -> Void)? = nil

    static func == (lhs: DashboardMetricCard, rhs: DashboardMetricCard) -> Bool {
        lhs.title == rhs.title
            && lhs.value == rhs.value
            && lhs.icon == rhs.icon
            && lhs.color == rhs.color
            && lhs.subtitle == rhs.subtitle
            && lhs.compact == rhs.compact
            && lhs.showInfoButton == rhs.showInfoButton
    }

    private var cardCornerRadius: CGFloat {
        compact ? 16 : 20
    }

    private var cardPadding: CGFloat {
        compact ? 13 : 18
    }

    private var minimumCardHeight: CGFloat {
        compact ? 118 : 158
    }

    private var iconFont: Font {
        .system(size: compact ? 13 : 15, weight: .semibold)
    }

    private var titleFont: Font {
        .system(size: compact ? 9 : 10, weight: .black)
    }

    private var valueFont: Font {
        .system(size: compact ? 21 : 30, weight: .bold, design: .monospaced)
    }

    private var subtitleFont: Font {
        .system(size: compact ? 10 : 11, weight: .semibold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(iconFont)
                Spacer()
                Text(title.uppercased())
                    .font(titleFont)
                    .foregroundColor(.secondary)
                    .tracking(0.9)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text(value)
                        .font(valueFont)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(" ")
                            .font(subtitleFont)
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
            shadowOpacity: compact ? 0.1 : 0.14
        )
    }
}
