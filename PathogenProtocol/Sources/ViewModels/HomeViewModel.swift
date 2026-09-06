import Foundation

/// Backs the home dashboard: strain picker, scenario/difficulty pickers, today's
/// daily challenge, and the gallery of past reports (spec section 4, home screen).
@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public var selectedStrain: StrainDefinition = StrainCatalog.balanced
    @Published public var selectedScenario: WorldScenario = ScenarioCatalog.isolatedTerritory
    @Published public var selectedDifficulty: DifficultyLevel = .challenging
    @Published public private(set) var pastReports: [SavedOutbreakReport] = []
    @Published public private(set) var unlockedAchievementCount: Int = 0

    public let dailyChallenge: DailyChallenge
    public let strains: [StrainDefinition] = StrainCatalog.all
    public let scenarios: [WorldScenario] = ScenarioCatalog.all
    public let difficulties: [DifficultyLevel] = DifficultyLevel.allCases

    private let historyStore: GameHistoryStore
    private let achievementManager: AchievementManager

    public init(
        historyStore: GameHistoryStore = .shared,
        achievementManager: AchievementManager = .shared,
        now: Date = Date()
    ) {
        self.historyStore = historyStore
        self.achievementManager = achievementManager
        self.dailyChallenge = DailyChallengeProvider.challenge(for: now)
    }

    public func refresh() {
        pastReports = historyStore.fetchAll()
        unlockedAchievementCount = achievementManager.allUnlockedIDs().count
    }

    public func makeGameViewModel(usingDailyChallenge: Bool) -> GameViewModel {
        if usingDailyChallenge {
            return GameViewModel(
                scenario: dailyChallenge.scenario, strain: dailyChallenge.strain, difficulty: dailyChallenge.difficulty
            )
        }
        return GameViewModel(scenario: selectedScenario, strain: selectedStrain, difficulty: selectedDifficulty)
    }
}
