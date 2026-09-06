import Foundation

/// The bot decision-maker: explicit condition/priority rules, not a
/// trained model. Every branch here maps directly to spec section 3.
///
/// Fairness rule: these functions only ever see the bot's *own* hand plus
/// information that is genuinely public at the table (the discard pile,
/// other players' card counts). They are never handed another player's
/// hand contents — the same constraint `TableReader` enforces for hints.
public enum OpponentEngine {

    public enum DrawAction: Equatable, Sendable {
        case declareYosuf
        case drawFromDeck
        case drawFromDiscard
    }

    /// Step 6 (Yosuf threshold) is checked first — a bot that can safely
    /// end the round does so once its caution delay has elapsed. Otherwise
    /// falls through to steps 1/5 (draw-source choice for this turn).
    public static func decideDrawAction(
        botID: PlayerID,
        hand: [Card],
        topDiscard: Card?,
        difficulty: OpponentDifficulty,
        personality: OpponentPersonality,
        profile: RuleProfile,
        memory: inout OpponentMemory,
        rng: RNGBox = RNGBox()
    ) -> DrawAction {
        let handValue = HandEvaluator.handValue(hand, aceHigh: profile.aceHigh)
        let personalThreshold = max(0, difficulty.baseYosufThreshold + personality.thresholdAdjustment)
        let effectiveThreshold = min(personalThreshold, profile.yosufThreshold)

        if handValue <= effectiveThreshold {
            let waited = memory.consecutiveEligibleTurns[botID, default: 0]
            if waited >= difficulty.cautionDelayTurns {
                memory.consecutiveEligibleTurns[botID] = 0
                return .declareYosuf
            }
            memory.consecutiveEligibleTurns[botID] = waited + 1
        } else {
            memory.consecutiveEligibleTurns[botID] = 0
        }

        if let top = topDiscard {
            let worthTaking = HandEvaluator.isDiscardPileCardWorthTaking(top, currentHand: hand, profile: profile)
            var generator = rng
            if worthTaking && Double.random(in: 0...1, using: &generator) < personality.discardPileGreed {
                return .drawFromDiscard
            }
        }
        return .drawFromDeck
    }

    /// Steps 2-4: best meld first, else the highest single card, else (for
    /// difficulties that plan ahead) break ties in favor of keeping cards
    /// that could complete a future meld.
    public static func decideDiscard(
        hand: [Card],
        difficulty: OpponentDifficulty,
        profile: RuleProfile
    ) -> [Card] {
        precondition(!hand.isEmpty, "A player always holds at least one card when discarding.")

        if let meld = MeldDetector.bestMeld(in: hand, minMeldSize: profile.minMeldSize) {
            return meld.cards
        }

        let maxValue = hand.map { $0.pointValue(aceHigh: profile.aceHigh) }.max() ?? 0
        let candidates = hand.filter { $0.pointValue(aceHigh: profile.aceHigh) == maxValue }
        guard candidates.count > 1, difficulty.planksAheadForMelds else {
            return [candidates[0]]
        }

        // Among equally-high cards, keep the one most "connected" to the
        // rest of the hand (same rank elsewhere, or adjacent rank/suit)
        // and discard the least connected one instead.
        let leastConnected = candidates.min { lhs, rhs in
            connectionCount(of: lhs, in: hand) < connectionCount(of: rhs, in: hand)
        }
        return [leastConnected ?? candidates[0]]
    }

    private static func connectionCount(of card: Card, in hand: [Card]) -> Int {
        hand.filter { other in
            guard other.id != card.id else { return false }
            if let r1 = card.rank, let r2 = other.rank, r1 == r2 { return true }
            if let s1 = card.suit, let s2 = other.suit, s1 == s2,
               let r1 = card.rank, let r2 = other.rank,
               abs(r1.rawValue - r2.rawValue) == 1 {
                return true
            }
            return false
        }.count
    }
}
