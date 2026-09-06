import Foundation

/// Drives one run, one day at a time.
///
/// The engine is a value type with no reference to any UI framework. A day is a
/// deterministic function of `(state, catalogs)` — feed the same seed and the
/// same player actions and you get the same board, every time, on every device.
public struct SimulationEngine: Sendable {

    public private(set) var state: GameState

    // MARK: Starting a run

    /// Builds a fresh run and seeds patient zero.
    public init(setup: GameSetup) {
        var generator = SeededGenerator(seed: setup.seed)
        let origin = RegionCatalog.startRegion(for: setup.scenario, using: &generator)
        var state = GameState(setup: setup, originRegion: origin, generator: generator)

        let blueprint = RegionCatalog.blueprint(origin)
        state.regions[origin]?.infected = SpreadRules.seedCount(for: blueprint.population)
        state.regions[origin]?.firstInfectedDay = 0
        state.touchedRegions.insert(origin)
        state.record(.outbreakBegan(region: origin))

        self.state = state
    }

    /// Restores an in-progress run (used by the autosave path).
    public init(restoring state: GameState) {
        self.state = state
    }

    // MARK: Player actions

    @discardableResult
    public mutating func unlock(_ trait: TraitID) -> Bool {
        state.unlock(trait)
    }

    @discardableResult
    public mutating func fold(_ trait: TraitID) -> Bool {
        state.fold(trait)
    }

    @discardableResult
    public mutating func collectBubble(_ id: UUID) -> Int {
        state.collectBubble(id)
    }

    /// Grants points from a rewarded ad or a future purchase.
    public mutating func grantBonusPoints(_ amount: Int) {
        guard amount > 0 else { return }
        state.evolutionPoints += amount
    }

    // MARK: The day loop

    /// Advances the simulation by one day. A no-op once the run has finished, so
    /// a stray timer tick after the summary screen can never corrupt the board.
    public mutating func advanceDay() {
        guard !state.isFinished else { return }

        state.advanceClock()

        let profile = state.profile
        let strain = StrainCatalog.strain(state.setup.strain)
        let difficulty = state.setup.difficulty
        let scenario = state.setup.scenario

        growWithinRegions(profile: profile, difficulty: difficulty, signature: strain.signature)
        spreadBetweenRegions(profile: profile, scenario: scenario)
        updateAwareness(profile: profile, difficulty: difficulty, scenario: scenario, signature: strain.signature)
        updateResearch(profile: profile, difficulty: difficulty)
        applyRestrictions(profile: profile, difficulty: difficulty)
        accrueEvolutionPoints(difficulty: difficulty, strain: strain)
        applyDriftMutation(signature: strain.signature)
        updateBubbles()
        evaluateOutcome()
    }

    // MARK: Step 1 — growth inside each territory

    private mutating func growWithinRegions(
        profile: EvolutionProfile,
        difficulty: Difficulty,
        signature: StrainSignature
    ) {
        for blueprint in RegionCatalog.all {
            guard var region = state.regions[blueprint.id], region.infected > 0 else { continue }
            let wasSaturated = region.isSaturated

            let losses = SpreadRules.newLosses(state: region, profile: profile)
            region.infected -= losses
            region.lost += losses

            let gained = SpreadRules.newInfections(
                region: blueprint, state: region, profile: profile,
                difficulty: difficulty, signature: signature
            )
            region.infected += gained
            region.infected = min(region.infected, max(0, Double(region.population) - region.lost))

            state.regions[blueprint.id] = region
            if !wasSaturated, region.isSaturated {
                state.record(.regionSaturated(region: blueprint.id))
            }
        }
    }

    // MARK: Step 2 — travel between territories

