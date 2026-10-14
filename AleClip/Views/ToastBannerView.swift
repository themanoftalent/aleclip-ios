//
//  ToastBannerView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

public enum ToastType {
    case info(String)
    case copied(String)
    case undo(title: String, onUndo: () -> Void)
    case success(String)
}

public struct ToastBannerView: View {
    let type: ToastType
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var timeRemaining: Int = 4

    public var body: some View {
        let isDark = colorScheme == .dark

        HStack(spacing: 12) {
            // Icon
            switch type {
            case .copied:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpectrumColors.mint)
            case .undo:
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpectrumColors.gold)
            case .success:
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpectrumColors.azure)
            case .info:
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpectrumColors.cyan)
            }

            // Message
            VStack(alignment: .leading, spacing: 2) {
                switch type {
                case .copied(let text), .info(let text), .success(let text):
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                case .undo(let title, _):
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Undo action or close button
            switch type {
            case .undo(_, let onUndo):
                Button(action: {
                    HapticService.shared.trigger(.medium)
                    onUndo()
                    onDismiss()
                }) {
                    Text(loc("action.undo"))
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SpectrumColors.gold.opacity(0.2))
                        .foregroundStyle(SpectrumColors.gold)
                        .clipShape(Capsule())
                }
            default:
                Button(action: {
                    HapticService.shared.trigger(.light)
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDark ? Color(white: 0.14).opacity(0.92) : Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.12), radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SpectrumColors.gradient, lineWidth: 1.2)
                .opacity(0.4)
        )
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}
