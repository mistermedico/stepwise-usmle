import Foundation

/// Elo-style skill rating computed purely from results against bots — no
/// server, no other players required, matching the "single-player first"
/// multiplayer strategy in the spec.
public enum SkillRating {
    public static let startingRating = 1000
    private static let kFactor = 24.0

    /// A fixed "virtual rating" per bot difficulty, used as the opponent
    /// rating in the Elo expected-score formula.
    public static func baselineRating(for difficulty: OpponentDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 800
        case .intermediate: return 1000
        case .advanced: return 1300
        case .expert: return 1600
        }
    }

    /// Updates a rating after one match. `didWin` is whether the human
    /// finished the match with the lowest total score.
    public static func updatedRating(
        current: Int,
        opponentDifficulty: OpponentDifficulty,
        didWin: Bool
    ) -> Int {
        let opponentRating = Double(baselineRating(for: opponentDifficulty))
        let expected = 1.0 / (1.0 + pow(10.0, (opponentRating - Double(current)) / 400.0))
        let actual = didWin ? 1.0 : 0.0
        let delta = kFactor * (actual - expected)
        return max(0, current + Int(delta.rounded()))
    }
}
