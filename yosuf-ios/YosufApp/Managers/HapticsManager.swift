import UIKit

/// Thin wrapper around UIKit's feedback generators so views never talk to
/// UIFeedbackGenerator directly — one place to disable haptics for
/// accessibility/settings, one place to tune intensities.
final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    var isEnabled = true

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    func dealCard() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.6)
    }

    func discard() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// A short escalating pulse used right before a Yosuf reveal, building tension.
    func preRevealPulse() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.7)
    }

    func yosufWin() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func asafCaught() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    func rankUp() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    func prepareAll() {
        guard isEnabled else { return }
        [impactLight, impactMedium, impactHeavy].forEach { $0.prepare() }
        notification.prepare()
        selection.prepare()
    }
}
