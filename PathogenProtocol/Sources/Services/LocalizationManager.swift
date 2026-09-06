import Foundation
import SwiftUI

/// The two shipping languages (spec section 6). Region names in `WorldScenario` are
/// localized in both via `Localizable.strings`, never hardcoded to a single language.
public enum AppLanguage: String, CaseIterable, Identifiable, Equatable {
    case english = "en"
    case hebrew = "he"

    public var id: String { rawValue }

    public var layoutDirection: LayoutDirection {
        self == .hebrew ? .rightToLeft : .leftToRight
    }

    public var displayNameKey: String {
        switch self {
        case .english: return "language.english"
        case .hebrew: return "language.hebrew"
        }
    }
}

/// Detects the system language at launch (spec: automatic detection by device region)
/// and exposes the resulting layout direction for the root view to apply.
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage

    private init() {
        let preferred = Locale.preferredLanguages.first ?? "en"
        currentLanguage = preferred.hasPrefix("he") ? .hebrew : .english
    }

    /// Explicit override for a future in-app language switcher; not required at launch
    /// since detection is automatic, but wired up for completeness.
    public func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}
