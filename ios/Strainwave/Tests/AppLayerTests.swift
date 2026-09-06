import XCTest
import OutbreakEngine
@testable import Strainwave

/// Persistence, backed by an in-memory store so tests never touch the device's
/// real history.
@MainActor
final class ReportStoreTests: XCTestCase {

    private var store: ReportStore!

    override func setUp() async throws {
        try await super.setUp()
        Settings.reset()
        store = ReportStore(controller: PersistenceController(inMemory: true))
    }

    override func tearDown() async throws {
        store = nil
        Settings.reset()
        try await super.tearDown()
    }

    /// Builds a finished run directly rather than simulating one, so the
    /// persistence assertions never depend on game balance.
    private func finishedReport(
        victory: Bool = true,
        days: Int = 60,
        dailyID: String? = nil,
        finishedAt: Date = Date()
    ) -> EpidemicReport {
        var state = GameState(
            setup: GameSetup(
                strain: .drift, difficulty: .breezy, scenario: .wildcard,
                seed: 1, objective: nil, dailyChallengeID: dailyID
            ),
            originRegion: .highbarrow,
            generator: SeededGenerator(seed: 1)
        )
        for _ in 0..<days { state.advanceClock() }
        for id in RegionID.allCases {
            let population = RegionCatalog.blueprint(id).population
            var region = RegionState(id: id, population: population)
            region.infected = Double(population)
            region.firstInfectedDay = 0
            state.regions[id] = region
            state.touchedRegions.insert(id)
        }
        state.isDetected = true
        state.detectionDay = 20
        state.outcome = victory ? .victory : .defeat(.solutionFound)
        return EpidemicReport(state: state, finishedAt: finishedAt)
    }

    func testAFreshStoreIsEmpty() {
        XCTAssertTrue(store.reports.isEmpty)
        XCTAssertTrue(store.earnedAchievements.isEmpty)
        XCTAssertEqual(store.victories, 0)
        XCTAssertNil(store.fastestVictoryDays)
    }

    func testSavingAReportMakesItReadable() {
        let report = finishedReport()
        store.save(report)

        XCTAssertEqual(store.reports.count, 1)
        XCTAssertEqual(store.reports.first?.id, report.id)
        XCTAssertEqual(store.reports.first?.days, report.days)
        XCTAssertEqual(store.reports.first?.title, report.title)
        XCTAssertEqual(Settings.runsFinished, 1)
    }

    func testReportsComeBackNewestFirst() {
        let older = finishedReport(days: 40, finishedAt: Date(timeIntervalSince1970: 1_000))
        let newer = finishedReport(days: 55, finishedAt: Date(timeIntervalSince1970: 2_000))
        store.save(older)
        store.save(newer)

        XCTAssertEqual(store.reports.first?.id, newer.id)

        let dates = store.reports.map(\.finishedAt)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testAchievementsAreAwardedOnceOnly() {
        let report = finishedReport()
        let first = store.save(report)
        let second = store.save(report)

        XCTAssertFalse(store.earnedAchievements.isEmpty, "A finished run earned nothing at all")
        XCTAssertTrue(second.isEmpty, "The same achievements were handed out twice")
        XCTAssertEqual(Set(first), store.earnedAchievements.intersection(Set(first)))
    }

    func testDailyChallengeBookkeeping() {
        XCTAssertFalse(store.hasPlayedDailyChallenge(id: "2026-05-01"))

        let report = finishedReport(dailyID: "2026-05-01")
        store.save(report)

        XCTAssertTrue(store.hasPlayedDailyChallenge(id: "2026-05-01"))
        XCTAssertFalse(store.hasPlayedDailyChallenge(id: "2026-05-02"))
        XCTAssertEqual(Settings.lastDailyChallengePlayed, "2026-05-01")
    }

    func testDeletingEverythingClearsReportsAchievementsAndCounters() {
        store.save(finishedReport())
        XCTAssertFalse(store.reports.isEmpty)

        store.deleteAll()

        XCTAssertTrue(store.reports.isEmpty)
        XCTAssertTrue(store.earnedAchievements.isEmpty)
        XCTAssertEqual(Settings.runsFinished, 0)
        XCTAssertNil(Settings.lastDailyChallengePlayed)
    }
}

/// Presentation logic that must not depend on a running run.
final class FiguresTests: XCTestCase {

    func testPopulationScalesToReadableUnits() {
        XCTAssertTrue(Figures.people(4_200_000_000).hasSuffix("B"))
        XCTAssertTrue(Figures.people(310_000_000).hasSuffix("M"))
        XCTAssertTrue(Figures.people(18_000).hasSuffix("K"))
        XCTAssertFalse(Figures.people(42).hasSuffix("K"))
        XCTAssertFalse(Figures.people(0).isEmpty)
    }

    func testPercentagesClampToTheValidRange() {
        XCTAssertEqual(Figures.percent(-1), Figures.percent(0))
        XCTAssertEqual(Figures.percent(3), Figures.percent(1))
        XCTAssertFalse(Figures.percent(0.5).isEmpty)
    }

