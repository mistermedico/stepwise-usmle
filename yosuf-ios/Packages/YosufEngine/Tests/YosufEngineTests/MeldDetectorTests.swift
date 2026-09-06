import XCTest
@testable import YosufEngine

final class MeldDetectorTests: XCTestCase {
    // MARK: Sets

    func testValidSetSameRankDifferentSuits() {
        let cards = [Card.standard(.seven, .hearts), .standard(.seven, .clubs), .standard(.seven, .spades)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .set)
    }

    func testSetRejectsMixedRanks() {
        let cards = [Card.standard(.seven, .hearts), .standard(.eight, .clubs), .standard(.seven, .spades)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 3))
    }

    func testSetWithJokerWildcard() {
        let cards = [Card.standard(.nine, .hearts), .standard(.nine, .clubs), .joker(0)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .set)
    }

    // MARK: Runs

    func testValidRunSameSuitConsecutive() {
        let cards = [Card.standard(.four, .diamonds), .standard(.five, .diamonds), .standard(.six, .diamonds)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .run)
    }

    func testRunRejectsMixedSuits() {
        let cards = [Card.standard(.four, .diamonds), .standard(.five, .hearts), .standard(.six, .diamonds)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 3))
    }

    func testRunRejectsDuplicateRank() {
        let cards = [Card.standard(.four, .diamonds), .standard(.four, .diamonds), .standard(.six, .diamonds)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 3))
    }

    func testRunWithJokerFillingInternalGap() {
        // 4, [joker as 5], 6 of diamonds
        let cards = [Card.standard(.four, .diamonds), .joker(0), .standard(.six, .diamonds)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .run)
    }

    func testRunCannotExceedTheFullAceToKingSpanEvenWithAJoker() {
        // A run already covering every rank Ace...King (13 cards) leaves zero
        // room for an extra joker on either end — it must be rejected rather
        // than silently accepted or index out of range.
        let fullSuitRun = Rank.allCases.map { Card.standard($0, .diamonds) }
        let cards = fullSuitRun + [.joker(0)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 14))
    }

    func testJokerCorrectlyFillsDownwardWhenTopOfRangeIsPinned() {
        // King pinned at the top; jokers should be recognized as extending
        // downward (Jack, Queen, King) rather than being rejected outright.
        let cards = [Card.standard(.queen, .spades), .standard(.king, .spades), .joker(0)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .run)
    }

    func testJokerCorrectlyFillsUpwardWhenBottomOfRangeIsPinned() {
        // Ace pinned at the bottom; the joker should extend upward
        // (Ace, 2, 3) rather than being rejected outright.
        let cards = [Card.standard(.ace, .clubs), .standard(.two, .clubs), .joker(0)]
        XCTAssertEqual(MeldDetector.validate(cards, minMeldSize: 3), .run)
    }

    // MARK: Edge cases

    func testAllJokersIsAmbiguousAndInvalid() {
        let cards = [Card.joker(0), Card.joker(1)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 3))
    }

    func testBelowMinimumSizeIsInvalid() {
        let cards = [Card.standard(.seven, .hearts), .standard(.seven, .clubs)]
        XCTAssertNil(MeldDetector.validate(cards, minMeldSize: 3))
    }

    func testEmptyHandProducesNoMelds() {
        XCTAssertTrue(MeldDetector.allMelds(in: [], minMeldSize: 3).isEmpty)
        XCTAssertNil(MeldDetector.bestMeld(in: [], minMeldSize: 3))
    }

    func testDuplicatePhysicalCardRejected() {
        let card = Card.standard(.seven, .hearts)
        XCTAssertNil(MeldDetector.validate([card, card, card], minMeldSize: 3))
    }

    func testBestMeldPicksHighestPointValue() {
        // set of three 7s (21 pts) vs run of 2,3,4 (9 pts) - within a 6-card hand
        let hand = [
            Card.standard(.seven, .hearts), .standard(.seven, .clubs), .standard(.seven, .spades),
            .standard(.two, .diamonds), .standard(.three, .diamonds), .standard(.four, .diamonds)
        ]
        let best = MeldDetector.bestMeld(in: hand, minMeldSize: 3)
        XCTAssertEqual(best?.totalPointValue, 21)
        XCTAssertEqual(best?.kind, .set)
    }
}
