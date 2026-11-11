import SwiftUI

extension TrendTimeRange {
    var localizedTitle: String {
        switch self {
        case .fiveMinutes: return AppStrings.tr(en: "5m", zh: "5分")
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
    var tintColor: Color = AeroPulseTheme.accentInk
    var secondaryPoints: [MetricHistoryPoint]? = nil
    var secondaryColor: Color = AeroPulseTheme.textMuted
    var secondaryTitle: String? = nil
    var metricKey: String? = nil
    var secondaryMetricKey: String? = nil

    @AppStorage("AeroPulse.SelectedTrendTimeRange") private var selectedRangeRaw: String = TrendTimeRange.fiveMinutes.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects
    @State private var hoverLocation: CGPoint? = nil
    @Namespace private var pillNamespace

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
            if rollups.count > 1 {
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
            if rollups.count > 1 {
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

    private var statMinVal: Double? {
        if selectedRange.isLongTerm {
            let mins = (primaryFiltered + secondaryFiltered).compactMap(\.minValue)
            if let m = mins.min() { return m }
        }
        return combinedValues.min()
    }

    private var statMaxVal: Double? {
        if selectedRange.isLongTerm {
            let maxs = (primaryFiltered + secondaryFiltered).compactMap(\.maxValue)
            if let m = maxs.max() { return m }
        }
        return combinedValues.max()
    }

    private var rangeBounds: (lower: Double, upper: Double) {
        let allMins = (selectedRange.isLongTerm ? (primaryFiltered + secondaryFiltered).compactMap(\.minValue) : []) + combinedValues
        let allMaxs = (selectedRange.isLongTerm ? (primaryFiltered + secondaryFiltered).compactMap(\.maxValue) : []) + combinedValues
        guard let minVal = allMins.min(), let maxVal = allMaxs.max() else {
            return (0, 100)
        }
        let span = max(4.0, maxVal - minVal)
        return (minVal - span * 0.12, maxVal + span * 0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            subHeaderRow
            chartArea
                .frame(height: 96)
        }
        .padding(16)
        .aeroPulseCard()
        .onAppear {
            if selectedRangeRaw == "1m" || selectedRangeRaw == "15m" {
                selectedRangeRaw = TrendTimeRange.fiveMinutes.rawValue
            }
        }
    }

    private var headerRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                legendGroup
                Spacer(minLength: 8)
                timeRangeSelector
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    legendGroup
                    Spacer(minLength: 4)
                }
                HStack {
                    Spacer(minLength: 0)
                    timeRangeSelector
                }
            }
        }
    }

    private var legendGroup: some View {
        HStack(spacing: 16) {
            // Lead series: Cobalt accent
            HStack(spacing: 8) {
                Circle()
                    .fill(AeroPulseTheme.accentInk)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textSecondary)

                if let latest = primaryFiltered.last?.value ?? points.last?.value {
                    Text(formatValue(latest))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textPrimary)
                }
            }

