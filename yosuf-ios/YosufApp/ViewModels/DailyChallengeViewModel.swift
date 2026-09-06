import Foundation
import YosufEngine

@MainActor
final class DailyChallengeViewModel: ObservableObject {
    let scenario = DailyChallengeGenerator.scenario()
    @Published private(set) var alreadyCompletedToday: Bool

    private let profileRepository = PlayerProfileRepository()

    init() {
        alreadyCompletedToday = PlayerProfileRepository().hasCompletedDailyChallenge(dateKey: DailyChallengeGenerator.scenario().dateKey)
    }

    func makePlayers(humanName: String) -> (players: [Player], humanID: PlayerID) {
        let humanID = PlayerID()
        var players = [Player(id: humanID, displayName: humanName, kind: .human, avatarColorIndex: 0)]
        for (index, opponent) in scenario.opponents.enumerated() {
            players.append(Player(
                displayName: "Bot-\(opponent.difficulty.rawValue)",
                kind: .bot(difficulty: opponent.difficulty, personality: opponent.personality),
                avatarColorIndex: index + 1
            ))
        }
        return (players, humanID)
    }

    func recordCompletion(finalScore: Int) {
        profileRepository.recordDailyChallenge(dateKey: scenario.dateKey, score: finalScore)
        alreadyCompletedToday = true
    }
}
