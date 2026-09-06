import Foundation

/// Backs the "collection album" screen: every level across every category, with the full
/// `Puzzle` (needed to render its tiny solved-image thumbnail) loaded on demand only for
/// completed levels. Locked/incomplete entries are shown as silhouette placeholders using
/// just the lightweight index data, so this never has to decode an unsolved puzzle's answer.
final class GalleryViewModel: ObservableObject {
    struct Item: Identifiable {
        let entry: LevelIndexEntry
        var puzzle: Puzzle?
        var isCompleted: Bool
        var isFlawless: Bool
        var id: String { entry.id }
    }

    @Published private(set) var itemsByCategory: [PuzzleCategory: [Item]] = [:]
    @Published private(set) var isLoading = false

    private let appViewModel: AppViewModel
    private let loader: PuzzleLoader

    init(appViewModel: AppViewModel, loader: PuzzleLoader = PuzzleLoader()) {
        self.appViewModel = appViewModel
        self.loader = loader
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        let progress = appViewModel.progress
        let categories = PuzzleCategory.allCases
        let entriesByCategory = categories.reduce(into: [PuzzleCategory: [LevelIndexEntry]]()) {
            $0[$1] = appViewModel.levels(in: $1)
        }
        let loader = self.loader

        DispatchQueue.global(qos: .userInitiated).async {
            var result: [PuzzleCategory: [Item]] = [:]
            for category in categories {
                let entries = entriesByCategory[category] ?? []
                result[category] = entries.map { entry in
                    let completed = progress.completedLevelIDs.contains(entry.id)
                    let puzzle = completed ? try? loader.loadPuzzle(id: entry.id, category: category) : nil
                    return Item(
                        entry: entry,
                        puzzle: puzzle,
                        isCompleted: completed,
                        isFlawless: progress.flawlessLevelIDs.contains(entry.id)
                    )
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.itemsByCategory = result
                self?.isLoading = false
            }
        }
    }
}
