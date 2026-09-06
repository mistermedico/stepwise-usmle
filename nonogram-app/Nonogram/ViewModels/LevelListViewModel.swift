import Foundation

/// Backs the level-select grid for a single category: the ordered list of levels plus
/// each one's lock/complete/flawless state, read live from `AppViewModel`.
final class LevelListViewModel: ObservableObject {
    let category: PuzzleCategory
    private let appViewModel: AppViewModel

    init(category: PuzzleCategory, appViewModel: AppViewModel) {
        self.category = category
        self.appViewModel = appViewModel
    }

    var entries: [LevelIndexEntry] {
        appViewModel.levels(in: category)
    }

    var completedCount: Int {
        appViewModel.completedCount(in: category)
    }

    var totalCount: Int {
        appViewModel.totalCount(in: category)
    }

    func isUnlocked(_ entry: LevelIndexEntry) -> Bool {
        appViewModel.isLevelUnlocked(entry)
    }

    func isCompleted(_ entry: LevelIndexEntry) -> Bool {
        appViewModel.progress.completedLevelIDs.contains(entry.id)
    }

    func isFlawless(_ entry: LevelIndexEntry) -> Bool {
        appViewModel.progress.flawlessLevelIDs.contains(entry.id)
    }
}
