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

                // About Section
                Section(header: Text(loc("settings.about"))) {
                    // Card 1: Open Source | Free to Fork & Use
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                                    .frame(width: 24, height: 24)
                                Text("{}")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            Text("Open Source | Free to Fork & Use")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text("Feel free to fork, modify, use, and contribute!")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Developed by:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("SoftAI Yazılım")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 4) {
                                Text("Developer:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("Assoc. Prof. Dr. Mehmet Akif Cifci")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 4) {
                                Text("GitHub:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Link("@themanoftalent", destination: URL(string: "https://github.com/themanoftalent")!)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Card 2: Follow & Support
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("❤️")
                                .font(.system(size: 16))
                            Text("Follow & Support")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text("If you find this project useful, star the repository, follow me, or buy me a coffee! Your support helps keep future projects free and open-source.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Button 1: GitHub
                                Link(destination: URL(string: "https://github.com/themanoftalent")!) {
                                    HStack(spacing: 6) {
                                        Text("</>")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                                        Text("GitHub")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                }

                                // Button 2: Sponsor Me
                                Link(destination: URL(string: "https://github.com/sponsors/themanoftalent")!) {
                                    HStack(spacing: 6) {
                                        Text("❤️")
                                            .font(.system(size: 12))
                                        Text("Sponsor Me")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                }

                                // Button 3: Buy Me a Coffee
                                Link(destination: URL(string: "https://buymeacoffee.com/themanoftalent")!) {
                                    HStack(spacing: 6) {
                                        Text("☕")
                                            .font(.system(size: 12))
                                        Text("Buy Me a Coffee")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Privacy Policy & Terms Link
                    Link(destination: URL(string: "https://themanoftalent.github.io/aleclip-ios/")!) {
                        HStack {
                            Label("Privacy Policy & Terms", systemImage: "hand.raised.shield")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
