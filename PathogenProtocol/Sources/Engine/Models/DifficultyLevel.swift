import Foundation

/// Difficulty presets. Names shown to players are localized separately
/// (see Localizable.strings: "difficulty.mild" / "difficulty.challenging" / "difficulty.lethal").
public enum DifficultyLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case mild
    case challenging
    case lethal

    public var id: String { rawValue }

    /// Multiplies how fast global awareness climbs from visible infection/lethality.
    public var awarenessGrowthMultiplier: Double {
        switch self {
        case .mild: return 0.7
        case .challenging: return 1.0
        case .lethal: return 1.4
        }
    }

    /// Fixed research points accrued per day once research has activated
    /// (see `WorldResponseRules.researchActivationThreshold`). Constant, not random,
    /// so the cure day can always be computed in advance.
    public var dailyResearchRate: Double {
        switch self {
        case .mild: return 3.0
        case .challenging: return 2.0
        case .lethal: return 1.35
        }
    }

    /// Total research points required to complete a cure.
    public var researchCompletionThreshold: Double { 100.0 }

    /// Base evolution points earned per day, before strain/upgrade modifiers.
    public var baseEvolutionPointsPerDay: Double {
        switch self {
        case .mild: return 3.0
        case .challenging: return 2.4
        case .lethal: return 2.0
        }
    }

    /// Regional awareness level above which a lockdown rule fires (see `WorldResponseEngine`).
    public var lockdownAwarenessThreshold: Double {
        switch self {
        case .mild: return 0.75
        case .challenging: return 0.6
        case .lethal: return 0.5
        }
    }
}
