import Foundation

/// Every way an engine action can fail. The engine never crashes or falls
/// into an undefined state — every rejected action surfaces one of these.
public enum GameError: Error, Equatable, Sendable {
    case notPlayersTurn
    case gameAlreadyOver
    case roundAlreadyOver
    case mustDrawBeforeDiscarding
    case alreadyDrewThisTurn
    case cardsNotInHand
    case invalidMeld
    case emptyDiscardSelection
    case cannotDeclareYosufYet(currentValue: Int, threshold: Int)
    case cannotDeclareYosufAfterDrawing
    case noAsafChallengeAvailable
    case bothPilesEmpty
    case playerNotFound
    case insufficientPlayers
    case tooManyPlayers
}

extension GameError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notPlayersTurn: return "It is not this player's turn."
        case .gameAlreadyOver: return "The match has already ended."
        case .roundAlreadyOver: return "The round has already ended."
        case .mustDrawBeforeDiscarding: return "The player must draw a card before discarding."
        case .alreadyDrewThisTurn: return "The player already drew a card this turn."
        case .cardsNotInHand: return "One or more selected cards are not in the player's hand."
        case .invalidMeld: return "The selected cards do not form a valid set or run."
        case .emptyDiscardSelection: return "At least one card must be discarded."
        case .cannotDeclareYosufYet(let value, let threshold):
            return "Hand value \(value) is above the Yosuf threshold of \(threshold)."
        case .cannotDeclareYosufAfterDrawing: return "Yosuf may only be declared before drawing on your turn."
        case .noAsafChallengeAvailable: return "There is no pending Yosuf declaration to challenge."
        case .bothPilesEmpty: return "Both the draw pile and discard pile are empty."
        case .playerNotFound: return "No such player exists in this match."
        case .insufficientPlayers: return "A match requires at least 2 players."
        case .tooManyPlayers: return "A match supports at most 4 players."
        }
    }
}
