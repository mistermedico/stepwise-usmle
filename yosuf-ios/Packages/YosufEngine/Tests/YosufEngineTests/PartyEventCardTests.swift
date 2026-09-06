import XCTest
@testable import YosufEngine

final class PartyEventCardTests: XCTestCase {
    func testNoEventProducesNeutralModifiers() {
        XCTAssertEqual(RoundModifiers.from(nil), .none)
    }

    func testEveryEventCaseProducesModifiersWithoutCrashing() {
        for event in PartyEventCard.allCases {
            let modifiers = RoundModifiers.from(event)
            XCTAssertEqual(modifiers.activeEvent, event)
        }
    }

    func testDoublePenaltyMultiplierIsTwo() {
        XCTAssertEqual(RoundModifiers.from(.doublePenalty).penaltyMultiplier, 2.0)
    }

    func testMercyRoundHalvesMultiplier() {
        XCTAssertEqual(RoundModifiers.from(.mercyRound).penaltyMultiplier, 0.5)
    }

    func testSkipNextPlayerSetsFlag() {
        XCTAssertTrue(RoundModifiers.from(.skipNextPlayer).skipsNextPlayer)
    }

    func testReverseOrderSetsFlag() {
        XCTAssertTrue(RoundModifiers.from(.reverseOrder).reversedOrder)
    }

    func testFreeOpeningDiscardSetsFlag() {
        XCTAssertTrue(RoundModifiers.from(.freeOpeningDiscard).freeOpeningDiscard)
    }
}
