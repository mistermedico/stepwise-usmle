import Foundation

public struct PlayerID: Hashable, Codable, Sendable {
    public let value: UUID
    public init(_ value: UUID = UUID()) { self.value = value }
}

public enum PlayerKind: Equatable, Codable, Sendable {
    case human
    case bot(difficulty: OpponentDifficulty, personality: OpponentPersonality)
}

public struct Player: Identifiable, Equatable, Sendable {
    public var id: PlayerID
    public var displayName: String
    public var kind: PlayerKind
    public var hand: [Card]
    /// Cumulative penalty score across rounds within one match.
    public var totalScore: Int
    public var avatarColorIndex: Int

    public init(
        id: PlayerID = PlayerID(),
        displayName: String,
        kind: PlayerKind,
        hand: [Card] = [],
        totalScore: Int = 0,
        avatarColorIndex: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.hand = hand
        self.totalScore = totalScore
        self.avatarColorIndex = avatarColorIndex
    }

    public var isBot: Bool {
        if case .bot = kind { return true }
        return false
    }

    public func handValue(aceHigh: Bool) -> Int {
        hand.reduce(0) { $0 + $1.pointValue(aceHigh: aceHigh) }
    }

    public static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}
