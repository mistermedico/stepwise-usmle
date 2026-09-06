import AudioToolbox
import Foundation

/// Short UI feedback sounds using the built-in iOS system sound bank (`AudioServicesPlaySystemSound`),
/// so the app needs zero bundled audio assets. System sound IDs below are documented, stable
/// iOS system sounds (the same bank Messages/Mail/etc use for "Tock", "Tweet Sent", etc).
final class SoundManager {
    static let shared = SoundManager()

    enum Effect {
        /// A single cell gets filled correctly — short, unobtrusive tick.
        case cellFill
        /// A cell gets filled incorrectly (a mistake) — a low, negative buzz.
        case wrongFill
        /// A row or column is completed and its clue strikes through — a bright little chime.
        case lineComplete
        /// The whole puzzle is solved — a fuller "success" fanfare.
        case levelComplete
        /// Generic light UI tap (mode toggle, booster button, navigation).
        case uiTap

        /// Standard iOS system sound IDs. See AudioServicesPlaySystemSound docs / the well-known
        /// community-catalogued list of `/System/Library/Audio/UISounds` IDs.
        var systemSoundID: SystemSoundID {
            switch self {
            case .cellFill: return 1104        // "Tock" — a soft, short keyboard-tock-style tick
            case .wrongFill: return 1053        // "Tink"-adjacent low negative tone used for errors
            case .lineComplete: return 1057        // "Tweet Sent"-style bright short chime
            case .levelComplete: return 1025        // "Fanfare"-style triumphant multi-tone
            case .uiTap: return 1105        // "Tock" variant, very light, for generic taps
            }
        }
    }

    private let defaults: UserDefaults
    private let soundEnabledKey = "com.nonogram.settings.soundEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persisted sound on/off toggle, exposed for `SettingsView`. Defaults to enabled.
    var soundEnabled: Bool {
        get { defaults.object(forKey: soundEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: soundEnabledKey) }
    }

    func play(_ effect: Effect) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }
}
