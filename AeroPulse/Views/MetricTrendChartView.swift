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
    let tintColor: Color
    var secondaryPoints: [MetricHistoryPoint]? = nil
    var secondaryColor: Color = .purple
    var secondaryTitle: String? = nil
    var metricKey: String? = nil
    var secondaryMetricKey: String? = nil

    @AppStorage("AeroPulse.SelectedTrendTimeRange") private var selectedRangeRaw: String = TrendTimeRange.fiveMinutes.rawValue
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
        VStack(alignment: .leading, spacing: 7) {
            headerRow
            subHeaderRow
            chartArea
                .frame(height: 74)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            tintColor.opacity(0.12),
                            Color.primary.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)
        .onAppear {
            if selectedRangeRaw == "1m" || selectedRangeRaw == "15m" {
                selectedRangeRaw = TrendTimeRange.fiveMinutes.rawValue
            }
        }
    }

    private var headerRow: some View {
        ViewThatFits(in: .horizontal) {
            // Priority 1: Spacious single-line layout
            HStack(alignment: .center) {
                legendGroup
                Spacer(minLength: 8)
                timeRangeSelector
            }

            // Priority 2: Responsive two-line layout when width is constrained
            VStack(alignment: .leading, spacing: 6) {
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
        HStack(spacing: 12) {
            // Primary series legend & current value
            HStack(spacing: 5) {
                Circle()
                    .fill(tintColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: tintColor.opacity(0.45), radius: 2)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let latest = primaryFiltered.last?.value ?? points.last?.value {
                    Text(formatValue(latest))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(tintColor)
                }
            }

            // Secondary series legend & current value
            if let secLatest = secondaryFiltered.last?.value ?? secondaryPoints?.last?.value,
               let secTitle = secondaryTitle {
                HStack(spacing: 5) {
                    Circle()
                        .fill(secondaryColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: secondaryColor.opacity(0.45), radius: 2)

                    Text(secTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(formatValue(secLatest))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryColor)
                }
            }
        }
    }

    private var subHeaderRow: some View {
        HStack(spacing: 6) {
            if let minVal = statMinVal, let maxVal = statMaxVal {
                if selectedRange.isLongTerm {
                    let avg = combinedValues.reduce(0, +) / Double(max(1, combinedValues.count))
                    statBadge(icon: "equal", label: AppStrings.trendAvg, value: formatCompactValue(avg), color: .secondary)
                    statBadge(icon: "arrow.down", label: AppStrings.trendMin, value: formatCompactValue(minVal), color: .blue)
                    statBadge(icon: "arrow.up", label: AppStrings.trendMax, value: formatCompactValue(maxVal), color: .orange)
                } else {
                    statBadge(icon: "arrow.down", label: AppStrings.trendMin, value: formatCompactValue(minVal), color: .blue)
                    statBadge(icon: "arrow.up", label: AppStrings.trendMax, value: formatCompactValue(maxVal), color: .orange)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 9))
                    Text(AppStrings.tr(en: "Collecting telemetry…", zh: "等待遥测数据…"))
                }
                .foregroundStyle(.secondary.opacity(0.8))
            }

            Spacer(minLength: 4)

            Text(selectedRange.localizedTitle)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.05), in: Capsule())
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    private func statBadge(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2.5) {
            Image(systemName: icon)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
            return "\(Int(val))\(unit)"
        }
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 2) {
            ForEach(TrendTimeRange.allCases) { range in
                let isSelected = selectedRange == range
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        selectedRangeRaw = range.rawValue
                    }
                } label: {
                    Text(range.localizedTitle)
                        .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(tintColor.opacity(0.18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(tintColor.opacity(0.35), lineWidth: 0.8)
                                    }
                                    .shadow(color: tintColor.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "selectedRangePill", in: pillNamespace)
                            }
                        }
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
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

        return ZStack {
            if primary.count > 1 || secondary.count > 1 {
                Canvas { context, size in
                    let w = size.width
                    let h = size.height

                    // Horizontal reference grid lines at 33% and 66%
                    for frac in [0.33, 0.66] {
                        var gridPath = Path()
                        gridPath.move(to: CGPoint(x: 0, y: h * frac))
                        gridPath.addLine(to: CGPoint(x: w, y: h * frac))
                        context.stroke(
                            gridPath,
                            with: .color(.secondary.opacity(0.10)),
                            style: StrokeStyle(lineWidth: 0.5, dash: [3, 4])
                        )
                    }

                    // Y-axis top & bottom scale values (subtle, right aligned)
                    let topLabel = Text(formatCompactValue(bounds.upper))
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.35))
                    context.draw(topLabel, at: CGPoint(x: w - 2, y: 6), anchor: .topTrailing)

                    let btmLabel = Text(formatCompactValue(bounds.lower))
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.35))
                    context.draw(btmLabel, at: CGPoint(x: w - 2, y: h - 6), anchor: .bottomTrailing)

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
                        renderSeries(
                            points: secondary,
                            coords: coords,
                            color: secondaryColor,
                            in: context,
                            width: w,
                            height: h,
                            bounds: bounds,
                            fillAlpha: 0.12
                        )
                    }

                    // Render primary curve (e.g. CPU or Fan RPM)
                    if primary.count > 1 {
                        let coords = primary.map(computePoint)
                        renderSeries(
                            points: primary,
                            coords: coords,
                            color: tintColor,
                            in: context,
                            width: w,
                            height: h,
                            bounds: bounds,
                            fillAlpha: 0.22
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

                            // Only draw crosshair and tooltip if mouse is within 35px of actual data points
                            if minDistance <= 35 {
                                // Vertical indicator hairline
                                var vGuide = Path()
                                vGuide.move(to: CGPoint(x: snapX, y: 0))
                                vGuide.addLine(to: CGPoint(x: snapX, y: h))
                                context.stroke(
                                    vGuide,
                                    with: .color(.primary.opacity(0.38)),
                                    style: StrokeStyle(lineWidth: 1.0, dash: [3, 3])
                                )

                                // Secondary dot snap
                                if let secPt = closestSec {
                                    let coord = computePoint(pt: secPt)
                                    let rHalo: CGFloat = 5.5
                                    let rCore: CGFloat = 3.2
                                    context.fill(Path(ellipseIn: CGRect(x: coord.x - rHalo, y: coord.y - rHalo, width: rHalo * 2, height: rHalo * 2)), with: .color(secondaryColor.opacity(0.25)))
                                    context.fill(Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)), with: .color(secondaryColor))
                                    context.stroke(Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)), with: .color(.white), style: StrokeStyle(lineWidth: 1.2))
                                }

                                // Primary dot snap
                                if let priPt = closestPri {
                                    let coord = computePoint(pt: priPt)
                                    let rHalo: CGFloat = 5.5
                                    let rCore: CGFloat = 3.2
                                    context.fill(Path(ellipseIn: CGRect(x: coord.x - rHalo, y: coord.y - rHalo, width: rHalo * 2, height: rHalo * 2)), with: .color(tintColor.opacity(0.25)))
                                    context.fill(Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)), with: .color(tintColor))
                                    context.stroke(Path(ellipseIn: CGRect(x: coord.x - rCore, y: coord.y - rCore, width: rCore * 2, height: rCore * 2)), with: .color(.white), style: StrokeStyle(lineWidth: 1.2))
                                }

                                // Floating HUD Tooltip
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
                                        parts.append(unit == "°C" ? String(format: "%.0f°C (%.0f~%.0f)", pri.value, minV, maxV) : String(format: "%.0f %@ (%.0f~%.0f)", pri.value, unit, minV, maxV))
                                    } else {
                                        parts.append(formatValue(pri.value))
                                    }
                                }
                                if let sec = closestSec, let secTitle = secondaryTitle {
                                    if selectedRange.isLongTerm, let minV = sec.minValue, let maxV = sec.maxValue {
                                        parts.append(unit == "°C" ? String(format: "%@: %.0f°C (%.0f~%.0f)", secTitle, sec.value, minV, maxV) : String(format: "%@: %.0f %@ (%.0f~%.0f)", secTitle, sec.value, unit, minV, maxV))
                                    } else {
                                        parts.append(String(format: "%@: %@", secTitle, formatValue(sec.value)))
                                    }
                                }
                                let tooltipString = parts.joined(separator: " · ")

                                let badgeWidth: CGFloat = CGFloat(Double(tooltipString.count) * 6.2 + 20.0)
                                let badgeHeight: CGFloat = 20
                                let badgeX = min(w - badgeWidth / 2 - 4, max(badgeWidth / 2 + 4, snapX))
                                let priY = closestPri.map { computePoint(pt: $0).y } ?? (h * 0.5)
                                let badgeY: CGFloat = priY < 32 ? min(h - 12, priY + 22) : 12

                                let badgeRect = CGRect(
                                    x: badgeX - badgeWidth / 2,
                                    y: badgeY - badgeHeight / 2,
                                    width: badgeWidth,
                                    height: badgeHeight
                                )
                                context.fill(
                                    Path(roundedRect: badgeRect, cornerRadius: 5),
                                    with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                                )
                                context.stroke(
                                    Path(roundedRect: badgeRect, cornerRadius: 5),
                                    with: .color(.primary.opacity(0.18)),
                                    style: StrokeStyle(lineWidth: 0.8)
                                )

                                let resolvedText = Text(tooltipString)
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                context.draw(resolvedText, at: CGPoint(x: badgeX, y: badgeY), anchor: .center)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tintColor.opacity(0.7))
                    Text(AppStrings.tr(en: "Collecting telemetry…", zh: "正在采集走势数据…"))
                        .font(.system(size: 11, weight: .medium))
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
        points: [ChartDataPoint],
        coords: [CGPoint],
        color: Color,
        in context: GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        bounds: (lower: Double, upper: Double),
        fillAlpha: Double
    ) {
        guard let first = coords.first else { return }

        // Render min-max range envelope band for long-term rollups
        if selectedRange.isLongTerm, points.count == coords.count {
            var topCoords: [CGPoint] = []
            var btmCoords: [CGPoint] = []

            for (idx, pt) in points.enumerated() {
                let x = coords[idx].x
                if let maxV = pt.maxValue, let minV = pt.minValue {
                    let normMax = (maxV - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                    let yTop = max(2.0, min(height - 2.0, height * (1.0 - CGFloat(normMax))))
                    let normMin = (minV - bounds.lower) / max(0.1, bounds.upper - bounds.lower)
                    let yBtm = max(2.0, min(height - 2.0, height * (1.0 - CGFloat(normMin))))
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
                context.fill(bandPath, with: .color(color.opacity(0.10)))
            }
        }

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
            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        )

        if let last = coords.last {
            let haloRect = CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: haloRect), with: .color(color.opacity(0.25)))

            let dotRect = CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))
            context.stroke(Path(ellipseIn: dotRect), with: .color(.white), style: StrokeStyle(lineWidth: 0.8))
        }
    }
}
