import Foundation

/// The complete, serializable state of one match. `GameEngine` is the only
/// thing allowed to mutate it; everything else (SwiftUI views, view models)
/// treats it as read-only data to render.
public struct GameState: Sendable {
    public var players: [Player]
    public var currentPlayerIndex: Int
    public var drawPile: Deck
    /// Most recent discard is `discardPile.cards.first`; the rest is history
    /// used by `TableReader` and by "reshuffle discard into draw pile" on exhaustion.
    public var discardPile: Deck
    public var ruleProfile: RuleProfile
    public var roundModifiers: RoundModifiers
    public var phase: GamePhase
    public var log: [GameLogEvent]
    public var hasDrawnThisTurn: Bool
    public var roundNumber: Int
    public var pendingYosufCallerID: PlayerID?
    /// Number of discards made so far this round — used to gate the
    /// `freeOpeningDiscard` event modifier to the round's very first discard.
    public var discardsThisRound: Int

    public init(
        players: [Player],
        currentPlayerIndex: Int,
        drawPile: Deck,
        discardPile: Deck,
        ruleProfile: RuleProfile,
        roundModifiers: RoundModifiers = .none,
        phase: GamePhase,
        log: [GameLogEvent] = [],
        hasDrawnThisTurn: Bool = false,
        roundNumber: Int = 1,
        pendingYosufCallerID: PlayerID? = nil,
        discardsThisRound: Int = 0
    ) {
        self.players = players
        self.currentPlayerIndex = currentPlayerIndex
        self.drawPile = drawPile
        self.discardPile = discardPile
        self.ruleProfile = ruleProfile
        self.roundModifiers = roundModifiers
        self.phase = phase
        self.log = log
        self.hasDrawnThisTurn = hasDrawnThisTurn
        self.roundNumber = roundNumber
        self.pendingYosufCallerID = pendingYosufCallerID
        self.discardsThisRound = discardsThisRound
    }

    public var currentPlayer: Player {
        players[currentPlayerIndex]
    }

    public func player(with id: PlayerID) -> Player? {
        players.first { $0.id == id }
    }

    public func index(of id: PlayerID) -> Int? {
        players.firstIndex { $0.id == id }
    }

    public var isMatchOver: Bool {
        if case .matchEnded = phase { return true }
        return false
    }
}