    private mutating func spreadBetweenRegions(
        profile: EvolutionProfile,
        scenario: StartScenario
    ) {
        // Snapshot the board first: everything this step reads is yesterday's
        // state, so evaluation order can never change the outcome.
        let snapshot = state.regions
        var generator = state.generator
        var arrivals: [(RegionID, TravelRoute)] = []

        for source in RegionCatalog.all {
            guard let sourceState = snapshot[source.id], sourceState.infected >= 1 else { continue }

            for route in TravelRoute.allCases {
                for destination in destinations(from: source, route: route) {
                    guard let destinationState = snapshot[destination.id],
                          !destinationState.isInfected else { continue }
                    // Skip if another route already delivered the strain today.
                    guard !arrivals.contains(where: { $0.0 == destination.id }) else { continue }

                    let probability = SpreadRules.travelProbability(
                        route: route, source: sourceState, profile: profile, scenario: scenario
                    )
                    guard generator.chance(probability) else { continue }
                    guard SpreadRules.routeIsOpen(
                        route: route, source: sourceState, destination: destinationState,
                        profile: profile, generator: &generator
                    ) else { continue }

                    arrivals.append((destination.id, route))
                }
            }
        }

        state.generator = generator

        for (regionID, route) in arrivals {
            let blueprint = RegionCatalog.blueprint(regionID)
            state.regions[regionID]?.infected = SpreadRules.seedCount(for: blueprint.population)
            state.regions[regionID]?.firstInfectedDay = state.day
            state.touchedRegions.insert(regionID)
            state.record(.regionInfected(region: regionID, route: route))
        }
    }

    /// Territories reachable from `source` over `route`.
    private func destinations(from source: RegionBlueprint, route: TravelRoute) -> [RegionBlueprint] {
        switch route {
        case .land:
            return source.neighbors.map(RegionCatalog.blueprint)
        case .air:
            guard source.hasAirport else { return [] }
            return RegionCatalog.all.filter { $0.id != source.id && $0.hasAirport }
        case .sea:
            guard source.hasSeaport else { return [] }
            return RegionCatalog.all.filter { $0.id != source.id && $0.hasSeaport }
        }
    }

    // MARK: Step 3 — awareness (global response rule 2)

    private mutating func updateAwareness(
        profile: EvolutionProfile,
        difficulty: Difficulty,
        scenario: StartScenario,
        signature: StrainSignature
    ) {
        for blueprint in RegionCatalog.all {
            guard var region = state.regions[blueprint.id] else { continue }
            let delta = GlobalResponseEngine.awarenessDelta(
                region: blueprint, state: region, profile: profile,
                difficulty: difficulty, scenario: scenario, signature: signature
            )
            region.awareness = min(100, max(0, region.awareness + delta))
            state.regions[blueprint.id] = region
        }

        state.globalAwareness = GlobalResponseEngine.globalAwareness(regions: state.regions)

        if !state.isDetected, state.globalAwareness >= GlobalResponseEngine.detectionAwareness {
            state.isDetected = true
            state.detectionDay = state.day
            state.regionsAtDetection = state.infectedRegionCount
            state.record(.strainDetected)
        }
    }

    // MARK: Step 4 — research (global response rule 3)

    private mutating func updateResearch(profile: EvolutionProfile, difficulty: Difficulty) {
        let delta = GlobalResponseEngine.researchDelta(
            regions: state.regions,
            globalAwareness: state.globalAwareness,
            profile: profile,
            difficulty: difficulty
        )
        guard delta > 0 else { return }

        if state.researchStartDay == nil {
            state.researchStartDay = state.day
            state.record(.researchBegan)
        }

        let before = state.researchProgress
        state.researchProgress = min(GlobalResponseEngine.solutionTarget, before + delta)

        // Quarter milestones, recorded once each, for the ticker and the report.
        for milestone in [25, 50, 75] {
            let threshold = Double(milestone)
            if before < threshold, state.researchProgress >= threshold {
                state.record(.researchMilestone(percent: milestone))
            }
        }
    }

    // MARK: Step 5 — restrictions (global response rule 4)

