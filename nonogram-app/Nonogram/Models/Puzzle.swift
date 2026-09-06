import Foundation

/// A single Nonogram puzzle, decoded from the static JSON resources shipped in `Resources/Levels`.
struct Puzzle: Codable, Identifiable, Equatable {
    let id: String
    let title: LocalizedText
    let category: PuzzleCategory
    let difficulty: PuzzleDifficulty
    let width: Int
    let height: Int
    /// Row-major solution grid. Each string has `width` characters of "0" (empty) or "1" (filled).
    let solution: [String]
    let rowClues: [[Int]]
    let colClues: [[Int]]
    let colorHex: String
    /// Position of this level within its category, used to gate unlocking.
    let order: Int

    /// The solution as a 2D boolean grid, `[row][col]`.
    var solutionGrid: [[Bool]] {
        solution.map { row in row.map { $0 == "1" } }
    }
}

struct LocalizedText: Codable, Equatable {
    let en: String
    let he: String

    func localized(for languageCode: String) -> String {
        languageCode.hasPrefix("he") ? he : en
    }
}

enum PuzzleCategory: String, Codable, CaseIterable, Identifiable {
    case animals
    case food
    case nature
    case objects

    var id: String { rawValue }

    var displayName: LocalizedText {
        switch self {
        case .animals: return LocalizedText(en: "Animals", he: "חיות")
        case .food: return LocalizedText(en: "Food", he: "אוכל")
        case .nature: return LocalizedText(en: "Nature", he: "טבע")
        case .objects: return LocalizedText(en: "Objects", he: "חפצים")
        }
    }
}

enum PuzzleDifficulty: String, Codable, CaseIterable, Comparable {
    case easy
    case medium
    case hard
    case expert

    private var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .expert: return 3
        }
    }

    static func < (lhs: PuzzleDifficulty, rhs: PuzzleDifficulty) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: LocalizedText {
        switch self {
        case .easy: return LocalizedText(en: "Easy", he: "קל")
        case .medium: return LocalizedText(en: "Medium", he: "בינוני")
        case .hard: return LocalizedText(en: "Hard", he: "קשה")
        case .expert: return LocalizedText(en: "Expert", he: "מומחה")
        }
    }
}

/// Lightweight index entry, mirrors `levels_index.json` so the level-select screen
/// doesn't need to decode every full puzzle (with its solution) up front.
struct LevelIndexEntry: Codable, Identifiable {
    let id: String
    let category: PuzzleCategory
    let difficulty: PuzzleDifficulty
    let width: Int
    let height: Int
    let order: Int
}

struct LevelIndex: Codable {
    let levels: [LevelIndexEntry]
}
