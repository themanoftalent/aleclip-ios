//
//  ClipDetailView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

@MainActor
public struct ClipDetailView: View {
    @Binding var item: ClipItem
    let isTrashMode: Bool
    let onSave: (ClipItem) -> Void
    let onDelete: () -> Void
    let onRestore: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editedContent: String = ""
    @State private var isPinned: Bool = false
    @State private var selectedType: ClipType = .text
    @State private var fullImage: UIImage? = nil
    @State private var showCopiedAlert: Bool = false

    public init(
        item: Binding<ClipItem>,
        isTrashMode: Bool = false,
        onSave: @escaping (ClipItem) -> Void,
        onDelete: @escaping () -> Void,
        onRestore: (() -> Void)? = nil
    ) {
        self._item = item
        self.isTrashMode = isTrashMode
        self.onSave = onSave
        self.onDelete = onDelete
        self.onRestore = onRestore
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Type Badge & Metadata Bar
                    HStack(spacing: 12) {
                        Label(selectedType.displayName, systemImage: selectedType.systemImage)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(selectedType.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedType.color.opacity(0.16))
                            .clipShape(Capsule())

                        Spacer()

                        Text(item.formattedTime)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Main Content Editor / Preview
                    contentEditorSection
                        .padding(.horizontal)

                    // Quick Actions Row
                    actionButtonsRow
                        .padding(.horizontal)

                    // Information details card
                    metadataDetailsCard
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
            .navigationTitle(loc("detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("action.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !isTrashMode && (editedContent != item.content || isPinned != item.isPinned) {
                        Button(loc("action.save")) {
                            saveChanges()
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SpectrumColors.gradient)
                    }
                }
            }
            .onAppear {
                self.editedContent = item.content
                self.isPinned = item.isPinned
                self.selectedType = item.type
                loadImageIfNeeded()
            }
        }
    }

    // MARK: - Content Editor Section

    @ViewBuilder
    private var contentEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch item.type {
            case .text, .richText, .html, .link:
                TextEditor(text: $editedContent)
                    .font(.system(size: 15, design: item.type == .link ? .monospaced : .default))
                    .frame(minHeight: 180)
                    .padding(12)
                    .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if item.type == .link, let url = URL(string: editedContent), UIApplication.shared.canOpenURL(url) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open in Safari")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SpectrumColors.azure)
                        .padding(.vertical, 8)
                    }
                }

            case .image:
                if let uiImage = fullImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .cornerRadius(14)
                        .shadow(radius: 6)
                } else {
                    ContentUnavailableView("Image Preview", systemImage: "photo")
                        .frame(height: 180)
                }

            case .color:
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: editedContent))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )

                    TextField("HEX Color (#RRGGBB)", text: $editedContent)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                }

            case .file:
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 32))
                        .foregroundColor(SpectrumColors.azure)

                    Text(editedContent)
                        .font(.system(size: 14))
                        .lineLimit(3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Copy button
            Button(action: {
                ClipboardService.shared.copyToClipboard(item: item)
                HapticService.shared.notify(.success)
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                    Text(loc("action.copy"))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SpectrumColors.gradient)
                .cornerRadius(12)
            }

            // Pin / Unpin button
            if !isTrashMode {
                Button(action: {
                    isPinned.toggle()
                    item.isPinned = isPinned
                    StorageService.shared.togglePin(id: item.id)
                    HapticService.shared.trigger(.light)
                }) {
                    Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(SpectrumColors.gold)
                        .frame(width: 46, height: 46)
                        .background(SpectrumColors.gold.opacity(0.15))
                        .cornerRadius(12)
                }
            }

            // Share Link
            ShareLink(item: editedContent) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(SpectrumColors.cyan)
                    .frame(width: 46, height: 46)
                    .background(SpectrumColors.cyan.opacity(0.15))
                    .cornerRadius(12)
            }

            // Delete or Restore
            if isTrashMode {
                if let onRestore = onRestore {
                    Button(action: {
                        onRestore()
                        dismiss()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(SpectrumColors.mint)
                            .frame(width: 46, height: 46)
                            .background(SpectrumColors.mint.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            } else {
                Button(action: {
                    onDelete()
                    dismiss()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.red)
                        .frame(width: 46, height: 46)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Metadata Card

    private var metadataDetailsCard: some View {
        VStack(spacing: 12) {
            metadataRow(title: loc("detail.created"), value: item.formattedTime)
            Divider()
            metadataRow(title: loc("detail.length"), value: "\(item.content.count) characters")
            Divider()
            metadataRow(title: loc("detail.words"), value: "\(item.content.split(whereSeparator: \.isWhitespace).count) words")
            if item.type == .image, let img = fullImage {
                Divider()
                metadataRow(title: "Dimensions", value: "\(Int(img.size.width)) × \(Int(img.size.height)) px")
            }
        }
        .padding(14)
        .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
        .cornerRadius(14)
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    private func saveChanges() {
        item.content = editedContent
        item.isPinned = isPinned
        onSave(item)
        HapticService.shared.notify(.success)
        dismiss()
    }

    private func loadImageIfNeeded() {
        guard item.type == .image else { return }
        if let data = item.imageData ?? StorageService.shared.loadImageBlob(filename: item.imagePath) {
            self.fullImage = UIImage(data: data)
        }
    }
}