            // Reference series: quiet neutral step
            if let secLatest = secondaryFiltered.last?.value ?? secondaryPoints?.last?.value,
               let secTitle = secondaryTitle {
                HStack(spacing: 8) {
                    Circle()
                        .strokeBorder(AeroPulseTheme.textMuted, lineWidth: 1.5)
                        .frame(width: 6, height: 6)

                    Text(secTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)

                    Text(formatValue(secLatest))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(AeroPulseTheme.textSecondary)
                }
            }
        }
    }

    private var subHeaderRow: some View {
        HStack(spacing: 12) {
            if let minVal = statMinVal, let maxVal = statMaxVal {
                if selectedRange.isLongTerm {
                    let avg = combinedValues.reduce(0, +) / Double(max(1, combinedValues.count))
                    statItem(label: AppStrings.trendAvg, value: formatCompactValue(avg))
                }
                statItem(label: AppStrings.trendMin, value: formatCompactValue(minVal))
                statItem(label: AppStrings.trendMax, value: formatCompactValue(maxVal))
            } else {
                Text(AppStrings.tr(en: "Collecting telemetry…", zh: "等待遥测数据…"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AeroPulseTheme.textMuted)
            }

            Spacer(minLength: 4)

            Text(selectedRange.localizedTitle)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textMuted)
        }
    }

    private func statItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AeroPulseTheme.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(AeroPulseTheme.textSecondary)
        }
    }

    private func formatValue(_ val: Double) -> String {
        if unit == "°C" {
            return String(format: "%.0f°C", val)
        } else {
            return String(format: "%.0f %@", val, unit)
        }
    }

    private func formatCompactValue(_ val: Double) -> String {
        if unit == "°C" {
            return "\(Int(val))°C"
        } else {
            return "\(Int(val)) \(unit)"
        }
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 2) {
            ForEach(TrendTimeRange.allCases) { range in
                let isSelected = selectedRange == range
                Button {
                    withAnimation(reduceMotion || reduceVisualEffects ? nil : AeroPulseTheme.motionFast) {
                        selectedRangeRaw = range.rawValue
                    }
                } label: {
                    Text(range.localizedTitle)
                        .font(.system(size: 11, weight: isSelected ? .medium : .regular, design: .monospaced))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                                    .fill(AeroPulseTheme.raisedSurface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AeroPulseTheme.innerRadius, style: .continuous)
                                            .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                                    }
                                    .matchedGeometryEffect(id: "selectedRangePill", in: pillNamespace)
                            }
                        }
                        .foregroundStyle(isSelected ? AeroPulseTheme.textPrimary : AeroPulseTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                .fill(AeroPulseTheme.deepestSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: AeroPulseTheme.controlRadius, style: .continuous)
                        .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                }
        }
    }

    private var chartArea: some View {
        let primary = primaryFiltered
        let secondary = secondaryFiltered
        let bounds = rangeBounds
        let duration = selectedRange.duration
        let currentNow = now

        let oldestDate = (primary + secondary).map(\.timestamp).min() ?? currentNow
        let availableHistory = max(0, currentNow.timeIntervalSince(oldestDate))
        let effectiveDuration = min(duration, max(60.0, availableHistory))

        let leadColor = AeroPulseTheme.accentInk
        let refColor = AeroPulseTheme.textMuted

        return ZStack {
            if primary.count > 1 || secondary.count > 1 {
                Canvas { context, size in
                    let w = size.width
                    let h = size.height

                    // Quiet horizontal hairline grid at 25%, 50%, 75%
                    for frac in [0.25, 0.50, 0.75] {
                        var gridPath = Path()
                        gridPath.move(to: CGPoint(x: 0, y: h * frac))
                        gridPath.addLine(to: CGPoint(x: w, y: h * frac))
                        context.stroke(
                            gridPath,
                            with: .color(AeroPulseTheme.hairline),
                            style: StrokeStyle(lineWidth: 1)
                        )
                    }

                    // Muted monospaced Y-axis bounds
                    let topLabel = Text(formatCompactValue(bounds.upper))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(AeroPulseTheme.textMuted)
                    context.draw(topLabel, at: CGPoint(x: w - 4, y: 4), anchor: .topTrailing)

                    let btmLabel = Text(formatCompactValue(bounds.lower))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(AeroPulseTheme.textMuted)
                    context.draw(btmLabel, at: CGPoint(x: w - 4, y: h - 4), anchor: .bottomTrailing)

                    func computePoint(pt: ChartDataPoint) -> CGPoint {
                        let elapsed = max(0, min(effectiveDuration, currentNow.timeIntervalSince(pt.timestamp)))
                        let x = w * (1.0 - CGFloat(elapsed / effectiveDuration))
                        let normY = (pt.value - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                        let y = max(4.0, min(h - 4.0, h * (1.0 - CGFloat(normY))))
                        return CGPoint(x: x, y: y)
                    }

                    // Secondary reference series: quiet neutral line, no area wash
                    if secondary.count > 1 {
                        let coords = secondary.map(computePoint)
                        renderSeries(
                            points: secondary,
                            coords: coords,
                            color: refColor,
                            in: context,
                            height: h,
                            bounds: bounds,
                            isLeadSeries: false
                        )
                    }

                    // Primary lead series: Cobalt accent + restrained single-hue fade
                    if primary.count > 1 {
                        let coords = primary.map(computePoint)
                        renderSeries(
                            points: primary,
                            coords: coords,
                            color: leadColor,
                            in: context,
                            height: h,
                            bounds: bounds,
                            isLeadSeries: true
                        )
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

                            let minDistance = min(
                                closestPri.map { abs(computePoint(pt: $0).x - loc.x) } ?? .infinity,
                                closestSec.map { abs(computePoint(pt: $0).x - loc.x) } ?? .infinity
                            )

                            if minDistance <= 36 {
                                var vGuide = Path()
                                vGuide.move(to: CGPoint(x: snapX, y: 0))
                                vGuide.addLine(to: CGPoint(x: snapX, y: h))
                                context.stroke(
                                    vGuide,
                                    with: .color(AeroPulseTheme.textMuted.opacity(0.45)),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )

                                if let secPt = closestSec {
                                    let coord = computePoint(pt: secPt)
                                    let rCore: CGFloat = 3
                                    context.fill(
                                        Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)),
                                        with: .color(refColor)
                                    )
                                }

                                if let priPt = closestPri {
                                    let coord = computePoint(pt: priPt)
                                    let rCore: CGFloat = 3.5
                                    context.fill(
                                        Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)),
                                        with: .color(leadColor)
                                    )
                                }

                                let targetTime = closestPri?.timestamp ?? closestSec?.timestamp ?? currentNow
                                let timeStr: String
                                switch selectedRange {
                                case .fiveMinutes, .thirtyMinutes:
                                    timeStr = Self.timeFormatter.string(from: targetTime)
                                case .twentyFourHours:
                                    timeStr = Self.timeFormatter24h.string(from: targetTime)
                                case .sevenDays, .thirtyDays:
                                    timeStr = Self.dateFormatterMultiDay.string(from: targetTime)
                                }

                                var parts: [String] = [timeStr]
                                if let pri = closestPri {
                                    if selectedRange.isLongTerm, let minV = pri.minValue, let maxV = pri.maxValue {
                                        parts.append(unit == "°C" ? String(format: "%.0f°C (%.0f–%.0f)", pri.value, minV, maxV) : String(format: "%.0f %@ (%.0f–%.0f)", pri.value, unit, minV, maxV))
                                    } else {
                                        parts.append(formatValue(pri.value))
                                    }
                                }
                                if let sec = closestSec, let secTitle = secondaryTitle {
                                    if selectedRange.isLongTerm, let minV = sec.minValue, let maxV = sec.maxValue {
                                        parts.append(unit == "°C" ? String(format: "%@ %.0f°C (%.0f–%.0f)", secTitle, sec.value, minV, maxV) : String(format: "%@ %.0f %@ (%.0f–%.0f)", secTitle, sec.value, unit, minV, maxV))
                                    } else {
                                        parts.append(String(format: "%@ %@", secTitle, formatValue(sec.value)))
                                    }
                                }
                                let tooltipString = parts.joined(separator: " · ")

                                let badgeWidth: CGFloat = CGFloat(Double(tooltipString.count) * 6.8 + 20.0)
                                let badgeHeight: CGFloat = 24
                                let badgeX = min(w - badgeWidth / 2 - 4, max(badgeWidth / 2 + 4, snapX))
                                let priY = closestPri.map { computePoint(pt: $0).y } ?? (h * 0.5)
                                let badgeY: CGFloat = priY < 36 ? min(h - 16, priY + 24) : 14

                                let badgeRect = CGRect(
                                    x: badgeX - badgeWidth / 2,
                                    y: badgeY - badgeHeight / 2,
                                    width: badgeWidth,
                                    height: badgeHeight
                                )
                                context.fill(
                                    Path(roundedRect: badgeRect, cornerRadius: AeroPulseTheme.innerRadius),
                                    with: .color(AeroPulseTheme.raisedSurface)
                                )
                                context.stroke(
                                    Path(roundedRect: badgeRect, cornerRadius: AeroPulseTheme.innerRadius),
                                    with: .color(AeroPulseTheme.hairline),
                                    style: StrokeStyle(lineWidth: 1)
                                )

                                let resolvedText = Text(tooltipString)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(AeroPulseTheme.textPrimary)
                                context.draw(resolvedText, at: CGPoint(x: badgeX, y: badgeY), anchor: .center)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textMuted)
                    Text(AppStrings.tr(en: "Collecting telemetry…", zh: "正在采集走势数据…"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AeroPulseTheme.textSecondary)
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
        points: [ChartDataPoint],
        coords: [CGPoint],
        color: Color,
        in context: GraphicsContext,
        height: CGFloat,
        bounds: (lower: Double, upper: Double),
        isLeadSeries: Bool
    ) {
        guard let first = coords.first else { return }

        if selectedRange.isLongTerm, isLeadSeries, points.count == coords.count {
            var topCoords: [CGPoint] = []
            var btmCoords: [CGPoint] = []

            for (idx, pt) in points.enumerated() {
                let x = coords[idx].x
                if let maxV = pt.maxValue, let minV = pt.minValue {
                    let normMax = (maxV - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                    let yTop = max(4.0, min(height - 4.0, height * (1.0 - CGFloat(normMax))))
                    let normMin = (minV - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                    let yBtm = max(4.0, min(height - 4.0, height * (1.0 - CGFloat(normMin))))
                    topCoords.append(CGPoint(x: x, y: yTop))
                    btmCoords.append(CGPoint(x: x, y: yBtm))
                }
            }

            if topCoords.count > 1 && btmCoords.count > 1 {
                var bandPath = Path()
                bandPath.move(to: topCoords[0])
                for pt in topCoords.dropFirst() {
                    bandPath.addLine(to: pt)
                }
                for pt in btmCoords.reversed() {
                    bandPath.addLine(to: pt)
                }
                bandPath.closeSubpath()
                context.fill(bandPath, with: .color(color.opacity(0.08)))
            }
        }

        var linePath = Path()
        linePath.move(to: first)
        for pt in coords.dropFirst() {
            linePath.addLine(to: pt)
        }

        if isLeadSeries, let last = coords.last {
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: last.x, y: height))
            fillPath.addLine(to: CGPoint(x: first.x, y: height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.14), color.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: height)
                )
            )
        }

        context.stroke(
            linePath,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: isLeadSeries ? 1.75 : 1.25,
                lineCap: .round,
                lineJoin: .round,
                dash: isLeadSeries ? [] : [4, 3]
            )
        )

        if let last = coords.last {
            let radius: CGFloat = isLeadSeries ? 2.5 : 2.0
            let dotRect = CGRect(x: last.x - radius, y: last.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))
        }
    }
}
