//
//  ShareViewController.swift
//  AleClipShareExtension
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        
        processIncomingItems()
    }
    
    private func processIncomingItems() {
        guard let extensionContext = extensionContext,
              let itemProviders = (extensionContext.inputItems as? [NSExtensionItem])?.compactMap({ $0.attachments }).flatMap({ $0 }),
              !itemProviders.isEmpty else {
            completeRequest()
            return
        }
        
        for provider in itemProviders {
            // Check for plain text or URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    if let url = item as? URL {
                        self?.saveClip(content: url.absoluteString, type: "link")
                    }
                    self?.completeRequest()
                }
                return
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    if let text = item as? String {
                        self?.saveClip(content: text, type: "text")
                    }
                    self?.completeRequest()
                }
                return
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                    if let imageURL = item as? URL, let data = try? Data(contentsOf: imageURL) {
                        self?.saveImageClip(data: data)
                    } else if let image = item as? UIImage, let data = image.pngData() {
                        self?.saveImageClip(data: data)
                    }
                    self?.completeRequest()
                }
                return
            }
        }
        
        completeRequest()
    }
    
    private func saveClip(content: String, type: String) {
        let appGroup = "group.com.themanoftalent.aleclip"
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = folder.appendingPathComponent("clips.json")
        
        var clips: [[String: Any]] = []
        if let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            clips = json
        }
        
        let newClip: [String: Any] = [
            "id": UUID().uuidString,
            "type": type,
            "content": content,
            "timestamp": Date().timeIntervalSince1970,
            "isPinned": false,
            "isDeleted": false
        ]
        
        clips.insert(newClip, at: 0)
        
        if let outputData = try? JSONSerialization.data(withJSONObject: clips, options: [.prettyPrinted]) {
            try? outputData.write(to: fileURL)
        }
    }
    
    private func saveImageClip(data: Data) {
        let appGroup = "group.com.themanoftalent.aleclip"
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let imagesFolder = folder.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
        
        let filename = "\(UUID().uuidString).png"
        let fileURL = imagesFolder.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        
        var clips: [[String: Any]] = []
        let clipsURL = folder.appendingPathComponent("clips.json")
        if let cData = try? Data(contentsOf: clipsURL),
           let json = try? JSONSerialization.jsonObject(with: cData) as? [[String: Any]] {
            clips = json
        }
        
        let newClip: [String: Any] = [
            "id": UUID().uuidString,
            "type": "image",
            "content": "Image (\(filename))",
            "imagePath": filename,
            "timestamp": Date().timeIntervalSince1970,
            "isPinned": false,
            "isDeleted": false
        ]
        
        clips.insert(newClip, at: 0)
        if let outputData = try? JSONSerialization.data(withJSONObject: clips, options: [.prettyPrinted]) {
            try? outputData.write(to: clipsURL)
        }
    }
    
    private func completeRequest() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
