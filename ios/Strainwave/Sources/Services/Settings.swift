import Foundation

/// Small, non-game preferences. Anything the player would expect to survive a
/// reinstall lives in Core Data instead (see `ReportStore`).
enum Settings {

    private enum Key {
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let reducedMotion = "settings.reducedMotion"
        static let lastDailyPlayed = "settings.lastDailyPlayed"
        static let dailyWins = "settings.dailyWins"
        static let unlockedStrains = "settings.unlockedStrains"
        static let runsFinished = "settings.runsFinished"
    }

    private static let defaults = UserDefaults.standard

    /// Registers the values a fresh install should start with. Called once at
    /// launch so a missing key never reads as `false` by accident.
    static func registerDefaults() {
        defaults.register(defaults: [
            Key.sound: true,
            Key.haptics: true,
            Key.reducedMotion: false,
            Key.dailyWins: 0,
            Key.runsFinished: 0
        ])
    }

    static var isSoundEnabled: Bool {
        get { defaults.bool(forKey: Key.sound) }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    static var isHapticsEnabled: Bool {
        get { defaults.bool(forKey: Key.haptics) }
        set { defaults.set(newValue, forKey: Key.haptics) }
    }

    /// The player's own motion preference, on top of the system setting.
    static var prefersReducedMotion: Bool {
        get { defaults.bool(forKey: Key.reducedMotion) }
        set { defaults.set(newValue, forKey: Key.reducedMotion) }
    }

    /// `yyyy-MM-dd` of the last daily challenge the player finished.
    static var lastDailyChallengePlayed: String? {
        get { defaults.string(forKey: Key.lastDailyPlayed) }
        set { defaults.set(newValue, forKey: Key.lastDailyPlayed) }
    }

    static var dailyChallengeWins: Int {
        get { defaults.integer(forKey: Key.dailyWins) }
        set { defaults.set(newValue, forKey: Key.dailyWins) }
    }

    static var runsFinished: Int {
        get { defaults.integer(forKey: Key.runsFinished) }
        set { defaults.set(newValue, forKey: Key.runsFinished) }
    }

    /// Raw values of strains unlocked beyond the free set.
    static var unlockedStrains: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.unlockedStrains) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.unlockedStrains) }
    }

    static func reset() {
        for key in [
            Key.sound, Key.haptics, Key.reducedMotion, Key.lastDailyPlayed,
            Key.dailyWins, Key.unlockedStrains, Key.runsFinished
        ] {
            defaults.removeObject(forKey: key)
        }
        registerDefaults()
    }
}
