import CoreData

/// All achievements are defined here as a closed catalog so the
/// Achievements screen can always render every possible achievement,
/// unlocked or not — never an undefined/unknown id.
enum AchievementID: String, CaseIterable, Hashable {
    case firstWin
    case tenWins
    case fiftyWins
    case flawlessRound      // won a round with a 0-value hand
    case comebackKing       // won a match after being within 5 points of maxScore
    case dailyChallengeWeek // completed 7 daily challenges
    case allProfilesPlayed  // played at least one match in every rule profile
    case rankGold
    case rankDiamond

    var titleKey: String { "achievement.\(rawValue).title" }
    var descriptionKey: String { "achievement.\(rawValue).description" }
}

struct AchievementRepository {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func unlockedIDs() -> Set<AchievementID> {
        let request = AchievementEntity.fetchRequest()
        guard let results = try? context.fetch(request) else { return [] }
        return Set(results.compactMap { $0.identifier.flatMap(AchievementID.init(rawValue:)) })
    }

    /// Unlocks an achievement if not already unlocked. Returns true if this
    /// call actually unlocked it (so the UI can show a "new achievement" toast).
    @discardableResult
    func unlock(_ id: AchievementID) -> Bool {
        guard !unlockedIDs().contains(id) else { return false }
        let entity = AchievementEntity(context: context)
        entity.identifier = id.rawValue
        entity.unlockedDate = Date()
        PersistenceController.shared.saveIfNeeded()
        return true
    }
}
