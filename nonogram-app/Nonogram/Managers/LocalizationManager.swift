import Foundation
import SwiftUI

/// The app supports two languages (en/he) with a manual in-app override that takes priority
/// over the system locale, so a Hebrew-speaking user on an English phone (or vice versa) can
/// still pick their preferred in-game language from Settings.
enum AppLanguageOverride: String, CaseIterable, Identifiable {
    case system
    case en
    case he

    var id: String { rawValue }

    var displayName: LocalizedText {
        switch self {
        case .system: return LocalizedText(en: "System", he: "מערכת")
        case .en: return LocalizedText(en: "English", he: "אנגלית")
        case .he: return LocalizedText(en: "Hebrew", he: "עברית")
        }
    }
}

/// Publishes the effective app language code ("en"/"he"), combining the manual override
/// (if any) with the system locale, so views can call `LocalizedText.localized(for:)` and
/// react live when the user changes the override in Settings.
final class LocalizationManager: ObservableObject {
    private let defaults: UserDefaults
    private let overrideKey = "com.nonogram.settings.languageOverride"

    @Published private(set) var languageCode: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.languageCode = LocalizationManager.resolveLanguageCode(
            override: LocalizationManager.readOverride(defaults: defaults)
        )
    }

    var override: AppLanguageOverride {
        get { LocalizationManager.readOverride(defaults: defaults) }
        set {
            defaults.set(newValue.rawValue, forKey: overrideKey)
            languageCode = LocalizationManager.resolveLanguageCode(override: newValue)
        }
    }

    /// SwiftUI layout direction to force on the root environment. The puzzle board itself
    /// always opts back out to `.leftToRight` regardless of this (see `BoardView`).
    var layoutDirection: LayoutDirection {
        languageCode.hasPrefix("he") ? .rightToLeft : .leftToRight
    }

    private static func readOverride(defaults: UserDefaults) -> AppLanguageOverride {
        guard let raw = defaults.string(forKey: "com.nonogram.settings.languageOverride"),
              let value = AppLanguageOverride(rawValue: raw) else {
            return .system
        }
        return value
    }

    private static func resolveLanguageCode(override: AppLanguageOverride) -> String {
        switch override {
        case .en: return "en"
        case .he: return "he"
        case .system:
            let preferred = Bundle.main.preferredLocalizations.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
            return preferred.hasPrefix("he") ? "he" : "en"
        }
    }
}
