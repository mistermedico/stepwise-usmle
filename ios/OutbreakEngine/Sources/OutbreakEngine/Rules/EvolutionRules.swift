import Foundation

/// Rules governing evolution point income and the collectable clusters that
/// surface on the map.
public enum EvolutionRules {

    /// Days a cluster stays on the board before it fades.
    public static let bubbleLifetime = 3
    /// Chance per infected territory, per day, of a cluster appearing.
    public static let bubbleChancePerRegion = 0.10
    /// Most clusters allowed on the board at once, so the map stays readable.
    public static let maxConcurrentBubbles = 4

    /// Points granted at the end of a day.
    ///
    ///     income = (base + perRegion × infectedRegions) × strainMultiplier
    ///
    /// Fractional income is accumulated by the caller, so a slow strain still
    /// earns steadily rather than rounding down to nothing every day.
    public static func dailyIncome(
        infectedRegions: Int,
        difficulty: Difficulty,
        strain: Strain
    ) -> Double {
        let raw = difficulty.basePointsPerDay
            + difficulty.pointsPerInfectedRegion * Double(infectedRegions)
        return max(0, raw * strain.pointIncomeMultiplier)
    }

    /// Decides whether a cluster appears today and where.
    ///
    /// Only territories that already carry the strain can host one.
    public static func spawnBubble(
        day: Int,
        infectedRegions: [RegionID],
        activeBubbles: Int,
        generator: inout SeededGenerator
    ) -> PointBubble? {
        guard activeBubbles < maxConcurrentBubbles, !infectedRegions.isEmpty else { return nil }
        let chance = min(0.6, bubbleChancePerRegion * Double(infectedRegions.count))
        guard generator.chance(chance) else { return nil }
        guard let region = generator.pick(infectedRegions) else { return nil }
        let value = generator.int(in: 2...4)
        let offset = MapPoint(
            0.30 + generator.unit() * 0.40,
            0.30 + generator.unit() * 0.40
        )
        return PointBubble(
            region: region,
            value: value,
            spawnedOnDay: day,
            expiresOnDay: day + bubbleLifetime,
            offset: offset
        )
    }

    /// Removes clusters whose time is up.
    public static func expireBubbles(_ bubbles: [PointBubble], day: Int) -> [PointBubble] {
        bubbles.filter { $0.expiresOnDay >= day }
    }

    /// The free symptom an unstable strain drifts into, if any.
    ///
    /// Only fires for `StrainSignature.unstable`, only on symptom nodes whose
    /// prerequisites are already met, and never more than once every ten days.
    public static func driftMutation(
        signature: StrainSignature,
        day: Int,
        unlocked: Set<TraitID>,
        generator: inout SeededGenerator
    ) -> TraitID? {
        guard signature == .unstable, day > 0, day % 10 == 0 else { return nil }
        let candidates = TraitCatalog.symptoms
            .filter { !unlocked.contains($0.id) }
            .filter { trait in trait.prerequisites.allSatisfy { unlocked.contains($0) } }
            .map(\.id)
        guard !candidates.isEmpty else { return nil }
        return generator.pick(candidates)
    }
}
