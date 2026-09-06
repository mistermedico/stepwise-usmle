import Foundation
@testable import OutbreakEngine

/// Shared builders so each test can start from a known board rather than a
/// random one. Nothing here touches a simulator or the file system.
enum Fixture {

    static func setup(
        strain: StrainID = .drift,
        difficulty: Difficulty = .tense,
        scenario: StartScenario = .wildcard,
        seed: UInt64 = 4242,
        objective: ChallengeObjective? = nil,
        dailyChallengeID: String? = nil
    ) -> GameSetup {
        GameSetup(
            strain: strain,
            difficulty: difficulty,
            scenario: scenario,
            seed: seed,
            objective: objective,
            dailyChallengeID: dailyChallengeID
        )
    }

    static func state(
        strain: StrainID = .drift,
        difficulty: Difficulty = .tense,
        scenario: StartScenario = .wildcard,
        seed: UInt64 = 4242,
        objective: ChallengeObjective? = nil
    ) -> GameState {
        SimulationEngine(
            setup: setup(
                strain: strain, difficulty: difficulty, scenario: scenario,
                seed: seed, objective: objective
            )
        ).state
    }

    /// A run whose board has been wiped back to zero, so a test can place
    /// exactly the territories it cares about without patient zero in the way.
    static func cleanState(
        strain: StrainID = .drift,
        difficulty: Difficulty = .tense,
        scenario: StartScenario = .wildcard,
        seed: UInt64 = 4242,
        objective: ChallengeObjective? = nil
    ) -> GameState {
        var value = state(
            strain: strain, difficulty: difficulty, scenario: scenario,
            seed: seed, objective: objective
        )
        value.regions = RegionCatalog.initialStates()
        value.touchedRegions = []
        return value
    }

    /// A territory state at a chosen saturation, with everything else at rest.
    static func region(
        _ id: RegionID,
        infectedFraction: Double = 0,
        lostFraction: Double = 0,
        awareness: Double = 0,
        transportLocked: Bool = false,
        bordersClosed: Bool = false
    ) -> RegionState {
        let blueprint = RegionCatalog.blueprint(id)
        var state = RegionState(id: id, population: blueprint.population)
        state.infected = Double(blueprint.population) * infectedFraction
        state.lost = Double(blueprint.population) * lostFraction
        state.awareness = awareness
        state.transportLocked = transportLocked
        state.bordersClosed = bordersClosed
        if state.infected >= 1 { state.firstInfectedDay = 0 }
        return state
    }

    /// A profile built from an explicit list of unlocked nodes.
    static func profile(_ traits: [TraitID], strain: StrainID = .drift) -> EvolutionProfile {
        var effects = StrainCatalog.strain(strain).innateEffects
        for id in traits {
            effects = effects + TraitCatalog.trait(id).effects
        }
        return EvolutionProfile(effects: effects)
    }

    /// A generator that is never consulted by the rule under test, or whose
    /// consumption the test does not care about.
    static func generator(_ seed: UInt64 = 7) -> SeededGenerator {
        SeededGenerator(seed: seed)
    }
}
