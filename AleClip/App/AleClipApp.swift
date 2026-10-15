//
//  AleClipApp.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import SwiftUI

@main
struct AleClipApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var storage = StorageService.shared
    @StateObject private var clipboard = ClipboardService.shared
    @StateObject private var l10n = LocalizationService.shared
    @StateObject private var haptics = HapticService.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(storage)
                .environmentObject(clipboard)
                .environmentObject(l10n)
                .environmentObject(haptics)
                .tint(SpectrumColors.azure)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                clipboard.checkPasteboardOnForeground()
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "aleclip" else { return }
        
        switch url.host {
        case "paste":
            clipboard.ingestCurrentPasteboard()
        default:
            break
        }
    }
}
