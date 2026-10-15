import SwiftUI

struct MiniSparklineView: View {
    let points: [MetricHistoryPoint]
    let tintColor: Color
    var width: CGFloat = 42
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = points.map(\.value)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let span = max(2.0, maxVal - minVal)
            let lower = minVal - span * 0.1
            let upper = maxVal + span * 0.1

            if points.count > 1 {
                ZStack {
                    Path { p in
                        for (idx, pt) in points.enumerated() {
                            let x = w * CGFloat(idx) / CGFloat(points.count - 1)
                            let normY = (pt.value - lower) / (upper - lower)
                            let y = h * (1.0 - CGFloat(normY))
                            let clampedY = max(1, min(h - 1, y))
                            if idx == 0 {
                                p.move(to: CGPoint(x: x, y: clampedY))
                            } else {
                                p.addLine(to: CGPoint(x: x, y: clampedY))
                            }
                        }
                    }
                    .stroke(tintColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        let normY = (last.value - lower) / (upper - lower)
                        let y = max(1, min(h - 1, h * (1.0 - CGFloat(normY))))
                        Circle()
                            .fill(tintColor)
                            .frame(width: 3, height: 3)
                            .position(x: w, y: y)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: width, height: height)
    }
}
