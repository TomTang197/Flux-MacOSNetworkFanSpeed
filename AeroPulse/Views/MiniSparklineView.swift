import SwiftUI

struct MiniSparklineView: View {
    let points: [MetricHistoryPoint]
    let tintColor: Color
    var width: CGFloat = 42
    var height: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Take the most recent 30 samples (~1 minute) for Menu Bar sparkline
            let recentPoints = points.suffix(30)
            guard recentPoints.count > 1 else { return }

            let values = recentPoints.map(\.value)
            guard let minVal = values.min(), let maxVal = values.max() else { return }
            let span = max(2.0, maxVal - minVal)
            let lower = minVal - span * 0.1
            let upper = maxVal + span * 0.1

            var linePath = Path()
            var lastPoint: CGPoint? = nil
            let count = recentPoints.count

            for (idx, pt) in recentPoints.enumerated() {
                let x = w * CGFloat(idx) / CGFloat(max(1, count - 1))
                let normY = (pt.value - lower) / (upper - lower)
                let y = max(1.0, min(h - 1.0, h * (1.0 - CGFloat(normY))))
                let cgPt = CGPoint(x: x, y: y)

                if idx == 0 {
                    linePath.move(to: cgPt)
                } else {
                    linePath.addLine(to: cgPt)
                }
                lastPoint = cgPt
            }

            context.stroke(
                linePath,
                with: .color(tintColor.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )

            if let last = lastPoint {
                let dotRect = CGRect(x: last.x - 1.5, y: last.y - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: dotRect), with: .color(tintColor))
            }
        }
        .frame(width: width, height: height)
        .transaction { $0.animation = nil }
    }
}