    private mutating func applyRestrictions(profile: EvolutionProfile, difficulty: Difficulty) {
        var generator = state.generator
        for blueprint in RegionCatalog.all {
            guard var region = state.regions[blueprint.id] else { continue }
            let decision = GlobalResponseEngine.restriction(
                state: region, profile: profile, difficulty: difficulty, generator: &generator
            )
            switch decision {
            case .none:
                continue
            case .lockTransport:
                region.transportLocked = true
                state.regions[blueprint.id] = region
                state.record(.transportLocked(region: blueprint.id))
            case .closeBorders:
                region.transportLocked = true
                region.bordersClosed = true
                state.regions[blueprint.id] = region
                state.record(.bordersClosed(region: blueprint.id))
            case .lift:
                region.transportLocked = false
                region.bordersClosed = false
                state.regions[blueprint.id] = region
                state.record(.restrictionsLifted(region: blueprint.id))
            }
        }
        state.generator = generator
    }

    // MARK: Step 6 — evolution points

    private mutating func accrueEvolutionPoints(difficulty: Difficulty, strain: Strain) {
        let income = EvolutionRules.dailyIncome(
            infectedRegions: state.infectedRegionCount,
            difficulty: difficulty,
            strain: strain
        )
        state.pointRemainder += income
        let whole = state.pointRemainder.rounded(.down)
        if whole >= 1 {
            state.evolutionPoints += Int(whole)
            state.pointRemainder -= whole
        }
        state.peakLethality = max(state.peakLethality, state.profile.lethality)
    }

    private mutating func applyDriftMutation(signature: StrainSignature) {
        var generator = state.generator
        let mutation = EvolutionRules.driftMutation(
            signature: signature,
            day: state.day,
            unlocked: state.unlockedTraits,
            generator: &generator
        )
        state.generator = generator
        if let mutation {
            state.applyDriftMutation(mutation)
        }
    }

    private mutating func updateBubbles() {
        state.bubbles = EvolutionRules.expireBubbles(state.bubbles, day: state.day)
        var generator = state.generator
        let infected = RegionCatalog.all
            .filter { state.regions[$0.id]?.isInfected == true }
            .map(\.id)
        let bubble = EvolutionRules.spawnBubble(
            day: state.day,
            infectedRegions: infected,
            activeBubbles: state.bubbles.count,
            generator: &generator
        )
        state.generator = generator
        if let bubble {
            state.bubbles.append(bubble)
        }
    }

    // MARK: Step 7 — outcome (global response rule 5 resolves here)

    private mutating func evaluateOutcome() {
        // A broken challenge condition ends the run immediately.
        if let objective = state.setup.objective,
           ObjectiveEvaluator.isBroken(objective, state: state) {
            finish(.defeat(.objectiveFailed))
            return
        }

        // Victory: every territory consumed. `isSaturated` (rather than a strict
        // "zero healthy") is what ends the run, so the last handful of people in
        // a billion-strong territory cannot stretch a decided game by weeks.
        if state.regions.values.allSatisfy(\.isSaturated) {
            if let objective = state.setup.objective,
               !ObjectiveEvaluator.isSatisfied(objective, state: state) {
                finish(.defeat(.objectiveFailed))
            } else {
                finish(.victory)
            }
            return
        }

        // Defeat: a solution completed.
        if state.researchProgress >= GlobalResponseEngine.solutionTarget {
            finish(.defeat(.solutionFound))
            return
        }

        // Defeat: the strain burned out without reaching everyone.
        if state.totalInfected < 1, state.day > 1 {
            finish(.defeat(.burnedOut))
        }
    }

    private mutating func finish(_ outcome: GameOutcome) {
        state.outcome = outcome
        switch outcome {
        case .victory:
            state.record(.victory)
        case .defeat(let reason):
            state.record(.defeat(reason: reason))
        }
    }

    // MARK: Convenience

    /// Runs to completion, capped so a pathological configuration can never
    /// hang a caller. Used by the balance tests and the smoke test.
    @discardableResult
    public mutating func runToCompletion(maxDays: Int = 500) -> GameOutcome {
        while !state.isFinished, state.day < maxDays {
            advanceDay()
        }
        if let outcome = state.outcome { return outcome }
        // Ran out of budget: treat a stalled board as a burn-out.
        finish(.defeat(.burnedOut))
        return state.outcome ?? .defeat(.burnedOut)
    }
}
