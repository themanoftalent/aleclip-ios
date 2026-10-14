//
//  SettingsView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct SettingsView: View {
    @ObservedObject private var storage = StorageService.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    @ObservedObject private var l10n = LocalizationService.shared
    @ObservedObject private var haptics = HapticService.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmptyTrashConfirm: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var exportData: ExportDoc? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false

    private let historyLimits = [25, 50, 100, 200, 500]

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Branding Header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            SpectrumLogoBadge(size: 64)
                            
                            VStack(spacing: 2) {
                                Text("AleClip")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(SpectrumColors.gradient)

                                Text(locF("about.version", "2.0.1", "2026"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // General Settings
                Section(header: Text(loc("settings.general"))) {
                    // Language
                    Picker(loc("settings.language"), selection: Binding(
                        get: { l10n.currentLanguage },
                        set: { l10n.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }

                    // Max Clips
                    Picker(loc("settings.maxHistory"), selection: $storage.maxClips) {
                        ForEach(historyLimits, id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }

                    // Auto Ingest
                    Toggle(loc("settings.autoIngest"), isOn: $clipboard.autoIngestOnForeground)

                    // Haptics
                    Toggle(loc("settings.soundEffects"), isOn: $haptics.isEnabled)
                }

                // Storage & Trash
                Section(header: Text(loc("settings.storage"))) {
                    HStack {
                        Text(loc("settings.activeClips"))
                        Spacer()
                        Text("\(storage.activeClips.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(loc("settings.trashClips"))
                        Spacer()
                        Text("\(storage.deletedClips.count)")
                            .foregroundColor(.secondary)
                    }

                    if !storage.deletedClips.isEmpty {
                        Button(role: .destructive, action: {
                            showEmptyTrashConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "trash.slash")
                                Text(loc("action.emptyTrash"))
                            }
                        }
                    }
                }

                // Backup & Migration
                Section(header: Text(loc("settings.backup"))) {
                    Button(action: prepareExport) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(SpectrumColors.azure)
                            Text(loc("action.exportBackup"))
                        }
                    }

                    Button(action: { showImportPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(SpectrumColors.mint)
                            Text(loc("action.importBackup"))
                        }
                    }
                }

                // About & Privacy
                Section(header: Text(loc("settings.about"))) {
                    HStack {
                        Text(loc("about.developer"))
                        Spacer()
                        Text("themanoftalent")
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(SpectrumColors.emerald)
                            Text("100% On-Device & Private")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        Text(loc("about.tagline"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(loc("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("action.done")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .confirmationDialog(
                loc("trash.emptyConfirmTitle"),
                isPresented: $showEmptyTrashConfirm,
                titleVisibility: .visible
            ) {
                Button(loc("action.emptyTrash"), role: .destructive) {
                    storage.emptyTrash()
                    haptics.notify(.success)
                }
                Button(loc("action.cancel"), role: .cancel) {}
            } message: {
                Text(loc("trash.emptyConfirmMessage"))
            }
            .sheet(isPresented: $showExportSheet) {
                if let doc = exportData {
                    ShareSheet(activityItems: [doc.url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("AleClip"),
                    message: Text(alertMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func prepareExport() {
        guard let data = storage.exportBackupJSON() else {
            alertMessage = "Failed to create backup export."
            showAlert = true
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("AleClip_Backup.json")
        do {
            try data.write(to: tempURL)
            self.exportData = ExportDoc(url: tempURL)
            self.showExportSheet = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            guard selectedURL.startAccessingSecurityScopedResource() else { return }
            defer { selectedURL.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: selectedURL)
            if storage.importBackupJSON(data: data) {
                haptics.notify(.success)
                alertMessage = "Backup imported successfully!"
                showAlert = true
            } else {
                alertMessage = "Failed to parse backup file."
                showAlert = true
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// Helper document wrapper
private struct ExportDoc: Identifiable {
    let id = UUID()
    let url: URL
}

// UIActivityViewController wrapper for SwiftUI
private struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
