import CoreData
import YosufEngine

struct PlayerProfileSnapshot {
    var skillRating: Int
    var gamesPlayed: Int
    var gamesWon: Int
    var lastDailyChallengeDateKey: String?
    var lastDailyChallengeScore: Int

    var rankTier: RankTier { RankTier.forRating(skillRating) }
}

/// The single local player's profile — there is exactly one row, created
/// lazily on first access. Kept separate from `MatchHistoryEntity` so
/// reading "my current rank" never requires scanning full match history.
struct PlayerProfileRepository {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    private func fetchOrCreateEntity() -> PlayerProfileEntity {
        let request = PlayerProfileEntity.fetchRequest()
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first {
            return existing
        }
        let entity = PlayerProfileEntity(context: context)
        entity.skillRating = Int32(SkillRating.startingRating)
        entity.gamesPlayed = 0
        entity.gamesWon = 0
        return entity
    }

    func snapshot() -> PlayerProfileSnapshot {
        let entity = fetchOrCreateEntity()
        return PlayerProfileSnapshot(
            skillRating: Int(entity.skillRating),
            gamesPlayed: Int(entity.gamesPlayed),
            gamesWon: Int(entity.gamesWon),
            lastDailyChallengeDateKey: entity.lastDailyChallengeDateKey,
            lastDailyChallengeScore: Int(entity.lastDailyChallengeScore)
        )
    }

    func recordMatchResult(didWin: Bool, opponentDifficulty: OpponentDifficulty) {
        let entity = fetchOrCreateEntity()
        entity.gamesPlayed += 1
        if didWin { entity.gamesWon += 1 }
        entity.skillRating = Int32(SkillRating.updatedRating(
            current: Int(entity.skillRating), opponentDifficulty: opponentDifficulty, didWin: didWin
        ))
        PersistenceController.shared.saveIfNeeded()
    }

    func recordDailyChallenge(dateKey: String, score: Int) {
        let entity = fetchOrCreateEntity()
        entity.lastDailyChallengeDateKey = dateKey
        entity.lastDailyChallengeScore = Int32(score)
        PersistenceController.shared.saveIfNeeded()
    }

    func hasCompletedDailyChallenge(dateKey: String) -> Bool {
        fetchOrCreateEntity().lastDailyChallengeDateKey == dateKey
    }
}
