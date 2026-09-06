import Foundation

/// A stack of cards. Used for both the closed draw pile and (as a single
/// top card + history) the discard pile.
public struct Deck: Codable, Sendable {
    public private(set) var cards: [Card]

    public init(cards: [Card]) {
        self.cards = cards
    }

    /// Builds a full 54-card deck (52 standard + 2 jokers), unshuffled.
    public static func fullDeck() -> Deck {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(.standard(rank, suit))
            }
        }
        cards.append(.joker(0))
        cards.append(.joker(1))
        return Deck(cards: cards)
    }

    public var isEmpty: Bool { cards.isEmpty }
    public var count: Int { cards.count }

    public mutating func shuffle(using generator: inout some RandomNumberGenerator) {
        cards.shuffle(using: &generator)
    }

    public mutating func shuffle() {
        cards.shuffle()
    }

    /// Draws the top card. Returns nil on an empty deck — callers must
    /// handle this explicitly (e.g. reshuffle the discard pile).
    public mutating func drawTop() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    public mutating func push(_ card: Card) {
        cards.insert(card, at: 0)
    }

    public mutating func push(contentsOf newCards: [Card]) {
        cards.insert(contentsOf: newCards, at: 0)
    }

    public var top: Card? { cards.first }
}
