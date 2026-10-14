//
//  ClipRowView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

@MainActor
public struct ClipRowView: View {
    let item: ClipItem
    let isTrashMode: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onRestore: (() -> Void)?
    let onPermanentDelete: (() -> Void)?
    let onSelectDetail: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var justCopied: Bool = false
    @State private var thumbnailImage: UIImage? = nil

    public init(
        item: ClipItem,
        isTrashMode: Bool = false,
        onCopy: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRestore: (() -> Void)? = nil,
        onPermanentDelete: (() -> Void)? = nil,
        onSelectDetail: @escaping () -> Void
    ) {
        self.item = item
        self.isTrashMode = isTrashMode
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onPermanentDelete = onPermanentDelete
        self.onSelectDetail = onSelectDetail
    }

    public var body: some View {
        let isDark = colorScheme == .dark

        Button(action: {
            if isTrashMode {
                onSelectDetail()
            } else {
                performCopy()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Leading Type Indicator & Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.type.color.opacity(isDark ? 0.22 : 0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: item.type.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(item.type.color)
                }

                // Middle Content Area
                VStack(alignment: .leading, spacing: 5) {
                    // Header row: Type name, character count, Pin icon, timestamp
                    HStack(spacing: 6) {
                        Text(item.type.displayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(item.type.color)

                        if item.type == .text {
                            Text("• \(item.content.count) chars")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(SpectrumColors.gold)
                        }

                        Spacer()

                        Text(item.formattedTime)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Content preview based on type
                    contentPreview
                }

                Spacer(minLength: 4)

                // Trailing Action/Detail Chevron
                VStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.secondary.opacity(0.45))
                    Spacer()
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDark ? Color(white: 0.12) : Color.white)
                    .shadow(color: Color.black.opacity(isDark ? 0.18 : 0.04), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        justCopied ? SpectrumColors.gradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: justCopied ? 2 : 0
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isTrashMode {
                Button(action: performCopy) {
                    Label(loc("action.copy"), systemImage: "doc.on.doc")
                }
                Button(action: onTogglePin) {
                    Label(item.isPinned ? loc("action.unpin") : loc("action.pin"), systemImage: item.isPinned ? "pin.slash" : "pin")
                }
                Button(action: onSelectDetail) {
                    Label(loc("action.edit"), systemImage: "pencil")
                }
                ShareLink(item: item.content) {
                    Label(loc("action.share"), systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(loc("action.delete"), systemImage: "trash")
                }
            } else {
                if let onRestore = onRestore {
                    Button(action: onRestore) {
                        Label(loc("action.restore"), systemImage: "arrow.uturn.backward")
                    }
                }
                if let onPermanentDelete = onPermanentDelete {
                    Button(role: .destructive, action: onPermanentDelete) {
                        Label(loc("action.permanentDelete"), systemImage: "trash.slash")
                    }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isTrashMode {
                Button {
                    onTogglePin()
                } label: {
                    Label(item.isPinned ? loc("action.unpin") : loc("action.pin"), systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
                }
                .tint(SpectrumColors.gold)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isTrashMode {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(loc("action.delete"), systemImage: "trash.fill")
                }
            } else {
                if let onPermanentDelete = onPermanentDelete {
                    Button(role: .destructive) {
                        onPermanentDelete()
                    } label: {
                        Label(loc("action.permanentDelete"), systemImage: "trash.slash.fill")
                    }
                }
                if let onRestore = onRestore {
                    Button {
                        onRestore()
                    } label: {
                        Label(loc("action.restore"), systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    .tint(SpectrumColors.mint)
                }
            }
        }
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text, .richText, .html:
            Text(item.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

        case .link:
            HStack(spacing: 4) {
                Image(systemName: "safari")
                    .font(.system(size: 12))
                    .foregroundColor(SpectrumColors.azure)
                Text(item.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SpectrumColors.azure)
                    .lineLimit(2)
            }

        case .color:
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: item.content))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))

                Text(item.content)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

        case .image:
            if let uiImage = thumbnailImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 110)
                    .clipped()
                    .cornerRadius(8)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                    Text(item.content)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

        case .file:
            HStack(spacing: 6) {
                Image(systemName: "doc")
                    .foregroundColor(.secondary)
                Text(item.content)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
    }

    private func performCopy() {
        onCopy()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            justCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                justCopied = false
            }
        }
    }

    private func loadThumbnailIfNeeded() {
        guard item.type == .image else { return }
        if let data = item.imageData ?? StorageService.shared.loadImageBlob(filename: item.imagePath) {
            self.thumbnailImage = UIImage(data: data)
        }
    }
}
