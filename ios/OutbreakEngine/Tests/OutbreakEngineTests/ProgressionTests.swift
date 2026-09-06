import XCTest
@testable import OutbreakEngine

final class EvolutionRulesTests: XCTestCase {

    func testIncomeGrowsWithReachAndOrdersByDifficulty() {
        let strain = StrainCatalog.strain(.drift)
        for difficulty in Difficulty.allCases {
            let narrow = EvolutionRules.dailyIncome(infectedRegions: 1, difficulty: difficulty, strain: strain)
            let wide = EvolutionRules.dailyIncome(infectedRegions: 12, difficulty: difficulty, strain: strain)
            XCTAssertGreaterThan(narrow, 0)
            XCTAssertGreaterThan(wide, narrow)
        }

        let incomes = Difficulty.allCases.map {
            EvolutionRules.dailyIncome(infectedRegions: 6, difficulty: $0, strain: strain)
        }
        XCTAssertGreaterThan(incomes[0], incomes[1])
        XCTAssertGreaterThan(incomes[1], incomes[2])
    }

    func testStrainMultiplierAppliesToIncome() {
        let plain = EvolutionRules.dailyIncome(
            infectedRegions: 4, difficulty: .tense, strain: StrainCatalog.strain(.drift)
        )
        let rich = EvolutionRules.dailyIncome(
            infectedRegions: 4, difficulty: .tense, strain: StrainCatalog.strain(.nyx)
        )
        XCTAssertGreaterThan(rich, plain)
    }

    func testBubblesOnlyAppearInInfectedTerritories() throws {
        var generator = Fixture.generator(1)
        XCTAssertNil(
            EvolutionRules.spawnBubble(
                day: 4, infectedRegions: [], activeBubbles: 0, generator: &generator
            ),
            "A cluster appeared with nowhere to put it"
        )

        var found: PointBubble?
        for seed in 0..<400 where found == nil {
            var local = SeededGenerator(seed: UInt64(seed + 1))
            found = EvolutionRules.spawnBubble(
                day: 4, infectedRegions: [.emberfall], activeBubbles: 0, generator: &local
            )
        }

        let bubble = try XCTUnwrap(found, "No cluster appeared across 400 seeds")
        XCTAssertEqual(bubble.region, .emberfall)
        XCTAssertEqual(bubble.spawnedOnDay, 4)
        XCTAssertEqual(bubble.expiresOnDay, 4 + EvolutionRules.bubbleLifetime)
        XCTAssertTrue((2...4).contains(bubble.value))
        XCTAssertTrue((0...1).contains(bubble.offset.x))
        XCTAssertTrue((0...1).contains(bubble.offset.y))
    }

    func testBubbleBoardIsCapped() {
        var generator = Fixture.generator(3)
        XCTAssertNil(
            EvolutionRules.spawnBubble(
                day: 10,
                infectedRegions: RegionID.allCases,
                activeBubbles: EvolutionRules.maxConcurrentBubbles,
                generator: &generator
            )
        )
    }

    func testExpiredBubblesAreDropped() {
        let live = PointBubble(
            region: .sunwake, value: 3, spawnedOnDay: 5, expiresOnDay: 8, offset: MapPoint(0.5, 0.5)
        )
        let stale = PointBubble(
            region: .sunwake, value: 3, spawnedOnDay: 1, expiresOnDay: 4, offset: MapPoint(0.5, 0.5)
        )
        let kept = EvolutionRules.expireBubbles([live, stale], day: 6)
        XCTAssertEqual(kept.map(\.id), [live.id])
    }

    func testDriftOnlyAffectsUnstableStrainsOnItsCadence() {
        var generator = Fixture.generator(11)
        for signature in [StrainSignature.none, .fadingTrail, .heatSeeking, .coldSeeking] {
            XCTAssertNil(
                EvolutionRules.driftMutation(
                    signature: signature, day: 10, unlocked: [], generator: &generator
                ),
                "\(signature.rawValue) must not mutate on its own"
            )
        }

        XCTAssertNil(
            EvolutionRules.driftMutation(signature: .unstable, day: 7, unlocked: [], generator: &generator)
        )
        XCTAssertNil(
            EvolutionRules.driftMutation(signature: .unstable, day: 0, unlocked: [], generator: &generator)
        )
        XCTAssertNotNil(
            EvolutionRules.driftMutation(signature: .unstable, day: 10, unlocked: [], generator: &generator)
        )
    }

