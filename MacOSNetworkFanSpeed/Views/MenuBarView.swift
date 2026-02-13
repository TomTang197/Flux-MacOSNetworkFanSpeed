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
        let columns = groupedColumns()

        if columns.isEmpty {
            Image(systemName: AppImages.rocket)
        } else {
            let combinedImage = renderGroupedMetricsImage(columns)
            Image(nsImage: combinedImage)
        }
    }

    private struct MetricRow {
        let symbol: String
        let value: String
    }

    private struct MetricColumn {
        let top: MetricRow?
        let bottom: MetricRow?
        let isPaired: Bool
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

        // --- Single Metrics (Horizontal/Centered) ---
        let singles: [MetricType] = [.cpu, .memory, .temperature, .fan]
        for metric in singles {
            if enabled.contains(metric) {
                columns.append(MetricColumn(top: metricRow(for: metric), bottom: nil, isPaired: false))
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
            return MetricColumn(top: metricRow(for: top), bottom: metricRow(for: bottom), isPaired: true)
        }

        // If only one enabled, it defaults to a single centered layout
        let activeMetric = topEnabled ? top : bottom
        return MetricColumn(top: metricRow(for: activeMetric), bottom: nil, isPaired: false)
    }

    private func metricRow(for metric: MetricType) -> MetricRow {
        MetricRow(symbol: symbolForMetric(metric), value: valueForMetric(metric))
    }

    private func renderGroupedMetricsImage(_ columns: [MetricColumn]) -> NSImage {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .paragraphStyle: paragraphStyle,
        ]

        let rowHeight: CGFloat = 8
        let rowSpacing: CGFloat = 2
        let verticalPadding: CGFloat = 1
        let height = rowHeight * 2 + rowSpacing + verticalPadding * 2
        
        let columnWidthStacked: CGFloat = 66
        let columnWidthSingle: CGFloat = 58 // Slightly narrower for single items
        let dividerSpacing: CGFloat = 6
        let iconSlotWidth: CGFloat = 10
        let iconTextSpacing: CGFloat = 2
        
        // Calculate total width based on mix of column types
        var totalWidth: CGFloat = 0
        for (idx, col) in columns.enumerated() {
            totalWidth += col.isPaired ? columnWidthStacked : columnWidthSingle
            if idx < columns.count - 1 {
                totalWidth += dividerSpacing
            }
        }

        let finalImage = NSImage(size: NSSize(width: totalWidth, height: height))
        finalImage.lockFocus()

        var currentX: CGFloat = 0
        for (index, column) in columns.enumerated() {
            let colWidth = column.isPaired ? columnWidthStacked : columnWidthSingle
            let textWidth = colWidth - iconSlotWidth - iconTextSpacing

            if column.isPaired {
                // Draw Stacked
                let topY = verticalPadding + rowHeight + rowSpacing
                let bottomY = verticalPadding
                drawRow(column.top, xOrigin: currentX, yOrigin: topY, rowHeight: rowHeight, iconConfig: iconConfig, iconSlotWidth: iconSlotWidth, iconTextSpacing: iconTextSpacing, textWidth: textWidth, textAttributes: textAttributes)
                drawRow(column.bottom, xOrigin: currentX, yOrigin: bottomY, rowHeight: rowHeight, iconConfig: iconConfig, iconSlotWidth: iconSlotWidth, iconTextSpacing: iconTextSpacing, textWidth: textWidth, textAttributes: textAttributes)
            } else {
                // Draw Single Centered
                let centerY = (height - rowHeight) / 2
                drawRow(column.top, xOrigin: currentX, yOrigin: centerY, rowHeight: rowHeight, iconConfig: iconConfig, iconSlotWidth: iconSlotWidth, iconTextSpacing: iconTextSpacing, textWidth: textWidth, textAttributes: textAttributes)
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

    private func drawRow(
        _ row: MetricRow?,
        xOrigin: CGFloat,
        yOrigin: CGFloat,
        rowHeight: CGFloat,
        iconConfig: NSImage.SymbolConfiguration,
        iconSlotWidth: CGFloat,
        iconTextSpacing: CGFloat,
        textWidth: CGFloat,
        textAttributes: [NSAttributedString.Key: Any]
    ) {
        guard let row else { return }

        let icon = configuredSymbolImage(named: row.symbol, config: iconConfig)
        let iconY = yOrigin + max(0, (rowHeight - icon.size.height) / 2)
        icon.draw(
            at: NSPoint(x: xOrigin, y: iconY),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        let textRect = NSRect(
            x: xOrigin + iconSlotWidth + iconTextSpacing,
            y: yOrigin,
            width: textWidth,
            height: rowHeight
        )

        (row.value as NSString).draw(
            in: textRect,
            withAttributes: textAttributes
        )
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
        return NSImage(size: NSSize(width: 8, height: 8))
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
