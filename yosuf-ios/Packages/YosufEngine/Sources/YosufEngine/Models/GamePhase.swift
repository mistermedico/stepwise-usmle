import Foundation

/// The round-level state machine. Every legal transition is enforced by
/// `GameEngine` — the app layer can only ever observe one of these, never
/// construct an invalid combination itself.
public enum GamePhase: Equatable, Sendable {
    case awaitingDraw(playerID: PlayerID)
    case awaitingDiscard(playerID: PlayerID)
    case roundEnded(outcome: RoundOutcome)
    case matchEnded(winnerID: PlayerID)
}

public enum RoundOutcome: Equatable, Sendable {
    /// The caller had the strictly lowest hand: they win the round outright.
    case yosufSuccess(callerID: PlayerID)
    /// A challenger matched or beat the caller: the caller is penalized and
    /// the challenger is credited with the round.
    case asafSuccess(callerID: PlayerID, challengerID: PlayerID)
}

/// A single notable happening during a round, kept for the UI to animate
/// and for the history log — never used by the engine itself for decisions.
public enum GameLogEvent: Equatable, Sendable {
    case cardsDealt
    case drew(playerID: PlayerID, fromDiscard: Bool)
    case discarded(playerID: PlayerID, meld: Bool)
    case yosufDeclared(playerID: PlayerID)
    case asafDeclared(challengerID: PlayerID, callerID: PlayerID)
    case roundEnded(outcome: RoundOutcome)
    case matchEnded(winnerID: PlayerID)
    case eventCardDrawn(PartyEventCard)
}
