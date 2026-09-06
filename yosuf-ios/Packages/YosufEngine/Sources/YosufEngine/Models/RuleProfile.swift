import Foundation

/// The five ready-made rule presets, plus a user-tunable custom slot.
/// All numeric values live here so the engine never hard-codes a magic
/// number — every knob is visible and swappable in one place.
public struct RuleProfile: Identifiable, Equatable, Codable, Sendable {
    public enum ProfileKind: String, Codable, Sendable, CaseIterable, Hashable {
        case classic
        case quick
        case grandma
        case street
        case custom
    }

    public let id: ProfileKind
    /// Hand total at or below which a player may declare "Yosuf!".
    public var yosufThreshold: Int
    /// Points added to the caller's score when someone successfully calls "Asaf!" on them.
    public var asafPenalty: Int
    /// Score at which a player is eliminated / the match ends.
    public var maxScore: Int
    /// Aces count as 15 instead of 1 (a common "house rule" variant).
    public var aceHigh: Bool
    /// Minimum cards required to form a set or run.
    public var minMeldSize: Int
    /// Whether "party" event cards are active for this profile.
    public var eventCardsEnabled: Bool
    /// A caller who ties the Asaf-challenger's hand still loses the tie (strict Yaniv rule).
    public var tieFavorsChallenger: Bool
    public var displayName: String
    public var displayNameKey: String
    public var descriptionKey: String

    public static let classic = RuleProfile(
        id: .classic, yosufThreshold: 7, asafPenalty: 30, maxScore: 100,
        aceHigh: false, minMeldSize: 3, eventCardsEnabled: false,
        tieFavorsChallenger: true, displayName: "קלאסי",
        displayNameKey: "rules.classic.name", descriptionKey: "rules.classic.description"
    )

    public static let quick = RuleProfile(
        id: .quick, yosufThreshold: 7, asafPenalty: 20, maxScore: 50,
        aceHigh: false, minMeldSize: 3, eventCardsEnabled: false,
        tieFavorsChallenger: true, displayName: "מהיר",
        displayNameKey: "rules.quick.name", descriptionKey: "rules.quick.description"
    )

    public static let grandma = RuleProfile(
        id: .grandma, yosufThreshold: 5, asafPenalty: 40, maxScore: 150,
        aceHigh: true, minMeldSize: 3, eventCardsEnabled: false,
        tieFavorsChallenger: true, displayName: "חוקי סבתא",
        displayNameKey: "rules.grandma.name", descriptionKey: "rules.grandma.description"
    )

    public static let street = RuleProfile(
        id: .street, yosufThreshold: 7, asafPenalty: 30, maxScore: 100,
        aceHigh: false, minMeldSize: 3, eventCardsEnabled: true,
        tieFavorsChallenger: true, displayName: "רחוב",
        displayNameKey: "rules.street.name", descriptionKey: "rules.street.description"
    )

    public static let defaultCustom = RuleProfile(
        id: .custom, yosufThreshold: 7, asafPenalty: 30, maxScore: 100,
        aceHigh: false, minMeldSize: 3, eventCardsEnabled: false,
        tieFavorsChallenger: true, displayName: "מותאם אישית",
        displayNameKey: "rules.custom.name", descriptionKey: "rules.custom.description"
    )

    public static let allPresets: [RuleProfile] = [.classic, .quick, .grandma, .street, .defaultCustom]

    /// Clamps user-entered custom values to sane, non-degenerate ranges.
    public func clamped() -> RuleProfile {
        var copy = self
        copy.yosufThreshold = max(0, min(yosufThreshold, 50))
        copy.asafPenalty = max(0, min(asafPenalty, 100))
        copy.maxScore = max(copy.asafPenalty + 10, min(maxScore, 500))
        copy.minMeldSize = max(3, min(minMeldSize, 5))
        return copy
    }
}
