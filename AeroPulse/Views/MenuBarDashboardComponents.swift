import SwiftUI

/// Quiet Graphite card surface for menu bar popover sections.
struct MenuBarSection<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AeroPulseTheme.cardRadius, style: .continuous)
                .fill(AeroPulseTheme.cardSurface.opacity(reduceTransparency || reduceVisualEffects ? 1.0 : 0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AeroPulseTheme.cardRadius, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? AeroPulseTheme.textPrimary.opacity(0.32)
                        : AeroPulseTheme.hairline,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }
}

struct MenuBarSectionHeading: View {
    let title: String
    let detailTitle: String
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(reduceMotion || reduceVisualEffects ? nil : AeroPulseTheme.motionPanel) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AeroPulseTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(isHovered ? AeroPulseTheme.textPrimary : AeroPulseTheme.textMuted)
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                    .fill(isHovered ? AeroPulseTheme.raisedSurface : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(detailTitle)
        .accessibilityValue(isExpanded ? AppStrings.tr(en: "Expanded", zh: "已展开") : AppStrings.tr(en: "Collapsed", zh: "已折叠"))
        .help(detailTitle)
    }
}

struct MenuBarReadout: View, Equatable {
    let title: String
    let value: String
    var icon: String? = nil
    var size: CGFloat = 20
    var subtitle: String? = nil
    var progress: Double? = nil

    static func == (lhs: MenuBarReadout, rhs: MenuBarReadout) -> Bool {
        lhs.title == rhs.title &&
        lhs.value == rhs.value &&
        lhs.icon == rhs.icon &&
        lhs.size == rhs.size &&
        lhs.subtitle == rhs.subtitle &&
        lhs.progress == rhs.progress
    }

    private func fillForProgress(_ value: Double) -> Color {
        if value >= 0.92 { return AeroPulseTheme.negative }
        if value >= 0.80 { return AeroPulseTheme.warning }
        return AeroPulseTheme.accentFill
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
            }

            Text(value)
                .font(.system(size: size, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.identity)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .lineLimit(1)
            }

            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AeroPulseTheme.textPrimary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(fillForProgress(progress))
                            .frame(width: max(0, min(proxy.size.width, proxy.size.width * CGFloat(progress))))
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarValueRow: View, Equatable {
    let title: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AeroPulseTheme.textMuted)
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.identity)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarProcessList: View, Equatable {
    let title: String
    let lines: [NetworkViewModel.ProcessUsageLine]
    var emptyText = AppStrings.tr(en: "Waiting for process data…", zh: "等待进程数据…")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textMuted)
            if lines.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(lines.prefix(3)), id: \.pid) { line in
                    HStack(spacing: 8) {
                        Text(line.name)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AeroPulseTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(line.value)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AeroPulseTheme.textSecondary)
                            .fixedSize()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                            .fill(AeroPulseTheme.raisedSurface)
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
