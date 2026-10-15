import SwiftUI

extension TrendTimeRange {
    var localizedTitle: String {
        switch self {
        case .oneMinute: return AppStrings.tr(en: "1m", zh: "1分")
        case .fiveMinutes: return AppStrings.tr(en: "5m", zh: "5分")
        case .fifteenMinutes: return AppStrings.tr(en: "15m", zh: "15分")
        case .thirtyMinutes: return AppStrings.tr(en: "30m", zh: "30分")
        case .twentyFourHours: return AppStrings.tr(en: "24h", zh: "24时")
        case .sevenDays: return AppStrings.tr(en: "7d", zh: "7天")
        case .thirtyDays: return AppStrings.tr(en: "30d", zh: "30天")
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let minValue: Double?
    let maxValue: Double?

    init(id: UUID = UUID(), timestamp: Date, value: Double, minValue: Double? = nil, maxValue: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
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
    var metricKey: String? = nil
    var secondaryMetricKey: String? = nil

    @AppStorage("AeroPulse.SelectedTrendTimeRange") private var selectedRangeRaw: String = TrendTimeRange.fiveMinutes.rawValue
    @State private var hoverLocation: CGPoint? = nil

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    private static let timeFormatter24h: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private static let dateFormatterMultiDay: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df
    }()

    private var selectedRange: TrendTimeRange {
        TrendTimeRange(rawValue: selectedRangeRaw) ?? .fiveMinutes
    }

    private var now: Date { Date() }

    private var primaryFiltered: [ChartDataPoint] {
        let currentNow = now
        if selectedRange.isLongTerm, let metricKey {
            let rollups = TelemetryHistoryStore.shared.queryHistory(metricKey: metricKey, range: selectedRange, now: currentNow)
            if !rollups.isEmpty {
                return rollups.map {
                    ChartDataPoint(timestamp: $0.timestamp, value: $0.avgValue, minValue: $0.minValue, maxValue: $0.maxValue)
                }
            }
        }
        let cutoff = currentNow.addingTimeInterval(-selectedRange.duration)
        return points
            .filter { $0.timestamp >= cutoff }
            .map { ChartDataPoint(timestamp: $0.timestamp, value: $0.value) }
    }

    private var secondaryFiltered: [ChartDataPoint] {
        let currentNow = now
        if selectedRange.isLongTerm, let secondaryMetricKey {
            let rollups = TelemetryHistoryStore.shared.queryHistory(metricKey: secondaryMetricKey, range: selectedRange, now: currentNow)
            if !rollups.isEmpty {
                return rollups.map {
                    ChartDataPoint(timestamp: $0.timestamp, value: $0.avgValue, minValue: $0.minValue, maxValue: $0.maxValue)
                }
            }
        }
        guard let secondaryPoints else { return [] }
        let cutoff = currentNow.addingTimeInterval(-selectedRange.duration)
        return secondaryPoints
            .filter { $0.timestamp >= cutoff }
            .map { ChartDataPoint(timestamp: $0.timestamp, value: $0.value) }
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
                if selectedRange.isLongTerm {
                    let avg = combinedValues.reduce(0, +) / Double(max(1, combinedValues.count))
                    Text("\(AppStrings.trendAvg): \(Int(avg))\(unit)")
                    Text("·")
                    Text("\(AppStrings.trendMin): \(Int(minVal))\(unit)")
                    Text("·")
                    Text("\(AppStrings.trendMax): \(Int(maxVal))\(unit)")
                } else {
                    Text("\(AppStrings.trendMin): \(Int(minVal))\(unit)")
                    Text("·")
                    Text("\(AppStrings.trendMax): \(Int(maxVal))\(unit)")
                }
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
                        .font(.system(size: 9, weight: selectedRange == range ? .bold : .medium))
                        .padding(.horizontal, 4)
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
        let effectiveDuration: TimeInterval
        if selectedRange.isLongTerm {
            if availableHistory > min(3600.0, duration * 0.1) {
                effectiveDuration = duration
            } else {
                effectiveDuration = max(60.0, availableHistory)
            }
        } else {
            effectiveDuration = min(duration, max(30.0, availableHistory))
        }

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

                    func computePoint(pt: ChartDataPoint) -> CGPoint {
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

                    // Hover inspection crosshair and tooltip
                    if let loc = hoverLocation {
                        let allPoints = primary + secondary
                        if !allPoints.isEmpty {
                            let closestPri = primary.min(by: {
                                abs(computePoint(pt: $0).x - loc.x) < abs(computePoint(pt: $1).x - loc.x)
                            })
                            let closestSec = secondary.min(by: {
                                abs(computePoint(pt: $0).x - loc.x) < abs(computePoint(pt: $1).x - loc.x)
                            })

                            let snapX = closestPri.map { computePoint(pt: $0).x }
                                ?? closestSec.map { computePoint(pt: $0).x }
                                ?? loc.x

                            // Vertical indicator hairline
                            var vGuide = Path()
                            vGuide.move(to: CGPoint(x: snapX, y: 0))
                            vGuide.addLine(to: CGPoint(x: snapX, y: h))
                            context.stroke(
                                vGuide,
                                with: .color(.primary.opacity(0.40)),
                                style: StrokeStyle(lineWidth: 1.0, dash: [3, 3])
                            )

                            // Secondary dot snap
                            if let secPt = closestSec {
                                let coord = computePoint(pt: secPt)
                                let r: CGFloat = 3.5
                                let rect = CGRect(x: coord.x - r, y: coord.y - r, width: r * 2, height: r * 2)
                                context.fill(Path(ellipseIn: rect), with: .color(secondaryColor))
                                context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1.2))
                            }

                            // Primary dot snap
                            if let priPt = closestPri {
                                let coord = computePoint(pt: priPt)
                                let r: CGFloat = 3.5
                                let rect = CGRect(x: coord.x - r, y: coord.y - r, width: r * 2, height: r * 2)
                                context.fill(Path(ellipseIn: rect), with: .color(tintColor))
                                context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1.2))
                            }

                            // Floating HUD Tooltip
                            let targetTime = closestPri?.timestamp ?? closestSec?.timestamp ?? currentNow
                            let timeStr: String
                            switch selectedRange {
                            case .oneMinute, .fiveMinutes, .fifteenMinutes, .thirtyMinutes:
                                timeStr = Self.timeFormatter.string(from: targetTime)
                            case .twentyFourHours:
                                timeStr = Self.timeFormatter24h.string(from: targetTime)
                            case .sevenDays, .thirtyDays:
                                timeStr = Self.dateFormatterMultiDay.string(from: targetTime)
                            }

                            var parts: [String] = [timeStr]
                            if let pri = closestPri {
                                if selectedRange.isLongTerm, let minV = pri.minValue, let maxV = pri.maxValue {
                                    parts.append(String(format: "%.0f %@ (%.0f~%.0f)", pri.value, unit, minV, maxV))
                                } else {
                                    parts.append(String(format: "%.0f %@", pri.value, unit))
                                }
                            }
                            if let sec = closestSec, let secTitle = secondaryTitle {
                                if selectedRange.isLongTerm, let minV = sec.minValue, let maxV = sec.maxValue {
                                    parts.append(String(format: "%@: %.0f %@ (%.0f~%.0f)", secTitle, sec.value, unit, minV, maxV))
                                } else {
                                    parts.append(String(format: "%@: %.0f %@", secTitle, sec.value, unit))
                                }
                            }
                            let tooltipString = parts.joined(separator: " · ")

                            let badgeWidth: CGFloat = CGFloat(tooltipString.count * 6 + 18)
                            let badgeHeight: CGFloat = 18
                            let badgeX = min(w - badgeWidth / 2 - 4, max(badgeWidth / 2 + 4, snapX))
                            let badgeY: CGFloat = 11

                            let badgeRect = CGRect(
                                x: badgeX - badgeWidth / 2,
                                y: badgeY - badgeHeight / 2,
                                width: badgeWidth,
                                height: badgeHeight
                            )
                            context.fill(
                                Path(roundedRect: badgeRect, cornerRadius: 4),
                                with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                            )
                            context.stroke(
                                Path(roundedRect: badgeRect, cornerRadius: 4),
                                with: .color(.secondary.opacity(0.35)),
                                style: StrokeStyle(lineWidth: 0.8)
                            )

                            let resolvedText = Text(tooltipString)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            context.draw(resolvedText, at: CGPoint(x: badgeX, y: badgeY), anchor: .center)
                        }
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
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
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
