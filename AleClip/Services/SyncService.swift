//
//  SyncService.swift
//  AleClip
//
//  Syncs clips with AleClip for Mac (and Android) through the shared
//  "My Drive/AleClip/.sync" folder. The user picks the AleClip folder once in the
//  Files app (Google Drive appears there); a security-scoped bookmark keeps access.
//
//  Protocol (same on every platform):
//    .sync/sync_payload_<device>.json = { version, deviceName, timestamp,
//                                        collections, clips, deletedHashes }
//    deletedHashes: contentHash -> deletion time, so deletions spread to all devices.
//

import Foundation
import UIKit

private struct SyncPayloadOut: Encodable {
    let version: String
    let deviceName: String
    let timestamp: Date
    let collections: [String]   // iOS has no Pinboards; always empty
    let clips: [ClipItem]
    let deletedHashes: [String: Date]
}

private struct SyncPayloadIn: Decodable {
    let deviceName: String?
    let clips: [ClipItem]?
    let deletedHashes: [String: Date]?
}

@MainActor
public final class SyncService: ObservableObject {
    public static let shared = SyncService()

    @Published public private(set) var folderName: String?
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSync: Date?
    @Published public private(set) var statusMessage: String = ""

    private let bookmarkKey = "AleClipSyncFolderBookmark"
    private let lastSyncKey = "AleClipLastSync"
    private var debounce: DispatchWorkItem?

    public var isConfigured: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }

    /// Stable per-install file name, e.g. "sync_payload_iPhone-3F2A.json".
    private var ownFileName: String {
        let vendor = UIDevice.current.identifierForVendor?.uuidString.prefix(4) ?? "0000"
        return "sync_payload_\(UIDevice.current.model)-\(vendor).json"
    }

    private init() {
        lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        if let url = resolveFolder() { folderName = url.lastPathComponent }
    }

    // MARK: Folder selection

    /// Called with the folder the user picked in the Files picker.
    public func setFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            folderName = url.lastPathComponent
            statusMessage = ""
            syncNow()
        } catch {
            statusMessage = "Couldn't keep access to that folder: \(error.localizedDescription)"
        }
    }

    public func disconnect() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderName = nil
        statusMessage = ""
    }

    private func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        return url
    }

    // MARK: Sync

    /// Debounced sync after local changes (new clip, delete).
    public func scheduleSync(delay: TimeInterval = 3) {
        guard isConfigured else { return }
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.syncNow() }
        }
        debounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func syncNow() {
        guard !isSyncing, let folder = resolveFolder() else { return }
        isSyncing = true
        statusMessage = "Syncing…"
        let ownName = ownFileName

        Task.detached(priority: .utility) {
            let incoming = Self.readIncomingPayloads(folder: folder, excluding: ownName)
            await MainActor.run {
                let storage = StorageService.shared
                var added = 0, removed = 0
                for payload in incoming.payloads {
                    // Images reference blobs stored only on the device that captured them.
                    let clips = (payload.clips ?? []).filter { $0.type != .image }
                    let r = storage.applyRemote(clips: clips, tombstones: payload.deletedHashes ?? [:])
                    added += r.added; removed += r.removed
                }
                let out = SyncPayloadOut(
                    version: "2.2.0",
                    deviceName: UIDevice.current.model,
                    timestamp: Date(),
                    collections: [],
                    clips: storage.clips.filter { $0.type != .image },
                    deletedHashes: storage.tombstones
                )
                Task.detached(priority: .utility) {
                    let writeError = Self.writePayload(out, folder: folder, fileName: ownName)
                    await MainActor.run {
                        let shared = SyncService.shared
                        shared.isSyncing = false
                        if let err = incoming.error ?? writeError {
                            shared.statusMessage = "Sync failed: \(err)"
                        } else {
                            shared.lastSync = Date()
                            UserDefaults.standard.set(shared.lastSync, forKey: shared.lastSyncKey)
                            var msg = "Synced with \(incoming.payloads.count) other device\(incoming.payloads.count == 1 ? "" : "s")"
                            if added > 0 { msg += " · \(added) new" }
                            if removed > 0 { msg += " · \(removed) removed" }
                            shared.statusMessage = msg
                        }
                    }
                }
            }
        }
    }

    // MARK: File IO (off the main thread, coordinated for File Provider folders like Google Drive)

    private nonisolated static func syncDir(_ folder: URL) -> URL {
        folder.appendingPathComponent(".sync", isDirectory: true)
    }

    private nonisolated static func readIncomingPayloads(folder: URL, excluding ownName: String) -> (payloads: [SyncPayloadIn], error: String?) {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let dir = syncDir(folder)
        var candidates: [URL] = []
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: dir, options: [], error: &coordError) { url in
            candidates = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        }
        // Older Mac versions wrote payloads next to the clip folders.
        let root = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        candidates += root.filter { $0.lastPathComponent.hasPrefix("sync_payload_") }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var payloads: [SyncPayloadIn] = []
        for file in candidates where file.pathExtension == "json" && file.lastPathComponent != ownName {
            var data: Data?
            var err: NSError?
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &err) { url in
                data = try? Data(contentsOf: url)
            }
            if let data, let payload = try? decoder.decode(SyncPayloadIn.self, from: data) {
                payloads.append(payload)
            }
        }
        return (payloads, nil)
    }

    private nonisolated static func writePayload(_ payload: SyncPayloadOut, folder: URL, fileName: String) -> String? {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(payload) else { return "could not encode clips" }

        let dir = syncDir(folder)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(fileName)
        var writeError: String?
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error.localizedDescription }
        }
        return writeError ?? coordError?.localizedDescription
    }
}
