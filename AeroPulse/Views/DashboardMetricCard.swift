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

    private var cardPadding: CGFloat {
        compact ? 12 : 16
    }

    private var minimumCardHeight: CGFloat {
        compact ? 116 : 152
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: compact ? 20 : 28, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(" ")
                            .font(.system(size: 11, weight: .regular))
                            .hidden()
                    }
                }

                Spacer(minLength: 4)

                if showInfoButton {
                    Button {
                        action?()
                    } label: {
                        Image(systemName: AppImages.info)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.viewThermalDetails)
                }
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, minHeight: minimumCardHeight, alignment: .topLeading)
        .aeroPulseCard()
    }
}
