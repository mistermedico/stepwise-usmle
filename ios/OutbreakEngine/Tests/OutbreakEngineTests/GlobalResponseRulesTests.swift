import XCTest
@testable import OutbreakEngine

/// Section 3 verification: one group of assertions per documented rule, each
/// exercised at every difficulty tier against fixed board states.
final class GlobalResponseRulesTests: XCTestCase {

    // MARK: Rule 1 — visible assessment

    func testRule1ReadsOnlyTheVisibleBoard() {
        var state = Fixture.cleanState()
        state.regions[.northreach] = Fixture.region(.northreach, infectedFraction: 0.4, lostFraction: 0.1)
        state.regions[.sunwake] = Fixture.region(.sunwake, infectedFraction: 0.2)
        state.regions[.farhaven] = Fixture.region(.farhaven, infectedFraction: 0.999)

        let assessment = GlobalResponseEngine.assess(state)

        XCTAssertEqual(assessment.infectedRegions, 3)
        XCTAssertEqual(assessment.saturatedRegions, 0)
        XCTAssertGreaterThan(assessment.visibleLethality, 0)
        XCTAssertLessThan(assessment.visibleLethality, 1)
    }

    func testRule1ReportsZeroLethalityOnACleanBoard() {
        let state = Fixture.state()
        let assessment = GlobalResponseEngine.assess(state)
        // Patient zero is already seeded, but nobody has been lost.
        XCTAssertEqual(assessment.infectedRegions, 1)
        XCTAssertEqual(assessment.visibleLethality, 0)
        XCTAssertEqual(assessment.researchProgress, 0)
    }

    func testRule1CountsSaturatedTerritories() {
        var state = Fixture.cleanState()
        state.regions[.farhaven] = Fixture.region(.farhaven, infectedFraction: 1.0)
        let assessment = GlobalResponseEngine.assess(state)
        XCTAssertEqual(assessment.saturatedRegions, 1)
    }

    // MARK: Rule 2 — awareness

    func testRule2GrowsWithCarriersAtEveryDifficulty() {
        let blueprint = RegionCatalog.blueprint(.verdanmoor)
        let profile = Fixture.profile([])

        for difficulty in Difficulty.allCases {
            let quiet = Fixture.region(.verdanmoor, infectedFraction: 0.05)
            let loud = Fixture.region(.verdanmoor, infectedFraction: 0.60)

            let quietDelta = GlobalResponseEngine.awarenessDelta(
                region: blueprint, state: quiet, profile: profile,
                difficulty: difficulty, scenario: .wildcard, signature: .none
            )
            let loudDelta = GlobalResponseEngine.awarenessDelta(
                region: blueprint, state: loud, profile: profile,
                difficulty: difficulty, scenario: .wildcard, signature: .none
            )

            XCTAssertGreaterThan(quietDelta, 0, "\(difficulty.rawValue): quiet spread should still register")
            XCTAssertGreaterThan(loudDelta, quietDelta, "\(difficulty.rawValue): awareness must track carriers")
        }
    }

    func testRule2ScalesWithDifficulty() {
        let blueprint = RegionCatalog.blueprint(.verdanmoor)
        let state = Fixture.region(.verdanmoor, infectedFraction: 0.3)
        let profile = Fixture.profile([])

        let deltas = Difficulty.allCases.map { difficulty in
            GlobalResponseEngine.awarenessDelta(
                region: blueprint, state: state, profile: profile,
                difficulty: difficulty, scenario: .wildcard, signature: .none
            )
        }
        // breezy < tense < lethal, in declaration order.
        XCTAssertLessThan(deltas[0], deltas[1])
        XCTAssertLessThan(deltas[1], deltas[2])
    }

