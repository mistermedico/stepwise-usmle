import XCTest
@testable import PathogenProtocol

final class GameStateTests: XCTestCase {

    private func baseState() -> GameState {
        GameState(scenario: ScenarioCatalog.isolatedTerritory, strain: StrainCatalog.balanced, difficulty: .mild)
    }

    func testEffectiveTransmissionRateIncludesUpgrades() {
        var state = baseState()
        state.unlockedUpgradeIDs = ["transmission.1"]
        XCTAssertEqual(
            state.effectiveTransmissionRate,
            StrainCatalog.balanced.baseTransmissionRate + UpgradeCatalog.node("transmission.1")!.effect.transmissionRateBonus,
            accuracy: 0.0001
        )
    }

    func testHasLockdownBypassFalseByDefault() {
        XCTAssertFalse(baseState().hasLockdownBypass)
    }

    func testHasLockdownBypassTrueAfterTierFourResistance() {
        var state = baseState()
        state.unlockedUpgradeIDs = ["resistance.4"]
        XCTAssertTrue(state.hasLockdownBypass)
    }

    func testGlobalInfectionFractionZeroAtStartIsNearZeroNotExactlyZero() {
        // Patient zero always starts with a small seed, so this is > 0 but tiny.
        let state = baseState()
        XCTAssertGreaterThan(state.globalInfectionFraction, 0)
        XCTAssertLessThan(state.globalInfectionFraction, 0.01)
    }

    func testGlobalInfectionFractionOneWhenFullyInfected() {
        var state = baseState()
        for id in state.regionStates.keys {
            state.regionStates[id]?.infectionLevel = 1.0
        }
        XCTAssertEqual(state.globalInfectionFraction, 1.0, accuracy: 0.0001)
    }

    func testProjectedCureDayNilBeforeActivation() {
        XCTAssertNil(baseState().projectedCureDay)
    }

    func testProjectedCureDayIsExactAndFixed() {
        var state = baseState()
        state.day = 5
        state.isResearchActive = true
        state.researchActivatedOnDay = 5
        state.researchProgress = 0
        // mild: rate 3.0/day, threshold 100 -> ceil(100/3) = 34 days after activation.
        XCTAssertEqual(state.projectedCureDay, 5 + 34)
    }

    func testProjectedCureDayShrinksAsProgressAccrues() {
        var state = baseState()
        state.isResearchActive = true
        state.researchActivatedOnDay = 0
        state.researchProgress = 97 // 1 day left at 3.0/day
        XCTAssertEqual(state.projectedCureDay, 1)
    }
}
