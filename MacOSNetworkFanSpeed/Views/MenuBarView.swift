//
//  MenuBarView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//  Modified for Mixed Layout (Stacked/Single) on 14/02/26.
//

import SwiftUI

/// `MenuBarView` determines which speed values to display in the system menu bar.
struct MenuBarView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        let singleMetricRows = enabledMetricRows()

        if singleMetricRows.count == 1, let row = singleMetricRows.first {
            let image = renderSingleMetricImage(row)
            return Image(nsImage: image)
        }

        let columns = groupedColumns()

        if columns.isEmpty {
            return Image(systemName: AppImages.rocket)
        } else {
            let combinedImage = renderGroupedMetricsImage(columns)
            return Image(nsImage: combinedImage)
        }
    }

    private struct MetricRow {
        let metric: MetricType
        let symbol: String
        let value: String
    }

    private struct MetricColumn {
        let top: MetricRow?
        let bottom: MetricRow?
        let kind: ColumnKind
    }

    private enum ColumnKind {
        case stacked
        case singleRegular
        case singleCompact
    }

    private func enabledMetricRows() -> [MetricRow] {
        let enabled = networkViewModel.enabledMetrics
        let orderedMetrics: [MetricType] = [
            .download, .upload, .diskRead, .diskWrite, .cpu, .memory, .temperature, .fan,
        ]

        return orderedMetrics.compactMap { metric in
            guard enabled.contains(metric) else { return nil }
            return metricRow(for: metric)
        }
    }

    private func groupedColumns() -> [MetricColumn] {
        let enabled = networkViewModel.enabledMetrics
        var columns: [MetricColumn] = []

        // --- Paired Metrics (Stacked) ---
        if let networkColumn = makePairedColumn(top: .download, bottom: .upload, enabled: enabled) {
            columns.append(networkColumn)
        }
        if let diskColumn = makePairedColumn(top: .diskRead, bottom: .diskWrite, enabled: enabled) {
            columns.append(diskColumn)
        }

        // Temperature/Fan are grouped in one stacked slot.
        if let thermalColumn = makePairedColumn(top: .temperature, bottom: .fan, enabled: enabled) {
            columns.append(thermalColumn)
        }

        // CPU/Memory stay single but use compact width.
        let singles: [MetricType] = [.cpu, .memory]
        for metric in singles {
            if enabled.contains(metric) {
                columns.append(
                    MetricColumn(
                        top: metricRow(for: metric),
                        bottom: nil,
                        kind: .singleCompact
                    )
                )
            }
        }

        return columns
    }

    private func makePairedColumn(top: MetricType, bottom: MetricType, enabled: Set<MetricType>) -> MetricColumn? {
        let topEnabled = enabled.contains(top)
        let bottomEnabled = enabled.contains(bottom)
        guard topEnabled || bottomEnabled else { return nil }

        // If both enabled, they are paired (stacked)
        if topEnabled && bottomEnabled {
            return MetricColumn(
                top: metricRow(for: top),
                bottom: metricRow(for: bottom),
                kind: .stacked
            )
        }

        // If only one enabled, it defaults to a single centered layout
        let activeMetric = topEnabled ? top : bottom
        return MetricColumn(top: metricRow(for: activeMetric), bottom: nil, kind: .singleRegular)
    }

    private func metricRow(for metric: MetricType) -> MetricRow {
        MetricRow(metric: metric, symbol: symbolForMetric(metric), value: valueForMetric(metric))
    }

    private func renderGroupedMetricsImage(_ columns: [MetricColumn]) -> NSImage {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let emphasizedIconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)

        let rowHeight: CGFloat = 12
        let rowSpacing: CGFloat = 2
        let verticalPadding: CGFloat = 1
        let height = rowHeight * 2 + rowSpacing + verticalPadding * 2
        
        let columnWidthStacked: CGFloat = 78
        let columnWidthSingleRegular: CGFloat = 66
        let columnWidthSingleCompact: CGFloat = 50
        let dividerSpacing: CGFloat = 6
        
        // Calculate total width based on mix of column types
        var totalWidth: CGFloat = 0
        for (idx, col) in columns.enumerated() {
            totalWidth += width(
                for: col.kind,
                stacked: columnWidthStacked,
                regular: columnWidthSingleRegular,
                compact: columnWidthSingleCompact
            )
            if idx < columns.count - 1 {
                totalWidth += dividerSpacing
            }
        }

        let finalImage = NSImage(size: NSSize(width: totalWidth, height: height))
        finalImage.lockFocus()

        var currentX: CGFloat = 0
        for (index, column) in columns.enumerated() {
            let colWidth = width(
                for: column.kind,
                stacked: columnWidthStacked,
                regular: columnWidthSingleRegular,
                compact: columnWidthSingleCompact
            )

            if column.kind == .stacked {
                // Draw Stacked
                let topY = verticalPadding + rowHeight + rowSpacing
                let bottomY = verticalPadding
                drawRow(column.top, xOrigin: currentX, columnWidth: colWidth, yOrigin: topY, rowHeight: rowHeight, iconConfig: iconConfig, emphasizedIconConfig: emphasizedIconConfig, valueFont: valueFont)
                drawRow(column.bottom, xOrigin: currentX, columnWidth: colWidth, yOrigin: bottomY, rowHeight: rowHeight, iconConfig: iconConfig, emphasizedIconConfig: emphasizedIconConfig, valueFont: valueFont)
            } else {
                // Draw Single Centered
                let centerY = (height - rowHeight) / 2
                drawRow(column.top, xOrigin: currentX, columnWidth: colWidth, yOrigin: centerY, rowHeight: rowHeight, iconConfig: iconConfig, emphasizedIconConfig: emphasizedIconConfig, valueFont: valueFont)
            }

            if index < columns.count - 1 {
                let dividerX = currentX + colWidth + dividerSpacing / 2
                let path = NSBezierPath()
                path.move(to: NSPoint(x: dividerX, y: verticalPadding + 2))
                path.line(to: NSPoint(x: dividerX, y: height - verticalPadding - 2))
                NSColor.labelColor.withAlphaComponent(0.2).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
            
            currentX += colWidth + dividerSpacing
        }

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func renderSingleMetricImage(_ row: MetricRow) -> NSImage {
        let prefersExtraLarge = row.metric == .cpu || row.metric == .memory
        let iconPointSize: CGFloat = prefersExtraLarge ? 20 : 16
        let valuePointSize: CGFloat = prefersExtraLarge ? 17 : 16

        let iconConfig = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: valuePointSize, weight: .bold)
        let textAttributes = textAttributes(for: valueFont)

        let height: CGFloat = 24
        let leadingPadding: CGFloat = prefersExtraLarge ? 3 : 4
        let trailingPadding: CGFloat = 3
        let iconSlotWidth: CGFloat = prefersExtraLarge ? 18 : 15
        let iconTextSpacing: CGFloat = prefersExtraLarge ? 1 : 2
        let icon = configuredSymbolImage(named: row.symbol, config: iconConfig)
        let width = singleMetricWidth(for: row.metric)

        let finalImage = NSImage(size: NSSize(width: width, height: height))
        finalImage.lockFocus()

        let iconX = leadingPadding + floor((iconSlotWidth - icon.size.width) / 2)
        let iconY = max(0, (height - icon.size.height) / 2)
        let iconRect = NSRect(
            x: iconX,
            y: iconY,
            width: icon.size.width,
            height: icon.size.height
        )
        drawMetricIcon(icon, metric: row.metric, in: iconRect)

        let textX = leadingPadding + iconSlotWidth + iconTextSpacing
        let textWidth = max(0, width - textX - trailingPadding)
        let measuredTextSize = measuredTextSize(for: row.value, attributes: textAttributes)
        let textY = floor(yCenter(for: measuredTextSize.height, in: height))
        let textRect = NSRect(
            x: textX,
            y: textY,
            width: textWidth,
            height: measuredTextSize.height
        )
        (row.value as NSString).draw(
            in: textRect,
            withAttributes: textAttributes
        )

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func width(
        for kind: ColumnKind,
        stacked: CGFloat,
        regular: CGFloat,
        compact: CGFloat
    ) -> CGFloat {
        switch kind {
        case .stacked:
            return stacked
        case .singleRegular:
            return regular
        case .singleCompact:
            return compact
        }
    }

    private func drawRow(
        _ row: MetricRow?,
        xOrigin: CGFloat,
        columnWidth: CGFloat,
        yOrigin: CGFloat,
        rowHeight: CGFloat,
        iconConfig: NSImage.SymbolConfiguration,
        emphasizedIconConfig: NSImage.SymbolConfiguration,
        valueFont: NSFont
    ) {
        guard let row else { return }
        let textAttributes = textAttributes(for: valueFont)

        let emphasizesIcon = row.metric == .cpu || row.metric == .memory
        let config = emphasizesIcon ? emphasizedIconConfig : iconConfig
        let icon = configuredSymbolImage(named: row.symbol, config: config)
        let textSize = measuredTextSize(for: row.value, attributes: textAttributes)
        let leadingPadding: CGFloat = emphasizesIcon ? 2 : 3
        let trailingPadding: CGFloat = 2
        let iconSlotWidth: CGFloat = emphasizesIcon ? 15 : 12
        let iconTextSpacing: CGFloat = emphasizesIcon ? 1 : 2

        let iconX = xOrigin + leadingPadding + floor((iconSlotWidth - icon.size.width) / 2)
        let iconY = yOrigin + max(0, (rowHeight - icon.size.height) / 2)
        let iconRect = NSRect(
            x: iconX,
            y: iconY,
            width: icon.size.width,
            height: icon.size.height
        )
        drawMetricIcon(icon, metric: row.metric, in: iconRect)

        let textX = xOrigin + leadingPadding + iconSlotWidth + iconTextSpacing
        let textWidth = max(0, columnWidth - leadingPadding - iconSlotWidth - iconTextSpacing - trailingPadding)
        let textY = yOrigin + floor(yCenter(for: textSize.height, in: rowHeight))
        let textRect = NSRect(
            x: textX,
            y: textY,
            width: textWidth,
            height: textSize.height
        )
        (row.value as NSString).draw(
            in: textRect,
            withAttributes: textAttributes
        )
    }

    private func singleMetricWidth(for metric: MetricType) -> CGFloat {
        switch metric {
        case .cpu, .memory:
            return 84
        case .temperature, .fan:
            return 104
        case .download, .upload, .diskRead, .diskWrite:
            return 122
        }
    }

    private func textAttributes(for font: NSFont) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        return [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]
    }

    private func measuredTextSize(
        for value: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSSize {
        let size = (value as NSString).size(withAttributes: attributes)
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    private func yCenter(for contentHeight: CGFloat, in containerHeight: CGFloat) -> CGFloat {
        max(0, (containerHeight - contentHeight) / 2)
    }

    private func drawMetricIcon(_ icon: NSImage, metric: MetricType, in rect: NSRect) {
        if metric == .temperature {
            drawRotatedIcon(icon, in: rect, degrees: -90)
        } else {
            icon.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
        }
    }

    private func drawRotatedIcon(_ icon: NSImage, in rect: NSRect, degrees: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()
        icon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func symbolForMetric(_ metric: MetricType) -> String {
        switch metric {
        case .download: return AppImages.download
        case .upload: return AppImages.upload
        case .diskRead: return AppImages.diskRead
        case .diskWrite: return AppImages.diskWrite
        case .cpu: return AppImages.cpuUsage
        case .memory: return AppImages.memory
        case .fan: return AppImages.fan
        case .temperature: return AppImages.temperature
        }
    }

    private func configuredSymbolImage(named symbol: String, config: NSImage.SymbolConfiguration) -> NSImage {
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        {
            return image
        }
        return NSImage(size: NSSize(width: 10, height: 10))
    }

    private func valueForMetric(_ metric: MetricType) -> String {
        switch metric {
        case .download: return networkViewModel.downloadSpeed
        case .upload: return networkViewModel.uploadSpeed
        case .diskRead: return networkViewModel.diskReadSpeed
        case .diskWrite: return networkViewModel.diskWriteSpeed
        case .cpu: return networkViewModel.cpuUsage
        case .memory: return networkViewModel.memoryUsage
        case .fan: return fanViewModel.primaryFanRPM
        case .temperature: return fanViewModel.primaryTemp
        }
    }
}
