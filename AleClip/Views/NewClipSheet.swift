//
//  NewClipSheet.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

public struct NewClipSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String = ""
    @State private var selectedType: ClipType = .text
    @State private var isPinned: Bool = false

    let onSave: (ClipType, String, Bool) -> Void

    public init(onSave: @escaping (ClipType, String, Bool) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type")) {
                    Picker("Type", selection: $selectedType) {
                        Text("Text").tag(ClipType.text)
                        Text("Link").tag(ClipType.link)
                        Text("Color").tag(ClipType.color)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Content")) {
                    if selectedType == .text || selectedType == .link {
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                    } else if selectedType == .color {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: text))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))

                            TextField("#00F0FF", text: $text)
                                .textInputAutocapitalization(.characters)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                        }
                    }

                    // Paste from clipboard helper button
                    if let pbString = UIPasteboard.general.string, !pbString.isEmpty {
                        Button(action: {
                            text = pbString
                            autoDetectType(for: pbString)
                            HapticService.shared.trigger(.light)
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste from Clipboard")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SpectrumColors.azure)
                        }
                    }
                }

                Section {
                    Toggle("Pin to Top", isOn: $isPinned)
                }
            }
            .navigationTitle("New Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("action.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("action.save")) {
                        save()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SpectrumColors.gradient)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func autoDetectType(for string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            selectedType = .link
        } else if trimmed.hasPrefix("#") && (trimmed.count == 7 || trimmed.count == 9) {
            selectedType = .color
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(selectedType, trimmed, isPinned)
        HapticService.shared.notify(.success)
        dismiss()
    }
}
