//
//  WaterfallColumnsLayout.swift
//  MacOSNetworkFanSpeed
//

import SwiftUI

struct WaterfallColumnsLayout: Layout {
    var columns: Int
    var spacing: CGFloat

    init(columns: Int = 2, spacing: CGFloat = 10) {
        self.columns = max(1, columns)
        self.spacing = max(0, spacing)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let measuredWidth = max(proposal.width ?? defaultWidth, 0)
        let result = computeLayout(width: measuredWidth, subviews: subviews)
        return CGSize(width: measuredWidth, height: result.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = computeLayout(width: bounds.width, subviews: subviews)

        for item in result.items {
            let frame = item.frame.offsetBy(dx: bounds.minX, dy: bounds.minY)
            subviews[item.index].place(
                at: frame.origin,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private var defaultWidth: CGFloat {
        columns == 1 ? 320 : 520
    }

    private func computeLayout(width: CGFloat, subviews: Subviews) -> (items: [LayoutItem], height: CGFloat) {
        guard !subviews.isEmpty else { return ([], 0) }

        let columnCount = max(1, columns)
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        let columnWidth = max(0, (width - totalSpacing) / CGFloat(columnCount))

        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)
        var items: [LayoutItem] = []

        for index in subviews.indices {
            let subview = subviews[index]
            let targetColumn = shortestColumn(in: columnHeights)
            let x = CGFloat(targetColumn) * (columnWidth + spacing)
            let y = columnHeights[targetColumn]
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let frame = CGRect(x: x, y: y, width: columnWidth, height: size.height)

            items.append(LayoutItem(index: index, frame: frame))
            columnHeights[targetColumn] = y + size.height + spacing
        }

        let rawHeight = columnHeights.max() ?? 0
        let finalHeight = max(rawHeight - spacing, 0)
        return (items, finalHeight)
    }

    private func shortestColumn(in heights: [CGFloat]) -> Int {
        var result = 0
        var minimum = CGFloat.greatestFiniteMagnitude

        for (index, value) in heights.enumerated() {
            if value < minimum {
                minimum = value
                result = index
            }
        }

        return result
    }

    private struct LayoutItem {
        let index: Int
        let frame: CGRect
    }
}
