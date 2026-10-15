//
//  HapticService.swift
//  AleClip
//
//  Created for AleClip iOS v2.0.1 (2026).
//  Copyright © 2026 AleClip. All rights reserved.
//

import UIKit
import SwiftUI

@MainActor
public final class HapticService: ObservableObject {
    public static let shared = HapticService()

    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "aleclip_haptics_enabled")
        }
    }

    public enum ImpactStyle {
        case light
        case medium
        case heavy
        case selection
    }

    public enum NotificationType {
        case success
        case warning
        case error
    }

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "aleclip_haptics_enabled") as? Bool ?? true
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    public func trigger(_ style: ImpactStyle) {
        guard isEnabled else { return }
        switch style {
        case .light:
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        case .selection:
            selectionGenerator.selectionChanged()
        }
    }

    public func notify(_ type: NotificationType) {
        guard isEnabled else { return }
        switch type {
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    public func copied() {
        trigger(.light)
    }

    // Backward compatibility methods
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        switch style {
        case .light:
            lightGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        default:
            mediumGenerator.impactOccurred()
        }
    }

    public func success() {
        notify(.success)
    }

    public func warning() {
        notify(.warning)
    }
}
