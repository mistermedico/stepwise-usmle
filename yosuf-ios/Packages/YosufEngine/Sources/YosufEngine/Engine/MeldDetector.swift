import Foundation

/// Validates and discovers sets/runs. Jokers act as wildcards. This is the
/// single source of truth for "is this a legal meld" — both the human
/// discard path and the bot AI go through it, so they can never disagree.
public enum MeldDetector {

    /// Checks whether `cards` forms a valid set (same rank) or run (same
    /// suit, consecutive ranks), with jokers filling in as wildcards.
    public static func validate(_ cards: [Card], minMeldSize: Int) -> MeldKind? {
        guard cards.count >= minMeldSize else { return nil }
        guard Set(cards.map(\.id)).count == cards.count else { return nil } // no duplicate physical cards
        if isValidSet(cards) { return .set }
        if isValidRun(cards) { return .run }
        return nil
    }

    public static func makeMeld(from cards: [Card], minMeldSize: Int) -> Meld? {
        guard let kind = validate(cards, minMeldSize: minMeldSize) else { return nil }
        return Meld.makeValidated(kind: kind, cards: cards)
    }

    static func isValidSet(_ cards: [Card]) -> Bool {
        let nonJokers = cards.filter { !$0.isJoker }
        guard let firstRank = nonJokers.first?.rank else { return false } // all-joker: ambiguous, reject
        return nonJokers.allSatisfy { $0.rank == firstRank }
    }

    static func isValidRun(_ cards: [Card]) -> Bool {
        let jokerCount = cards.filter(\.isJoker).count
        let nonJokers = cards.filter { !$0.isJoker }
        guard let firstSuit = nonJokers.first?.suit else { return false } // all-joker: ambiguous, reject
        guard nonJokers.allSatisfy({ $0.suit == firstSuit }) else { return false }

        let ranks = nonJokers.compactMap(\.rank).map(\.rawValue).sorted()
        guard Set(ranks).count == ranks.count else { return false } // duplicate rank, can't be a run

        guard let lo = ranks.first, let hi = ranks.last else { return false }
        let internalGaps = (hi - lo + 1) - ranks.count // empty slots strictly between lo and hi
        guard internalGaps <= jokerCount else { return false }

        let remainingJokers = jokerCount - internalGaps
        let capacityBelow = lo - Rank.ace.rawValue      // room to extend downward before hitting Ace
        let capacityAbove = Rank.king.rawValue - hi     // room to extend upward before hitting King
        return remainingJokers <= (capacityBelow + capacityAbove)
    }

    /// Enumerates every valid meld (of any size ≥ minMeldSize) contained in
    /// a hand. Hands are small (≤ 6 cards), so brute-force subset search is
    /// fast and easy to reason about/test.
    public static func allMelds(in hand: [Card], minMeldSize: Int) -> [Meld] {
        guard hand.count >= minMeldSize else { return [] }
        var results: [Meld] = []
        for size in minMeldSize...hand.count {
            for combo in combinations(hand, size) {
                if let meld = makeMeld(from: combo, minMeldSize: minMeldSize) {
                    results.append(meld)
                }
            }
        }
        return results
    }

    /// The largest-point-value meld available, if any — used by the AI's
    /// top discard priority ("reduce hand value the most").
    public static func bestMeld(in hand: [Card], minMeldSize: Int) -> Meld? {
        allMelds(in: hand, minMeldSize: minMeldSize).max { $0.totalPointValue < $1.totalPointValue }
    }

    private static func combinations<T>(_ array: [T], _ k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        guard array.count >= k else { return [] }
        if array.count == k { return [array] }
        var result: [[T]] = []
        var rest = array
        let first = rest.removeFirst()
        result.append(contentsOf: combinations(rest, k - 1).map { [first] + $0 })
        result.append(contentsOf: combinations(rest, k))
        return result
    }
}
