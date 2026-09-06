import Combine
import Foundation

/// Root, app-lifetime state container. Injected once as `@EnvironmentObject` from
/// `NonogramApp`; every other view model is scoped to a screen/session and talks back to
/// this one for anything that touches persisted player progress.
final class AppViewModel: ObservableObject {
    @Published private(set) var progress: PlayerProgress
    @Published private(set) var levelIndex: LevelIndex
    @Published private(set) var loadError: String?

    let soundManager: SoundManager
    let hapticManager: HapticManager
    let adManager: AdManaging
    let localization: LocalizationManager

    private let loader: PuzzleLoader
    private let persistence: PersistenceManager
    private var cancellables: Set<AnyCancellable> = []

    init(
        loader: PuzzleLoader = PuzzleLoader(),
        persistence: PersistenceManager = .shared,
        soundManager: SoundManager = .shared,
        hapticManager: HapticManager = .shared,
        adManager: AdManaging = AdManagerFactory.make(),
        localization: LocalizationManager = LocalizationManager()
    ) {
        self.loader = loader
        self.persistence = persistence
        self.soundManager = soundManager
        self.hapticManager = hapticManager
        self.adManager = adManager
        self.localization = localization
        self.progress = persistence.loadProgress()

        do {
            self.levelIndex = try loader.loadIndex()
        } catch {
            // Empty index degrades every screen to "nothing to show" rather than crashing;
            // the parallel content-generation effort is expected to fill this in.
            self.levelIndex = LevelIndex(levels: [])
            self.loadError = "\(error)"
        }

        // LocalizationManager is its own ObservableObject (so it can also be handed around
        // independently if needed); forward its changes so a single @EnvironmentObject
        // (AppViewModel) is enough to re-render language-dependent UI.
        localization.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func onAppLaunch() {
        persistence.regenerateLivesIfNeeded(&progress)
        persistence.registerPlaySession(&progress)
        checkAchievements()
        persist()
        adManager.requestTrackingAuthorizationIfNeeded { [weak self] in
            self?.adManager.loadInterstitial()
        }
    }

    func refreshLivesRegeneration() {
        persistence.regenerateLivesIfNeeded(&progress)
        persist()
    }

    func persist() {
        persistence.saveProgress(progress)
    }

    // MARK: - Levels / unlocking

    /// All levels in a category, in play order.
    func levels(in category: PuzzleCategory) -> [LevelIndexEntry] {
        levelIndex.levels
            .filter { $0.category == category }
            .sorted { $0.order < $1.order }
    }

    /// Unlock rule: the first level of each category is always available; every subsequent
    /// level unlocks once the previous level (by `order`) in that same category has been
    /// completed. Simple, predictable linear progression per category.
    func isLevelUnlocked(_ entry: LevelIndexEntry) -> Bool {
        let siblings = levels(in: entry.category)
        guard let index = siblings.firstIndex(where: { $0.id == entry.id }) else { return false }
        guard index > 0 else { return true }
        return progress.completedLevelIDs.contains(siblings[index - 1].id)
    }

    func completedCount(in category: PuzzleCategory) -> Int {
        levels(in: category).filter { progress.completedLevelIDs.contains($0.id) }.count
    }

    func totalCount(in category: PuzzleCategory) -> Int {
        levels(in: category).count
    }

    // MARK: - Progress mutation

    func consumeLife() {
        progress.lives = max(0, progress.lives - 1)
        persist()
    }

    func grantLife() {
        progress.lives = min(PlayerProgress.Constants.maxLives, progress.lives + 1)
        persist()
    }

    @discardableResult
    func consumeBooster(_ type: BoosterType) -> Bool {
        guard (progress.boosterCounts[type] ?? 0) > 0 else { return false }
        progress.boosterCounts[type, default: 0] -= 1
        persist()
        return true
    }

    func grantBooster(_ type: BoosterType, count: Int = 1) {
        progress.boosterCounts[type, default: 0] += count
        persist()
    }

    func recordLevelCompletion(levelID: String, flawless: Bool) {
        progress.completedLevelIDs.insert(levelID)
        if flawless {
            progress.flawlessLevelIDs.insert(levelID)
        }
        checkAchievements()
        persist()
    }

    func recordDailyChallengeCompletion(dateKey: String) {
        progress.dailyChallengeCompletedDates.insert(dateKey)
        checkAchievements()
        persist()
    }

    // MARK: - Achievements

    /// Re-scans progress after anything that could newly satisfy an achievement and unlocks it.
    /// Safe to call redundantly; already-unlocked achievements are skipped.
    @discardableResult
    private func checkAchievements() -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        func unlock(_ id: String) {
            guard !progress.unlockedAchievementIDs.contains(id) else { return }
            progress.unlockedAchievementIDs.insert(id)
            if let achievement = AchievementCatalog.all.first(where: { $0.id == id }) {
                newlyUnlocked.append(achievement)
            }
        }

        if !progress.completedLevelIDs.isEmpty {
            unlock("first_solve")
        }
        if progress.flawlessLevelIDs.count >= 10 {
            unlock("flawless_10")
        }
        if progress.currentStreak >= 7 {
            unlock("streak_7")
        }
        if progress.dailyChallengeCompletedDates.count >= 7 {
            unlock("daily_7")
        }
        for category in PuzzleCategory.allCases {
            let total = totalCount(in: category)
            if total > 0 && completedCount(in: category) == total {
                unlock("category_\(category.rawValue)_complete")
            }
        }
        if levelIndex.levels.contains(where: { $0.difficulty == .expert && progress.completedLevelIDs.contains($0.id) }) {
            unlock("expert_solver")
        }
        if !levelIndex.levels.isEmpty && progress.completedLevelIDs.count == levelIndex.levels.count {
            unlock("all_complete")
        }

        return newlyUnlocked
    }
}
