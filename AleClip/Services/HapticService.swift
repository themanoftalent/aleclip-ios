import UIKit

@MainActor
public final class HapticService {
    public static let shared = HapticService()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }

    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard StorageService.shared.settings.hapticFeedback else { return }
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
        guard StorageService.shared.settings.hapticFeedback else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    public func warning() {
        guard StorageService.shared.settings.hapticFeedback else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
}
