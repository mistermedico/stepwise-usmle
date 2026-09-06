import CoreData
import Foundation

/// Reads and writes `AchievementRecordEntity` rows — which achievement IDs have ever
/// been unlocked, persisted so the achievements screen survives app relaunches.
public final class AchievementStore {
    public static let shared = AchievementStore()

    private let controller: PersistenceController

    public init(controller: PersistenceController = .shared) {
        self.controller = controller
    }

    public func unlockedIDs() -> Set<String> {
        let request = AchievementRecordEntity.fetchRequest()
        guard let entities = try? controller.viewContext.fetch(request) else { return [] }
        return Set(entities.map(\.id))
    }

    /// Persists any IDs not already stored. Returns only the newly-unlocked subset,
    /// so the caller can show a "new achievement" toast for exactly those.
    @discardableResult
    public func unlock(_ ids: Set<String>) -> Set<String> {
        let alreadyUnlocked = unlockedIDs()
        let newlyUnlocked = ids.subtracting(alreadyUnlocked)
        guard !newlyUnlocked.isEmpty else { return [] }

        let context = controller.viewContext
        for id in newlyUnlocked {
            let entity = AchievementRecordEntity(context: context)
            entity.id = id
            entity.unlockedAt = Date()
        }
        controller.save()
        return newlyUnlocked
    }
}

/// Ties `AchievementEvaluator` (pure logic) to `AchievementStore` (persistence) so view
/// models have one call to make when a run ends.
public final class AchievementManager {
    public static let shared = AchievementManager()

    private let store: AchievementStore

    public init(store: AchievementStore = .shared) {
        self.store = store
    }

    @discardableResult
    public func recordFinishedRun(_ state: GameState) -> Set<String> {
        let earned = AchievementEvaluator.earnedAchievements(for: state)
        return store.unlock(earned)
    }

    public func allUnlockedIDs() -> Set<String> {
        store.unlockedIDs()
    }
}
