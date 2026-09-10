import SwiftUI

/// Content surfaces stay lightweight; the menu bar window supplies the glass.
struct MenuBarSection<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(reduceTransparency || reduceVisualEffects ? 1 : 0.50))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? AnyShapeStyle(Color.primary.opacity(0.4))
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.primary.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ),
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
            withAnimation(reduceMotion || reduceVisualEffects ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.1)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
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
    var iconColor: Color? = nil
    var size: CGFloat = 20
    var subtitle: String? = nil
    var progress: Double? = nil
    var progressColors: [Color]? = nil

    static func == (lhs: MenuBarReadout, rhs: MenuBarReadout) -> Bool {
        lhs.title == rhs.title &&
        lhs.value == rhs.value &&
        lhs.icon == rhs.icon &&
        lhs.iconColor == rhs.iconColor &&
        lhs.size == rhs.size &&
        lhs.subtitle == rhs.subtitle &&
        lhs.progress == rhs.progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor ?? .secondary)
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: size, weight: .semibold))
                .tracking(-0.2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.identity)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if let progress {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 3.5)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: progressColors ?? [iconColor ?? .accentColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(proxy.size.width, proxy.size.width * CGFloat(progress))))
                        }
                    }
                    .padding(.top, 2)
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
    var iconColor: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor ?? .secondary)
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.identity)
        }
        .font(.system(size: 11.5))
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarProcessList: View, Equatable {
    let title: String
    let lines: [NetworkViewModel.ProcessUsageLine]
    var emptyText = AppStrings.tr(en: "Waiting for process data…", zh: "等待进程数据…")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if lines.isEmpty {
                Text(emptyText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(Array(lines.prefix(3)), id: \.pid) { line in
                    HStack(spacing: 8) {
                        Text(line.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(line.value)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .fixedSize()
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