    func testDriftRespectsPrerequisitesAndStopsWhenExhausted() {
        var generator = Fixture.generator(21)
        let unlockedRoots: Set<TraitID> = [.lethargy, .chromaticFlush, .resonantCough]
        let mutation = EvolutionRules.driftMutation(
            signature: .unstable, day: 20, unlocked: unlockedRoots, generator: &generator
        )
        let picked = mutation.map(TraitCatalog.trait)
        XCTAssertEqual(picked?.category, .symptoms)
        XCTAssertTrue(
            picked?.prerequisites.allSatisfy { unlockedRoots.contains($0) } ?? false
        )

        let everySymptom = Set(TraitCatalog.symptoms.map(\.id))
        XCTAssertNil(
            EvolutionRules.driftMutation(
                signature: .unstable, day: 30, unlocked: everySymptom, generator: &generator
            )
        )
    }
}

final class ObjectiveEvaluatorTests: XCTestCase {

    func testDayBudgetBreaksOnlyAfterTheDeadline() {
        var state = Fixture.state()
        let objective = ChallengeObjective.within(days: 3)
        for _ in 0..<3 { state.advanceClock() }
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))
        state.advanceClock()
        XCTAssertTrue(ObjectiveEvaluator.isBroken(objective, state: state))
    }

    func testLethalityCapUsesThePeakNotTheCurrentValue() {
        var state = Fixture.state()
        let objective = ChallengeObjective.lethalityBelow(cap: 1.0)
        state.peakLethality = 0.9
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))
        state.peakLethality = 1.4
        XCTAssertTrue(ObjectiveEvaluator.isBroken(objective, state: state))
    }

    func testStealthObjectiveOnlyResolvesOnceDetected() {
        var state = Fixture.state()
        let objective = ChallengeObjective.undetectedUntilRegions(count: 5)
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))

        state.isDetected = true
        state.regionsAtDetection = 3
        XCTAssertTrue(ObjectiveEvaluator.isBroken(objective, state: state))

        state.regionsAtDetection = 6
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))
    }

    func testLossBudgetBreaksWhenExceeded() {
        var state = Fixture.cleanState()
        let objective = ChallengeObjective.lossesBelow(fraction: 0.10)
        state.regions[.farhaven] = Fixture.region(.farhaven, lostFraction: 1.0)
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))

        state.regions[.highbarrow] = Fixture.region(.highbarrow, lostFraction: 1.0)
        XCTAssertTrue(ObjectiveEvaluator.isBroken(objective, state: state))
    }

    func testSpendBudgetTracksActualPurchases() {
        var state = Fixture.state()
        let objective = ChallengeObjective.spendAtMost(points: 10)
        state.evolutionPoints = 100

        XCTAssertTrue(state.unlock(.lethargy))          // 4
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))
        XCTAssertTrue(state.unlock(.chromaticFlush))    // +5 = 9
        XCTAssertFalse(ObjectiveEvaluator.isBroken(objective, state: state))
        XCTAssertTrue(state.unlock(.resonantCough))     // +7 = 16
        XCTAssertTrue(ObjectiveEvaluator.isBroken(objective, state: state))
    }

    func testPressureStaysNormalised() {
        var state = Fixture.state()
        state.peakLethality = 0.5
        state.evolutionPoints = 100
        state.isDetected = false

        let objectives: [ChallengeObjective] = [
            .within(days: 50),
            .lethalityBelow(cap: 2),
            .undetectedUntilRegions(count: 4),
            .lossesBelow(fraction: 0.2),
            .spendAtMost(points: 40)
        ]
        for objective in objectives {
            let pressure = ObjectiveEvaluator.pressure(objective, state: state)
            XCTAssertGreaterThanOrEqual(pressure, 0, "\(objective)")
            XCTAssertLessThanOrEqual(pressure, 1, "\(objective)")
        }
    }

    func testPressureHandlesDegenerateBudgets() {
        let state = Fixture.state()
        XCTAssertEqual(ObjectiveEvaluator.pressure(.within(days: 0), state: state), 1)
        XCTAssertEqual(ObjectiveEvaluator.pressure(.lethalityBelow(cap: 0), state: state), 1)
        XCTAssertEqual(ObjectiveEvaluator.pressure(.spendAtMost(points: 0), state: state), 1)
        XCTAssertEqual(ObjectiveEvaluator.pressure(.lossesBelow(fraction: 0), state: state), 1)
        XCTAssertEqual(ObjectiveEvaluator.pressure(.undetectedUntilRegions(count: 0), state: state), 0)
    }
}

final class DailyChallengeTests: XCTestCase {

