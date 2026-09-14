import XCTest
@testable import PathogenProtocol

final class AchievementEvaluatorTests: XCTestCase {

    private func baseState() -> GameState {
        GameState(scenario: ScenarioCatalog.isolatedTerritory, strain: StrainCatalog.balanced, difficulty: .challenging)
    }

    func testNoAchievementsWhileRunning() {
        XCTAssertTrue(AchievementEvaluator.earnedAchievements(for: baseState()).isEmpty)
    }

    func testFirstRunAlwaysAwardedOnAnyFinish() {
        var state = baseState()
        state.outcome = .defeat
        XCTAssertTrue(AchievementEvaluator.earnedAchievements(for: state).contains(AchievementCatalog.firstRun.id))
    }

    func testDefeatNeverAwardsVictoryOnlyAchievements() {
        var state = baseState()
        state.outcome = .defeat
        let earned = AchievementEvaluator.earnedAchievements(for: state)
        XCTAssertFalse(earned.contains(AchievementCatalog.silentVictory.id))
        XCTAssertFalse(earned.contains(AchievementCatalog.noLockdownVictory.id))
    }

    func testNoLockdownVictoryAchievement() {
        var state = baseState()
        state.outcome = .victory
        state.day = 30
        state.history = [DaySnapshot(day: 1, globalInfectionFraction: 1, globalAwareness: 0.9, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 0)]
        XCTAssertTrue(AchievementEvaluator.earnedAchievements(for: state).contains(AchievementCatalog.noLockdownVictory.id))
    }

    func testNoLockdownAchievementNotAwardedIfAnyDayHadALockdown() {
        var state = baseState()
        state.outcome = .victory
        state.day = 30
        state.history = [
            DaySnapshot(day: 1, globalInfectionFraction: 0.2, globalAwareness: 0.9, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 0),
            DaySnapshot(day: 2, globalInfectionFraction: 1, globalAwareness: 0.9, researchProgress: 0, regionsInfected: 6, regionsLockedDown: 1),
        ]
        XCTAssertFalse(AchievementEvaluator.earnedAchievements(for: state).contains(AchievementCatalog.noLockdownVictory.id))
    }

    func testAllBranchesMaxedAchievement() {
        var state = baseState()
        state.outcome = .victory
        state.day = 30
        state.unlockedUpgradeIDs = Set(UpgradeCatalog.allNodes.map(\.id))
        XCTAssertTrue(AchievementEvaluator.earnedAchievements(for: state).contains(AchievementCatalog.allBranchesMaxed.id))
    }

    func testAllBranchesMaxedNotAwardedWhenOneBranchIncomplete() {
        var state = baseState()
        state.outcome = .victory
        state.day = 30
        state.unlockedUpgradeIDs = Set(UpgradeCatalog.allNodes.filter { $0.category != .symptoms }.map(\.id))
        XCTAssertFalse(AchievementEvaluator.earnedAchievements(for: state).contains(AchievementCatalog.allBranchesMaxed.id))
    }
}
