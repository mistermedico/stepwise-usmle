import XCTest
@testable import YosufEngine

final class HandEvaluatorTests: XCTestCase {
    func testEmptyHandValueIsZero() {
        XCTAssertEqual(HandEvaluator.handValue([], aceHigh: false), 0)
    }

    func testEmptyHandIsAlwaysEligibleToDeclareYosuf() {
        XCTAssertTrue(HandEvaluator.isEligibleToDeclareYosuf(hand: [], profile: .classic))
    }

    func testHandValueSumsPointsCorrectly() {
        let hand = [Card.standard(.king, .hearts), .standard(.ace, .clubs), .joker(0)]
        XCTAssertEqual(HandEvaluator.handValue(hand, aceHigh: false), 11) // 10 + 1 + 0
    }

    func testAceHighChangesHandValue() {
        let hand = [Card.standard(.ace, .hearts)]
        XCTAssertEqual(HandEvaluator.handValue(hand, aceHigh: false), 1)
        XCTAssertEqual(HandEvaluator.handValue(hand, aceHigh: true), 15)
    }

    func testEligibilityBoundaryAtExactThreshold() {
        let hand = [Card.standard(.four, .hearts), .standard(.three, .clubs)] // = 7
        XCTAssertTrue(HandEvaluator.isEligibleToDeclareYosuf(hand: hand, profile: .classic))
    }

    func testEligibilityFailsOneAboveThreshold() {
        let hand = [Card.standard(.four, .hearts), .standard(.four, .clubs)] // = 8
        XCTAssertFalse(HandEvaluator.isEligibleToDeclareYosuf(hand: hand, profile: .classic))
    }

    func testHighestValueCardIgnoresJokers() {
        let hand = [Card.joker(0), .standard(.two, .hearts)]
        XCTAssertEqual(HandEvaluator.highestValueCard(in: hand, aceHigh: false)?.rank, .two)
    }

    func testHighestValueCardOnEmptyHandIsNil() {
        XCTAssertNil(HandEvaluator.highestValueCard(in: [], aceHigh: false))
    }

    func testDiscardPileCardWorthTakingWhenItCompletesAMeld() {
        let hand = [Card.standard(.five, .hearts), .standard(.five, .clubs)]
        let candidate = Card.standard(.five, .spades)
        XCTAssertTrue(HandEvaluator.isDiscardPileCardWorthTaking(candidate, currentHand: hand, profile: .classic))
    }

    func testDiscardPileCardNotWorthTakingWhenItHelpsNothing() {
        let hand = [Card.standard(.five, .hearts), .standard(.nine, .clubs)]
        let candidate = Card.standard(.two, .spades)
        XCTAssertFalse(HandEvaluator.isDiscardPileCardWorthTaking(candidate, currentHand: hand, profile: .classic))
    }
}