    func testSameDayGivesEveryPlayerTheSameChallenge() {
        let first = DailyChallenge.challenge(id: "2026-03-14")
        let second = DailyChallenge.challenge(id: "2026-03-14")
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.setup.seed, second.setup.seed)
        XCTAssertEqual(first.objective, second.objective)
    }

    func testDifferentDaysDiffer() {
        let days = (1...28).map { DailyChallenge.challenge(id: String(format: "2026-02-%02d", $0)) }
        XCTAssertGreaterThan(Set(days.map(\.setup.seed)).count, 20, "Daily seeds are clustering")
        XCTAssertGreaterThan(Set(days.map(\.setup.strain)).count, 1)
    }

    func testChallengeAlwaysCarriesItsIdentityAndObjective() {
        for day in 1...31 {
            let id = String(format: "2026-07-%02d", day)
            let challenge = DailyChallenge.challenge(id: id)
            XCTAssertEqual(challenge.setup.dailyChallengeID, id)
            XCTAssertTrue(challenge.setup.isDailyChallenge)
            XCTAssertEqual(challenge.setup.objective, challenge.objective)
            XCTAssertFalse(
                StrainCatalog.strain(challenge.setup.strain).requiresUnlock,
                "A daily challenge must never require an unlocked strain"
            )
        }
    }

    func testObjectiveValuesAreAlwaysPlayable() {
        for day in 1...60 {
            let challenge = DailyChallenge.challenge(id: String(format: "2026-1%d-%02d", day % 2, (day % 28) + 1))
            switch challenge.objective {
            case .within(let days):
                XCTAssertGreaterThan(days, 30)
            case .lethalityBelow(let cap):
                XCTAssertGreaterThan(cap, 0)
            case .undetectedUntilRegions(let count):
                XCTAssertGreaterThanOrEqual(count, 2)
                XCTAssertLessThanOrEqual(count, RegionID.allCases.count)
            case .lossesBelow(let fraction):
                XCTAssertGreaterThan(fraction, 0)
                XCTAssertLessThanOrEqual(fraction, 1)
            case .spendAtMost(let points):
                XCTAssertGreaterThan(points, 30)
            }
        }
    }

    func testIdentifierIsUTCAndZeroPadded() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = 23
        components.minute = 59
        let calendar = Calendar.utcCalendar
        let date = calendar.date(from: components) ?? Date()
        XCTAssertEqual(DailyChallenge.identifier(for: date, calendar: calendar), "2026-01-05")
    }

    func testChallengeFromDateMatchesChallengeFromIdentifier() {
        let calendar = Calendar.utcCalendar
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 6
        let date = calendar.date(from: components) ?? Date()
        XCTAssertEqual(
            DailyChallenge.challenge(for: date, calendar: calendar),
            DailyChallenge.challenge(id: "2026-09-06")
        )
    }
}

final class ReportAndAchievementTests: XCTestCase {

    /// Builds a finished run without running the simulation, so a title can be
    /// asserted against exact figures.
    private func finishedState(
        outcome: GameOutcome,
        days: Int,
        detectionDay: Int?,
        lostFraction: Double,
        infectedFraction: Double = 1.0,
        strain: StrainID = .drift,
        scenario: StartScenario = .wildcard,
        difficulty: Difficulty = .tense
    ) -> GameState {
        var state = Fixture.cleanState(strain: strain, difficulty: difficulty, scenario: scenario)
        for _ in 0..<days { state.advanceClock() }
        for id in RegionID.allCases {
            state.regions[id] = Fixture.region(
                id,
                infectedFraction: max(0, infectedFraction - lostFraction),
                lostFraction: lostFraction
            )
            state.touchedRegions.insert(id)
        }
        state.detectionDay = detectionDay
        state.isDetected = detectionDay != nil
        state.outcome = outcome
        return state
    }

    func testLightningTitleForAFastWin() {
        let state = finishedState(outcome: .victory, days: 30, detectionDay: 5, lostFraction: 0.1)
        XCTAssertEqual(EpidemicReport(state: state).title, .lightningOutbreak)
    }

    func testSilentTitleForALateDetection() {
        let state = finishedState(outcome: .victory, days: 100, detectionDay: 80, lostFraction: 0.1)
        XCTAssertEqual(EpidemicReport(state: state).title, .silentOutbreak)
    }

    func testScorchedTitleForHeavyLosses() {
        let state = finishedState(outcome: .victory, days: 100, detectionDay: 10, lostFraction: 0.8)
        XCTAssertEqual(EpidemicReport(state: state).title, .scorchedPath)
    }

    func testSlowCreepTitleForALongWin() {
        let state = finishedState(outcome: .victory, days: 160, detectionDay: 10, lostFraction: 0.1)
        XCTAssertEqual(EpidemicReport(state: state).title, .slowCreep)
    }

