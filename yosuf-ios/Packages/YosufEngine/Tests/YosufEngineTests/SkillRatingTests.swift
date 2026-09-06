import XCTest
@testable import YosufEngine

final class SkillRatingTests: XCTestCase {
    func testWinningAgainstAHarderBotGainsMoreRating() {
        let gainVsExpert = SkillRating.updatedRating(current: 1000, opponentDifficulty: .expert, didWin: true) - 1000
        let gainVsBeginner = SkillRating.updatedRating(current: 1000, opponentDifficulty: .beginner, didWin: true) - 1000
        XCTAssertGreaterThan(gainVsExpert, gainVsBeginner)
    }

    func testLosingAlwaysDecreasesOrHoldsRating() {
        let result = SkillRating.updatedRating(current: 1000, opponentDifficulty: .intermediate, didWin: false)
        XCTAssertLessThanOrEqual(result, 1000)
    }

    func testRatingNeverGoesNegative() {
        let result = SkillRating.updatedRating(current: 0, opponentDifficulty: .expert, didWin: false)
        XCTAssertGreaterThanOrEqual(result, 0)
    }

    func testRankTierBoundaries() {
        XCTAssertEqual(RankTier.forRating(0), .bronze)
        XCTAssertEqual(RankTier.forRating(999), .bronze)
        XCTAssertEqual(RankTier.forRating(1000), .silver)
        XCTAssertEqual(RankTier.forRating(2100), .champion)
        XCTAssertEqual(RankTier.forRating(999_999), .champion)
    }

    func testPointsToNextTier() {
        XCTAssertEqual(RankTier.bronze.pointsToNext(from: 800), 200)
        XCTAssertNil(RankTier.champion.pointsToNext(from: 5000))
    }
}
