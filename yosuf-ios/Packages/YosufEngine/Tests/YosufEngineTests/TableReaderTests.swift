import XCTest
@testable import YosufEngine

final class TableReaderTests: XCTestCase {
    func testFlagsOwnHandCloseToThreshold() {
        let observer = PlayerID()
        let hints = TableReader.generateHints(
            observerID: observer,
            observerHand: [.standard(.four, .hearts), .standard(.four, .clubs)], // value 8, margin 1
            publicPlayerCardCounts: [(observer, 2)],
            discardHistory: [],
            profile: .classic
        )
        XCTAssertTrue(hints.contains(.yourHandIsClose(margin: 1)))
    }

    func testDoesNotFlagOwnHandWhenFarFromThreshold() {
        let observer = PlayerID()
        let hints = TableReader.generateHints(
            observerID: observer,
            observerHand: [.standard(.king, .hearts), .standard(.king, .clubs)], // value 20
            publicPlayerCardCounts: [(observer, 2)],
            discardHistory: [],
            profile: .classic
        )
        XCTAssertFalse(hints.contains(where: { if case .yourHandIsClose = $0 { return true }; return false }))
    }

    func testFlagsOpponentWithFewerCardsThanDealt() {
        let observer = PlayerID()
        let opponent = PlayerID()
        let hints = TableReader.generateHints(
            observerID: observer,
            observerHand: [.standard(.king, .hearts)],
            publicPlayerCardCounts: [(observer, 1), (opponent, 2)],
            discardHistory: [],
            profile: .classic
        )
        XCTAssertTrue(hints.contains(.opponentLikelyClose(playerID: opponent, cardCount: 2)))
    }

    func testDoesNotFlagOpponentAtFullHandSize() {
        let observer = PlayerID()
        let opponent = PlayerID()
        let hints = TableReader.generateHints(
            observerID: observer,
            observerHand: [.standard(.king, .hearts)],
            publicPlayerCardCounts: [(observer, 1), (opponent, 5)],
            discardHistory: [],
            profile: .classic
        )
        XCTAssertFalse(hints.contains(where: {
            if case .opponentLikelyClose = $0 { return true }; return false
        }))
    }

    func testFlagsRunningColdRankAfterTwoConsecutiveDiscards() {
        let hints = TableReader.generateHints(
            observerID: PlayerID(),
            observerHand: [],
            publicPlayerCardCounts: [],
            discardHistory: [.standard(.four, .hearts), .standard(.four, .clubs), .standard(.nine, .spades)],
            profile: .classic
        )
        XCTAssertTrue(hints.contains(.rankRunningCold(rank: .four)))
    }

    func testDoesNotFlagColdRankForASingleDiscard() {
        let hints = TableReader.generateHints(
            observerID: PlayerID(),
            observerHand: [],
            publicPlayerCardCounts: [],
            discardHistory: [.standard(.four, .hearts), .standard(.nine, .spades)],
            profile: .classic
        )
        XCTAssertFalse(hints.contains(where: { if case .rankRunningCold = $0 { return true }; return false }))
    }

    func testFlagsUnclaimedJokerOnTopOfDiscard() {
        let hints = TableReader.generateHints(
            observerID: PlayerID(),
            observerHand: [],
            publicPlayerCardCounts: [],
            discardHistory: [.joker(0)],
            profile: .classic
        )
        XCTAssertTrue(hints.contains(.unclaimedJokerOnTop))
    }

    func testEmptyDiscardHistoryProducesNoDiscardBasedHints() {
        let hints = TableReader.generateHints(
            observerID: PlayerID(),
            observerHand: [.standard(.two, .hearts)],
            publicPlayerCardCounts: [],
            discardHistory: [],
            profile: .classic
        )
        XCTAssertFalse(hints.contains(.unclaimedJokerOnTop))
        XCTAssertFalse(hints.contains(where: { if case .rankRunningCold = $0 { return true }; return false }))
    }
}