    func testRule2IsDampedByStealthAndRaisedByLoudSymptoms() {
        let blueprint = RegionCatalog.blueprint(.verdanmoor)
        let state = Fixture.region(.verdanmoor, infectedFraction: 0.3)

        let bare = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: Fixture.profile([]),
            difficulty: .tense, scenario: .wildcard, signature: .none
        )
        let stealthy = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: Fixture.profile([.mimicryI, .mimicryII]),
            difficulty: .tense, scenario: .wildcard, signature: .none
        )
        let loud = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: Fixture.profile([.systemicCascade, .spectralFever, .chromaticFlush]),
            difficulty: .tense, scenario: .wildcard, signature: .none
        )

        XCTAssertLessThan(stealthy, bare)
        XCTAssertGreaterThan(stealthy, 0, "Stealth must slow awareness, never reverse it")
        XCTAssertGreaterThan(loud, bare)
    }

    func testRule2CoolsDownWhenNoCarriersRemain() {
        let blueprint = RegionCatalog.blueprint(.verdanmoor)
        var state = Fixture.region(.verdanmoor, infectedFraction: 0, awareness: 40)
        state.infected = 0

        let delta = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: Fixture.profile([]),
            difficulty: .tense, scenario: .wildcard, signature: .none
        )
        XCTAssertLessThan(delta, 0)

        let fading = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: Fixture.profile([], strain: .halo),
            difficulty: .tense, scenario: .wildcard, signature: .fadingTrail
        )
        XCTAssertLessThan(fading, delta, "The Halo signature should cool faster")
    }

    func testRule2NeverExceedsTheDailyStep() {
        let blueprint = RegionCatalog.blueprint(.sunwake)
        let state = Fixture.region(.sunwake, infectedFraction: 1.0)
        let everySymptom = Fixture.profile([
            .lethargy, .chromaticFlush, .resonantCough, .microTremor,
            .spectralFever, .neuralBloom, .systemicCascade, .totalCollapse
        ])

        let delta = GlobalResponseEngine.awarenessDelta(
            region: blueprint, state: state, profile: everySymptom,
            difficulty: .lethal, scenario: .transitHub, signature: .none
        )
        XCTAssertLessThanOrEqual(delta, GlobalResponseEngine.maxAwarenessStep)
    }

    func testRule2GlobalAwarenessIsPopulationWeighted() {
        var regions = RegionCatalog.initialStates()
        // Awareness in the smallest territory alone must barely move the needle.
        regions[.farhaven]?.awareness = 100
        let small = GlobalResponseEngine.globalAwareness(regions: regions)

        regions = RegionCatalog.initialStates()
        regions[.highbarrow]?.awareness = 100
        let large = GlobalResponseEngine.globalAwareness(regions: regions)

        XCTAssertLessThan(small, large)
        XCTAssertTrue((0...100).contains(small))
        XCTAssertTrue((0...100).contains(large))
    }

    // MARK: Rule 3 — research

    func testRule3StaysAtZeroBelowTheAwarenessThreshold() {
        for difficulty in Difficulty.allCases {
            let below = difficulty.researchThreshold - 0.1
            let delta = GlobalResponseEngine.researchDelta(
                regions: RegionCatalog.initialStates(),
                globalAwareness: below,
                profile: Fixture.profile([]),
                difficulty: difficulty
            )
            XCTAssertEqual(delta, 0, "\(difficulty.rawValue) started research too early")
        }
    }

    func testRule3StartsExactlyAtTheThreshold() {
        for difficulty in Difficulty.allCases {
            var regions = RegionCatalog.initialStates()
            regions[.verdanmoor] = Fixture.region(.verdanmoor, infectedFraction: 0.2)

            let delta = GlobalResponseEngine.researchDelta(
                regions: regions,
                globalAwareness: difficulty.researchThreshold,
                profile: Fixture.profile([]),
                difficulty: difficulty
            )
            XCTAssertGreaterThan(delta, 0, "\(difficulty.rawValue) failed to start at its own threshold")
        }
    }

    func testRule3RateIsFixedForAFixedBoard() {
        var regions = RegionCatalog.initialStates()
        regions[.verdanmoor] = Fixture.region(.verdanmoor, infectedFraction: 0.2)

        let first = GlobalResponseEngine.researchDelta(
            regions: regions, globalAwareness: 50,
            profile: Fixture.profile([]), difficulty: .tense
        )
        let second = GlobalResponseEngine.researchDelta(
            regions: regions, globalAwareness: 50,
            profile: Fixture.profile([]), difficulty: .tense
        )
        XCTAssertEqual(first, second, "Research must not wander between calls")
    }

    func testRule3GrowsWithLaboratoryReachAndOrdersByDifficulty() {
        var narrow = RegionCatalog.initialStates()
        narrow[.tidecrest] = Fixture.region(.tidecrest, infectedFraction: 0.3)

        var wide = RegionCatalog.initialStates()
        for id in RegionID.allCases {
            wide[id] = Fixture.region(id, infectedFraction: 0.3)
        }

        for difficulty in Difficulty.allCases {
            let narrowDelta = GlobalResponseEngine.researchDelta(
                regions: narrow, globalAwareness: 90,
                profile: Fixture.profile([]), difficulty: difficulty
            )
            let wideDelta = GlobalResponseEngine.researchDelta(
                regions: wide, globalAwareness: 90,
                profile: Fixture.profile([]), difficulty: difficulty
            )
            XCTAssertLessThan(narrowDelta, wideDelta, "\(difficulty.rawValue): reach should matter")
        }

        let rates = Difficulty.allCases.map { difficulty in
            GlobalResponseEngine.researchDelta(
                regions: wide, globalAwareness: 90,
                profile: Fixture.profile([]), difficulty: difficulty
            )
        }
        XCTAssertLessThan(rates[0], rates[1])
        XCTAssertLessThan(rates[1], rates[2])
    }

    func testRule3IsDampedByResistanceButNeverNegative() {
        var regions = RegionCatalog.initialStates()
        for id in RegionID.allCases {
            regions[id] = Fixture.region(id, infectedFraction: 0.5)
        }

        let bare = GlobalResponseEngine.researchDelta(
            regions: regions, globalAwareness: 90,
            profile: Fixture.profile([]), difficulty: .tense
        )
        let resistant = GlobalResponseEngine.researchDelta(
            regions: regions, globalAwareness: 90,
            profile: Fixture.profile([.mimicryI, .driftCodingI, .driftCodingII]),
            difficulty: .tense
        )
        XCTAssertLessThan(resistant, bare)
        XCTAssertGreaterThan(resistant, 0)
    }

    func testRule3LaboratoryWeightStaysNormalised() {
        XCTAssertEqual(
            GlobalResponseEngine.laboratoryWeight(regions: RegionCatalog.initialStates()), 0
        )
        var all = RegionCatalog.initialStates()
        for id in RegionID.allCases {
            all[id] = Fixture.region(id, infectedFraction: 0.1)
        }
        XCTAssertEqual(GlobalResponseEngine.laboratoryWeight(regions: all), 1, accuracy: 1e-9)
    }

    // MARK: Rule 4 — restrictions

    func testRule4LocksTransportAtEachDifficultyThreshold() {
        for difficulty in Difficulty.allCases {
            var generator = Fixture.generator()
            let below = Fixture.region(.goldensands, awareness: difficulty.lockdownThreshold - 0.1)
            let at = Fixture.region(.goldensands, awareness: difficulty.lockdownThreshold)

            XCTAssertEqual(
                GlobalResponseEngine.restriction(
                    state: below, profile: Fixture.profile([]),
                    difficulty: difficulty, generator: &generator
                ),
                .none, "\(difficulty.rawValue) locked down too early"
            )
            XCTAssertEqual(
                GlobalResponseEngine.restriction(
                    state: at, profile: Fixture.profile([]),
                    difficulty: difficulty, generator: &generator
                ),
                .lockTransport, "\(difficulty.rawValue) failed to lock at its own threshold"
            )
        }
    }

    func testRule4ClosesBordersOnlyAtTheHigherThreshold() {
        for difficulty in Difficulty.allCases {
            var generator = Fixture.generator()
            let state = Fixture.region(
                .goldensands,
                awareness: difficulty.borderClosureThreshold,
                transportLocked: true
            )
            XCTAssertEqual(
                GlobalResponseEngine.restriction(
                    state: state, profile: Fixture.profile([]),
                    difficulty: difficulty, generator: &generator
                ),
                .closeBorders
            )
        }
    }

    func testRule4LiftsOnlyAfterTheReleaseMargin() {
        let difficulty = Difficulty.tense
        var generator = Fixture.generator()

        let stillTense = Fixture.region(
            .goldensands,
            awareness: difficulty.lockdownThreshold - difficulty.lockdownReleaseMargin + 1,
            transportLocked: true
        )
        XCTAssertEqual(
            GlobalResponseEngine.restriction(
                state: stillTense, profile: Fixture.profile([]),
                difficulty: difficulty, generator: &generator
            ),
            .none
        )

        let calm = Fixture.region(
            .goldensands,
            awareness: difficulty.lockdownThreshold - difficulty.lockdownReleaseMargin - 1,
            transportLocked: true
        )
        XCTAssertEqual(
            GlobalResponseEngine.restriction(
                state: calm, profile: Fixture.profile([]),
                difficulty: difficulty, generator: &generator
            ),
            .lift
        )
    }

    func testRule4CanBeResistedByBorderSlip() {
        // With a full bypass profile the order should sometimes be dodged.
        let state = Fixture.region(.goldensands, awareness: 99)
        let profile = Fixture.profile([.cryoCoatI, .thermalShellI, .environmentalHardening, .borderSlip])

        var dodged = 0
        for seed in 0..<200 {
            var generator = SeededGenerator(seed: UInt64(seed + 1))
            let decision = GlobalResponseEngine.restriction(
                state: state, profile: profile, difficulty: .tense, generator: &generator
            )
            if decision == .none { dodged += 1 }
        }
        XCTAssertGreaterThan(dodged, 0, "borderSlip never resisted an order")
        XCTAssertLessThan(dodged, 200, "borderSlip resisted every single order")
    }

    func testRule4WarnsBeforeItLocks() {
        let difficulty = Difficulty.tense
        let approaching = Fixture.region(.goldensands, awareness: difficulty.lockdownThreshold - 4)
        let calm = Fixture.region(.goldensands, awareness: 5)
        let alreadyLocked = Fixture.region(
            .goldensands, awareness: difficulty.lockdownThreshold - 4, transportLocked: true
        )

        XCTAssertTrue(GlobalResponseEngine.isRestrictionImminent(state: approaching, difficulty: difficulty))
        XCTAssertFalse(GlobalResponseEngine.isRestrictionImminent(state: calm, difficulty: difficulty))
        XCTAssertFalse(GlobalResponseEngine.isRestrictionImminent(state: alreadyLocked, difficulty: difficulty))
    }

    // MARK: Rule 5 — the solution date

    func testRule5HasNoDeadlineBeforeResearchStarts() {
        let state = Fixture.state()
        XCTAssertNil(GlobalResponseEngine.projectedSolutionDay(state))
        XCTAssertNil(GlobalResponseEngine.daysUntilSolution(state))
    }

    func testRule5MatchesTheClosedFormAtEveryDifficulty() {
        for difficulty in Difficulty.allCases {
            var state = Fixture.state(difficulty: difficulty)
            for id in RegionID.allCases {
                state.regions[id] = Fixture.region(id, infectedFraction: 0.4, awareness: 95)
            }
            state.globalAwareness = 95
            state.researchProgress = 40

            let rate = GlobalResponseEngine.researchDelta(
                regions: state.regions,
                globalAwareness: state.globalAwareness,
                profile: state.profile,
                difficulty: difficulty
            )
            XCTAssertGreaterThan(rate, 0)

            let expected = state.day + Int(((100.0 - 40.0) / rate).rounded(.up))
            XCTAssertEqual(GlobalResponseEngine.projectedSolutionDay(state), expected)
            XCTAssertEqual(GlobalResponseEngine.daysUntilSolution(state), expected - state.day)
        }
    }

    func testRule5IsStableAndConsumesNoRandomness() {
        var state = Fixture.state()
        for id in RegionID.allCases {
            state.regions[id] = Fixture.region(id, infectedFraction: 0.4, awareness: 95)
        }
        state.globalAwareness = 95
        state.researchProgress = 10

        let generatorBefore = state.generator
        let first = GlobalResponseEngine.projectedSolutionDay(state)
        let second = GlobalResponseEngine.projectedSolutionDay(state)

        XCTAssertEqual(first, second)
        XCTAssertEqual(state.generator, generatorBefore, "Rule 5 must never touch the generator")
    }

    func testRule5CountdownShrinksAsResearchProgresses() {
        var state = Fixture.state()
        for id in RegionID.allCases {
            state.regions[id] = Fixture.region(id, infectedFraction: 0.4, awareness: 95)
        }
        state.globalAwareness = 95

        state.researchProgress = 10
        let early = GlobalResponseEngine.daysUntilSolution(state)
        state.researchProgress = 80
        let late = GlobalResponseEngine.daysUntilSolution(state)

        XCTAssertNotNil(early)
        XCTAssertNotNil(late)
        XCTAssertLessThan(late ?? .max, early ?? 0)
    }

    func testRule5ReachesZeroWhenTheSolutionIsDone() {
        var state = Fixture.state()
        for id in RegionID.allCases {
            state.regions[id] = Fixture.region(id, infectedFraction: 0.4, awareness: 95)
        }
        state.globalAwareness = 95
        state.researchProgress = 100
        XCTAssertEqual(GlobalResponseEngine.daysUntilSolution(state), 0)
    }
}
