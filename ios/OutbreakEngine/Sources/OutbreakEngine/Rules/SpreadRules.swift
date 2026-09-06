import Foundation

/// Rules that move the strain: growth inside a territory, and travel between
/// territories. Every function here is pure, so each one is asserted directly by
/// `SpreadRulesTests` against fixed board states.
public enum SpreadRules {

    // MARK: Tuning constants (documented so tests can reference them by name)

    /// Base logistic growth coefficient before any modifier.
    public static let baseGrowth = 0.26
    /// Growth retained inside a territory whose transport is suspended.
    public static let lockdownGrowthPenalty = 0.55
    /// Base per-day probability of a land crossing at full source saturation.
    public static let baseLandTravel = 0.060
    /// Base per-day probability of an air crossing at full source saturation.
    public static let baseAirTravel = 0.022
    /// Base per-day probability of a sea crossing at full source saturation.
    public static let baseSeaTravel = 0.016
    /// Carriers seeded into a newly reached territory, as a share of population.
    public static let seedFraction = 2e-8
    /// Daily losses as a share of carriers, per point of summed lethality.
    public static let lossRatePerLethality = 0.0035

    // MARK: Rule S1 — growth inside a territory

    /// Effective logistic coefficient for one territory on one day.
    ///
    ///     k = base
    ///       × (1 + infectivity)
    ///       × climateFactor          (climate band offset by trait tolerance)
    ///       × densityFactor          (urban / rural, offset by trait affinity)
    ///       × wealthFactor
    ///       × lockdownFactor
    ///       × difficultyFactor
    ///
    /// Clamped to `0...2` so no combination can produce a runaway step.
    public static func growthCoefficient(
        region: RegionBlueprint,
        state: RegionState,
        profile: EvolutionProfile,
        difficulty: Difficulty,
        signature: StrainSignature
    ) -> Double {
        var climateFactor = profile.climateFactor(for: region.climate)
        climateFactor *= signatureClimateMultiplier(signature, climate: region.climate)

        let coefficient = baseGrowth
            * (1 + profile.infectivity)
            * climateFactor
            * profile.densityFactor(for: region.density)
            * region.wealth.spreadMultiplier
            * (state.transportLocked ? lockdownGrowthPenalty : 1.0)
            * difficulty.spreadMultiplier

        return min(2.0, max(0, coefficient))
    }

    /// A strain signature's pull toward its preferred climate band.
    public static func signatureClimateMultiplier(
        _ signature: StrainSignature,
        climate: Climate
    ) -> Double {
        switch signature {
        case .heatSeeking:
            switch climate {
            case .tropical, .arid: return 1.25
            case .frigid: return 0.75
            case .temperate: return 1.0
            }
        case .coldSeeking:
            switch climate {
            case .frigid: return 1.30
            case .tropical: return 0.75
            case .arid: return 0.90
            case .temperate: return 1.05
            }
        case .none, .fadingTrail, .unstable:
            return 1.0
        }
    }

    /// New carriers in one territory on one day, using logistic growth over the
    /// still-healthy share. Never exceeds the healthy population.
    public static func newInfections(
        region: RegionBlueprint,
        state: RegionState,
        profile: EvolutionProfile,
        difficulty: Difficulty,
        signature: StrainSignature
    ) -> Double {
        guard state.infected > 0, state.healthy > 0 else { return 0 }
        let coefficient = growthCoefficient(
            region: region, state: state, profile: profile,
            difficulty: difficulty, signature: signature
        )
        let population = Double(state.population)
        let carriers = state.infected
        let healthyShare = state.healthy / population
        // Logistic step, plus a small floor so a single carrier still moves.
        let growth = coefficient * carriers * healthyShare
        let floor = state.infected >= 1 ? coefficient * 0.35 : 0
        return min(state.healthy, max(growth, floor))
    }

    /// Daily losses from the strain's summed lethality.
    public static func newLosses(state: RegionState, profile: EvolutionProfile) -> Double {
        guard profile.lethality > 0, state.infected > 0 else { return 0 }
        return min(state.infected, state.infected * profile.lethality * lossRatePerLethality)
    }

    // MARK: Rule S2 — travel between territories

    /// Whether a route out of (or into) a territory is usable today.
    ///
    /// Land routes need open borders on both sides; air and sea need transport
    /// running on both sides. A suspended link can still be slipped with the
    /// `borderSlip` trait — the only place `lockdownBypass` is consulted.
    public static func routeIsOpen(
        route: TravelRoute,
        source: RegionState,
        destination: RegionState,
        profile: EvolutionProfile,
        generator: inout SeededGenerator
    ) -> Bool {
        let blocked: Bool
        switch route {
        case .land:
            blocked = source.bordersClosed || destination.bordersClosed
        case .air, .sea:
            blocked = source.transportLocked || destination.transportLocked
        }
        guard blocked else { return true }
        return generator.chance(profile.lockdownBypass)
    }

    /// Per-day probability that the strain crosses one specific link.
    ///
    /// Scales with the square root of the source's saturation, so a territory
    /// starts exporting early but never dominates the board on its own.
    public static func travelProbability(
        route: TravelRoute,
        source: RegionState,
        profile: EvolutionProfile,
        scenario: StartScenario
    ) -> Double {
        guard source.infected >= 1 else { return 0 }
        let base: Double
        let traitBonus: Double
        switch route {
        case .land:
            base = baseLandTravel
            traitBonus = profile.effects.landTransmission
        case .air:
            base = baseAirTravel
            traitBonus = profile.effects.airTransmission
        case .sea:
            base = baseSeaTravel
            traitBonus = profile.effects.seaTransmission
        }
        let saturation = sqrt(source.infectedFraction)
        let probability = base * (1 + traitBonus) * saturation * scenario.travelModifier
        return min(0.85, max(0, probability))
    }

    /// Carriers seeded when the strain first reaches a territory. At least one
    /// person, so the growth rule always has something to work with.
    public static func seedCount(for population: Int) -> Double {
        max(1, Double(population) * seedFraction)
    }
}
