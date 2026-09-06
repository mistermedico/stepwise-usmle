import Foundation

/// Pure hand-scoring helpers shared by the engine, the AI, and the table
/// reader — no mutation, no side effects, trivially unit-testable.
public enum HandEvaluator {
    public static func handValue(_ hand: [Card], aceHigh: Bool) -> Int {
        hand.reduce(0) { $0 + $1.pointValue(aceHigh: aceHigh) }
    }

    public static func isEligibleToDeclareYosuf(hand: [Card], profile: RuleProfile) -> Bool {
        handValue(hand, aceHigh: profile.aceHigh) <= profile.yosufThreshold
    }

    /// The single highest-value card in a hand — the fallback discard when
    /// no meld is available. Ties broken by joker-never-picked-alone (a
    /// joker is worth 0 and should never be "the highest card").
    public static func highestValueCard(in hand: [Card], aceHigh: Bool) -> Card? {
        hand.max { $0.pointValue(aceHigh: aceHigh) < $1.pointValue(aceHigh: aceHigh) }
    }

    /// Whether taking `card` from the discard pile would reduce hand value
    /// more than a random unseen card from the closed deck would, on
    /// average. Used by both bots and the (optional) "worth it?" hint.
    public static func isDiscardPileCardWorthTaking(
        _ card: Card,
        currentHand: [Card],
        profile: RuleProfile
    ) -> Bool {
        // Heuristic: worth taking if it directly extends an existing near-meld,
        // i.e. adding it creates at least one valid meld that wasn't there before.
        let before = MeldDetector.allMelds(in: currentHand, minMeldSize: profile.minMeldSize).count
        let after = MeldDetector.allMelds(in: currentHand + [card], minMeldSize: profile.minMeldSize).count
        return after > before
    }
}
