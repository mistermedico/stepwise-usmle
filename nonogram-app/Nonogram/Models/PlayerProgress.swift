import Foundation

/// Everything about the player's save state that isn't a specific in-progress board
/// (that's `GameEngine`). Persisted as a single JSON blob via `PersistenceManager`.
struct PlayerProgress: Codable, Equatable {
    var completedLevelIDs: Set<String> = []
    /// Levels completed with zero mistakes, for the "flawless" achievement/gallery badge.
    var flawlessLevelIDs: Set<String> = []
    var unlockedAchievementIDs: Set<String> = []

    var lives: Int = Constants.startingLives
    var lastLifeRegenerationDate: Date = Date()

    var boosterCounts: [BoosterType: Int] = [
        .revealLine: Constants.startingReveals,
        .checkErrors: Constants.startingChecks,
        .hintCell: Constants.startingHints
    ]

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastPlayedDate: Date?

    var dailyChallengeCompletedDates: Set<String> = [] // "yyyy-MM-dd" keys, calendar-independent

    enum Constants {
        static let startingLives = 5
        static let maxLives = 5
        static let lifeRegenerationInterval: TimeInterval = 30 * 60
        static let startingReveals = 3
        static let startingChecks = 5
        static let startingHints = 3
    }
}

enum BoosterType: String, Codable, CaseIterable {
    case revealLine
    case checkErrors
    case hintCell
}

struct Achievement: Codable, Identifiable {
    let id: String
    let title: LocalizedText
    let detail: LocalizedText
    let iconSystemName: String
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "first_solve",
            title: LocalizedText(en: "First Reveal", he: "החשיפה הראשונה"),
            detail: LocalizedText(en: "Complete your first puzzle.", he: "השלימו את החידה הראשונה שלכם."),
            iconSystemName: "sparkles"
        ),
        Achievement(
            id: "flawless_10",
            title: LocalizedText(en: "Sharp Eye", he: "עין חדה"),
            detail: LocalizedText(en: "Solve 10 puzzles without a single mistake.", he: "פתרו 10 חידות בלי אף טעות."),
            iconSystemName: "eye"
        ),
        Achievement(
            id: "streak_7",
            title: LocalizedText(en: "Week Streak", he: "רצף שבועי"),
            detail: LocalizedText(en: "Play 7 days in a row.", he: "שחקו 7 ימים ברצף."),
            iconSystemName: "flame"
        ),
        Achievement(
            id: "category_animals_complete",
            title: LocalizedText(en: "Animal Whisperer", he: "לוחש לחיות"),
            detail: LocalizedText(en: "Complete every puzzle in Animals.", he: "השלימו את כל החידות בקטגוריית חיות."),
            iconSystemName: "pawprint"
        ),
        Achievement(
            id: "category_food_complete",
            title: LocalizedText(en: "Gourmet", he: "גורמה"),
            detail: LocalizedText(en: "Complete every puzzle in Food.", he: "השלימו את כל החידות בקטגוריית אוכל."),
            iconSystemName: "fork.knife"
        ),
        Achievement(
            id: "category_nature_complete",
            title: LocalizedText(en: "Naturalist", he: "חובב טבע"),
            detail: LocalizedText(en: "Complete every puzzle in Nature.", he: "השלימו את כל החידות בקטגוריית טבע."),
            iconSystemName: "leaf"
        ),
        Achievement(
            id: "category_objects_complete",
            title: LocalizedText(en: "Collector", he: "אספן"),
            detail: LocalizedText(en: "Complete every puzzle in Objects.", he: "השלימו את כל החידות בקטגוריית חפצים."),
            iconSystemName: "cube"
        ),
        Achievement(
            id: "daily_7",
            title: LocalizedText(en: "Daily Devotee", he: "חסיד יומי"),
            detail: LocalizedText(en: "Complete 7 daily challenges.", he: "השלימו 7 אתגרים יומיים."),
            iconSystemName: "calendar"
        ),
        Achievement(
            id: "expert_solver",
            title: LocalizedText(en: "Expert Solver", he: "פותר מומחה"),
            detail: LocalizedText(en: "Complete an Expert-difficulty puzzle.", he: "השלימו חידה ברמת מומחה."),
            iconSystemName: "crown"
        ),
        Achievement(
            id: "all_complete",
            title: LocalizedText(en: "Master of Pixels", he: "אמן הפיקסלים"),
            detail: LocalizedText(en: "Complete every puzzle in the game.", he: "השלימו את כל החידות במשחק."),
            iconSystemName: "trophy"
        )
    ]
}
