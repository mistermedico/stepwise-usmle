import XCTest
@testable import OutbreakEngine

final class SimulationEngineTests: XCTestCase {

    // MARK: Invariants

    /// Everything that must be true of the board after any number of days.
    private func assertInvariants(
        _ state: GameState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (id, region) in state.regions {
            let population = Double(region.population)
            XCTAssertFalse(region.infected.isNaN, "\(id.rawValue) carriers went NaN", file: file, line: line)
            XCTAssertFalse(region.lost.isNaN, "\(id.rawValue) losses went NaN", file: file, line: line)
            XCTAssertGreaterThanOrEqual(region.infected, 0, "\(id.rawValue)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(region.lost, 0, "\(id.rawValue)", file: file, line: line)
            XCTAssertLessThanOrEqual(
                region.infected + region.lost, population + 1e-6,
                "\(id.rawValue) holds more people than it has", file: file, line: line
            )
            XCTAssertTrue(
                (0...100).contains(region.awareness),
                "\(id.rawValue) awareness \(region.awareness) out of range", file: file, line: line
            )
            if region.bordersClosed {
                XCTAssertTrue(
                    region.transportLocked,
                    "\(id.rawValue) closed borders without suspending transport", file: file, line: line
                )
            }
        }
        XCTAssertTrue((0...100).contains(state.globalAwareness), file: file, line: line)
        XCTAssertTrue((0...100).contains(state.researchProgress), file: file, line: line)
        XCTAssertGreaterThanOrEqual(state.evolutionPoints, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(state.pointsSpent, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(
            state.bubbles.count, EvolutionRules.maxConcurrentBubbles, file: file, line: line
        )
        if state.isDetected {
            XCTAssertNotNil(state.detectionDay, file: file, line: line)
        }
    }

    // MARK: Opening state

    func testFreshRunSeedsExactlyOneTerritory() {
        let engine = SimulationEngine(setup: Fixture.setup())
        let state = engine.state

        XCTAssertEqual(state.day, 0)
        XCTAssertEqual(state.infectedRegionCount, 1)
        XCTAssertTrue(state.regions[state.originRegion]?.isInfected ?? false)
        XCTAssertEqual(state.regions[state.originRegion]?.firstInfectedDay, 0)
        XCTAssertEqual(state.touchedRegions, [state.originRegion])
        XCTAssertEqual(state.evolutionPoints, Difficulty.tense.startingPoints)
        XCTAssertFalse(state.isDetected)
        XCTAssertNil(state.outcome)
        XCTAssertEqual(state.events.count, 1)
        XCTAssertEqual(state.events.first?.kind, .outbreakBegan(region: state.originRegion))
        assertInvariants(state)
    }

    func testScenarioDecidesWhereTheRunStarts() {
        for _ in 0..<12 {
            let seed = UInt64.random(in: 1...9_999_999)
            let island = SimulationEngine(setup: Fixture.setup(scenario: .isolatedIsland, seed: seed))
            let hub = SimulationEngine(setup: Fixture.setup(scenario: .transitHub, seed: seed))
            XCTAssertTrue(RegionCatalog.lowConnectivityStarts.contains(island.state.originRegion))
            XCTAssertTrue(RegionCatalog.hubStarts.contains(hub.state.originRegion))
        }
    }

    // MARK: Determinism

    func testSameSeedProducesTheSameRun() {
        var first = SimulationEngine(setup: Fixture.setup(seed: 987_654))
        var second = SimulationEngine(setup: Fixture.setup(seed: 987_654))

        for _ in 0..<120 {
            first.advanceDay()
            second.advanceDay()
        }

        XCTAssertEqual(first.state.day, second.state.day)
        XCTAssertEqual(first.state.regions, second.state.regions)
        XCTAssertEqual(first.state.globalAwareness, second.state.globalAwareness)
        XCTAssertEqual(first.state.researchProgress, second.state.researchProgress)
        XCTAssertEqual(first.state.evolutionPoints, second.state.evolutionPoints)
        XCTAssertEqual(first.state.outcome, second.state.outcome)
        XCTAssertEqual(
            first.state.events.map(\.kind), second.state.events.map(\.kind),
            "Two identically seeded runs diverged"
        )
    }

    func testSameSeedWithTheSamePurchasesProducesTheSameRun() {
        func play() -> GameState {
            var engine = SimulationEngine(setup: Fixture.setup(seed: 24_680))
            for day in 0..<90 {
                engine.advanceDay()
                if day == 10 { engine.unlock(.lethargy) }
                if day == 25 { engine.unlock(.contactBloomI) }
                if day == 40 { engine.unlock(.aerosolI) }
            }
            return engine.state
        }
        let a = play()
        let b = play()
        XCTAssertEqual(a.regions, b.regions)
        XCTAssertEqual(a.unlockedTraits, b.unlockedTraits)
        XCTAssertEqual(a.evolutionPoints, b.evolutionPoints)
    }

    func testDifferentSeedsProduceDifferentRuns() {
        var first = SimulationEngine(setup: Fixture.setup(seed: 1))
        var second = SimulationEngine(setup: Fixture.setup(seed: 2))
        for _ in 0..<80 {
            first.advanceDay()
            second.advanceDay()
        }
        XCTAssertNotEqual(first.state.regions, second.state.regions)
    }

    // MARK: The day loop

    func testAdvancingIsANoOpOnceTheRunIsOver() {
        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .lethal, seed: 31337))
        engine.runToCompletion()
        let finished = engine.state

        engine.advanceDay()
        engine.advanceDay()

        XCTAssertEqual(engine.state.day, finished.day)
        XCTAssertEqual(engine.state.regions, finished.regions)
        XCTAssertEqual(engine.state.events.count, finished.events.count)
    }

    func testInvariantsHoldAcrossALongRun() {
        var engine = SimulationEngine(setup: Fixture.setup(strain: .nyx, difficulty: .tense, seed: 8_192))
        for day in 0..<250 {
            engine.advanceDay()
            if day % 12 == 0 {
                // Buy whatever is affordable, including deadly nodes, to push the
                // numbers into their extremes.
                for trait in TraitCatalog.all where engine.state.canUnlock(trait.id) {
                    engine.unlock(trait.id)
                    break
                }
            }
            assertInvariants(engine.state)
        }
    }

    func testDetectionIsRecordedExactlyOnce() {
        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .lethal, seed: 606))
        engine.unlock(.resonantCough)
        for _ in 0..<250 { engine.advanceDay() }

