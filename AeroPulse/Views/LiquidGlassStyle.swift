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
        nsView.style = style
        nsView.cornerRadius = cornerRadius
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var style: NSGlassEffectView.Style
    var shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    LiquidGlassEffectView(cornerRadius: cornerRadius, style: style)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            tint.opacity(0.12),
                            Color.black.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                tint.opacity(0.22),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 16, x: 0, y: 8)
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
