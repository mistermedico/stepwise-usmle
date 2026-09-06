import Foundation

/// The two legal meld shapes: three-or-more of the same rank, or
/// three-or-more consecutive cards of the same suit.
public enum MeldKind: Equatable, Sendable {
    case set
    case run
}

/// A validated group of cards a player may discard together in place of a
/// single card. Only ever constructed by `MeldDetector` — the app layer
/// never hand-assembles one, so an invalid meld cannot enter the engine.
public struct Meld: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let kind: MeldKind
    public let cards: [Card]

    fileprivate init(kind: MeldKind, cards: [Card]) {
        self.kind = kind
        self.cards = cards
    }

    public static func makeValidated(kind: MeldKind, cards: [Card]) -> Meld {
        Meld(kind: kind, cards: cards)
    }

    public var totalPointValue: Int {
        cards.reduce(0) { $0 + $1.pointValue() }
    }

    public static func == (lhs: Meld, rhs: Meld) -> Bool {
        Set(lhs.cards) == Set(rhs.cards)
    }
}
