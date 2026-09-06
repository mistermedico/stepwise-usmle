import Foundation

/// The ability map: thirty nodes across three branches.
///
/// Positions are normalised inside each branch (`0...1` in both axes) so the
/// renderer can lay the branch out at any size. Tier 0 sits at the top.
public enum TraitCatalog {

    public static let all: [Trait] = transmission + resilience + symptoms

    // MARK: Transmission — how the strain travels

    public static let transmission: [Trait] = [
        Trait(id: .contactBloomI, category: .transmission, cost: 5, prerequisites: [],
              effects: fx { $0.landTransmission = 0.50 },
              mapPosition: MapPoint(0.20, 0.08)),
        Trait(id: .aerosolI, category: .transmission, cost: 8, prerequisites: [],
              effects: fx { $0.airTransmission = 0.60; $0.infectivity = 0.10 },
              mapPosition: MapPoint(0.50, 0.08)),
        Trait(id: .hydrophileI, category: .transmission, cost: 7, prerequisites: [],
              effects: fx { $0.seaTransmission = 0.55 },
              mapPosition: MapPoint(0.80, 0.08)),

        Trait(id: .contactBloomII, category: .transmission, cost: 11, prerequisites: [.contactBloomI],
              effects: fx { $0.landTransmission = 0.90; $0.infectivity = 0.10 },
              mapPosition: MapPoint(0.12, 0.35)),
        Trait(id: .herdVector, category: .transmission, cost: 10, prerequisites: [.contactBloomI],
              effects: fx { $0.landTransmission = 0.35; $0.ruralAffinity = 0.55 },
              mapPosition: MapPoint(0.32, 0.35)),
        Trait(id: .aerosolII, category: .transmission, cost: 14, prerequisites: [.aerosolI],
              effects: fx { $0.airTransmission = 0.90; $0.infectivity = 0.15 },
              mapPosition: MapPoint(0.52, 0.35)),
        Trait(id: .hydrophileII, category: .transmission, cost: 13, prerequisites: [.hydrophileI],
              effects: fx { $0.seaTransmission = 0.90; $0.tropicalTolerance = 0.10 },
              mapPosition: MapPoint(0.82, 0.35)),

        Trait(id: .swarmVector, category: .transmission, cost: 12, prerequisites: [.contactBloomI],
              effects: fx { $0.landTransmission = 0.40; $0.tropicalTolerance = 0.45 },
              mapPosition: MapPoint(0.22, 0.62)),
        Trait(id: .migratoryVector, category: .transmission, cost: 16, prerequisites: [.aerosolI],
              effects: fx { $0.airTransmission = 0.50; $0.frigidTolerance = 0.30 },
              mapPosition: MapPoint(0.55, 0.62)),

        Trait(id: .denseBloom, category: .transmission, cost: 12, prerequisites: [.contactBloomII],
              effects: fx { $0.urbanAffinity = 0.65; $0.infectivity = 0.10 },
              mapPosition: MapPoint(0.35, 0.86))
    ]

    // MARK: Resilience — staying unnoticed and unsolved

    public static let resilience: [Trait] = [
        Trait(id: .cryoCoatI, category: .resilience, cost: 8, prerequisites: [],
              effects: fx { $0.frigidTolerance = 0.50 },
              mapPosition: MapPoint(0.18, 0.08)),
        Trait(id: .thermalShellI, category: .resilience, cost: 8, prerequisites: [],
              effects: fx { $0.aridTolerance = 0.40; $0.tropicalTolerance = 0.20 },
              mapPosition: MapPoint(0.50, 0.08)),
        Trait(id: .mimicryI, category: .resilience, cost: 10, prerequisites: [],
              effects: fx { $0.stealth = 0.25 },
              mapPosition: MapPoint(0.82, 0.08)),

        Trait(id: .cryoCoatII, category: .resilience, cost: 14, prerequisites: [.cryoCoatI],
              effects: fx { $0.frigidTolerance = 0.45; $0.temperateTolerance = 0.10 },
              mapPosition: MapPoint(0.12, 0.35)),
        Trait(id: .thermalShellII, category: .resilience, cost: 14, prerequisites: [.thermalShellI],
              effects: fx { $0.aridTolerance = 0.40; $0.tropicalTolerance = 0.25 },
              mapPosition: MapPoint(0.45, 0.35)),
        Trait(id: .mimicryII, category: .resilience, cost: 18, prerequisites: [.mimicryI],
              effects: fx { $0.stealth = 0.30 },
              mapPosition: MapPoint(0.85, 0.35)),

        Trait(id: .environmentalHardening, category: .resilience, cost: 16,
              prerequisites: [.cryoCoatI, .thermalShellI],
              effects: fx {
                  $0.frigidTolerance = 0.20
                  $0.aridTolerance = 0.20
                  $0.tropicalTolerance = 0.15
                  $0.temperateTolerance = 0.15
              },
              mapPosition: MapPoint(0.30, 0.62)),
        Trait(id: .driftCodingI, category: .resilience, cost: 12, prerequisites: [.mimicryI],
              effects: fx { $0.researchResistance = 0.20 },
              mapPosition: MapPoint(0.70, 0.62)),

        Trait(id: .borderSlip, category: .resilience, cost: 18, prerequisites: [.environmentalHardening],
              effects: fx { $0.lockdownBypass = 0.50 },
              mapPosition: MapPoint(0.32, 0.86)),
        Trait(id: .driftCodingII, category: .resilience, cost: 20, prerequisites: [.driftCodingI],
              effects: fx { $0.researchResistance = 0.30 },
              mapPosition: MapPoint(0.72, 0.86))
    ]

