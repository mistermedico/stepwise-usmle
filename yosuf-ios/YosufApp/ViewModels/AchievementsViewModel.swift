import Foundation

struct AchievementRow: Identifiable {
    let id: AchievementID
    let isUnlocked: Bool
    let unlockedDate: Date?
}

@MainActor
final class AchievementsViewModel: ObservableObject {
    @Published private(set) var rows: [AchievementRow] = []

    private let repository = AchievementRepository()

    func load() {
        let unlocked = repository.unlockedIDs()
        rows = AchievementID.allCases.map { AchievementRow(id: $0, isUnlocked: unlocked.contains($0), unlockedDate: nil) }
    }
}
