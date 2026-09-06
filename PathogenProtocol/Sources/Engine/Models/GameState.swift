import Foundation

/// The full mutable state of one run. Value type by design: the engine is a pure
/// `(GameState, Command) -> GameState` transform, which is what makes it unit-testable
/// without a simulator (spec section 8.2).
public struct GameState: Codable, Equatable {
    public var scenario: WorldScenario
    public var strain: StrainDefinition
    public var difficulty: DifficultyLevel

    public var day: Int = 0
    public var evolutionPoints: Double = 0
    public var unlockedUpgradeIDs: Set<String> = []
    public var regionStates: [RegionID: RegionState]

    public var globalAwareness: Double = 0
    public var isResearchActive: Bool = false
    public var researchProgress: Double = 0
    /// Day research first activated, used to compute a fixed, precomputable cure day
    /// (spec section 3, rule 5) rather than deriving it from randomness.
    public var researchActivatedOnDay: Int?

    public var outcome: GameOutcome?
    public var history: [DaySnapshot] = []

    public init(scenario: WorldScenario, strain: StrainDefinition, difficulty: DifficultyLevel) {
        self.scenario = scenario
        self.strain = strain
        self.difficulty = difficulty
        var initialStates: [RegionID: RegionState] = [:]
        for region in scenario.regions {
            initialStates[region.id] = .clean
        }
        initialStates[scenario.startingRegionID] = RegionState(
            infectionLevel: 0.02, awarenessLevel: 0, isLockedDown: false, isDiscovered: false
        )
        self.regionStates = initialStates
    }

    public var isRunning: Bool { outcome == nil }

    public var unlockedEffects: [UpgradeEffect] {
        unlockedUpgradeIDs.compactMap { UpgradeCatalog.node($0)?.effect }
    }

    public var effectiveTransmissionRate: Double {
        strain.baseTransmissionRate + unlockedEffects.reduce(0.0) { $0 + $1.transmissionRateBonus }
    }

    public var effectiveLethality: Double {
        strain.baseLethality + unlockedEffects.reduce(0.0) { $0 + $1.lethalityBonus }
    }

    public var effectiveDetectionResistance: Double {
        min(0.9, strain.baseDetectionResistance + unlockedEffects.reduce(0.0) { $0 + $1.detectionResistanceBonus })
    }

    public var effectiveSeverity: Double {
        unlockedEffects.reduce(0.0) { $0 + $1.severityBonus }
    }

    public var hasLockdownBypass: Bool {
        unlockedEffects.contains { $0.bypassesLockdown }
    }

    public var globalInfectionFraction: Double {
        let totalPopulation = scenario.regions.reduce(0) { $0 + $1.population }
        guard totalPopulation > 0 else { return 0 }
        let infected = scenario.regions.reduce(0.0) { sum, region in
            sum + (regionStates[region.id]?.infectionLevel ?? 0) * region.population
        }
        return infected / totalPopulation
    }

    public var regionsInfectedCount: Int {
        regionStates.values.filter { $0.infectionLevel > 0.001 }.count
    }

    public var regionsLockedDownCount: Int {
        regionStates.values.filter { $0.isLockedDown }.count
    }

    /// The exact day the cure will complete, computable the moment research activates
    /// because `DifficultyLevel.dailyResearchRate` is a fixed constant, never randomized.
    public var projectedCureDay: Int? {
        guard let activatedDay = researchActivatedOnDay, isResearchActive else { return nil }
        let remaining = max(0, difficulty.researchCompletionThreshold - researchProgress)
        let daysNeeded = Int((remaining / difficulty.dailyResearchRate).rounded(.up))
        return activatedDay + daysNeeded
    }
}
