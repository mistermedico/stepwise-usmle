import Foundation

/// A single "table reading" hint — a suggestion derived entirely from
/// information every player at the table can already see. Presentation
/// (which localized string to show) lives in the app layer; this only
/// decides *whether* a hint applies.
public enum TableHint: Equatable, Sendable {
    /// The observer's own hand is close enough to the Yosuf threshold to
    /// be worth watching (within `margin` points of it).
    case yourHandIsClose(margin: Int)
    /// An opponent's visible card count dropped below the dealt hand size,
    /// implying they discarded a meld and may be close to calling.
    case opponentLikelyClose(playerID: PlayerID, cardCount: Int)
    /// The same rank has been discarded repeatedly in a row — a "cold"
    /// rank unlikely to complete anyone's set right now.
    case rankRunningCold(rank: Rank)

    /// The top discard is a live joker sitting unclaimed — a strong pickup
    /// for whoever grabs it, worth flagging even without seeing hands.
    case unclaimedJokerOnTop
}

/// Generates hints from public information only. This type never receives
/// (and therefore cannot leak) any hidden hand contents besides the
/// observing player's own — that boundary is enforced by the parameter
/// list itself, not by convention.
public enum TableReader {
    private static let dealtHandSize = 5

    public static func generateHints(
        observerID: PlayerID,
        observerHand: [Card],
        publicPlayerCardCounts: [(id: PlayerID, count: Int)],
        discardHistory: [Card],
        profile: RuleProfile
    ) -> [TableHint] {
        var hints: [TableHint] = []

        let ownValue = HandEvaluator.handValue(observerHand, aceHigh: profile.aceHigh)
        let margin = ownValue - profile.yosufThreshold
        if margin >= 0, margin <= 2 {
            hints.append(.yourHandIsClose(margin: margin))
        }

        for entry in publicPlayerCardCounts where entry.id != observerID {
            if entry.count < dealtHandSize {
                hints.append(.opponentLikelyClose(playerID: entry.id, cardCount: entry.count))
            }
        }

        if let lastRun = trailingSameRankRun(discardHistory), lastRun.count >= 2 {
            hints.append(.rankRunningCold(rank: lastRun.rank))
        }

        if let top = discardHistory.first, top.isJoker {
            hints.append(.unclaimedJokerOnTop)
        }

        return hints
    }

    /// Looks at the most recent discards (from the top) and returns the
    /// rank/count of a run of consecutive same-rank discards, if any.
    private static func trailingSameRankRun(_ discardHistory: [Card]) -> (rank: Rank, count: Int)? {
        guard let topRank = discardHistory.first?.rank else { return nil }
        var count = 0
        for card in discardHistory {
            guard card.rank == topRank else { break }
            count += 1
        }
        return count >= 2 ? (topRank, count) : nil
    }
}
