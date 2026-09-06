import Foundation

/// The selectable strains. Each one is a different opening hand, not a
/// different rule set — the simulation stays identical, only the numbers and a
/// single signature behaviour change.
public enum StrainCatalog {

    public static let all: [Strain] = [
        // The clean baseline. Nothing special, nothing missing.
        Strain(
            id: .drift,
            innateEffects: fx { $0.landTransmission = 0.10 },
            pointIncomeMultiplier: 1.00,
            signature: .none,
            requiresUnlock: false
        ),
        // Quiet by nature: awareness fades while the strain keeps its head down.
        Strain(
            id: .halo,
            innateEffects: fx { $0.stealth = 0.15; $0.infectivity = -0.05 },
            pointIncomeMultiplier: 0.90,
            signature: .fadingTrail,
            requiresUnlock: false
        ),
        // Thrives in the heat, struggles in the cold.
        Strain(
            id: .cinder,
            innateEffects: fx { $0.tropicalTolerance = 0.35; $0.aridTolerance = 0.30; $0.frigidTolerance = -0.20 },
            pointIncomeMultiplier: 1.00,
            signature: .heatSeeking,
            requiresUnlock: false
        ),
        // The mirror image: at home in the cold.
        Strain(
            id: .rime,
            innateEffects: fx { $0.frigidTolerance = 0.45; $0.temperateTolerance = 0.10; $0.tropicalTolerance = -0.20 },
            pointIncomeMultiplier: 1.00,
            signature: .coldSeeking,
            requiresUnlock: false
        ),
        // Rich in points but genuinely unruly — it evolves without asking.
        // Flagged for a future unlock (rewarded video today, in-app purchase later).
        Strain(
            id: .nyx,
            innateEffects: fx { $0.infectivity = 0.15; $0.visibility = 0.10 },
            pointIncomeMultiplier: 1.35,
            signature: .unstable,
            requiresUnlock: true
        )
    ]

    private static let index: [StrainID: Strain] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// Strain lookup. Every `StrainID` has exactly one definition — guarded by
    /// `StrainCatalogTests.testEveryStrainIDHasADefinition`.
    public static func strain(_ id: StrainID) -> Strain {
        guard let found = index[id] else {
            preconditionFailure("Missing strain definition for \(id.rawValue)")
        }
        return found
    }

    /// Strains playable without an unlock.
    public static var freeStrains: [Strain] { all.filter { !$0.requiresUnlock } }

    private static func fx(_ build: (inout TraitEffects) -> Void) -> TraitEffects {
        var effects = TraitEffects()
        build(&effects)
        return effects
    }
}
