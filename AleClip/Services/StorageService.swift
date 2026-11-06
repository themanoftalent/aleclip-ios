//
//  StorageService.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import CryptoKit

/// Content hash identical to the Mac app's, so the same clip is recognised on every device.
/// Mac: sha256("text:…"), "html:…", "url:…", "color:…", "file:…" (hex).
public func aleClipContentHash(type: ClipType, content: String) -> String {
    let prefix: String
    switch type {
    case .text, .richText: prefix = "text"
    case .html: prefix = "html"
    case .link: prefix = "url"
    case .color: prefix = "color"
    case .file: prefix = "file"
    case .image: prefix = "image"
    }
    let digest = SHA256.hash(data: Data("\(prefix):\(content)".utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

public struct AppSettings: Codable, Sendable {
    public var historyLimit: Int = 200
    public var autoCapture: Bool = true
    public var hapticFeedback: Bool = true
}

@MainActor
public final class StorageService: ObservableObject {
    public static let shared = StorageService()

    @Published public var clips: [ClipItem] = []
    @Published public private(set) var deletedClips: [ClipItem] = []
    @Published public var settings: AppSettings = AppSettings()

    // Aliases for View Compatibility
    public var activeClips: [ClipItem] {
        get { clips }
        set { clips = newValue }
    }

    public var maxClips: Int {
        get { settings.historyLimit }
        set {
            settings.historyLimit = newValue
            saveSettings()
        }
    }

    private let fileManager = FileManager.default
    private let storageDirectoryURL: URL
    private let historyFileURL: URL
    private let deletedHistoryFileURL: URL
    private let settingsFileURL: URL
    private let blobsDirectoryURL: URL

    private var undoStack: [(clip: ClipItem, originalIndex: Int)] = []

    /// Sync tombstones: contentHash -> deletion time, shared with the Mac and Android.
    @Published public private(set) var tombstones: [String: Date] = [:]
    private var tombstonesFileURL: URL { storageDirectoryURL.appendingPathComponent("sync_tombstones.json") }
    private static let tombstoneLifetime: TimeInterval = 60 * 60 * 24 * 60 // 60 days

    private init() {
        let appGroupId = "group.com.themanoftalent.aleclip"
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        let baseDirectory = groupURL ?? documentsURL
        self.storageDirectoryURL = baseDirectory.appendingPathComponent("AleClipData", isDirectory: true)
        self.historyFileURL = storageDirectoryURL.appendingPathComponent("history.json")
        self.deletedHistoryFileURL = storageDirectoryURL.appendingPathComponent("deleted_history.json")
        self.settingsFileURL = storageDirectoryURL.appendingPathComponent("settings.json")
        self.blobsDirectoryURL = storageDirectoryURL.appendingPathComponent("blobs", isDirectory: true)

        createDirectoriesIfNeeded()
        loadSettings()
        loadHistory()
        loadDeletedHistory()
        loadTombstones()
        migrateHashesToMacFormat()
    }

    /// Older iOS versions used base64 hashes; switch to the Mac's SHA-256 format once.
    private func migrateHashesToMacFormat() {
        var changed = false
        for i in clips.indices where clips[i].type != .image && clips[i].contentHash.count != 64 {
            clips[i].contentHash = aleClipContentHash(type: clips[i].type, content: clips[i].plainText)
            changed = true
        }
        if changed { saveHistory() }
    }

    // MARK: - Sync Tombstones & Merge

    private func recordTombstones(for items: [ClipItem]) {
        guard !items.isEmpty else { return }
        let now = Date()
        for item in items { tombstones[item.contentHash] = now }
        saveTombstones()
        SyncService.shared.scheduleSync()
    }

    private func clearTombstones(for items: [ClipItem]) {
        var changed = false
        for item in items where tombstones.removeValue(forKey: item.contentHash) != nil { changed = true }
        if changed { saveTombstones() }
    }

    private func saveTombstones() {
        let cutoff = Date().addingTimeInterval(-Self.tombstoneLifetime)
        tombstones = tombstones.filter { $0.value > cutoff }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(tombstones) {
            try? data.write(to: tombstonesFileURL, options: .atomic)
        }
    }

    private func loadTombstones() {
        guard let data = try? Data(contentsOf: tombstonesFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        tombstones = (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    /// Merges another device's clips and deletions (same rules as the Mac). Never triggers a sync.
    @discardableResult
    public func applyRemote(clips remoteClips: [ClipItem], tombstones remoteTombstones: [String: Date]) -> (added: Int, removed: Int) {
        var removed: [ClipItem] = []
        var tombstonesChanged = false
        for (hash, deletedAt) in remoteTombstones {
            if let existing = tombstones[hash], existing >= deletedAt { continue }
            tombstones[hash] = deletedAt
            tombstonesChanged = true
            removed += clips.filter { $0.contentHash == hash && $0.lastUsedAt <= deletedAt && !$0.isPinned }
        }
        if !removed.isEmpty {
            let ids = Set(removed.map(\.id))
            clips.removeAll { ids.contains($0.id) }
            deletedClips.removeAll { ids.contains($0.id) }
            deletedClips.insert(contentsOf: removed, at: 0)
            if deletedClips.count > 100 { deletedClips = Array(deletedClips.prefix(100)) }
        }

        let localHashes = Set(clips.map(\.contentHash))
        var added = 0
        for clip in remoteClips where !localHashes.contains(clip.contentHash) {
            if let deletedAt = tombstones[clip.contentHash], deletedAt >= clip.lastUsedAt { continue }
            clips.append(clip)
            added += 1
        }
        if added > 0 { clips.sort { $0.createdAt > $1.createdAt } }

        if tombstonesChanged { saveTombstones() }
        if added > 0 || !removed.isEmpty {
            saveHistory()
            saveDeletedHistory()
        }
        return (added, removed.count)
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Operations

    private var saveDebounceWorkItem: DispatchWorkItem?

    public func scheduleSaveHistory() {
        saveDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.saveHistory()
            }
        }
        saveDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    @discardableResult
    public func addClip(
        type: ClipType,
        content: String,
        imagePath: String? = nil,
        imageData: Data? = nil,
        isPinned: Bool = false
    ) -> ClipItem {
        let hash = aleClipContentHash(type: type, content: content)
        let item = ClipItem(
            type: type,
            plainText: content,
            imageFileName: imagePath,
            isPinned: isPinned,
            contentHash: hash
        )
        addClip(item)
        return item
    }

    public func addClip(_ clip: ClipItem) {
        if let existingIndex = clips.firstIndex(where: { $0.contentHash == clip.contentHash }) {
            var existing = clips.remove(at: existingIndex)
            existing.lastUsedAt = Date()
            existing.createdAt = Date()
            clips.insert(existing, at: 0)
        } else {
            clips.insert(clip, at: 0)
        }
        clearTombstones(for: [clip])

        pruneHistoryIfNeeded()
        scheduleSaveHistory()
        SyncService.shared.scheduleSync()
    }

    public func updateClip(_ updated: ClipItem) {
        if let index = clips.firstIndex(where: { $0.id == updated.id }) {
            clips[index] = updated
            scheduleSaveHistory()
        }
    }

    public func togglePin(id: UUID) {
        togglePin(for: id)
    }

    public func togglePin(for clipId: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].isPinned.toggle()
        scheduleSaveHistory()
    }

    @discardableResult
    public func deleteClip(id: UUID, permanent: Bool = false) -> ClipItem? {
        if permanent {
            return permanentlyDeleteClip(id: id)
        }

        // Soft deletion
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = clips.remove(at: index)
        recordTombstones(for: [removed])

        undoStack.append((clip: removed, originalIndex: index))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }

        deletedClips.removeAll { $0.id == removed.id }
        deletedClips.insert(removed, at: 0)
        if deletedClips.count > 100 {
            let overflow = deletedClips.suffix(from: 100)
            for item in overflow {
                cleanupBlobIfNotReferenced(filename: item.imageFileName)
            }
            deletedClips = Array(deletedClips.prefix(100))
        }

        scheduleSaveHistory()
        saveDeletedHistory()
        return removed
    }

    @discardableResult
    public func permanentlyDeleteClip(id: UUID) -> ClipItem? {
        if let index = deletedClips.firstIndex(where: { $0.id == id }) {
            let removed = deletedClips.remove(at: index)
            undoStack.removeAll { $0.clip.id == id }
            cleanupBlobIfNotReferenced(filename: removed.imageFileName)
            saveDeletedHistory()
            return removed
        }
        if let index = clips.firstIndex(where: { $0.id == id }) {
            let removed = clips.remove(at: index)
            recordTombstones(for: [removed])
            undoStack.removeAll { $0.clip.id == id }
            cleanupBlobIfNotReferenced(filename: removed.imageFileName)
            scheduleSaveHistory()
            return removed
        }
        return nil
    }

    @discardableResult
    public func restoreClip(id: UUID) -> ClipItem? {
        guard let index = deletedClips.firstIndex(where: { $0.id == id }) else { return nil }
        let restored = deletedClips.remove(at: index)
        clearTombstones(for: [restored])
        undoStack.removeAll { $0.clip.id == id }

        clips.removeAll { $0.id == restored.id }
        clips.insert(restored, at: 0)

        scheduleSaveHistory()
        saveDeletedHistory()
        return restored
    }

    @discardableResult
    public func undoLastDelete() -> ClipItem? {
        guard let last = undoStack.popLast() else { return nil }
        let clip = last.clip
        clearTombstones(for: [clip])
        let targetIndex = min(last.originalIndex, clips.count)

        deletedClips.removeAll { $0.id == clip.id }
        clips.removeAll { $0.id == clip.id }
        clips.insert(clip, at: targetIndex)

        scheduleSaveHistory()
        saveDeletedHistory()
        return clip
    }

    public func emptyTrash() {
        for item in deletedClips {
            cleanupBlobIfNotReferenced(filename: item.imageFileName)
        }
        deletedClips.removeAll()
        undoStack.removeAll()
        saveDeletedHistory()
    }

    private func cleanupBlobIfNotReferenced(filename: String?) {
        guard let filename = filename else { return }
        let referencedInClips = clips.contains { $0.imageFileName == filename }
        let referencedInDeleted = deletedClips.contains { $0.imageFileName == filename }
        if !referencedInClips && !referencedInDeleted {
            deleteBlob(named: filename)
        }
    }

    private func pruneHistoryIfNeeded() {
        guard clips.count > settings.historyLimit else { return }
        let unpinnedIndices = clips.indices.filter { !clips[$0].isPinned }
        let overflow = clips.count - settings.historyLimit

        if overflow > 0 && !unpinnedIndices.isEmpty {
            let toRemove = unpinnedIndices.suffix(overflow)
            var idsToRemove: Set<UUID> = []
            for idx in toRemove {
                idsToRemove.insert(clips[idx].id)
                deletedClips.removeAll { $0.id == clips[idx].id }
                deletedClips.insert(clips[idx], at: 0)
            }
            clips.removeAll { idsToRemove.contains($0.id) }

            if deletedClips.count > 100 {
                let extra = deletedClips.suffix(from: 100)
                for item in extra {
                    cleanupBlobIfNotReferenced(filename: item.imageFileName)
                }
                deletedClips = Array(deletedClips.prefix(100))
            }
            saveDeletedHistory()
        }
    }

    // MARK: - Images / Blobs

    public func saveImageBlob(data: Data) -> String? {
        let filename = "\(UUID().uuidString).png"
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save image blob: \(error)")
            return nil
        }
    }

    public nonisolated func loadImageBlob(filename: String?) -> Data? {
        guard let filename = filename else { return nil }
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    private func deleteBlob(named filename: String) {
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    public func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(clips)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.clips = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
            self.clips = []
        }
    }

    public func saveDeletedHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(deletedClips)
            try data.write(to: deletedHistoryFileURL, options: .atomic)
        } catch {
            print("Failed to save deleted history: \(error)")
        }
    }

    private func loadDeletedHistory() {
        guard fileManager.fileExists(atPath: deletedHistoryFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: deletedHistoryFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.deletedClips = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load deleted history: \(error)")
            self.deletedClips = []
        }
    }

    public func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    private func loadSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            saveSettings()
            return
        }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            self.settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
        }
    }

    // MARK: - Export & Import

    public func exportBackupJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(clips)
    }

    public func importBackupJSON(data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode([ClipItem].self, from: data) else {
            return false
        }

        let existingHashes = Set(clips.map { $0.contentHash })
        for item in imported {
            if !existingHashes.contains(item.contentHash) {
                clips.append(item)
            }
        }

        pruneHistoryIfNeeded()
        saveHistory()
        return true
    }
}
