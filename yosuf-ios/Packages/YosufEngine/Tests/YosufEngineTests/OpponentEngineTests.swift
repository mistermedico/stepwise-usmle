import XCTest
@testable import YosufEngine

final class OpponentEngineTests: XCTestCase {

    func testBotDeclaresYosufWhenEligibleAndNoCautionDelay() {
        var memory = OpponentMemory()
        let botID = PlayerID()
        let hand = [Card.standard(.two, .hearts)] // value 2, well under any threshold
        let action = OpponentEngine.decideDrawAction(
            botID: botID, hand: hand, topDiscard: nil,
            difficulty: .expert, personality: .balanced, profile: .classic, memory: &memory
        )
        XCTAssertEqual(action, .declareYosuf)
    }

    func testBotWithCautionDelayWaitsBeforeDeclaring() {
        var memory = OpponentMemory()
        let botID = PlayerID()
        let hand = [Card.standard(.two, .hearts)]
        // intermediate has cautionDelayTurns == 1: first eligible turn should NOT declare yet.
        let firstAction = OpponentEngine.decideDrawAction(
            botID: botID, hand: hand, topDiscard: nil,
            difficulty: .intermediate, personality: .balanced, profile: .classic, memory: &memory
        )
        XCTAssertNotEqual(firstAction, .declareYosuf)

        let secondAction = OpponentEngine.decideDrawAction(
            botID: botID, hand: hand, topDiscard: nil,
            difficulty: .intermediate, personality: .balanced, profile: .classic, memory: &memory
        )
        XCTAssertEqual(secondAction, .declareYosuf)
    }

    func testMemoryResetsWhenNoLongerEligible() {
        var memory = OpponentMemory()
        let botID = PlayerID()
        let lowHand = [Card.standard(.two, .hearts)]
        let highHand = [Card.standard(.king, .hearts), .standard(.king, .clubs)]

        _ = OpponentEngine.decideDrawAction(
            botID: botID, hand: lowHand, topDiscard: nil,
            difficulty: .intermediate, personality: .balanced, profile: .classic, memory: &memory
        )
        XCTAssertEqual(memory.consecutiveEligibleTurns[botID], 1)

        _ = OpponentEngine.decideDrawAction(
            botID: botID, hand: highHand, topDiscard: nil,
            difficulty: .intermediate, personality: .balanced, profile: .classic, memory: &memory
        )
        XCTAssertEqual(memory.consecutiveEligibleTurns[botID], 0)
    }

    func testAggressivePersonalityCallsEarlierThanCautiousOfSameTier() {
        // Beginner base threshold is 5. Cautious adjusts to 4 (won't call at
        // hand value 6); aggressive adjusts to 6 (will call, beginner has no
        // caution delay so it fires immediately once eligible).
        var cautiousMemory = OpponentMemory()
        var aggressiveMemory = OpponentMemory()
        let botID = PlayerID()
        let hand = [Card.standard(.six, .hearts)] // value 6

        let cautious = OpponentEngine.decideDrawAction(
            botID: botID, hand: hand, topDiscard: nil,
            difficulty: .beginner, personality: .cautious, profile: .classic, memory: &cautiousMemory
        )
        let aggressive = OpponentEngine.decideDrawAction(
            botID: botID, hand: hand, topDiscard: nil,
            difficulty: .beginner, personality: .aggressive, profile: .classic, memory: &aggressiveMemory
        )
        XCTAssertNotEqual(cautious, .declareYosuf)
        XCTAssertEqual(aggressive, .declareYosuf)
    }

    func testDiscardPrefersBestMeldOverSingleCard() {
        let hand = [
            Card.standard(.seven, .hearts), .standard(.seven, .clubs), .standard(.seven, .spades),
            .standard(.king, .diamonds)
        ]
        let discarded = OpponentEngine.decideDiscard(hand: hand, difficulty: .beginner, profile: .classic)
        XCTAssertEqual(Set(discarded.map(\.kind)), Set([
            Card.standard(.seven, .hearts).kind, Card.standard(.seven, .clubs).kind, Card.standard(.seven, .spades).kind
        ]))
    }

    func testDiscardFallsBackToHighestSingleCardWhenNoMeld() {
        let hand = [Card.standard(.two, .hearts), .standard(.king, .clubs), .standard(.five, .diamonds)]
        let discarded = OpponentEngine.decideDiscard(hand: hand, difficulty: .beginner, profile: .classic)
        XCTAssertEqual(discarded.count, 1)
        XCTAssertEqual(discarded.first?.rank, .king)
    }

    func testAdvancedDifficultyBreaksHighCardTiesByConnection() {
        // Two sevens tie for highest value. The seven of hearts sits next to
        // a six of hearts (same suit, adjacent rank - a near-run), while the
        // seven of clubs has no such neighbor. An advanced bot should keep
        // the more "connected" card and discard the isolated one instead.
        let hand = [
            Card.standard(.seven, .hearts), .standard(.six, .hearts),
            Card.standard(.seven, .clubs),
            .standard(.two, .diamonds)
        ]
        let discarded = OpponentEngine.decideDiscard(hand: hand, difficulty: .advanced, profile: .classic)
        XCTAssertEqual(discarded.first?.suit, .clubs)
    }

    func testSingleCardHandAlwaysDiscardsThatCard() {
        let hand = [Card.standard(.nine, .hearts)]
        let discarded = OpponentEngine.decideDiscard(hand: hand, difficulty: .expert, profile: .classic)
        XCTAssertEqual(discarded.map(\.kind), [Card.standard(.nine, .hearts).kind])
    }
}
