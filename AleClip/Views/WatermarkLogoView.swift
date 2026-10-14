//
//  WatermarkLogoView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

public struct SpectrumColors {
    // Vibrant spectrum palette: Zero Pink!
    public static let cyan = Color(red: 0.00, green: 0.88, blue: 1.00)       // Electric Cyan
    public static let azure = Color(red: 0.05, green: 0.52, blue: 1.00)      // Cobalt Azure
    public static let mint = Color(red: 0.00, green: 0.90, blue: 0.65)       // Neon Mint
    public static let emerald = Color(red: 0.12, green: 0.82, blue: 0.38)    // Emerald Green
    public static let lime = Color(red: 0.64, green: 0.90, blue: 0.10)       // Electric Lime
    public static let gold = Color(red: 1.00, green: 0.78, blue: 0.00)       // Sunburst Gold
    public static let tangerine = Color(red: 1.00, green: 0.44, blue: 0.00)  // Sunset Tangerine

    public static var gradient: LinearGradient {
        LinearGradient(
            colors: [cyan, azure, mint, emerald, lime, gold, tangerine],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    public static var verticalGradient: LinearGradient {
        LinearGradient(
            colors: [cyan, azure, mint, emerald, lime, gold, tangerine],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct SpectrumLogoBadge: View {
    var size: CGFloat = 54
    @Environment(\.colorScheme) private var colorScheme

    public init(size: CGFloat = 54) {
        self.size = size
    }

    public var body: some View {
        let isDark = colorScheme == .dark
        let glowRadius = size * 0.28
        let iconSize = size * 0.48

        ZStack {
            // Ambient chromatic glow
            Circle()
                .fill(SpectrumColors.gradient)
                .frame(width: size * 1.05, height: size * 1.05)
                .blur(radius: glowRadius)
                .opacity(isDark ? 0.35 : 0.20)

            // Glassmorphic squircle
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SpectrumColors.cyan.opacity(isDark ? 0.22 : 0.14),
                            SpectrumColors.tangerine.opacity(isDark ? 0.22 : 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(SpectrumColors.gradient, lineWidth: max(1.5, size * 0.035))
                        .opacity(0.85)
                )

            // Radiant paperclip icon
            Image(systemName: "paperclip")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(SpectrumColors.gradient)
                .rotationEffect(.degrees(-45))
        }
    }
}

public struct WatermarkLogoView: View {
    var compact: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        let isDark = colorScheme == .dark
        let textOpacity = isDark ? 0.85 : 0.70
        let glowOpacity = isDark ? 0.35 : 0.20

        HStack(spacing: compact ? 10 : 16) {
            SpectrumLogoBadge(size: compact ? 40 : 54)

            VStack(alignment: .leading, spacing: -2) {
                ZStack(alignment: .leading) {
                    Text("ALE")
                        .font(.system(size: compact ? 34 : 48, weight: .black, design: .rounded))
                        .foregroundStyle(SpectrumColors.gradient)
                        .blur(radius: 12)
                        .opacity(glowOpacity)

                    Text("ALE")
                        .font(.system(size: compact ? 34 : 48, weight: .black, design: .rounded))
                        .foregroundStyle(SpectrumColors.gradient)
                        .opacity(textOpacity)
                }

                HStack(spacing: 5) {
                    Text("CLIP")
                        .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(SpectrumColors.gradient)
                        .opacity(textOpacity)

                    Capsule()
                        .fill(SpectrumColors.gradient)
                        .frame(width: compact ? 20 : 26, height: 2)
                        .opacity(textOpacity)
                }
                .padding(.leading, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AleClip")
    }
}
