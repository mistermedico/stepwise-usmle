import XCTest
@testable import PathogenProtocol

final class OutbreakSimulationEngineTests: XCTestCase {

    private func freshState(difficulty: DifficultyLevel = .challenging) -> GameState {
        GameState(scenario: ScenarioCatalog.isolatedTerritory, strain: StrainCatalog.balanced, difficulty: difficulty)
    }

    func testAdvanceOneDayIncrementsDay() {
        let state = freshState()
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        XCTAssertEqual(next.day, state.day + 1)
    }

    func testAdvanceOneDayIsNoOpOnceOutcomeIsSet() {
        var state = freshState()
        state.outcome = .victory
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        XCTAssertEqual(next.day, state.day)
        XCTAssertEqual(next, state)
    }

    func testAdvanceOneDayGrowsInfectionInStartingRegion() {
        let state = freshState()
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        let startRegion = state.scenario.startingRegionID
        XCTAssertGreaterThan(next.regionStates[startRegion]!.infectionLevel, state.regionStates[startRegion]!.infectionLevel)
    }

    func testAdvanceOneDayNeverInfectsBeyondFullSaturation() {
        var state = freshState()
        for id in state.regionStates.keys {
            state.regionStates[id]?.infectionLevel = 1.0
        }
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        for regionState in next.regionStates.values {
            XCTAssertLessThanOrEqual(regionState.infectionLevel, 1.0)
        }
    }

    func testAdvanceOneDayAppendsExactlyOneHistoryEntry() {
        let state = freshState()
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        XCTAssertEqual(next.history.count, state.history.count + 1)
        XCTAssertEqual(next.history.last?.day, next.day)
    }

    func testAdvanceOneDayAwardsEvolutionPoints() {
        let state = freshState(difficulty: .mild)
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        XCTAssertEqual(next.evolutionPoints, state.evolutionPoints + DifficultyLevel.mild.baseEvolutionPointsPerDay, accuracy: 0.0001)
    }

    func testLockedDownRegionDoesNotSpreadToNeighborsWithoutBypass() {
        var state = freshState()
        var start = state.regionStates["outland"]!
        start.infectionLevel = 0.9
        start.isLockedDown = true
        state.regionStates["outland"] = start

        let next = OutbreakSimulationEngine.advanceOneDay(state)

        XCTAssertEqual(next.regionStates["gatecross"]!.infectionLevel, 0)
    }

    func testLockdownBypassUpgradeAllowsContinuedSpread() {
        var state = freshState()
        state.unlockedUpgradeIDs = ["resistance.1", "resistance.2", "resistance.3", "resistance.4"]
        var start = state.regionStates["outland"]!
        start.infectionLevel = 0.9
        start.isLockedDown = true
        state.regionStates["outland"] = start

        let next = OutbreakSimulationEngine.advanceOneDay(state)

        XCTAssertGreaterThan(next.regionStates["gatecross"]!.infectionLevel, 0)
    }

    func testPurchaseUpgradeSucceedsWithEnoughPointsAndPrerequisite() {
        var state = freshState()
        state.evolutionPoints = 100
        let next = OutbreakSimulationEngine.purchaseUpgrade(state, nodeID: "transmission.1")
        XCTAssertTrue(next.unlockedUpgradeIDs.contains("transmission.1"))
        XCTAssertEqual(next.evolutionPoints, 100 - Double(UpgradeCatalog.node("transmission.1")!.cost))
    }

    func testPurchaseUpgradeFailsWithoutEnoughPoints() {
        var state = freshState()
        state.evolutionPoints = 1
        let next = OutbreakSimulationEngine.purchaseUpgrade(state, nodeID: "transmission.1")
        XCTAssertFalse(next.unlockedUpgradeIDs.contains("transmission.1"))
        XCTAssertEqual(next.evolutionPoints, 1)
    }

    func testPurchaseUpgradeFailsWithoutPrerequisite() {
        var state = freshState()
        state.evolutionPoints = 1000
        let next = OutbreakSimulationEngine.purchaseUpgrade(state, nodeID: "transmission.2")
        XCTAssertFalse(next.unlockedUpgradeIDs.contains("transmission.2"))
        XCTAssertEqual(next.evolutionPoints, 1000)
    }

    func testPurchaseUpgradeFailsWhenAlreadyUnlocked() {
        var state = freshState()
        state.evolutionPoints = 1000
        state.unlockedUpgradeIDs.insert("transmission.1")
        let pointsBefore = state.evolutionPoints
        let next = OutbreakSimulationEngine.purchaseUpgrade(state, nodeID: "transmission.1")
        XCTAssertEqual(next.evolutionPoints, pointsBefore)
    }

    // A full deterministic playthrough on mild difficulty must terminate (win or lose)
    // in a bounded number of days — guards against an infinite/stuck simulation loop.
    func testFullPlaythroughTerminates() {
        var state = freshState(difficulty: .mild)
        var iterations = 0
        while state.isRunning && iterations < 500 {
            state = OutbreakSimulationEngine.advanceOneDay(state)
            iterations += 1
        }
        XCTAssertNotNil(state.outcome)
        XCTAssertLessThan(iterations, 500)
    }

    // Same starting state, same sequence of days, must produce an identical result —
    // the whole engine has to be deterministic for daily challenges to be fair.
    func testIdenticalStartsProduceIdenticalOutcomes() {
        let stateA = freshState(difficulty: .challenging)
        let stateB = freshState(difficulty: .challenging)
        var runA = stateA
        var runB = stateB
        for _ in 0..<30 {
            runA = OutbreakSimulationEngine.advanceOneDay(runA)
            runB = OutbreakSimulationEngine.advanceOneDay(runB)
        }
        XCTAssertEqual(runA, runB)
    }
}
