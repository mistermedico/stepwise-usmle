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

    private let loader: PuzzleLoader

    init(loader: PuzzleLoader = PuzzleLoader()) {
        self.loader = loader
    }

    /// Takes a snapshot of what it needs from `AppViewModel` as plain parameters (rather than
    /// holding a reference to it) so this view model has no construction-order dependency on
    /// the environment object being available yet.
    func load(
        entriesByCategory: [PuzzleCategory: [LevelIndexEntry]],
        completedLevelIDs: Set<String>,
        flawlessLevelIDs: Set<String>
    ) {
        guard !isLoading else { return }
        isLoading = true
        let loader = self.loader

        DispatchQueue.global(qos: .userInitiated).async {
            var result: [PuzzleCategory: [Item]] = [:]
            for (category, entries) in entriesByCategory {
                result[category] = entries.map { entry in
                    let completed = completedLevelIDs.contains(entry.id)
                    let puzzle = completed ? try? loader.loadPuzzle(id: entry.id, category: category) : nil
                    return Item(
                        entry: entry,
                        puzzle: puzzle,
                        isCompleted: completed,
                        isFlawless: flawlessLevelIDs.contains(entry.id)
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
