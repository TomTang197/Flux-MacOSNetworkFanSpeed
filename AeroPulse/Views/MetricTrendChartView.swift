import SwiftUI

extension TrendTimeRange {
    var localizedTitle: String {
        switch self {
        case .oneMinute: return AppStrings.tr(en: "1m", zh: "1分")
        case .fiveMinutes: return AppStrings.tr(en: "5m", zh: "5分")
        case .fifteenMinutes: return AppStrings.tr(en: "15m", zh: "15分")
        case .thirtyMinutes: return AppStrings.tr(en: "30m", zh: "30分")
        }
    }
}

struct MetricTrendChartView: View {
    let title: String
    let points: [MetricHistoryPoint]
    let unit: String
    let tintColor: Color
    var secondaryPoints: [MetricHistoryPoint]? = nil
    var secondaryColor: Color = .purple
    var secondaryTitle: String? = nil

    @AppStorage("AeroPulse.SelectedTrendTimeRange") private var selectedRangeRaw: String = TrendTimeRange.fiveMinutes.rawValue

    private var selectedRange: TrendTimeRange {
        TrendTimeRange(rawValue: selectedRangeRaw) ?? .fiveMinutes
    }

    private var now: Date { Date() }

    private var primaryFiltered: [MetricHistoryPoint] {
        let cutoff = now.addingTimeInterval(-selectedRange.duration)
        return points.filter { $0.timestamp >= cutoff }
    }

    private var secondaryFiltered: [MetricHistoryPoint] {
        guard let secondaryPoints else { return [] }
        let cutoff = now.addingTimeInterval(-selectedRange.duration)
        return secondaryPoints.filter { $0.timestamp >= cutoff }
    }

    private var combinedValues: [Double] {
        primaryFiltered.map(\.value) + secondaryFiltered.map(\.value)
    }

    private var rangeBounds: (lower: Double, upper: Double) {
        guard let minVal = combinedValues.min(), let maxVal = combinedValues.max() else {
            return (0, 100)
        }
        let span = max(4.0, maxVal - minVal)
        return (minVal - span * 0.12, maxVal + span * 0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            headerRow
            subHeaderRow
            chartArea
                .frame(height: 65)
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .transaction { $0.animation = nil }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let latest = primaryFiltered.last?.value ?? points.last?.value {
                    Text(String(format: "%.0f %@", latest, unit))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(tintColor)
                }

                if let secLatest = secondaryFiltered.last?.value ?? secondaryPoints?.last?.value,
                   let secTitle = secondaryTitle {
                    Text("· \(secTitle)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f %@", secLatest, unit))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(secondaryColor)
                }
            }

            Spacer()

            timeRangeSelector
        }
    }

    private var subHeaderRow: some View {
        HStack(spacing: 8) {
            if let minVal = combinedValues.min(), let maxVal = combinedValues.max() {
                Text("\(AppStrings.trendMin): \(Int(minVal))\(unit)")
                Text("·")
                Text("\(AppStrings.trendMax): \(Int(maxVal))\(unit)")
            } else {
                Text(AppStrings.tr(en: "Waiting for telemetry…", zh: "等待遥测数据…"))
            }
            Spacer()
            Text(selectedRange.localizedTitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary.opacity(0.85))
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 2) {
            ForEach(TrendTimeRange.allCases) { range in
                Button {
                    selectedRangeRaw = range.rawValue
                } label: {
                    Text(range.localizedTitle)
                        .font(.system(size: 9.5, weight: selectedRange == range ? .bold : .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            selectedRange == range
                                ? Color.primary.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        .foregroundStyle(selectedRange == range ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var chartArea: some View {
        let primary = primaryFiltered
        let secondary = secondaryFiltered
        let bounds = rangeBounds
        let duration = selectedRange.duration
        let currentNow = now

        let oldestDate = (primary + secondary).map(\.timestamp).min() ?? currentNow
        let availableHistory = max(0, currentNow.timeIntervalSince(oldestDate))
        let effectiveDuration = min(duration, max(30.0, availableHistory))

        return ZStack {
            if primary.count > 1 || secondary.count > 1 {
                Canvas { context, size in
                    let w = size.width
                    let h = size.height

                    // Dotted center baseline guide
                    var gridPath = Path()
                    gridPath.move(to: CGPoint(x: 0, y: h * 0.5))
                    gridPath.addLine(to: CGPoint(x: w, y: h * 0.5))
                    context.stroke(
                        gridPath,
                        with: .color(.secondary.opacity(0.15)),
                        style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                    )

                    func computePoint(pt: MetricHistoryPoint) -> CGPoint {
                        let elapsed = max(0, min(effectiveDuration, currentNow.timeIntervalSince(pt.timestamp)))
                        let x = w * (1.0 - CGFloat(elapsed / effectiveDuration))
                        let normY = (pt.value - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                        let y = max(2.0, min(h - 2.0, h * (1.0 - CGFloat(normY))))
                        return CGPoint(x: x, y: y)
                    }

                    // Render secondary curve (e.g. GPU)
                    if secondary.count > 1 {
                        let coords = secondary.map(computePoint)
                        renderSeries(coords: coords, color: secondaryColor, in: context, width: w, height: h, fillAlpha: 0.10)
                    }

                    // Render primary curve (e.g. CPU or Fan RPM)
                    if primary.count > 1 {
                        let coords = primary.map(computePoint)
                        renderSeries(coords: coords, color: tintColor, in: context, width: w, height: h, fillAlpha: 0.20)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text(AppStrings.tr(en: "Collecting trend telemetry…", zh: "正在采集走势数据…"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .transaction { $0.animation = nil }
    }

    private func renderSeries(
        coords: [CGPoint],
        color: Color,
        in context: GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        fillAlpha: Double
    ) {
        guard let first = coords.first else { return }

        var linePath = Path()
        linePath.move(to: first)
        for pt in coords.dropFirst() {
            linePath.addLine(to: pt)
        }

        // Closed path for subtle gradient under-curve
        var fillPath = linePath
        if let last = coords.last {
            fillPath.addLine(to: CGPoint(x: last.x, y: height))
            fillPath.addLine(to: CGPoint(x: first.x, y: height))
            fillPath.closeSubpath()
        }

        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [color.opacity(fillAlpha), color.opacity(0.01)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: height)
            )
        )

        context.stroke(
            linePath,
            with: .color(color),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        )

        if let last = coords.last {
            let dotRect = CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))
        }
    }
}
