import XCTest
@testable import PathogenProtocol

final class ReportAnalyzerTests: XCTestCase {

    private func baseState() -> GameState {
        GameState(scenario: ScenarioCatalog.isolatedTerritory, strain: StrainCatalog.balanced, difficulty: .challenging)
    }

    func testNilWhileRunning() {
        XCTAssertNil(ReportAnalyzer.character(for: baseState()))
    }

    func testSilentOutbreakForLowPeakAwarenessVictory() {
        var state = baseState()
        state.outcome = .victory
        state.day = 20
        state.history = [DaySnapshot(day: 1, globalInfectionFraction: 1, globalAwareness: 0.1, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 0)]
        XCTAssertEqual(ReportAnalyzer.character(for: state), .silentOutbreak)
    }

    func testLightningOutbreakForFastHighAwarenessVictory() {
        var state = baseState()
        state.outcome = .victory
        state.day = 10
        state.history = [DaySnapshot(day: 1, globalInfectionFraction: 1, globalAwareness: 0.9, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 0)]
        XCTAssertEqual(ReportAnalyzer.character(for: state), .lightningOutbreak)
    }

    func testGrindingSiegeForSlowHighAwarenessVictory() {
        var state = baseState()
        state.outcome = .victory
        state.day = 40
        state.history = [DaySnapshot(day: 1, globalInfectionFraction: 1, globalAwareness: 0.9, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 3)]
        XCTAssertEqual(ReportAnalyzer.character(for: state), .grindingSiege)
    }

    func testNearMissForDefeatWithHighFinalInfection() {
        var state = baseState()
        state.outcome = .defeat
        state.day = 25
        for id in state.regionStates.keys {
            state.regionStates[id]?.infectionLevel = 0.9
        }
        XCTAssertEqual(ReportAnalyzer.character(for: state), .nearMiss)
    }

    func testContainedEarlyForFastLowInfectionDefeat() {
        var state = baseState()
        state.outcome = .defeat
        state.day = 3
        XCTAssertEqual(ReportAnalyzer.character(for: state), .containedEarly)
    }

    func testSummarizeReturnsNilWhileRunning() {
        XCTAssertNil(ReportAnalyzer.summarize(baseState()))
    }

    func testSummarizeMatchesCharacter() {
        var state = baseState()
        state.outcome = .victory
        state.day = 5
        state.history = [DaySnapshot(day: 1, globalInfectionFraction: 1, globalAwareness: 0.1, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 0)]
        let summary = ReportAnalyzer.summarize(state)
        XCTAssertEqual(summary?.character, .silentOutbreak)
        XCTAssertEqual(summary?.outcome, .victory)
        XCTAssertEqual(summary?.totalDays, 5)
    }
}