    // MARK: Symptoms — the lethality / spreadability trade-off

    public static let symptoms: [Trait] = [
        Trait(id: .lethargy, category: .symptoms, cost: 4, prerequisites: [],
              effects: fx { $0.infectivity = 0.30; $0.visibility = 0.05 },
              mapPosition: MapPoint(0.20, 0.08)),
        Trait(id: .chromaticFlush, category: .symptoms, cost: 5, prerequisites: [],
              effects: fx { $0.infectivity = 0.50; $0.visibility = 0.15 },
              mapPosition: MapPoint(0.50, 0.08)),
        Trait(id: .resonantCough, category: .symptoms, cost: 7, prerequisites: [],
              effects: fx { $0.infectivity = 0.90; $0.visibility = 0.25 },
              mapPosition: MapPoint(0.80, 0.08)),

        Trait(id: .microTremor, category: .symptoms, cost: 9, prerequisites: [.lethargy],
              effects: fx { $0.infectivity = 0.40; $0.lethality = 0.40; $0.visibility = 0.30 },
              mapPosition: MapPoint(0.15, 0.32)),
        Trait(id: .dormancy, category: .symptoms, cost: 12, prerequisites: [.lethargy],
              effects: fx { $0.stealth = 0.30; $0.infectivity = -0.10 },
              mapPosition: MapPoint(0.33, 0.32)),
        Trait(id: .spectralFever, category: .symptoms, cost: 10, prerequisites: [.chromaticFlush],
              effects: fx { $0.infectivity = 0.60; $0.lethality = 0.60; $0.visibility = 0.40 },
              mapPosition: MapPoint(0.55, 0.32)),
        Trait(id: .silentShedding, category: .symptoms, cost: 13, prerequisites: [.resonantCough],
              effects: fx { $0.infectivity = 0.80; $0.visibility = -0.10 },
              mapPosition: MapPoint(0.82, 0.32)),

        Trait(id: .neuralBloom, category: .symptoms, cost: 14, prerequisites: [.microTremor],
              effects: fx { $0.lethality = 1.40; $0.visibility = 0.60 },
              mapPosition: MapPoint(0.20, 0.58)),
        Trait(id: .systemicCascade, category: .symptoms, cost: 18, prerequisites: [.spectralFever],
              effects: fx { $0.lethality = 2.20; $0.visibility = 0.90 },
              mapPosition: MapPoint(0.55, 0.58)),

        Trait(id: .totalCollapse, category: .symptoms, cost: 24,
              prerequisites: [.neuralBloom, .systemicCascade],
              effects: fx { $0.lethality = 4.00; $0.visibility = 1.40 },
              mapPosition: MapPoint(0.40, 0.85))
    ]

    private static let index: [TraitID: Trait] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// Node lookup. Every `TraitID` has exactly one node — guarded by
    /// `TraitCatalogTests.testEveryTraitIDHasANode`.
    public static func trait(_ id: TraitID) -> Trait {
        guard let found = index[id] else {
            preconditionFailure("Missing trait definition for \(id.rawValue)")
        }
        return found
    }

    public static func traits(in category: TraitCategory) -> [Trait] {
        switch category {
        case .transmission: return transmission
        case .resilience: return resilience
        case .symptoms: return symptoms
        }
    }

    /// Symptom nodes an unstable strain may drift into, cheapest first.
    public static var driftPool: [TraitID] {
        symptoms.filter { $0.prerequisites.isEmpty }.map(\.id)
    }

    private static func fx(_ build: (inout TraitEffects) -> Void) -> TraitEffects {
        var effects = TraitEffects()
        build(&effects)
        return effects
    }
}
