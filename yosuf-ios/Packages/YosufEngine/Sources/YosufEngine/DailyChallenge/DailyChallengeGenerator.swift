import Foundation

/// Produces the day's fixed scenario: same seed, same opponent lineup, same
/// rule profile for every player on a given calendar date, so scores are
/// directly comparable.
public enum DailyChallengeGenerator {
    public struct OpponentSlot: Equatable, Sendable {
        public let difficulty: OpponentDifficulty
        public let personality: OpponentPersonality
    }

    private static let opponentLineups: [[OpponentSlot]] = [
        [OpponentSlot(difficulty: .intermediate, personality: .balanced),
         OpponentSlot(difficulty: .advanced, personality: .aggressive),
         OpponentSlot(difficulty: .beginner, personality: .cautious)],
        [OpponentSlot(difficulty: .advanced, personality: .balanced),
         OpponentSlot(difficulty: .expert, personality: .cautious),
         OpponentSlot(difficulty: .intermediate, personality: .aggressive)],
        [OpponentSlot(difficulty: .beginner, personality: .balanced),
         OpponentSlot(difficulty: .intermediate, personality: .cautious),
         OpponentSlot(difficulty: .advanced, personality: .balanced)],
        [OpponentSlot(difficulty: .expert, personality: .aggressive),
         OpponentSlot(difficulty: .advanced, personality: .cautious),
         OpponentSlot(difficulty: .intermediate, personality: .balanced)]
    ]

    public struct Scenario: Sendable {
        public let seed: UInt64
        public let ruleProfile: RuleProfile
        public let opponents: [OpponentSlot]
        public let dateKey: String
    }

    public static func scenario(for date: Date = Date(), calendar: Calendar = .current) -> Scenario {
        let seed = SeededGenerator.dailySeed(for: date, calendar: calendar)
        let lineup = opponentLineups[Int(seed % UInt64(opponentLineups.count))]
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return Scenario(seed: seed, ruleProfile: .classic, opponents: lineup, dateKey: dateKey)
    }
}
