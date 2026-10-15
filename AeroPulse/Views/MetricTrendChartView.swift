import SwiftUI

struct MetricTrendChartView: View {
    let title: String
    let points: [MetricHistoryPoint]
    let unit: String
    let tintColor: Color
    var secondaryPoints: [MetricHistoryPoint]? = nil
    var secondaryColor: Color = .purple
    var secondaryTitle: String? = nil

    private var primaryRange: ClosedRange<Double> {
        let values = points.map(\.value) + (secondaryPoints?.map(\.value) ?? [])
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }
        let padding = max(4.0, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            chartArea
                .frame(height: 65)
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let latest = points.last?.value {
                Text(String(format: "%.0f %@", latest, unit))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(tintColor)
            }

            if let secPoints = secondaryPoints, let secLatest = secPoints.last?.value, let secTitle = secondaryTitle {
                Text("· \(secTitle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f %@", secLatest, unit))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(secondaryColor)
            }

            Spacer()

            if let minVal = points.map(\.value).min(), let maxVal = points.map(\.value).max() {
                Text("\(AppStrings.trendMin): \(Int(minVal))\(unit) · \(AppStrings.trendMax): \(Int(maxVal))\(unit)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartArea: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let range = primaryRange

            ZStack {
                // Background gridlines
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w, y: h * 0.5))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                .foregroundStyle(Color.secondary.opacity(0.2))

                if let secondary = secondaryPoints, secondary.count > 1 {
                    curvePath(points: secondary, width: w, height: h, range: range, closed: true)
                        .fill(LinearGradient(colors: [secondaryColor.opacity(0.12), secondaryColor.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    curvePath(points: secondary, width: w, height: h, range: range, closed: false)
                        .stroke(secondaryColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                if points.count > 1 {
                    curvePath(points: points, width: w, height: h, range: range, closed: true)
                        .fill(LinearGradient(colors: [tintColor.opacity(0.20), tintColor.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    curvePath(points: points, width: w, height: h, range: range, closed: false)
                        .stroke(tintColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                    if let lastPt = normalizedPoint(index: points.count - 1, total: points.count, value: points.last!.value, width: w, height: h, range: range) {
                        Circle()
                            .fill(tintColor)
                            .frame(width: 4, height: 4)
                            .position(lastPt)
                    }
                } else {
                    Text(AppStrings.noData)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func normalizedPoint(index: Int, total: Int, value: Double, width: CGFloat, height: CGFloat, range: ClosedRange<Double>) -> CGPoint? {
        guard total > 1, range.upperBound > range.lowerBound else { return nil }
        let x = width * CGFloat(index) / CGFloat(total - 1)
        let normalizedY = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let y = height * (1.0 - CGFloat(normalizedY))
        return CGPoint(x: x, y: max(0, min(height, y)))
    }

    private func curvePath(points: [MetricHistoryPoint], width: CGFloat, height: CGFloat, range: ClosedRange<Double>, closed: Bool) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let coords: [CGPoint] = points.enumerated().compactMap { idx, pt in
            normalizedPoint(index: idx, total: points.count, value: pt.value, width: width, height: height, range: range)
        }
        guard let first = coords.first else { return path }

        path.move(to: first)
        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let curr = coords[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            path.addLine(to: curr)
        }

        if closed, let last = coords.last {
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.addLine(to: CGPoint(x: first.x, y: height))
            path.closeSubpath()
        }

        return path
    }
}
