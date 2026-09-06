import Foundation

public enum StrainID: String, CaseIterable, Codable, Hashable, Sendable {
    case drift
    case halo
    case cinder
    case rime
    case nyx

    public var titleKey: String { "strain.\(rawValue).title" }
    public var detailKey: String { "strain.\(rawValue).detail" }
}

/// A selectable strain: a starting effect package plus one signature rule.
public struct Strain: Equatable, Identifiable, Sendable {
    public let id: StrainID
    /// Effects the strain starts with, on top of any unlocked traits.
    public let innateEffects: TraitEffects
    /// Multiplier on daily evolution point income.
    public let pointIncomeMultiplier: Double
    /// Signature behaviour, applied by `SimulationEngine`.
    public let signature: StrainSignature
    /// Reserved for a future in-app purchase / rewarded unlock (see `AdManager`).
    public let requiresUnlock: Bool

    public init(
        id: StrainID,
        innateEffects: TraitEffects,
        pointIncomeMultiplier: Double,
        signature: StrainSignature,
        requiresUnlock: Bool
    ) {
        self.id = id
        self.innateEffects = innateEffects
        self.pointIncomeMultiplier = pointIncomeMultiplier
        self.signature = signature
        self.requiresUnlock = requiresUnlock
    }
}

/// The one special rule that makes each strain play differently.
public enum StrainSignature: String, Codable, Hashable, Sendable {
    /// No special rule — the clean baseline.
    case none
    /// Awareness decays a little every day while the strain stays quiet.
    case fadingTrail
    /// Warm bands spread faster still; cold bands bite harder.
    case heatSeeking
    /// Cold bands spread faster still; warm bands bite harder.
    case coldSeeking
    /// Gains extra points but drifts: occasionally picks up a free symptom on
    /// its own, which the player cannot choose.
    case unstable

    public var detailKey: String { "signature.\(rawValue)" }
}
