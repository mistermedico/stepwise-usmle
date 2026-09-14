import Foundation
import AudioToolbox

/// Every game event that plays a sound + haptic pair. Kept as an enum so call sites
/// stay declarative (`SoundManager.shared.play(.upgradeUnlocked)`).
public enum GameSound {
    case ambientPulse
    case upgradeUnlocked
    case awarenessSpike
    case victory
    case defeat
}

/// Uses built-in iOS system sound IDs — no bundled audio assets required — paired with
/// `HapticManager` for every event, per spec section 5. A single `isMuted` toggle
/// covers a future settings screen.
public final class SoundManager {
    public static let shared = SoundManager()

    public var isMuted: Bool = false

    private init() {}

    // Standard iOS system sound IDs (AudioToolbox), chosen for a light, non-alarming feel.
    private enum SystemSoundID_: SystemSoundID {
        case tock = 1104
        case tink = 1103
        case anticipate = 1020
        case success = 1025
        case fadeOut = 1021
    }

    public func play(_ sound: GameSound) {
        switch sound {
        case .ambientPulse:
            HapticManager.shared.ambientPulse()
        case .upgradeUnlocked:
            playSystemSound(.tink)
            HapticManager.shared.upgradeUnlocked()
        case .awarenessSpike:
            playSystemSound(.anticipate)
            HapticManager.shared.awarenessSpike()
        case .victory:
            playSystemSound(.success)
            HapticManager.shared.victory()
        case .defeat:
            playSystemSound(.fadeOut)
            HapticManager.shared.defeat()
        }
    }

    private func playSystemSound(_ id: SystemSoundID_) {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(id.rawValue)
    }
}
