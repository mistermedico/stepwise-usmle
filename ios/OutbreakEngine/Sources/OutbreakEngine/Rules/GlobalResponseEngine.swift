import Foundation

/// The opponent: a rule-based "global response".
///
/// This is an explicit decision tree over the visible board — plain conditionals
/// and closed-form arithmetic. There is no model, no training, and no
/// randomness anywhere in rules 1–3 and 5; rule 4 consults the generator only to
/// resolve the player's own `borderSlip` trait.
///
/// The five rules, in the order they run each day:
///
/// 1. `assess`        — read the visible board.
/// 2. `awarenessDelta` — awareness grows with carriers × how loud the strain is.
/// 3. `researchDelta`  — past an awareness threshold, research accrues at a fixed rate.
/// 4. `restrictions`   — regional awareness thresholds suspend transport, then borders.
/// 5. `solutionDay`    — a fixed, pre-computable completion day, never a dice roll.
public enum GlobalResponseEngine {

    // MARK: Tuning constants

    /// Awareness gained per day at full saturation with a silent strain.
    public static let awarenessGain = 4.6
    /// Awareness lost per day in a territory with no carriers left.
    public static let awarenessDecay = 0.55
    /// Extra decay applied by the `fadingTrail` signature.
    public static let fadingTrailDecay = 0.45
    /// Ceiling on a single day's awareness movement, so nothing spikes.
    public static let maxAwarenessStep = 8.0
    /// Global awareness at which the strain is considered noticed at all.
    public static let detectionAwareness = 1.0
    /// Research points that constitute a finished solution.
    public static let solutionTarget = 100.0

    // MARK: Rule 1 — visible assessment

    /// What the response can actually see. Notably it reads *carriers* and
    /// *losses*, never the player's trait list.
    public struct Assessment: Equatable, Sendable {
        public let infectedRegions: Int
        public let saturatedRegions: Int
        public let visibleLethality: Double
        public let globalAwareness: Double
        public let researchProgress: Double

        public init(
            infectedRegions: Int,
            saturatedRegions: Int,
            visibleLethality: Double,
            globalAwareness: Double,
            researchProgress: Double
        ) {
            self.infectedRegions = infectedRegions
            self.saturatedRegions = saturatedRegions
            self.visibleLethality = visibleLethality
            self.globalAwareness = globalAwareness
            self.researchProgress = researchProgress
        }
    }

    public static func assess(_ state: GameState) -> Assessment {
        let infected = state.regions.values.filter(\.isInfected).count
        let saturated = state.regions.values.filter(\.isSaturated).count
        let carriers = state.totalInfected
        let losses = state.totalLost
        // Losses relative to everyone touched — the only lethality signal visible
        // from outside the strain.
        let visibleLethality = (carriers + losses) > 0 ? losses / (carriers + losses) : 0
        return Assessment(
            infectedRegions: infected,
            saturatedRegions: saturated,
            visibleLethality: visibleLethality,
            globalAwareness: state.globalAwareness,
            researchProgress: state.researchProgress
        )
    }

    // MARK: Rule 2 — awareness

    /// Awareness movement for one territory on one day.
    ///
    ///     Δ = gain × infectedFraction × (1 + visibilityScore)
    ///           × wealthMultiplier × difficultyMultiplier × scenarioModifier
    ///           × (1 − stealth)
    ///
    /// With no carriers present the territory instead cools by `awarenessDecay`
    /// (plus `fadingTrailDecay` for the Halo signature). The result is clamped
    /// to ±`maxAwarenessStep`.
    public static func awarenessDelta(
        region: RegionBlueprint,
        state: RegionState,
        profile: EvolutionProfile,
        difficulty: Difficulty,
        scenario: StartScenario,
        signature: StrainSignature
    ) -> Double {
        guard state.infected >= 1 else {
            var decay = -awarenessDecay
            if signature == .fadingTrail { decay -= fadingTrailDecay }
            return max(-maxAwarenessStep, decay)
        }

        let raw = awarenessGain
            * state.infectedFraction
            * (1 + profile.visibilityScore)
            * region.wealth.awarenessMultiplier
            * difficulty.awarenessMultiplier
            * scenario.awarenessModifier
            * (1 - profile.stealth)

        let adjusted = signature == .fadingTrail ? raw - fadingTrailDecay * 0.5 : raw
        return min(maxAwarenessStep, max(-maxAwarenessStep, adjusted))
    }

