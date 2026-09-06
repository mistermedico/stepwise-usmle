import YosufEngine

/// Checks match-end conditions against the achievement catalog. Kept as a
/// pure evaluator over `GameState` + repositories, separate from the view
/// model, so the unlock rules are easy to read and to extend.
enum AchievementEvaluator {
    static func evaluateAfterMatch(state: GameState, humanID: PlayerID, didWin: Bool) {
        let achievements = AchievementRepository()
        let profile = PlayerProfileRepository().snapshot()

        if didWin {
            achievements.unlock(.firstWin)
            if profile.gamesWon >= 10 { achievements.unlock(.tenWins) }
            if profile.gamesWon >= 50 { achievements.unlock(.fiftyWins) }

            if let human = state.player(with: humanID),
               HandEvaluator.handValue(human.hand, aceHigh: state.ruleProfile.aceHigh) == 0 {
                achievements.unlock(.flawlessRound)
            }
            if let human = state.player(with: humanID),
               state.ruleProfile.maxScore - human.totalScore <= 5 {
                achievements.unlock(.comebackKing)
            }
        }

        switch profile.rankTier {
        case .gold, .platinum: achievements.unlock(.rankGold)
        case .diamond, .champion: achievements.unlock(.rankDiamond)
        default: break
        }

        let playedProfiles = Set(GameHistoryRepository().recentMatches(limit: 500).map(\.rulesProfileID))
        if Set(RuleProfile.ProfileKind.allCases).isSubset(of: playedProfiles.union([state.ruleProfile.id])) {
            achievements.unlock(.allProfilesPlayed)
        }
    }
}