    func testSteadyBloomIsTheFallback() {
        let state = finishedState(outcome: .victory, days: 90, detectionDay: 10, lostFraction: 0.1)
        XCTAssertEqual(EpidemicReport(state: state).title, .steadyBloom)
    }

    func testDefeatTitlesDistinguishTheirCause() {
        let solved = finishedState(
            outcome: .defeat(.solutionFound), days: 90, detectionDay: 10, lostFraction: 0.1
        )
        XCTAssertEqual(EpidemicReport(state: solved).title, .solvedInTime)

        var contained = Fixture.cleanState()
        contained.regions[.farhaven] = Fixture.region(.farhaven, infectedFraction: 0.001)
        contained.touchedRegions = [.farhaven]
        contained.outcome = .defeat(.burnedOut)
        XCTAssertEqual(EpidemicReport(state: contained).title, .containedEarly)
    }

    func testReportFractionsStayNormalised() {
        let state = finishedState(outcome: .victory, days: 70, detectionDay: 20, lostFraction: 0.25)
        let report = EpidemicReport(state: state)
        XCTAssertTrue((0...1).contains(report.reachFraction))
        XCTAssertTrue((0...1).contains(report.lossFraction))
        XCTAssertTrue((0...1).contains(report.stealthFraction))
        XCTAssertEqual(report.stealthFraction, 20.0 / 70.0, accuracy: 1e-9)
        XCTAssertEqual(report.regionsReached, RegionID.allCases.count)
    }

    func testReportSurvivesARoundTripThroughJSON() throws {
        let state = finishedState(outcome: .victory, days: 55, detectionDay: 12, lostFraction: 0.2)
        let report = EpidemicReport(state: state)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(EpidemicReport.self, from: data)

        XCTAssertEqual(decoded.id, report.id)
        XCTAssertEqual(decoded.outcome, report.outcome)
        XCTAssertEqual(decoded.title, report.title)
        XCTAssertEqual(decoded.days, report.days)
        XCTAssertEqual(decoded.strain, report.strain)
        XCTAssertEqual(decoded.difficulty, report.difficulty)
        XCTAssertEqual(decoded.timeline.count, report.timeline.count)
        XCTAssertEqual(decoded.totalLost, report.totalLost, accuracy: 1e-6)
    }

    func testNeverDetectedRunReportsFullStealth() {
        let state = finishedState(outcome: .victory, days: 60, detectionDay: nil, lostFraction: 0.05)
        let report = EpidemicReport(state: state)
        XCTAssertEqual(report.stealthFraction, 1)
        XCTAssertTrue(Achievement.earned(from: report).contains(.untouchedWorld))
    }

    func testAchievementsMatchTheRunTheyDescribe() {
        let fast = EpidemicReport(
            state: finishedState(
                outcome: .victory, days: 30, detectionDay: 25, lostFraction: 0.01,
                strain: .rime, scenario: .isolatedIsland, difficulty: .lethal
            )
        )
        let earned = Achievement.earned(from: fast)
        XCTAssertTrue(earned.contains(.firstBloom))
        XCTAssertTrue(earned.contains(.lightningStrike))
        XCTAssertTrue(earned.contains(.allRegionsReached))
        XCTAssertTrue(earned.contains(.gentleTouch))
        XCTAssertTrue(earned.contains(.coldBloodedRun))
        XCTAssertTrue(earned.contains(.islandStart))
        XCTAssertTrue(earned.contains(.lethalTier))
        XCTAssertFalse(earned.contains(.hubStart))
        XCTAssertFalse(earned.contains(.desertBloom))
    }

    func testDefeatEarnsNothingButFullCoverage() {
        let lost = EpidemicReport(
            state: finishedState(
                outcome: .defeat(.solutionFound), days: 80, detectionDay: 10, lostFraction: 0.2
            )
        )
        let earned = Achievement.earned(from: lost)
        XCTAssertFalse(earned.contains(.firstBloom))
        XCTAssertTrue(earned.contains(.allRegionsReached))
    }

    func testCumulativeAchievementNeedsAStreak() {
        XCTAssertTrue(Achievement.cumulative(dailyChallengesWon: 5).contains(.dailyRegular))
        XCTAssertFalse(Achievement.cumulative(dailyChallengesWon: 4).contains(.dailyRegular))
    }

    func testEveryAchievementIsReachable() {
        // A guard against adding a case to the enum and forgetting to award it.
        let awardable = Set(Achievement.allCases).subtracting([.dailyRegular])
        for achievement in awardable {
            XCTAssertFalse(achievement.isCumulative, "\(achievement.rawValue) needs an award path")
        }
        XCTAssertTrue(Achievement.dailyRegular.isCumulative)
    }
}