    /// Population-weighted global awareness, `0...100`.
    public static func globalAwareness(regions: [RegionID: RegionState]) -> Double {
        var weighted = 0.0
        var totalPopulation = 0.0
        for state in regions.values {
            weighted += state.awareness * Double(state.population)
            totalPopulation += Double(state.population)
        }
        guard totalPopulation > 0 else { return 0 }
        return min(100, max(0, weighted / totalPopulation))
    }

    // MARK: Rule 3 — research

    /// Research points added today.
    ///
    /// Zero until global awareness reaches `difficulty.researchThreshold`. After
    /// that it is a fixed daily rate scaled by how much of the world is involved
    /// and by how wealthy the affected territories are, then damped by the
    /// strain's `researchResistance`:
    ///
    ///     Δ = rate × (0.5 + 0.5 × laboratoryWeight) × (1 − researchResistance)
    ///
    /// It never depends on the day counter or on the generator, which is what
    /// makes rule 5 predictable.
    public static func researchDelta(
        regions: [RegionID: RegionState],
        globalAwareness: Double,
        profile: EvolutionProfile,
        difficulty: Difficulty
    ) -> Double {
        guard globalAwareness >= difficulty.researchThreshold else { return 0 }
        let weight = laboratoryWeight(regions: regions)
        let delta = difficulty.researchRatePerDay
            * (0.5 + 0.5 * weight)
            * (1 - profile.researchResistance)
        return max(0, delta)
    }

    /// Share of the world's laboratory capacity that has seen the strain, `0...1`.
    /// Affluent territories carry more weight — the trade-off that makes hiding
    /// in developing territories a real strategy.
    public static func laboratoryWeight(regions: [RegionID: RegionState]) -> Double {
        var engaged = 0.0
        var total = 0.0
        for blueprint in RegionCatalog.all {
            let capacity = Double(blueprint.population) * blueprint.wealth.researchWeight
            total += capacity
            if let state = regions[blueprint.id], state.isInfected {
                engaged += capacity
            }
        }
        guard total > 0 else { return 0 }
        return min(1, engaged / total)
    }

    // MARK: Rule 4 — restrictions

    /// What the response does to one territory's transport links today.
    public enum Restriction: Equatable, Sendable {
        case none
        case lockTransport
        case closeBorders
        case lift
    }

    /// Pure decision for one territory. Deterministic apart from the single
    /// `borderSlip` roll, which is the player's own trait resisting the order.
    public static func restriction(
        state: RegionState,
        profile: EvolutionProfile,
        difficulty: Difficulty,
        generator: inout SeededGenerator
    ) -> Restriction {
        let awareness = state.awareness

        if awareness >= difficulty.borderClosureThreshold, !state.bordersClosed {
            if generator.chance(profile.lockdownBypass * 0.5) { return .none }
            return .closeBorders
        }
        if awareness >= difficulty.lockdownThreshold, !state.transportLocked {
            if generator.chance(profile.lockdownBypass * 0.5) { return .none }
            return .lockTransport
        }
        if state.transportLocked,
           awareness < difficulty.lockdownThreshold - difficulty.lockdownReleaseMargin {
            return .lift
        }
        return .none
    }

    /// Whether a territory is close enough to its threshold to warrant the amber
    /// warning on the map (section 4: the player gets a visual window to react).
    public static func isRestrictionImminent(
        state: RegionState,
        difficulty: Difficulty
    ) -> Bool {
        guard !state.transportLocked else { return false }
        let distance = difficulty.lockdownThreshold - state.awareness
        return distance > 0 && distance <= 8
    }

    // MARK: Rule 5 — the solution date

    /// The day the response finishes a solution, assuming today's research rate
    /// holds. Fixed arithmetic, never a dice roll — so the player can always see
    /// the countdown and plan against it.
    ///
    /// Returns `nil` while no research is accruing (there is no deadline yet).
    public static func projectedSolutionDay(_ state: GameState) -> Int? {
        let dailyRate = researchDelta(
            regions: state.regions,
            globalAwareness: state.globalAwareness,
            profile: state.profile,
            difficulty: state.setup.difficulty
        )
        guard dailyRate > 0 else { return nil }
        let remaining = max(0, solutionTarget - state.researchProgress)
        let daysLeft = Int((remaining / dailyRate).rounded(.up))
        return state.day + daysLeft
    }

    /// Days remaining before a solution lands at today's rate, or `nil` when no
    /// research is under way.
    public static func daysUntilSolution(_ state: GameState) -> Int? {
        guard let day = projectedSolutionDay(state) else { return nil }
        return max(0, day - state.day)
    }
}
