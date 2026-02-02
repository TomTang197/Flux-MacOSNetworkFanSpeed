//
//  MenuBarView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

/// `MenuBarView` determines which speed values to display in the system menu bar.
struct MenuBarView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        let metrics = MetricType.allCases.filter { networkViewModel.enabledMetrics.contains($0) }

        if metrics.isEmpty {
            Image(systemName: "rocket.fill")
        } else {
            let combinedImage = renderCombinedMetricsImage(metrics)
            Image(nsImage: combinedImage)
        }
    }

    private func renderCombinedMetricsImage(_ metrics: [MetricType]) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let spacing: CGFloat = 4
        let dividerSpacing: CGFloat = 8

        var totalWidth: CGFloat = 0
        var items: [(image: NSImage, text: String, textSize: NSSize)] = []

        for metric in metrics {
            let symbol = symbolForMetric(metric)
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
                .withSymbolConfiguration(config)!
            let text = valueForMetric(metric)
            let textSize = text.size(withAttributes: attributes)

            items.append((image, text, textSize))
            totalWidth += image.size.width + spacing + textSize.width
        }

        if items.count > 1 {
            totalWidth += CGFloat(items.count - 1) * dividerSpacing
        }

        let height: CGFloat = 18
        let finalImage = NSImage(size: NSSize(width: totalWidth, height: height))
        finalImage.lockFocus()

        var currentX: CGFloat = 0
        for (index, item) in items.enumerated() {
            let yOffset = (height - item.image.size.height) / 2
            item.image.draw(
                at: NSPoint(x: currentX, y: yOffset),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )

            let textY = (height - item.textSize.height) / 2
            item.text.draw(
                at: NSPoint(x: currentX + item.image.size.width + spacing, y: textY),
                withAttributes: attributes
            )

            currentX += item.image.size.width + spacing + item.textSize.width

            if index < items.count - 1 {
                currentX += dividerSpacing / 2
                let dividerText = "|"
                let divSize = dividerText.size(withAttributes: attributes)
                dividerText.draw(
                    at: NSPoint(x: currentX - divSize.width / 2, y: (height - divSize.height) / 2),
                    withAttributes: attributes
                )
                currentX += dividerSpacing / 2
            }
        }

        finalImage.unlockFocus()
        finalImage.isTemplate = true
        return finalImage
    }

    private func symbolForMetric(_ metric: MetricType) -> String {
        switch metric {
        case .download: return "arrow.down.circle.fill"
        case .upload: return "arrow.up.circle.fill"
        case .fan: return "fanblades.fill"
        case .temperature: return "thermometer.medium"
        }
    }

    private func valueForMetric(_ metric: MetricType) -> String {
        switch metric {
        case .download: return networkViewModel.downloadSpeed
        case .upload: return networkViewModel.uploadSpeed
        case .fan: return fanViewModel.primaryFanRPM
        case .temperature: return fanViewModel.primaryTemp
        }
    }
}
