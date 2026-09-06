import Foundation

/// "Party mode" event cards — round-scoped rule modifiers, only ever drawn
/// when `RuleProfile.eventCardsEnabled` is true (currently the Street preset).
/// Kept as a closed enum so every effect is handled exhaustively by the engine.
public enum PartyEventCard: String, CaseIterable, Codable, Sendable, Equatable {
    case doublePenalty       // Asaf penalty this round is doubled.
    case silentYosuf         // Reveal animation is instant, no suspense delay.
    case skipNextPlayer      // The player after the current one loses their turn.
    case freeOpeningDiscard  // First discard of the round may be any single card, melds ignored.
    case mercyRound          // Asaf penalty this round is halved (rounded down).
    case wildDraw            // Players may draw from either pile freely, even mid-round.
    case reverseOrder        // Turn order reverses for the remainder of the round.
    case luckyJoker          // A joker drawn this round may be discarded alone for 0 points, no meld needed.

    public var titleKey: String { "event.\(rawValue).title" }
    public var descriptionKey: String { "event.\(rawValue).description" }
}

/// A modifier bundle derived from whichever event card (if any) is active
/// for the current round. Kept separate from `PartyEventCard` so the engine
/// deals with plain data rather than switching on the enum everywhere.
public struct RoundModifiers: Equatable, Sendable {
    public var activeEvent: PartyEventCard?
    public var penaltyMultiplier: Double
    public var skipsNextPlayer: Bool
    public var freeOpeningDiscard: Bool
    public var reversedOrder: Bool

    public static let none = RoundModifiers(
        activeEvent: nil, penaltyMultiplier: 1.0, skipsNextPlayer: false,
        freeOpeningDiscard: false, reversedOrder: false
    )

    public static func from(_ event: PartyEventCard?) -> RoundModifiers {
        guard let event else { return .none }
        switch event {
        case .doublePenalty:
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 2.0, skipsNextPlayer: false, freeOpeningDiscard: false, reversedOrder: false)
        case .mercyRound:
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 0.5, skipsNextPlayer: false, freeOpeningDiscard: false, reversedOrder: false)
        case .skipNextPlayer:
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 1.0, skipsNextPlayer: true, freeOpeningDiscard: false, reversedOrder: false)
        case .freeOpeningDiscard:
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 1.0, skipsNextPlayer: false, freeOpeningDiscard: true, reversedOrder: false)
        case .reverseOrder:
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 1.0, skipsNextPlayer: false, freeOpeningDiscard: false, reversedOrder: true)
        case .silentYosuf, .wildDraw, .luckyJoker:
            // Presentation-only or draw-rule effects handled at the call sites
            // that check `activeEvent` directly; no scoring modifier needed.
            return RoundModifiers(activeEvent: event, penaltyMultiplier: 1.0, skipsNextPlayer: false, freeOpeningDiscard: false, reversedOrder: false)
        }
    }
}