    func testIntegersAlwaysRender() {
        XCTAssertFalse(Figures.integer(0).isEmpty)
        XCTAssertFalse(Figures.integer(-5).isEmpty)
        XCTAssertFalse(Figures.integer(1_234_567).isEmpty)
    }
}

/// The run's view model, driven directly rather than through the clock.
@MainActor
final class GameViewModelTests: XCTestCase {

    private func makeModel(
        difficulty: Difficulty = .tense,
        objective: ChallengeObjective? = nil
    ) -> GameViewModel {
        let consent = ConsentManager()
        return GameViewModel(
            setup: GameSetup(
                strain: .drift, difficulty: difficulty, scenario: .wildcard,
                seed: 777, objective: objective
            ),
            feedback: SilentFeedback(),
            store: ReportStore(controller: PersistenceController(inMemory: true)),
            ads: AdManager(consent: consent, adapter: DisabledAdAdapter())
        )
    }

    func testAFreshModelMirrorsTheEngine() {
        let model = makeModel()
        XCTAssertEqual(model.state.day, 0)
        XCTAssertEqual(model.state.infectedRegionCount, 1)
        XCTAssertNil(model.finishedReport)
        XCTAssertFalse(model.ticker.isEmpty, "The opening event should already be on the ticker")
    }

    func testUnlockingSpendsPointsAndIsReflectedInTheNodeList() {
        let model = makeModel(difficulty: .breezy)
        let before = model.state.evolutionPoints

        model.unlock(.lethargy)

        XCTAssertTrue(model.state.isUnlocked(.lethargy))
        XCTAssertEqual(model.state.evolutionPoints, before - TraitCatalog.trait(.lethargy).cost)

        let node = model.nodes(in: .symptoms).first { $0.id == .lethargy }
        XCTAssertEqual(node?.status, .unlocked)
    }

    func testUnlockingAnUnaffordableNodeChangesNothing() {
        let model = makeModel(difficulty: .lethal)
        let before = model.state.evolutionPoints

        model.unlock(.totalCollapse)

        XCTAssertFalse(model.state.isUnlocked(.totalCollapse))
        XCTAssertEqual(model.state.evolutionPoints, before)
    }

    func testFoldingReturnsSomeOfTheCost() {
        let model = makeModel(difficulty: .breezy)
        model.unlock(.lethargy)
        let afterUnlock = model.state.evolutionPoints

        model.fold(.lethargy)

        XCTAssertFalse(model.state.isUnlocked(.lethargy))
        XCTAssertGreaterThan(model.state.evolutionPoints, afterUnlock)
    }

    func testPausingStopsTheClock() {
        let model = makeModel()
        model.start()
        model.pause()
        XCTAssertEqual(model.speed, .paused)
        XCTAssertNil(GameViewModel.Speed.paused.interval)
    }

    func testNodeStatusesCoverEveryBranch() {
        let model = makeModel(difficulty: .breezy)
        for category in TraitCategory.allCases {
            let nodes = model.nodes(in: category)
            XCTAssertEqual(nodes.count, TraitCatalog.traits(in: category).count)
            // With no purchases yet, deeper nodes must read as locked.
            XCTAssertTrue(nodes.contains { $0.status == .locked })
        }
    }

    func testObjectivePressureIsExposedOnlyForChallenges() {
        XCTAssertNil(makeModel().objectivePressure)

        let challenge = makeModel(objective: .within(days: 40))
        XCTAssertNotNil(challenge.objectivePressure)
        XCTAssertEqual(challenge.isObjectiveIntact, true)
    }

    func testARegionAlwaysHasAState() {
        let model = makeModel()
        for id in RegionID.allCases {
            XCTAssertEqual(model.regionState(id).id, id)
        }
    }
}

/// The ad layer's policy, with no network involved.
final class AdManagerTests: XCTestCase {

    @MainActor
    func testInterstitialCompletionAlwaysRunsEvenWithNothingToShow() {
        let manager = AdManager(consent: ConsentManager(), adapter: DisabledAdAdapter())
        let finished = expectation(description: "completion ran")
        manager.presentInterstitial { finished.fulfill() }
        wait(for: [finished], timeout: 1)
    }

    @MainActor
    func testRewardedReportsFailureRatherThanHanging() {
        let manager = AdManager(consent: ConsentManager(), adapter: DisabledAdAdapter())
        let finished = expectation(description: "completion ran")
        manager.presentRewarded { granted in
            XCTAssertFalse(granted)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 1)
    }

    func testTestUnitsAreStillFlagged() {
        // Turns into a failing test the moment the real units go in, which is
        // the reminder to update docs/RELEASE.md and the Info.plist together.
        XCTAssertTrue(AdUnits.isUsingTestUnits)
        XCTAssertTrue(AdUnits.banner.hasPrefix("ca-app-pub-3940256099942544"))
    }
}
