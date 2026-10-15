//
//  MainView.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

public enum FilterCategory: Hashable {
    case all
    case pinned
    case text
    case links
    case images
    case files
    case colors
    case trash

    var localizedName: String {
        switch self {
        case .all: return loc("filter.all")
        case .pinned: return loc("filter.pinned")
        case .text: return loc("filter.text")
        case .links: return loc("filter.links")
        case .images: return loc("filter.images")
        case .files: return loc("filter.files")
        case .colors: return loc("filter.colors")
        case .trash: return loc("filter.trash")
        }
    }

    var systemIcon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .pinned: return "pin.fill"
        case .text: return "doc.plaintext.fill"
        case .links: return "link"
        case .images: return "photo.fill"
        case .files: return "folder.fill"
        case .colors: return "paintpalette.fill"
        case .trash: return "trash.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .all: return SpectrumColors.cyan
        case .pinned: return SpectrumColors.gold
        case .text: return SpectrumColors.azure
        case .links: return SpectrumColors.azure
        case .images: return SpectrumColors.lime
        case .files: return SpectrumColors.emerald
        case .colors: return SpectrumColors.tangerine
        case .trash: return Color.red
        }
    }
}

@MainActor
public struct MainView: View {
    @ObservedObject private var storage = StorageService.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    @ObservedObject private var l10n = LocalizationService.shared
    @ObservedObject private var haptics = HapticService.shared

    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var selectedFilter: FilterCategory = .all
    @State private var activeToast: ToastType? = nil
    @State private var selectedClipForDetail: ClipItem? = nil
    @State private var showNewClipSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showEmptyTrashConfirm: Bool = false

