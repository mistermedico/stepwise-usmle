import Foundation

/// The three branches of the ability map.
public enum TraitCategory: String, CaseIterable, Codable, Hashable, Sendable {
    /// How the strain travels.
    case transmission
    /// How the strain avoids notice and resists counter-measures.
    case resilience
    /// What the strain does — the lethality vs. spreadability trade-off.
    case symptoms

    public var localizationKey: String { "trait.category.\(rawValue)" }
}

public enum TraitID: String, CaseIterable, Codable, Hashable, Sendable {
    // Transmission
    case contactBloomI, contactBloomII
    case aerosolI, aerosolII
    case hydrophileI, hydrophileII
    case swarmVector, migratoryVector, herdVector, denseBloom
    // Resilience
    case cryoCoatI, cryoCoatII
    case thermalShellI, thermalShellII
    case mimicryI, mimicryII
    case driftCodingI, driftCodingII
    case borderSlip, environmentalHardening
    // Symptoms
    case lethargy, chromaticFlush, resonantCough, silentShedding
    case microTremor, spectralFever, neuralBloom
    case systemicCascade, totalCollapse, dormancy

    public var titleKey: String { "trait.\(rawValue).title" }
    public var detailKey: String { "trait.\(rawValue).detail" }
}

/// Additive modifiers contributed by a single trait. Effects from every unlocked
/// trait are summed into an `EvolutionProfile` once per simulated day.
public struct TraitEffects: Equatable, Sendable {
    public var landTransmission: Double = 0
    public var airTransmission: Double = 0
    public var seaTransmission: Double = 0
    /// Extra spread inside urban territories.
    public var urbanAffinity: Double = 0
    /// Extra spread inside rural territories.
    public var ruralAffinity: Double = 0
    /// Per-climate tolerance that offsets `Climate.baseSpreadModifier`.
    public var frigidTolerance: Double = 0
    public var aridTolerance: Double = 0
    public var tropicalTolerance: Double = 0
    public var temperateTolerance: Double = 0
    /// General in-territory infectivity.
    public var infectivity: Double = 0
    /// Drives losses. Also raises how visible the strain is.
    public var lethality: Double = 0
    /// Raises awareness growth — the price of a strong symptom.
    public var visibility: Double = 0
    /// Multiplicative damping of awareness growth, summed then clamped to `0...0.85`.
    public var stealth: Double = 0
    /// Multiplicative damping of research progress, summed then clamped to `0...0.75`.
    public var researchResistance: Double = 0
    /// Probability of slipping through a suspended transport link.
    public var lockdownBypass: Double = 0

    public init() {}

    /// Tolerance lookup used by the spread rule.
    public func tolerance(for climate: Climate) -> Double {
        switch climate {
        case .frigid: return frigidTolerance
        case .arid: return aridTolerance
        case .tropical: return tropicalTolerance
        case .temperate: return temperateTolerance
        }
    }

    public static func + (lhs: TraitEffects, rhs: TraitEffects) -> TraitEffects {
        var result = TraitEffects()
        result.landTransmission = lhs.landTransmission + rhs.landTransmission
        result.airTransmission = lhs.airTransmission + rhs.airTransmission
        result.seaTransmission = lhs.seaTransmission + rhs.seaTransmission
        result.urbanAffinity = lhs.urbanAffinity + rhs.urbanAffinity
        result.ruralAffinity = lhs.ruralAffinity + rhs.ruralAffinity
        result.frigidTolerance = lhs.frigidTolerance + rhs.frigidTolerance
        result.aridTolerance = lhs.aridTolerance + rhs.aridTolerance
        result.tropicalTolerance = lhs.tropicalTolerance + rhs.tropicalTolerance
        result.temperateTolerance = lhs.temperateTolerance + rhs.temperateTolerance
        result.infectivity = lhs.infectivity + rhs.infectivity
        result.lethality = lhs.lethality + rhs.lethality
        result.visibility = lhs.visibility + rhs.visibility
        result.stealth = lhs.stealth + rhs.stealth
        result.researchResistance = lhs.researchResistance + rhs.researchResistance
        result.lockdownBypass = lhs.lockdownBypass + rhs.lockdownBypass
        return result
    }
}

/// One node on the ability map.
public struct Trait: Equatable, Identifiable, Sendable {
    public let id: TraitID
    public let category: TraitCategory
    public let cost: Int
    /// Every prerequisite must be unlocked before this node opens.
    public let prerequisites: [TraitID]
    public let effects: TraitEffects
    /// Node position inside its branch, normalised `0...1` in both axes.
    public let mapPosition: MapPoint

    public init(
        id: TraitID,
        category: TraitCategory,
        cost: Int,
        prerequisites: [TraitID],
        effects: TraitEffects,
        mapPosition: MapPoint
    ) {
        self.id = id
        self.category = category
        self.cost = cost
        self.prerequisites = prerequisites
        self.effects = effects
        self.mapPosition = mapPosition
    }

    /// Points returned when the node is folded back. Rounded up so devolving is
    /// never free but never punitive either.
    public var refund: Int { Int((Double(cost) * 0.6).rounded(.up)) }
}

/// Summed, clamped view of everything the strain currently is.
public struct EvolutionProfile: Equatable, Sendable {
    public let effects: TraitEffects

    public init(effects: TraitEffects) {
        self.effects = effects
    }

    public var stealth: Double { min(0.85, max(0, effects.stealth)) }
    public var researchResistance: Double { min(0.75, max(0, effects.researchResistance)) }
    public var lockdownBypass: Double { min(0.9, max(0, effects.lockdownBypass)) }
    public var lethality: Double { max(0, effects.lethality) }
    public var infectivity: Double { max(0, effects.infectivity) }

    /// How loud the strain is before stealth is applied. Feeds the awareness rule.
    public var visibilityScore: Double {
        max(0, effects.visibility + effects.lethality * 0.5)
    }

    public func climateFactor(for climate: Climate) -> Double {
        let raw = 1.0 + climate.baseSpreadModifier + effects.tolerance(for: climate)
        return min(2.5, max(0.05, raw))
    }

    public func densityFactor(for density: Density) -> Double {
        let affinity = density == .urban ? effects.urbanAffinity : effects.ruralAffinity
        return max(0.2, density.spreadMultiplier + affinity)
    }
}
