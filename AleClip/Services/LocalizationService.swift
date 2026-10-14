//
//  LocalizationService.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case turkish = "tr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }
}

@MainActor
public func loc(_ key: String) -> String {
    LocalizationService.shared.localizedString(key)
}

@MainActor
public func locF(_ key: String, _ arguments: CVarArg...) -> String {
    let format = LocalizationService.shared.localizedString(key)
    return String(format: format, locale: Locale.current, arguments: arguments)
}

@MainActor
public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()

    @Published public private(set) var currentLanguage: AppLanguage = .system

    private let userDefaultsKey = "selected_app_language"
    private var bundle: Bundle = .main

    private init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "system"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .system
        updateBundle()
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
        UserDefaults.standard.set(lang.rawValue, forKey: userDefaultsKey)
        updateBundle()
        objectWillChange.send()
    }

    public func setLanguage(_ rawLang: String) {
        let lang = AppLanguage(rawValue: rawLang) ?? .system
        setLanguage(lang)
    }

    public func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private func updateBundle() {
        if currentLanguage == .system {
            self.bundle = .main
            return
        }
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
        } else {
            self.bundle = .main
        }
    }
}