    private let filterCategories: [FilterCategory] = [
        .all, .pinned, .text, .links, .images, .files, .colors, .trash
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                (colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Pills Horizontal Bar
                    filterPillsBar
                        .padding(.vertical, 8)

                    // Clips Content List / Empty View
                    if filteredClips.isEmpty {
                        emptyStateView
                    } else {
                        clipsListView
                    }
                }

                // Floating Toast Banner
                if let toast = activeToast {
                    VStack {
                        ToastBannerView(type: toast) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                activeToast = nil
                            }
                        }
                        .padding(.top, 6)
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Navigation Bar Header with Watermark & Logo
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        SpectrumLogoBadge(size: 28)
                        Text("AleClip")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(SpectrumColors.gradient)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Quick Paste Button
                    Button(action: {
                        clipboard.ingestCurrentPasteboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SpectrumColors.azure.opacity(0.15))
                        .foregroundStyle(SpectrumColors.azure)
                        .clipShape(Capsule())
                    }

                    // Add Note/Clip Button
                    Button(action: {
                        haptics.trigger(.light)
                        showNewClipSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(SpectrumColors.mint)
                    }

                    // Settings Button
                    Button(action: {
                        haptics.trigger(.light)
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: loc("search.placeholder"))
            .sheet(item: $selectedClipForDetail) { clip in
                ClipDetailView(
                    item: Binding(
                        get: { clip },
                        set: { updated in
                            if let idx = storage.activeClips.firstIndex(where: { $0.id == updated.id }) {
                                storage.activeClips[idx] = updated
                            }
                        }
                    ),
                    isTrashMode: selectedFilter == .trash,
                    onSave: { updated in
                        storage.updateClip(updated)
                    },
                    onDelete: {
                        deleteClipWithUndo(clip)
                    },
                    onRestore: {
                        storage.restoreClip(id: clip.id)
                        triggerToast(.success(loc("toast.restored")))
                    }
                )
            }
            .sheet(isPresented: $showNewClipSheet) {
                NewClipSheet { type, content, isPinned in
                    _ = storage.addClip(type: type, content: content, isPinned: isPinned)
                    triggerToast(.success("Clip saved"))
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .onReceive(clipboard.$showPasteDetectedToast) { show in
                if show, let item = clipboard.lastDetectedItem {
                    triggerToast(.info(loc("toast.newCaptured")))
                    clipboard.showPasteDetectedToast = false
                }
            }
        }
    }

    // MARK: - Filter Pills Bar

    private var filterPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterCategories, id: \.self) { cat in
                    let isSelected = selectedFilter == cat
                    Button(action: {
                        haptics.trigger(.selection)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedFilter = cat
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: cat.systemIcon)
                                .font(.system(size: 11, weight: .bold))

                            Text(cat.localizedName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                            if cat == .trash && !storage.deletedClips.isEmpty {
                                Text("\(storage.deletedClips.count)")
                                    .font(.system(size: 10, weight: .heavy))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? cat.accentColor.opacity(0.18) : (colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92)))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? cat.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundColor(isSelected ? cat.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Clips List View

    private var clipsListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                // If in trash, show header to empty trash
                if selectedFilter == .trash {
                    HStack {
                        Text(loc("trash.title"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(role: .destructive, action: {
                            showEmptyTrashConfirm = true
                        }) {
                            Text(loc("action.emptyTrash"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                ForEach(filteredClips) { clip in
                    ClipRowView(
                        item: clip,
                        isTrashMode: selectedFilter == .trash,
                        onCopy: {
                            clipboard.copyToClipboard(item: clip)
                            triggerToast(.copied(loc("toast.copied")))
                        },
                        onTogglePin: {
                            storage.togglePin(id: clip.id)
                        },
                        onDelete: {
                            deleteClipWithUndo(clip)
                        },
                        onRestore: {
                            storage.restoreClip(id: clip.id)
                            triggerToast(.success(loc("toast.restored")))
                        },
                        onPermanentDelete: {
                            storage.permanentlyDeleteClip(id: clip.id)
                            haptics.notify(.warning)
                        },
                        onSelectDetail: {
                            selectedClipForDetail = clip
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
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
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 50)

            WatermarkLogoView(compact: false)
                .opacity(0.85)

            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)

                Text(emptySubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if selectedFilter == .trash && !storage.deletedClips.isEmpty == false {
                // Trash is clean
            } else if selectedFilter != .trash && storage.activeClips.isEmpty {
                Button(action: {
                    clipboard.ingestCurrentPasteboard()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(SpectrumColors.gradient)
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Filter Logic

    private var filteredClips: [ClipItem] {
        let baseList: [ClipItem] = (selectedFilter == .trash) ? storage.deletedClips : storage.activeClips

        return baseList.filter { item in
            // Search text match
            if !searchText.isEmpty && !item.matches(query: searchText) {
                return false
            }

            // Category filter
            switch selectedFilter {
            case .all, .trash:
                return true
            case .pinned:
                return item.isPinned
            case .text:
                return item.type == .text
            case .links:
                return item.type == .link
            case .images:
                return item.type == .image
            case .files:
                return item.type == .file
            case .colors:
                return item.type == .color
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return loc("search.noResults")
        }
        switch selectedFilter {
        case .trash: return loc("trash.empty")
        case .pinned: return "No Pinned Clips"
        default: return loc("empty.title")
        }
    }

    private var emptySubtitle: String {
        if !searchText.isEmpty {
            return "Try a different search term."
        }
        switch selectedFilter {
        case .trash: return loc("trash.emptyDesc")
        case .pinned: return "Swipe right on any clip to pin it for quick access."
        default: return loc("empty.subtitle")
        }
    }

    // MARK: - Actions

    private func deleteClipWithUndo(_ clip: ClipItem) {
        storage.deleteClip(id: clip.id)
        haptics.trigger(.medium)

        let toast = ToastType.undo(title: loc("toast.deletedMoved")) {
            storage.undoLastDelete()
        }
        triggerToast(toast, duration: 5.0)
    }

    private func triggerToast(_ toast: ToastType, duration: TimeInterval = 2.5) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            activeToast = toast
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.3)) {
                // If it's still showing, dismiss
                self.activeToast = nil
            }
        }
    }
}
