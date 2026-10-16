//
//  LiquidGlassStyle.swift
//  AeroPulse
//
//  Created by Codex on 12/02/26.
//

import AppKit
import SwiftUI

/// Reusable macOS 26 glass surface used across dashboard cards and setting panels.
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
    var tint: Color
    var style: NSGlassEffectView.Style
    var shadowOpacity: Double
    @Environment(\.windowInteractionActive) private var windowInteractionActive
    @Environment(\.visualEffectsReduced) private var reduceVisualEffects

    private var shouldReduceEffects: Bool {
        windowInteractionActive || reduceVisualEffects
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if shouldReduceEffects {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.96))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.regularMaterial)

                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                tint.opacity(0.06),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        shouldReduceEffects
                            ? AnyShapeStyle(Color.primary.opacity(0.08))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        tint.opacity(0.16),
                                        Color.primary.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ),
                        lineWidth: 0.8
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: Color.black.opacity(shouldReduceEffects ? 0 : shadowOpacity * 0.35),
                radius: shouldReduceEffects ? 0 : 5,
                x: 0,
                y: shouldReduceEffects ? 0 : 2
            )
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 16,
        tint: Color = .blue,
        style: NSGlassEffectView.Style = .regular,
        shadowOpacity: Double = 0.14
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                style: style,
                shadowOpacity: shadowOpacity
            )
        )
    }
}
