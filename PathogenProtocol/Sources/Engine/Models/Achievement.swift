import Foundation

public struct Achievement: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let titleKey: String
    public let descriptionKey: String

    public init(id: String, titleKey: String, descriptionKey: String) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
    }
}

public enum AchievementCatalog {
    public static let silentVictory = Achievement(
        id: "achievement.silent_victory",
        titleKey: "achievement.silent_victory.title",
        descriptionKey: "achievement.silent_victory.desc"
    )
    public static let lightningVictory = Achievement(
        id: "achievement.lightning_victory",
        titleKey: "achievement.lightning_victory.title",
        descriptionKey: "achievement.lightning_victory.desc"
    )
    public static let fullSpreadInTenDays = Achievement(
        id: "achievement.full_spread_ten_days",
        titleKey: "achievement.full_spread_ten_days.title",
        descriptionKey: "achievement.full_spread_ten_days.desc"
    )
    public static let noLockdownVictory = Achievement(
        id: "achievement.no_lockdown_victory",
        titleKey: "achievement.no_lockdown_victory.title",
        descriptionKey: "achievement.no_lockdown_victory.desc"
    )
    public static let allBranchesMaxed = Achievement(
        id: "achievement.all_branches_maxed",
        titleKey: "achievement.all_branches_maxed.title",
        descriptionKey: "achievement.all_branches_maxed.desc"
    )
    public static let firstRun = Achievement(
        id: "achievement.first_run",
        titleKey: "achievement.first_run.title",
        descriptionKey: "achievement.first_run.desc"
    )

    public static let all: [Achievement] = [
        firstRun, silentVictory, lightningVictory, fullSpreadInTenDays, noLockdownVictory, allBranchesMaxed,
    ]
}

/// Pure evaluation of which achievements a finished run newly earns. Testable without
/// touching Core Data — persistence of *which* achievements were already unlocked is
/// the caller's responsibility (see `AchievementManager`).
public enum AchievementEvaluator {
    public static func earnedAchievements(for state: GameState) -> Set<String> {
        guard let outcome = state.outcome else { return [] }
        var earned: Set<String> = [AchievementCatalog.firstRun.id]

        guard outcome == .victory else { return earned }

        let peakAwareness = state.history.map(\.globalAwareness).max() ?? state.globalAwareness
        if peakAwareness < 0.3 {
            earned.insert(AchievementCatalog.silentVictory.id)
        }
        if state.day <= 10 {
            earned.insert(AchievementCatalog.fullSpreadInTenDays.id)
            earned.insert(AchievementCatalog.lightningVictory.id)
        }
        if state.history.allSatisfy({ $0.regionsLockedDown == 0 }) {
            earned.insert(AchievementCatalog.noLockdownVictory.id)
        }
        let maxTierPerCategory = Dictionary(grouping: UpgradeCatalog.allNodes, by: \.category)
            .mapValues { $0.map(\.tier).max() ?? 0 }
        let maxedAllBranches = maxTierPerCategory.allSatisfy { category, maxTier in
            UpgradeCatalog.allNodes
                .filter { $0.category == category && $0.tier == maxTier }
                .allSatisfy { state.unlockedUpgradeIDs.contains($0.id) }
        }
        if maxedAllBranches {
            earned.insert(AchievementCatalog.allBranchesMaxed.id)
        }
        return earned
    }
}
