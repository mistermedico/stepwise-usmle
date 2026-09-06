import XCTest
@testable import PathogenProtocol

final class WorldResponseEngineTests: XCTestCase {

    private func freshState(difficulty: DifficultyLevel = .challenging) -> GameState {
        GameState(scenario: ScenarioCatalog.isolatedTerritory, strain: StrainCatalog.balanced, difficulty: difficulty)
    }

    // Rule 1/2: awareness should not move at all in a region with zero infection.
    func testAwarenessStaysZeroWithNoInfection() {
        var state = freshState()
        state.regionStates["gatecross"] = .clean
        WorldResponseEngine.updateAwareness(&state)
        XCTAssertEqual(state.regionStates["gatecross"]?.awarenessLevel, 0)
        XCTAssertEqual(state.globalAwareness, 0)
    }

    // Rule 2: a discovered, infected region's awareness must strictly increase.
    func testAwarenessIncreasesForDiscoveredInfectedRegion() {
        var state = freshState()
        var start = state.regionStates["outland"]!
        start.infectionLevel = 0.3
        start.isDiscovered = true
        state.regionStates["outland"] = start

        WorldResponseEngine.updateAwareness(&state)

        XCTAssertGreaterThan(state.regionStates["outland"]!.awarenessLevel, 0)
        XCTAssertGreaterThan(state.globalAwareness, 0)
    }

    // Rule 2: a region only auto-discovers past the 5% infection visibility threshold.
    func testRegionDiscoveryThreshold() {
        var state = freshState()
        var start = state.regionStates["outland"]!
        start.infectionLevel = 0.04
        state.regionStates["outland"] = start
        WorldResponseEngine.updateAwareness(&state)
        XCTAssertFalse(state.regionStates["outland"]!.isDiscovered)

        start.infectionLevel = 0.06
        state.regionStates["outland"] = start
        WorldResponseEngine.updateAwareness(&state)
        XCTAssertTrue(state.regionStates["outland"]!.isDiscovered)
    }

    // Rule 2: detection-resistance upgrades must dampen the awareness gain.
    func testDetectionResistanceDampensAwarenessGain() {
        func awarenessAfterOneTick(withResistanceUpgrade: Bool) -> Double {
            var state = freshState()
            var start = state.regionStates["outland"]!
            start.infectionLevel = 0.5
            start.isDiscovered = true
            state.regionStates["outland"] = start
            if withResistanceUpgrade {
                state.unlockedUpgradeIDs.insert("resistance.1")
            }
            WorldResponseEngine.updateAwareness(&state)
            return state.regionStates["outland"]!.awarenessLevel
        }

        let withoutUpgrade = awarenessAfterOneTick(withResistanceUpgrade: false)
        let withUpgrade = awarenessAfterOneTick(withResistanceUpgrade: true)
        XCTAssertLessThan(withUpgrade, withoutUpgrade)
    }

    // Rule 3: research must stay inactive below the fixed activation threshold.
    func testResearchStaysInactiveBelowThreshold() {
        var state = freshState()
        state.globalAwareness = WorldResponseRules.researchActivationThreshold - 0.05
        WorldResponseEngine.updateResearch(&state)
        XCTAssertFalse(state.isResearchActive)
        XCTAssertEqual(state.researchProgress, 0)
    }

    // Rule 3: crossing the threshold activates research and immediately applies one
    // fixed day of accrual at the difficulty's constant daily rate.
    func testResearchActivatesAndAccruesAtFixedRate() {
        var state = freshState(difficulty: .mild)
        state.day = 7
        state.globalAwareness = WorldResponseRules.researchActivationThreshold + 0.01
        WorldResponseEngine.updateResearch(&state)
        XCTAssertTrue(state.isResearchActive)
        XCTAssertEqual(state.researchActivatedOnDay, 7)
        XCTAssertEqual(state.researchProgress, DifficultyLevel.mild.dailyResearchRate, accuracy: 0.0001)
    }

    // Rule 3: the accrual rate never varies once active — same input state, same output.
    func testResearchAccrualIsDeterministic() {
        var stateA = freshState(difficulty: .lethal)
        stateA.isResearchActive = true
        stateA.researchProgress = 10
        var stateB = stateA

        WorldResponseEngine.updateResearch(&stateA)
        WorldResponseEngine.updateResearch(&stateB)

        XCTAssertEqual(stateA.researchProgress, stateB.researchProgress)
    }

    // Rule 3: research progress must never exceed the completion threshold.
    func testResearchProgressClampsAtCompletionThreshold() {
        var state = freshState(difficulty: .mild)
        state.isResearchActive = true
        state.researchProgress = DifficultyLevel.mild.researchCompletionThreshold - 1
        WorldResponseEngine.updateResearch(&state)
        XCTAssertEqual(state.researchProgress, DifficultyLevel.mild.researchCompletionThreshold)
    }

    // Rule 4: a region locks down once its own awareness crosses the difficulty threshold.
    func testLockdownFiresAboveThreshold() {
        var state = freshState(difficulty: .challenging)
        var region = state.regionStates["outland"]!
        region.awarenessLevel = DifficultyLevel.challenging.lockdownAwarenessThreshold + 0.01
        state.regionStates["outland"] = region

        WorldResponseEngine.applyLockdowns(&state)

        XCTAssertTrue(state.regionStates["outland"]!.isLockedDown)
    }

    func testLockdownDoesNotFireBelowThreshold() {
        var state = freshState(difficulty: .challenging)
        var region = state.regionStates["outland"]!
        region.awarenessLevel = DifficultyLevel.challenging.lockdownAwarenessThreshold - 0.01
        state.regionStates["outland"] = region

        WorldResponseEngine.applyLockdowns(&state)

        XCTAssertFalse(state.regionStates["outland"]!.isLockedDown)
    }

    // Rule 4: a lockdown-bypass upgrade must prevent every lockdown, even above threshold.
    func testLockdownBypassPreventsAllLockdowns() {
        var state = freshState(difficulty: .challenging)
        state.unlockedUpgradeIDs = ["resistance.1", "resistance.2", "resistance.3", "resistance.4"]
        var region = state.regionStates["outland"]!
        region.awarenessLevel = 1.0
        state.regionStates["outland"] = region

        WorldResponseEngine.applyLockdowns(&state)

        XCTAssertFalse(state.regionStates["outland"]!.isLockedDown)
    }

    // Rule 5: victory fires once global infection crosses the fixed threshold.
    func testEvaluateOutcomeVictory() {
        var state = freshState()
        for id in state.regionStates.keys {
            state.regionStates[id]?.infectionLevel = 1.0
        }
        XCTAssertEqual(WorldResponseEngine.evaluateOutcome(state), .victory)
    }

    // Rule 5: defeat fires once research progress reaches the fixed completion threshold.
    func testEvaluateOutcomeDefeat() {
        var state = freshState(difficulty: .mild)
        state.researchProgress = DifficultyLevel.mild.researchCompletionThreshold
        XCTAssertEqual(WorldResponseEngine.evaluateOutcome(state), .defeat)
    }

    func testEvaluateOutcomeNilWhileRunning() {
        let state = freshState()
        XCTAssertNil(WorldResponseEngine.evaluateOutcome(state))
    }
}
