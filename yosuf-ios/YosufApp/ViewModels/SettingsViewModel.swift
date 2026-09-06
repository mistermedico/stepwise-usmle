import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    private let defaults = UserDefaults.standard
    private enum Key {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
        static let tableHints = "settings.tableHintsEnabled"
        static let cardSkin = "settings.cardSkin"
    }

    @Published var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: Key.sound)
            SoundManager.shared.isEnabled = soundEnabled
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Key.haptics)
            HapticsManager.shared.isEnabled = hapticsEnabled
        }
    }

    @Published var tableHintsEnabled: Bool {
        didSet { defaults.set(tableHintsEnabled, forKey: Key.tableHints) }
    }

    @Published var cardSkin: CardSkin {
        didSet { defaults.set(cardSkin.rawValue, forKey: Key.cardSkin) }
    }

    init() {
        let defaults = UserDefaults.standard
        let sound = defaults.object(forKey: Key.sound) as? Bool ?? true
        let haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
        let hints = defaults.object(forKey: Key.tableHints) as? Bool ?? true
        let skin = (defaults.string(forKey: Key.cardSkin)).flatMap(CardSkin.init(rawValue:)) ?? .classic

        soundEnabled = sound
        hapticsEnabled = haptics
        tableHintsEnabled = hints
        cardSkin = skin

        SoundManager.shared.isEnabled = sound
        HapticsManager.shared.isEnabled = haptics
    }
}
