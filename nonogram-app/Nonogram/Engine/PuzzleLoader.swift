import Foundation

enum PuzzleLoaderError: Error {
    case missingIndex
    case missingLevel(String)
    case decodingFailed(String, Error)
}

/// Loads the static, pre-generated puzzle content that ships in `Resources/Levels`.
/// All 200+ levels are authored offline by `Scripts/generate_levels.py`, which already
/// verified each one has a unique solution — this type just decodes them at runtime.
struct PuzzleLoader {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadIndex() throws -> LevelIndex {
        guard let url = bundle.url(forResource: "levels_index", withExtension: "json", subdirectory: "Levels") else {
            throw PuzzleLoaderError.missingIndex
        }
        do {
            return try JSONDecoder().decode(LevelIndex.self, from: Data(contentsOf: url))
        } catch {
            throw PuzzleLoaderError.decodingFailed("levels_index", error)
        }
    }

    func loadPuzzle(id: String, category: PuzzleCategory) throws -> Puzzle {
        guard let url = bundle.url(
            forResource: id,
            withExtension: "json",
            subdirectory: "Levels/\(category.rawValue)"
        ) else {
            throw PuzzleLoaderError.missingLevel(id)
        }
        do {
            return try JSONDecoder().decode(Puzzle.self, from: Data(contentsOf: url))
        } catch {
            throw PuzzleLoaderError.decodingFailed(id, error)
        }
    }

    /// Loads every puzzle in the index. Used by content-integrity tests and by the
    /// daily-challenge picker, which needs full solutions (not just the lightweight index).
    func loadAllPuzzles() throws -> [Puzzle] {
        try loadIndex().levels.map { try loadPuzzle(id: $0.id, category: $0.category) }
    }
}
