//
//  ClipboardService.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import UIKit
import Combine
import SwiftUI

@MainActor
final class ClipboardService: ObservableObject {
    static let shared = ClipboardService()
    
    @Published var lastDetectedItem: ClipItem? = nil
    @Published var showPasteDetectedToast: Bool = false
    @Published var autoIngestOnForeground: Bool {
        didSet {
            UserDefaults.standard.set(autoIngestOnForeground, forKey: "aleclip_auto_ingest")
        }
    }
    
    private var lastChangeCount: Int = UIPasteboard.general.changeCount
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.autoIngestOnForeground = UserDefaults.standard.object(forKey: "aleclip_auto_ingest") as? Bool ?? true
        
        // Listen to app foregrounding
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkPasteboardOnForeground()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Triggered whenever the app comes to foreground or when user taps "Paste" button
    func checkPasteboardOnForeground(force: Bool = false) {
        let currentCount = UIPasteboard.general.changeCount
        guard force || (autoIngestOnForeground && currentCount != lastChangeCount) else {
            return
        }
        
        lastChangeCount = currentCount
        ingestCurrentPasteboard()
    }
    
    /// Reads UIPasteboard.general and saves into StorageService if new
    func ingestCurrentPasteboard() {
        let pasteboard = UIPasteboard.general
        let storage = StorageService.shared
        
        // 1. Check for Image
        if pasteboard.hasImages, let image = pasteboard.image {
            guard let pngData = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else { return }
            
            // Check if identical to most recent clip
            if let first = storage.activeClips.first, first.type == .image, first.imageData == pngData {
                return
            }
            
            let filename = storage.saveImageBlob(data: pngData)
            let item = storage.addClip(
                type: .image,
                content: "Image (\(Int(image.size.width))x\(Int(image.size.height)))",
                imagePath: filename,
                imageData: pngData
            )
            
            HapticService.shared.notify(.success)
            self.lastDetectedItem = item
            self.showPasteDetectedToast = true
            return
        }
        
        // 2. Check for URL
        if pasteboard.hasURLs, let url = pasteboard.url {
            let urlString = url.absoluteString
            if let first = storage.activeClips.first, first.content == urlString {
                return
            }
            
            let item = storage.addClip(type: .link, content: urlString)
            HapticService.shared.notify(.success)
            self.lastDetectedItem = item
            self.showPasteDetectedToast = true
            return
        }
        
        // 3. Check for Color
        if pasteboard.hasColors, let color = pasteboard.color {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
            
            if let first = storage.activeClips.first, first.content == hex {
                return
            }
            
            let item = storage.addClip(type: .color, content: hex)
            HapticService.shared.notify(.success)
            self.lastDetectedItem = item
            self.showPasteDetectedToast = true
            return
        }
        
        // 4. Check for String
        if pasteboard.hasStrings, let string = pasteboard.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check duplicate with top clip
            if let first = storage.activeClips.first, first.content == trimmed {
                return
            }
            
            // Auto-detect link or color
            let type: ClipType
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                type = .link
            } else if trimmed.hasPrefix("#") && (trimmed.count == 7 || trimmed.count == 9) {
                type = .color
            } else {
                type = .text
            }
            
            let item = storage.addClip(type: type, content: trimmed)
            HapticService.shared.notify(.success)
            self.lastDetectedItem = item
            self.showPasteDetectedToast = true
            return
        }
    }
    
    /// Copies an item back to UIPasteboard and sets change count to ignore self-paste
    func copyToClipboard(item: ClipItem) {
        let pasteboard = UIPasteboard.general
        
        switch item.type {
        case .image:
            if let data = item.imageData ?? StorageService.shared.loadImageBlob(filename: item.imagePath),
               let image = UIImage(data: data) {
                pasteboard.image = image
            } else {
                pasteboard.string = item.content
            }
        case .link:
            if let url = URL(string: item.content) {
                pasteboard.url = url
            } else {
                pasteboard.string = item.content
            }
        case .color:
            pasteboard.string = item.content
        case .text, .file:
            pasteboard.string = item.content
        }
        
        lastChangeCount = pasteboard.changeCount
        HapticService.shared.copied()
    }
}
