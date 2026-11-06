//
//  ClipItem.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Color Extension for HEX Support

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 240, 255) // Default to Electric Cyan
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ClipType

public enum ClipType: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case html
    case image
    case link
    case file
    case color

    @MainActor
    public var displayName: String {
        switch self {
        case .text: return loc("filter.text")
        case .richText: return loc("filter.text")
        case .html: return "HTML"
        case .image: return loc("filter.images")
        case .link: return loc("filter.links")
        case .file: return loc("filter.files")
        case .color: return loc("filter.colors")
        }
    }

    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .richText: return "text.quote"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "folder"
        case .color: return "paintpalette"
        }
    }

    public var systemImage: String { iconName }

    public var accentColor: Color {
        switch self {
        case .text: return Color(red: 0.05, green: 0.52, blue: 1.00) // Cobalt Azure
        case .richText: return Color(red: 0.12, green: 0.82, blue: 0.38)
        case .html: return Color(red: 0.00, green: 0.90, blue: 0.65) // Neon Mint
        case .image: return Color(red: 0.64, green: 0.90, blue: 0.10) // Electric Lime
        case .link: return Color(red: 0.00, green: 0.88, blue: 1.00) // Electric Cyan
        case .file: return Color(red: 1.00, green: 0.78, blue: 0.00) // Gold
        case .color: return Color(red: 1.00, green: 0.44, blue: 0.00) // Tangerine - NO PINK!
        }
    }

    public var color: Color { accentColor }
}

// MARK: - ClipItem

public struct ClipItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var type: ClipType
    public var plainText: String
    public var htmlContent: String?
    public var rtfData: Data?
    public var imageFileName: String?
    public var url: String?
    public var colorHex: String?
    public var title: String?
    public var sourceAppName: String?
    public var createdAt: Date
    public var lastUsedAt: Date
    public var isPinned: Bool
    public var contentHash: String
    /// Which device captured the clip ("Mac", "iPhone", "Android"). Shared via sync.
    public var sourceDevice: String?

    enum CodingKeys: String, CodingKey {
        case id, type, plainText, htmlContent, rtfData, imageFileName, url, colorHex
        case title, sourceAppName, createdAt, lastUsedAt, isPinned, contentHash, sourceDevice
    }

    /// Tolerant decoding so clips synced from the Mac or Android always load:
    /// missing fields get defaults and unknown types (e.g. Mac "code") become plain text.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        let rawType = (try? c.decode(String.self, forKey: .type)) ?? "text"
        self.type = ClipType(rawValue: rawType) ?? .text
        self.plainText = (try? c.decode(String.self, forKey: .plainText)) ?? ""
        self.htmlContent = try? c.decodeIfPresent(String.self, forKey: .htmlContent)
        self.rtfData = try? c.decodeIfPresent(Data.self, forKey: .rtfData)
        self.imageFileName = try? c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.url = try? c.decodeIfPresent(String.self, forKey: .url)
        self.colorHex = try? c.decodeIfPresent(String.self, forKey: .colorHex)
        self.title = try? c.decodeIfPresent(String.self, forKey: .title)
        self.sourceAppName = try? c.decodeIfPresent(String.self, forKey: .sourceAppName)
        self.createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        self.lastUsedAt = (try? c.decode(Date.self, forKey: .lastUsedAt)) ?? self.createdAt
        self.isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        self.contentHash = (try? c.decode(String.self, forKey: .contentHash)) ?? UUID().uuidString
        self.sourceDevice = try? c.decodeIfPresent(String.self, forKey: .sourceDevice)
    }

    // Convenient aliases
    public var content: String {
        get { plainText }
        set { plainText = newValue }
    }

    public var formattedTime: String { relativeTimeString }
    public var imagePath: String? { imageFileName }
    public var imageData: Data? { nil }

    public init(
        id: UUID = UUID(),
        type: ClipType,
        plainText: String,
        htmlContent: String? = nil,
        rtfData: Data? = nil,
        imageFileName: String? = nil,
        url: String? = nil,
        colorHex: String? = nil,
        title: String? = nil,
        sourceAppName: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        isPinned: Bool = false,
        contentHash: String = UUID().uuidString,
        sourceDevice: String? = "iPhone"
    ) {
        self.sourceDevice = sourceDevice
        self.id = id
        self.type = type
        self.plainText = plainText
        self.htmlContent = htmlContent
        self.rtfData = rtfData
        self.imageFileName = imageFileName
        self.url = url
        self.colorHex = colorHex
        self.title = title
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.contentHash = contentHash
    }

    public var displayTitle: String {
        if let customTitle = title, !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customTitle
        }
        switch type {
        case .color:
            return colorHex ?? "Color"
        case .file:
            if let url = url, let lastComp = URL(string: url)?.lastPathComponent {
                return lastComp
            }
            return plainText
        case .link:
            return url ?? plainText
        default:
            let firstLine = plainText.components(separatedBy: .newlines).first ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Clip" : trimmed
        }
    }

    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if let title = title, title.localizedStandardContains(trimmed) { return true }
        if plainText.localizedStandardContains(trimmed) { return true }
        if let url = url, url.localizedStandardContains(trimmed) { return true }
        if let colorHex = colorHex, colorHex.localizedStandardContains(trimmed) { return true }
        if let appName = sourceAppName, appName.localizedStandardContains(trimmed) { return true }
        return false
    }
}
