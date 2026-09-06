import Foundation

/// A single playing card. Jokers are modeled as a distinct case so the type
/// system rules out invalid states like "a joker with a suit" — no raw
/// strings/ints, no sentinel values.
public struct Card: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: Hashable, Codable, Sendable {
        case standard(rank: Rank, suit: Suit)
        /// `index` (0 or 1) only exists to keep the two jokers distinct/hashable.
        case joker(index: Int)
    }

    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }

    public static func standard(_ rank: Rank, _ suit: Suit) -> Card {
        Card(kind: .standard(rank: rank, suit: suit))
    }

    public static func joker(_ index: Int) -> Card {
        Card(kind: .joker(index: index))
    }

    public var isJoker: Bool {
        if case .joker = kind { return true }
        return false
    }

    public var rank: Rank? {
        if case .standard(let rank, _) = kind { return rank }
        return nil
    }

    public var suit: Suit? {
        if case .standard(_, let suit) = kind { return suit }
        return nil
    }

    /// Point value contributed to a hand total. Jokers are always worth 0.
    public func pointValue(aceHigh: Bool = false) -> Int {
        switch kind {
        case .standard(let rank, _): return rank.pointValue(aceHigh: aceHigh)
        case .joker: return 0
        }
    }
}

extension Card: CustomStringConvertible {
    public var description: String {
        switch kind {
        case .standard(let rank, let suit): return "\(rank)\(suit.symbol)"
        case .joker(let index): return "Joker#\(index)"
        }
    }
}