        let detections = engine.state.events.filter { $0.kind == .strainDetected }
        XCTAssertLessThanOrEqual(detections.count, 1)
        if engine.state.isDetected {
            XCTAssertEqual(detections.count, 1)
            XCTAssertNotNil(engine.state.regionsAtDetection)
            XCTAssertEqual(engine.state.detectionDay, detections.first?.day)
        }
    }

    func testResearchStartsOnceAndOnlyAfterAwareness() {
        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .lethal, seed: 4_040))
        engine.unlock(.chromaticFlush)
        for _ in 0..<300 { engine.advanceDay() }

        let starts = engine.state.events.filter { $0.kind == .researchBegan }
        XCTAssertLessThanOrEqual(starts.count, 1)
        if engine.state.researchProgress > 0 {
            XCTAssertEqual(starts.count, 1)
            XCTAssertNotNil(engine.state.researchStartDay)
        } else {
            XCTAssertNil(engine.state.researchStartDay)
        }
    }

    // MARK: Player actions

    func testUnlockChargesPointsAndRespectsPrerequisites() {
        var engine = SimulationEngine(setup: Fixture.setup())
        engine.grantBonusPoints(100)
        let before = engine.state.evolutionPoints

        XCTAssertFalse(engine.state.canUnlock(.contactBloomII), "A locked node should not be buyable")
        XCTAssertFalse(engine.unlock(.contactBloomII))
        XCTAssertEqual(engine.state.evolutionPoints, before)

        XCTAssertTrue(engine.unlock(.contactBloomI))
        XCTAssertEqual(engine.state.evolutionPoints, before - TraitCatalog.trait(.contactBloomI).cost)
        XCTAssertTrue(engine.state.isUnlocked(.contactBloomI))
        XCTAssertTrue(engine.unlock(.contactBloomII))
    }

    func testUnlockIsRejectedWithoutEnoughPoints() {
        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .lethal))
        // Lethal opens with 5 points; Total Collapse costs 24.
        XCTAssertFalse(engine.unlock(.totalCollapse))
        XCTAssertTrue(engine.state.unlockedTraits.isEmpty)
    }

    func testFoldingRefundsAndIsBlockedByDependents() {
        var engine = SimulationEngine(setup: Fixture.setup())
        engine.grantBonusPoints(100)
        engine.unlock(.contactBloomI)
        engine.unlock(.contactBloomII)

        XCTAssertFalse(engine.state.canFold(.contactBloomI), "A node with a dependent must stay")
        XCTAssertFalse(engine.fold(.contactBloomI))

        let before = engine.state.evolutionPoints
        XCTAssertTrue(engine.fold(.contactBloomII))
        XCTAssertEqual(engine.state.evolutionPoints, before + TraitCatalog.trait(.contactBloomII).refund)
        XCTAssertFalse(engine.state.isUnlocked(.contactBloomII))
        XCTAssertTrue(engine.state.canFold(.contactBloomI))
    }

    func testFoldingNeverRefundsMoreThanItCost() {
        var engine = SimulationEngine(setup: Fixture.setup())
        engine.grantBonusPoints(100)
        let start = engine.state.evolutionPoints
        engine.unlock(.resonantCough)
        engine.fold(.resonantCough)
        XCTAssertLessThan(engine.state.evolutionPoints, start)
    }

    func testCollectingAClusterPaysOutExactlyOnce() {
        var engine = SimulationEngine(setup: Fixture.setup(seed: 5_150))
        for _ in 0..<200 where engine.state.bubbles.isEmpty {
            engine.advanceDay()
        }
        guard let bubble = engine.state.bubbles.first else {
            return XCTFail("No cluster appeared in 200 days")
        }

        let before = engine.state.evolutionPoints
        XCTAssertEqual(engine.collectBubble(bubble.id), bubble.value)
        XCTAssertEqual(engine.state.evolutionPoints, before + bubble.value)
        XCTAssertFalse(engine.state.bubbles.contains { $0.id == bubble.id })
        XCTAssertEqual(engine.collectBubble(bubble.id), 0, "A cluster paid out twice")
    }

    func testBonusPointsIgnoreNonPositiveGrants() {
        var engine = SimulationEngine(setup: Fixture.setup())
        let before = engine.state.evolutionPoints
        engine.grantBonusPoints(0)
        engine.grantBonusPoints(-25)
        XCTAssertEqual(engine.state.evolutionPoints, before)
    }

    // MARK: Outcomes

    func testEveryConfigurationTerminatesCleanly() {
        for difficulty in Difficulty.allCases {
            for strain in StrainID.allCases {
                for scenario in StartScenario.allCases {
                    var engine = SimulationEngine(
                        setup: Fixture.setup(
                            strain: strain, difficulty: difficulty,
                            scenario: scenario, seed: 1_234_567
                        )
                    )
                    let outcome = engine.runToCompletion(maxDays: 600)
                    XCTAssertNotNil(engine.state.outcome, "\(strain)/\(difficulty)/\(scenario) never ended")
                    XCTAssertEqual(engine.state.outcome, outcome)
                    XCTAssertLessThanOrEqual(engine.state.day, 600)
                    assertInvariants(engine.state)

                    let report = EpidemicReport(state: engine.state)
                    XCTAssertEqual(report.isVictory, outcome == .victory)
                    XCTAssertTrue((0...1).contains(report.reachFraction))
                }
            }
        }
    }

    func testAPassiveStrainLosesOnTheHardestTier() {
        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .lethal, seed: 7_777))
        let outcome = engine.runToCompletion(maxDays: 600)
        XCTAssertNotEqual(outcome, .victory, "Doing nothing should never take the world")
    }

    func testAWellPlayedRunCanWin() {
        // A deterministic greedy player: buy the next affordable node from a
        // spread-first shopping list. This is the full-playthrough check that
        // section 8.5 asks for.
        let shoppingList: [TraitID] = [
            .contactBloomI, .lethargy, .chromaticFlush, .aerosolI, .hydrophileI,
            .resonantCough, .contactBloomII, .aerosolII, .hydrophileII, .denseBloom,
            .silentShedding, .cryoCoatI, .thermalShellI, .cryoCoatII, .thermalShellII,
            .environmentalHardening, .herdVector, .swarmVector, .migratoryVector, .mimicryI
        ]

        var engine = SimulationEngine(setup: Fixture.setup(difficulty: .breezy, seed: 20_260_906))
        while !engine.state.isFinished, engine.state.day < 500 {
            for id in shoppingList where engine.state.canUnlock(id) {
                engine.unlock(id)
            }
            for bubble in engine.state.bubbles {
                engine.collectBubble(bubble.id)
            }
            engine.advanceDay()
        }

        XCTAssertEqual(engine.state.outcome, .victory, "A spread-first build should take the board on Breezy")
        assertInvariants(engine.state)

        let report = EpidemicReport(state: engine.state)
        XCTAssertTrue(report.isVictory)
        XCTAssertEqual(report.regionsReached, RegionID.allCases.count)
        XCTAssertFalse(report.timeline.isEmpty)
        XCTAssertTrue(Achievement.earned(from: report).contains(.firstBloom))
    }

    func testABrokenObjectiveEndsTheRunImmediately() {
        var engine = SimulationEngine(
            setup: Fixture.setup(difficulty: .breezy, seed: 909, objective: .within(days: 5))
        )
        let outcome = engine.runToCompletion(maxDays: 200)
        XCTAssertEqual(outcome, .defeat(.objectiveFailed))
        XCTAssertEqual(engine.state.day, 6, "The run should stop on the first day past the budget")
    }

    func testAnIntactObjectiveDoesNotBlockAWin() {
        var engine = SimulationEngine(
            setup: Fixture.setup(
                difficulty: .breezy, seed: 4_242, objective: .lethalityBelow(cap: 99)
            )
        )
        let outcome = engine.runToCompletion(maxDays: 600)
        if outcome == .victory {
            XCTAssertTrue(
                ObjectiveEvaluator.isSatisfied(.lethalityBelow(cap: 99), state: engine.state)
            )
        }
        XCTAssertNotEqual(outcome, .defeat(.objectiveFailed))
    }

    // MARK: Save and restore

    func testARunSurvivesBeingSavedAndRestored() throws {
        var engine = SimulationEngine(setup: Fixture.setup(seed: 3_141))
        for _ in 0..<60 { engine.advanceDay() }
        engine.grantBonusPoints(40)
        engine.unlock(.contactBloomI)

        let data = try JSONEncoder().encode(engine.state)
        let restoredState = try JSONDecoder().decode(GameState.self, from: data)
        var restored = SimulationEngine(restoring: restoredState)

        for _ in 0..<40 {
            engine.advanceDay()
            restored.advanceDay()
        }

        XCTAssertEqual(engine.state.day, restored.state.day)
        XCTAssertEqual(engine.state.regions, restored.state.regions)
        XCTAssertEqual(engine.state.evolutionPoints, restored.state.evolutionPoints)
        XCTAssertEqual(engine.state.researchProgress, restored.state.researchProgress)
    }
}
