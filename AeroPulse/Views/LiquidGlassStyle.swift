//
//  LiquidGlassStyle.swift
//  AeroPulse
//
//  Created by Codex on 12/02/26.
//

import AppKit
import SwiftUI

/// Design tokens derived from the AeroPulse instrument direction:
/// Graphite neutral ramp, three text roles, one Cobalt accent, toned semantics,
/// 4px spacing rhythm, nested radii, and a single ease-out curve.
enum AeroPulseTheme {
    private static func dynamicColor(darkHex: UInt32, darkAlpha: CGFloat = 1, lightHex: UInt32, lightAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? darkHex : lightHex
            let alpha = isDark ? darkAlpha : lightAlpha
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
        })
    }

    // MARK: - Graphite Neutral Ramp
    static let deepestSurface = dynamicColor(darkHex: 0x0F0F10, lightHex: 0xF4F4F5)
    static let pageBackground = dynamicColor(darkHex: 0x141415, lightHex: 0xFAFAFA)
    static let cardSurface = dynamicColor(darkHex: 0x19191B, lightHex: 0xFFFFFF)
    static let raisedSurface = dynamicColor(darkHex: 0x232325, lightHex: 0xF4F4F5)
    static let hairline = dynamicColor(darkHex: 0xEDEDED, darkAlpha: 0.08, lightHex: 0x171717, lightAlpha: 0.08)
    static let activeTopHighlight = dynamicColor(darkHex: 0xFFFFFF, darkAlpha: 0.08, lightHex: 0x171717, lightAlpha: 0.04)

    // MARK: - Three Text Roles
    static let textPrimary = dynamicColor(darkHex: 0xEDEDED, lightHex: 0x171717)
    static let textSecondary = dynamicColor(darkHex: 0xA1A1A6, lightHex: 0x525252)
    static let textMuted = dynamicColor(darkHex: 0x85858B, lightHex: 0x737373)

    // MARK: - Cobalt Accent & Toned Semantics
    /// Solid Cobalt fill (>= 5.1:1 contrast with white text).
    static let accentFill = Color(nsColor: NSColor(srgbRed: 0x25 / 255.0, green: 0x63 / 255.0, blue: 0xEB / 255.0, alpha: 1))
    /// Cobalt ink (>= 5.1:1 contrast on both dark and light card surfaces).
    static let accentInk = dynamicColor(darkHex: 0x60A5FA, lightHex: 0x2563EB)

    static let positive = dynamicColor(darkHex: 0x4CC38A, lightHex: 0x16A34A)
    static let warning = dynamicColor(darkHex: 0xF59E0B, lightHex: 0xB45309)
    static let negative = dynamicColor(darkHex: 0xE5484D, lightHex: 0xDC2626)

    // MARK: - Radii (Nested math: 12 card -> 8 row/control -> 6 inner tag/segment)
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let innerRadius: CGFloat = 6

    // MARK: - Motion (Single cubic-bezier(0.22, 1, 0.36, 1) curve)
    static let motionFast = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.16)
    static let motionPanel = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.20)
}

/// Reusable macOS 26 glass surface retained for API compatibility.
struct LiquidGlassEffectView: NSViewRepresentable {
    var cornerRadius: CGFloat
    var style: NSGlassEffectView.Style = .regular

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = style
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        if nsView.style != style {
            nsView.style = style
        }
        if abs(nsView.cornerRadius - cornerRadius) > 0.5 {
            nsView.cornerRadius = cornerRadius
        }
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.windowInteractionActive) private var windowInteractionActive
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects

    private var shouldReduceEffects: Bool {
        windowInteractionActive || reduceVisualEffects
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AeroPulseTheme.cardSurface)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AeroPulseTheme.hairline, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: (colorScheme == .dark || shouldReduceEffects)
                    ? Color.clear
                    : Color.black.opacity(0.05),
                radius: (colorScheme == .dark || shouldReduceEffects) ? 0 : 2,
                x: 0,
                y: (colorScheme == .dark || shouldReduceEffects) ? 0 : 1
            )
    }
}

private struct AeroPulseRaisedModifier: ViewModifier {
    var cornerRadius: CGFloat
    var highlighted: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AeroPulseTheme.raisedSurface)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        highlighted ? AeroPulseTheme.accentInk.opacity(0.45) : AeroPulseTheme.hairline,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = AeroPulseTheme.cardRadius,
        tint: Color = AeroPulseTheme.accentInk,
        style: NSGlassEffectView.Style = .regular,
        shadowOpacity: Double = 0.05
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    func aeroPulseCard(cornerRadius: CGFloat = AeroPulseTheme.cardRadius) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    func aeroPulseRaised(
        cornerRadius: CGFloat = AeroPulseTheme.controlRadius,
        highlighted: Bool = false
    ) -> some View {
        modifier(AeroPulseRaisedModifier(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}
