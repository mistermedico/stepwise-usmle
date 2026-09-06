import Foundation

/// Documented constants for the rule-based "world response" engine (spec section 3).
/// Every rule here is a plain, explicit function — no ML, no hidden weights — so each
/// one is independently unit-testable against fixed board states.
public enum WorldResponseRules {
    /// Rule 2 — Awareness update: today's awareness delta is a direct function of
    /// (infected fraction × lethality), scaled by difficulty and reduced by the
    /// pathogen's detection resistance. `awarenessGainCoefficient` is the fixed
    /// multiplier applied to that product before clamping to [0, 1].
    public static let awarenessGainCoefficient: Double = 3.2

    /// Rule 3 — Research activation threshold: once global awareness crosses this
    /// value, research begins accruing at the difficulty's fixed daily rate.
    public static let researchActivationThreshold: Double = 0.18

    /// Rule 4 — Lockdown: a region locks its borders once its own awareness crosses
    /// `DifficultyLevel.lockdownAwarenessThreshold`, unless the pathogen has unlocked
    /// a lockdown-bypass upgrade (`UpgradeEffect.bypassesLockdown`).
    /// Rule 5 — Win/lose thresholds.
    public static let victoryInfectionFraction: Double = 0.97
    public static let defeatResearchProgress: Double = 100.0

    /// Internal per-region infection growth: how fast an already-seeded region climbs
    /// toward full saturation, before transmission-rate bonuses.
    public static let baseInternalGrowthRate: Double = 0.18
}
