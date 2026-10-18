//
//  MenuBarView.swift
//  AeroPulse
//
//  Created by Bandan.K on 29/01/26.
//  Modified for Mixed Layout (Stacked/Single) on 14/02/26.
//

import SwiftUI

/// `MenuBarView` determines which speed values to display in the system menu bar.
struct MenuBarView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var updaterViewModel = SparkleUpdaterViewModel.shared

    private var hasUpdateIcon: Bool {
        updaterViewModel.isUpdateAvailable && updaterViewModel.showUpdateInMenuBar
    }

    var body: some View {
        let _ = DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
        Group {
            let singleMetricRows = enabledMetricRows()

            if singleMetricRows.count == 1, let row = singleMetricRows.first {
                let cacheKey = "single:\(row.metric.rawValue):\(row.symbol):\(row.value):upd:\(hasUpdateIcon)"
                let image = MenuBarImageCache.shared.image(for: cacheKey) {
                    renderSingleMetricImage(row, showUpdateIcon: hasUpdateIcon)
                }
                Image(nsImage: image)
            } else {
                let columns = groupedColumns()

                if columns.isEmpty {
                    if hasUpdateIcon {
                        let cacheKey = "empty:rocket:upd:true"
                        let image = MenuBarImageCache.shared.image(for: cacheKey) {
                            renderEmptyMetricsImage(showUpdateIcon: true)
                        }
                        Image(nsImage: image)
                    } else {
                        Image(systemName: AppImages.rocket)
                    }
                } else {
                    let cacheKey = columns.map {
                        "\($0.kind)-\($0.top?.metric.rawValue ?? ""):\($0.top?.value ?? "")|\($0.bottom?.metric.rawValue ?? ""):\($0.bottom?.value ?? "")"
                    }.joined(separator: ";") + ":upd:\(hasUpdateIcon)"
                    let combinedImage = MenuBarImageCache.shared.image(for: cacheKey) {
                        renderGroupedMetricsImage(columns, showUpdateIcon: hasUpdateIcon)
                    }
                    Image(nsImage: combinedImage)
                }
            }
        }
        .onAppear {
            DashboardWindowManager.shared.registerOpenWindowAction(openWindow)
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
        case stackedWide
        case stackedCompact
        case singleRegular
        case singleCompact
    }

    private func enabledMetricRows() -> [MetricRow] {
        let enabled = networkViewModel.enabledMetrics
        let orderedMetrics: [MetricType] = [
            .download, .upload, .diskRead, .diskWrite, .power, .gpu, .memory, .cpu, .chargingPower, .temperature, .fan,
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
        if
            let diskColumn = makePairedColumn(
                top: .diskRead,
                bottom: .diskWrite,
                enabled: enabled,
                stackedKind: .stackedWide
            )
        {
            columns.append(diskColumn)
        }

        // Total power/GPU are grouped in one stacked slot.
        if
            let computeColumn = makePairedColumn(
                top: .power,
                bottom: .gpu,
                enabled: enabled,
                stackedKind: .stackedCompact,
                singleKind: .singleCompact
            )
        {
            columns.append(computeColumn)
        }

        // Memory/CPU are grouped in one stacked slot.
        if
            let memoryCPUColumn = makePairedColumn(
                top: .memory,
                bottom: .cpu,
                enabled: enabled,
                stackedKind: .stackedCompact,
                singleKind: .singleCompact
            )
        {
            columns.append(memoryCPUColumn)
        }

        // Temperature/Fan are grouped in one stacked slot.
        if let thermalColumn = makePairedColumn(top: .temperature, bottom: .fan, enabled: enabled) {
            columns.append(thermalColumn)
        }

        // Charging power stays single.
        if enabled.contains(.chargingPower) {
            columns.append(
                MetricColumn(
                    top: metricRow(for: .chargingPower),
                    bottom: nil,
                    kind: .singleCompact
                )
            )
        }

        return columns
    }

    private func makePairedColumn(
        top: MetricType,
        bottom: MetricType,
        enabled: Set<MetricType>,
        stackedKind: ColumnKind = .stacked,
        singleKind: ColumnKind = .singleRegular
    ) -> MetricColumn? {
        let topEnabled = enabled.contains(top)
        let bottomEnabled = enabled.contains(bottom)
        guard topEnabled || bottomEnabled else { return nil }

        // If both enabled, they are paired (stacked)
        if topEnabled && bottomEnabled {
            return MetricColumn(
                top: metricRow(for: top),
                bottom: metricRow(for: bottom),
                kind: stackedKind
            )
        }

        // If only one enabled, it defaults to a single centered layout
        let activeMetric = topEnabled ? top : bottom
        return MetricColumn(top: metricRow(for: activeMetric), bottom: nil, kind: singleKind)
    }

    private func metricRow(for metric: MetricType) -> MetricRow {
        MetricRow(metric: metric, symbol: symbolForMetric(metric), value: valueForMetric(metric))
    }

    private static let iconConfigGrouped = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
    private static let valueFontGrouped = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
    private static let textAttributesGrouped: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        return [
            .font: valueFontGrouped,
            .paragraphStyle: paragraphStyle,
        ]
    }()

    private static let iconConfigSingle = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
    private static let valueFontSingle = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
    private static let textAttributesSingle: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        return [
            .font: valueFontSingle,
            .paragraphStyle: paragraphStyle,
        ]
    }()

    private func renderGroupedMetricsImage(_ columns: [MetricColumn], showUpdateIcon: Bool = false) -> NSImage {
        let iconConfig = Self.iconConfigGrouped
        let valueFont = Self.valueFontGrouped

        let rowHeight: CGFloat = 12
        let rowSpacing: CGFloat = 2
        let verticalPadding: CGFloat = 1
        let height = rowHeight * 2 + rowSpacing + verticalPadding * 2
        
        let columnWidthStacked: CGFloat = 78
        let columnWidthStackedWide: CGFloat = 84
        let columnWidthStackedCompact: CGFloat = 62
        let columnWidthSingleRegular: CGFloat = 66
        let columnWidthSingleCompact: CGFloat = 56
        let dividerSpacing: CGFloat = 6
        let updateIconWidth: CGFloat = 16
        
        // Calculate total width based on mix of column types
        var totalWidth: CGFloat = 0
        for (idx, col) in columns.enumerated() {
            totalWidth += width(
                for: col.kind,
                stacked: columnWidthStacked,
                stackedWide: columnWidthStackedWide,
                stackedCompact: columnWidthStackedCompact,
                regular: columnWidthSingleRegular,
                compact: columnWidthSingleCompact
            )
            if idx < columns.count - 1 {
                totalWidth += dividerSpacing
            }
        }
        if showUpdateIcon {
            if !columns.isEmpty {
                totalWidth += dividerSpacing
            }
            totalWidth += updateIconWidth
        }

        let finalImage = NSImage(size: NSSize(width: totalWidth, height: height))
        finalImage.lockFocus()

        var currentX: CGFloat = 0
        for (index, column) in columns.enumerated() {
            let colWidth = width(
                for: column.kind,
                stacked: columnWidthStacked,
                stackedWide: columnWidthStackedWide,
                stackedCompact: columnWidthStackedCompact,
                regular: columnWidthSingleRegular,
                compact: columnWidthSingleCompact
            )

            if column.kind == .stacked || column.kind == .stackedWide || column.kind == .stackedCompact {
                // Draw Stacked
                let topY = verticalPadding + rowHeight + rowSpacing
                let bottomY = verticalPadding
                drawRow(column.top, xOrigin: currentX, columnWidth: colWidth, yOrigin: topY, rowHeight: rowHeight, iconConfig: iconConfig, valueFont: valueFont)
                drawRow(column.bottom, xOrigin: currentX, columnWidth: colWidth, yOrigin: bottomY, rowHeight: rowHeight, iconConfig: iconConfig, valueFont: valueFont)
            } else {
                // Draw Single Centered
                let centerY = (height - rowHeight) / 2
                drawRow(column.top, xOrigin: currentX, columnWidth: colWidth, yOrigin: centerY, rowHeight: rowHeight, iconConfig: iconConfig, valueFont: valueFont)
            }

            if index < columns.count - 1 || showUpdateIcon {
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

        if showUpdateIcon {
            let updateIcon = configuredSymbolImage(named: "arrow.triangle.2.circlepath", config: iconConfig)
            let iconX = currentX + floor((updateIconWidth - updateIcon.size.width) / 2)
            let iconY = floor((height - updateIcon.size.height) / 2)
            let iconRect = NSRect(
                x: iconX,
                y: iconY,
                width: updateIcon.size.width,
                height: updateIcon.size.height
            )
            updateIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func renderSingleMetricImage(_ row: MetricRow, showUpdateIcon: Bool = false) -> NSImage {
        let iconConfig = Self.iconConfigSingle
        let textAttributes = Self.textAttributesSingle

        let height: CGFloat = 24
        let leadingPadding: CGFloat = 4
        let trailingPadding: CGFloat = 3
        let iconSlotWidth: CGFloat = 15
        let iconTextSpacing: CGFloat = 2
        let icon = configuredSymbolImage(named: row.symbol, config: iconConfig)
        let metricWidth = singleMetricWidth(for: row.metric)
        let updateIconWidth: CGFloat = 16
        let dividerSpacing: CGFloat = 6
        let width = showUpdateIcon ? (metricWidth + dividerSpacing + updateIconWidth) : metricWidth

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
        let textWidth = max(0, metricWidth - textX - trailingPadding)
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

        if showUpdateIcon {
            let dividerX = metricWidth + dividerSpacing / 2
            let path = NSBezierPath()
            path.move(to: NSPoint(x: dividerX, y: 3))
            path.line(to: NSPoint(x: dividerX, y: height - 3))
            NSColor.labelColor.withAlphaComponent(0.2).setStroke()
            path.lineWidth = 1
            path.stroke()

            let updateIcon = configuredSymbolImage(named: "arrow.triangle.2.circlepath", config: Self.iconConfigGrouped)
            let iconX = metricWidth + dividerSpacing + floor((updateIconWidth - updateIcon.size.width) / 2)
            let iconY = floor((height - updateIcon.size.height) / 2)
            let iconRect = NSRect(
                x: iconX,
                y: iconY,
                width: updateIcon.size.width,
                height: updateIcon.size.height
            )
            updateIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func renderEmptyMetricsImage(showUpdateIcon: Bool = false) -> NSImage {
        guard showUpdateIcon else {
            return configuredSymbolImage(named: AppImages.rocket, config: Self.iconConfigSingle)
        }
        let height: CGFloat = 24
        let rocketWidth: CGFloat = 20
        let updateIconWidth: CGFloat = 16
        let dividerSpacing: CGFloat = 6
        let width = rocketWidth + dividerSpacing + updateIconWidth

        let finalImage = NSImage(size: NSSize(width: width, height: height))
        finalImage.lockFocus()

        let rocketIcon = configuredSymbolImage(named: AppImages.rocket, config: Self.iconConfigSingle)
        let rocketRect = NSRect(
            x: floor((rocketWidth - rocketIcon.size.width) / 2),
            y: floor((height - rocketIcon.size.height) / 2),
            width: rocketIcon.size.width,
            height: rocketIcon.size.height
        )
        rocketIcon.draw(in: rocketRect, from: .zero, operation: .sourceOver, fraction: 1)

        let dividerX = rocketWidth + dividerSpacing / 2
        let path = NSBezierPath()
        path.move(to: NSPoint(x: dividerX, y: 3))
        path.line(to: NSPoint(x: dividerX, y: height - 3))
        NSColor.labelColor.withAlphaComponent(0.2).setStroke()
        path.lineWidth = 1
        path.stroke()

        let updateIcon = configuredSymbolImage(named: "arrow.triangle.2.circlepath", config: Self.iconConfigGrouped)
        let iconX = rocketWidth + dividerSpacing + floor((updateIconWidth - updateIcon.size.width) / 2)
        let iconY = floor((height - updateIcon.size.height) / 2)
        let iconRect = NSRect(
            x: iconX,
            y: iconY,
            width: updateIcon.size.width,
            height: updateIcon.size.height
        )
        updateIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func width(
        for kind: ColumnKind,
        stacked: CGFloat,
        stackedWide: CGFloat,
        stackedCompact: CGFloat,
        regular: CGFloat,
        compact: CGFloat
    ) -> CGFloat {
        switch kind {
        case .stacked:
            return stacked
        case .stackedWide:
            return stackedWide
        case .stackedCompact:
            return stackedCompact
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
        valueFont: NSFont
    ) {
        guard let row else { return }
        let textAttributes = Self.textAttributesGrouped

        let icon = configuredSymbolImage(named: row.symbol, config: iconConfig)
        let textSize = measuredTextSize(for: row.value, attributes: textAttributes)
        let leadingPadding: CGFloat = 3
        let trailingPadding: CGFloat = 2
        let iconSlotWidth: CGFloat = 12
        let iconTextSpacing: CGFloat = 2

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
        case .power, .chargingPower, .cpu:
            return 76
        case .gpu, .memory:
            return 66
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
        case .power: return AppImages.powerUsage
        case .chargingPower: return AppImages.chargingPower
        case .gpu: return AppImages.gpuUsage
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
        case .power: return networkViewModel.powerUsage
        case .chargingPower: return networkViewModel.chargingPowerUsage
        case .gpu: return networkViewModel.gpuUsage
        case .memory: return networkViewModel.memoryUsage
        case .fan: return fanViewModel.primaryFanRPM
        case .temperature: return fanViewModel.compactAverageTemperatureSummary
        }
    }
}

private final class MenuBarImageCache {
    static let shared = MenuBarImageCache()
    private var lastKey: String = ""
    private var lastImage: NSImage?
    private var renderPolicy = MenuBarRenderPolicy(minimumInterval: 2.0)
    private let lock = NSLock()

    func image(for key: String, generator: () -> NSImage) -> NSImage {
        lock.lock()
        defer { lock.unlock() }
        if key == lastKey, let lastImage {
            return lastImage
        }
        let shouldRender = renderPolicy.shouldRender(key: key)
        if let previousImage = lastImage, !shouldRender {
            return previousImage
        }
        let image = generator()
        lastKey = key
        lastImage = image
        return image
    }
}
