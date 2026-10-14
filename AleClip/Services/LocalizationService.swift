import Foundation
import SwiftUI

public func loc(_ key: String) -> String {
    LocalizationService.shared.localizedString(key)
}

public func locF(_ key: String, _ arguments: CVarArg...) -> String {
    let format = LocalizationService.shared.localizedString(key)
    return String(format: format, locale: Locale.current, arguments: arguments)
}

@MainActor
public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()

    @Published public private(set) var currentLanguage: String = "system"

    private let userDefaultsKey = "selected_app_language"
    private var bundle: Bundle = .main

    private init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "system"
        self.currentLanguage = saved
        updateBundle()
    }

    public func setLanguage(_ lang: String) {
        self.currentLanguage = lang
        UserDefaults.standard.set(lang, forKey: userDefaultsKey)
        updateBundle()
        objectWillChange.send()
    }

    public func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private func updateBundle() {
        if currentLanguage == "system" {
            self.bundle = .main
            return
        }
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
        } else {
            self.bundle = .main
        }
    }
}
