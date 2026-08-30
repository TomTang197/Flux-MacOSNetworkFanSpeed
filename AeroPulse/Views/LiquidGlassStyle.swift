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

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.72))

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            tint.opacity(0.08),
                            Color.clear,
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
                                Color.white.opacity(0.25),
                                tint.opacity(0.18),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(shadowOpacity * 0.4), radius: 3, x: 0, y: 1.5)
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
