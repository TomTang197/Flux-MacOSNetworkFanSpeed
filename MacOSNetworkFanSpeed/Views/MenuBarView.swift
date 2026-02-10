//
//  MenuBarView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
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
    }

    private func groupedColumns() -> [MetricColumn] {
        let enabled = networkViewModel.enabledMetrics
        var columns: [MetricColumn] = []

        if let networkColumn = makePairedColumn(top: .download, bottom: .upload, enabled: enabled) {
            columns.append(networkColumn)
        }
        if let diskColumn = makePairedColumn(top: .diskRead, bottom: .diskWrite, enabled: enabled) {
            columns.append(diskColumn)
        }
        if let thermalColumn = makePairedColumn(top: .temperature, bottom: .fan, enabled: enabled) {
            columns.append(thermalColumn)
        }

        return columns
    }

    private func makePairedColumn(top: MetricType, bottom: MetricType, enabled: Set<MetricType>) -> MetricColumn?
    {
        let topEnabled = enabled.contains(top)
        let bottomEnabled = enabled.contains(bottom)
        guard topEnabled || bottomEnabled else { return nil }

        if topEnabled && bottomEnabled {
            return MetricColumn(top: metricRow(for: top), bottom: metricRow(for: bottom))
        }

        if topEnabled {
            return MetricColumn(top: metricRow(for: top), bottom: nil)
        }

        return MetricColumn(top: metricRow(for: bottom), bottom: nil)
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
        let columnWidth: CGFloat = 66
        let dividerSpacing: CGFloat = 6
        let iconSlotWidth: CGFloat = 10
        let iconTextSpacing: CGFloat = 2
        let textWidth = columnWidth - iconSlotWidth - iconTextSpacing
        let height = rowHeight * 2 + rowSpacing + verticalPadding * 2
        let totalWidth = CGFloat(columns.count) * columnWidth + CGFloat(max(columns.count - 1, 0)) * dividerSpacing

        let finalImage = NSImage(size: NSSize(width: totalWidth, height: height))
        finalImage.lockFocus()

        for (index, column) in columns.enumerated() {
            let xOrigin = CGFloat(index) * (columnWidth + dividerSpacing)
            let topY = verticalPadding + rowHeight + rowSpacing
            let bottomY = verticalPadding

            drawRow(
                column.top,
                xOrigin: xOrigin,
                yOrigin: topY,
                rowHeight: rowHeight,
                iconConfig: iconConfig,
                iconSlotWidth: iconSlotWidth,
                iconTextSpacing: iconTextSpacing,
                textWidth: textWidth,
                textAttributes: textAttributes
            )
            drawRow(
                column.bottom,
                xOrigin: xOrigin,
                yOrigin: bottomY,
                rowHeight: rowHeight,
                iconConfig: iconConfig,
                iconSlotWidth: iconSlotWidth,
                iconTextSpacing: iconTextSpacing,
                textWidth: textWidth,
                textAttributes: textAttributes
            )

            if index < columns.count - 1 {
                let dividerX = xOrigin + columnWidth + dividerSpacing / 2
                let path = NSBezierPath()
                path.move(to: NSPoint(x: dividerX, y: verticalPadding))
                path.line(to: NSPoint(x: dividerX, y: height - verticalPadding))
                NSColor.labelColor.withAlphaComponent(0.25).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
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

        if let fallback = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        {
            return fallback
        }

        return NSImage(size: NSSize(width: 8, height: 8))
    }

    private func valueForMetric(_ metric: MetricType) -> String {
        switch metric {
        case .download: return networkViewModel.downloadSpeed
        case .upload: return networkViewModel.uploadSpeed
        case .diskRead: return networkViewModel.diskReadSpeed
        case .diskWrite: return networkViewModel.diskWriteSpeed
        case .fan: return fanViewModel.primaryFanRPM
        case .temperature: return fanViewModel.primaryTemp
        }
    }
}
