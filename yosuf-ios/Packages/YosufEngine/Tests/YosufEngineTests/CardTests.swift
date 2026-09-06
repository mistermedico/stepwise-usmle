import XCTest
@testable import YosufEngine

final class CardTests: XCTestCase {
    func testStandardCardPointValues() {
        XCTAssertEqual(Card.standard(.ace, .hearts).pointValue(aceHigh: false), 1)
        XCTAssertEqual(Card.standard(.ace, .hearts).pointValue(aceHigh: true), 15)
        XCTAssertEqual(Card.standard(.seven, .clubs).pointValue(), 7)
        XCTAssertEqual(Card.standard(.jack, .spades).pointValue(), 10)
        XCTAssertEqual(Card.standard(.queen, .spades).pointValue(), 10)
        XCTAssertEqual(Card.standard(.king, .spades).pointValue(), 10)
    }

    func testJokerAlwaysWorthZero() {
        XCTAssertEqual(Card.joker(0).pointValue(aceHigh: true), 0)
        XCTAssertEqual(Card.joker(1).pointValue(aceHigh: false), 0)
        XCTAssertTrue(Card.joker(0).isJoker)
        XCTAssertNil(Card.joker(0).rank)
        XCTAssertNil(Card.joker(0).suit)
    }

    func testFullDeckHas54UniqueCards() {
        let deck = Deck.fullDeck()
        XCTAssertEqual(deck.count, 54)
        XCTAssertEqual(Set(deck.cards.map(\.id)).count, 54)
        XCTAssertEqual(deck.cards.filter(\.isJoker).count, 2)
    }

    func testDeckDrawFromEmptyReturnsNilNotCrash() {
        var deck = Deck(cards: [])
        XCTAssertNil(deck.drawTop())
        XCTAssertTrue(deck.isEmpty)
    }

    func testDeterministicShuffleIsReproducible() {
        var genA = SeededGenerator(seed: 42)
        var genB = SeededGenerator(seed: 42)
        var deckA = Deck.fullDeck()
        var deckB = Deck.fullDeck()
        deckA.shuffle(using: &genA)
        deckB.shuffle(using: &genB)
        XCTAssertEqual(deckA.cards.map(\.kind), deckB.cards.map(\.kind))
    }
}
