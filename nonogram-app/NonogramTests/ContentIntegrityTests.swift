import XCTest
@testable import Nonogram

/// Verifies the core fairness promise of every *shipped* puzzle: for each JSON level file
/// discovered under `Resources/Levels/<category>/*.json`, the stored clues genuinely match
/// the stored solution, and -- most importantly -- the clues alone resolve to exactly one
/// possible grid (no ambiguous or unsolvable puzzle ever ships).
///
/// These files are produced by a separate, parallel content-generation effort and may not
/// exist on disk yet while this suite is first written (or briefly, in CI, before that
/// pipeline has run). Every test below therefore discovers whatever is actually present at
/// run time -- no level IDs, counts, or categories are hardcoded -- and skips gracefully via
/// `XCTSkip` when nothing is found yet, rather than silently passing or hard-failing the
/// whole suite.
final class ContentIntegrityTests: XCTestCase {

    // MARK: - Locating Resources/Levels

    /// Resolves the `Resources/Levels` directory two different ways, in order of preference:
    ///
    /// 1. **Bundle lookup** -- `Bundle(for: ContentIntegrityTests.self)` is the `NonogramTests`
    ///    test bundle. If it (or `Bundle.main`, in case this ever runs hosted inside the app
    ///    target) actually embeds the `Levels` folder reference as a resource, this is the most
    ///    faithful lookup, since it's the exact mechanism `PuzzleLoader` uses in the shipped app.
    ///    `Bundle.url(forResource: nil, withExtension: nil, subdirectory:)` is the documented
    ///    way to resolve a bundled *subdirectory itself* (rather than one specific resource
    ///    file inside it).
    /// 2. **Source-tree fallback**, anchored on `#filePath` of this very test file. As of this
    ///    writing, `project.yml`'s `NonogramTests` target declares no `resources` of its own
    ///    (only the `Nonogram` app target bundles `Resources/Levels`), so approach 1 will not
    ///    actually find anything in Xcode-built test bundles today, and a plain `swift test`
    ///    invocation has no bundle resource machinery at all. This file is known to always live
    ///    at `<repoRoot>/nonogram-app/NonogramTests/ContentIntegrityTests.swift`, so walking
    ///    upward from it looking for a sibling `Nonogram/Resources/Levels` directory finds the
    ///    real content regardless of build-system resource wiring. This is the path that
    ///    actually makes the test meaningful right now, kept simple and dependency-free.
    ///
    /// Returns `nil` (never throws) when neither approach finds anything, so callers can
    /// `XCTSkip` with a clear message instead of failing outright.
    private static func resolveLevelsDirectory() -> URL? {
        let testBundle = Bundle(for: ContentIntegrityTests.self)
        if let url = testBundle.url(forResource: nil, withExtension: nil, subdirectory: "Levels"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let url = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "Levels"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = directory
                .appendingPathComponent("Nonogram")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Levels")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }

    private static let levelsDirectory: URL? = resolveLevelsDirectory()

    // MARK: - Discovery

    private struct DiscoveredFile {
        let url: URL
        /// The `PuzzleCategory` implied by which subdirectory the file was found in
        /// (as opposed to the `category` field decoded from inside the JSON itself).
        let categoryFromPath: PuzzleCategory
    }

    /// Every `<category>/*.json` file found on disk, one entry per file, discovered fresh
    /// by scanning `PuzzleCategory.allCases` subdirectories -- nothing here is hardcoded to
    /// any particular level ID or expected count.
    private static let discoveredFiles: [DiscoveredFile] = {
        guard let levelsDirectory else { return [] }
        var result: [DiscoveredFile] = []
        for category in PuzzleCategory.allCases {
            let categoryDir = levelsDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: categoryDir, includingPropertiesForKeys: nil
            ) else { continue }
            for url in entries where url.pathExtension.lowercased() == "json" {
                result.append(DiscoveredFile(url: url, categoryFromPath: category))
            }
        }
        return result
    }()

    private struct DecodeFailure {
        let url: URL
        let error: Error
    }

    private struct DecodedLevel {
        let url: URL
        let categoryFromPath: PuzzleCategory
        let puzzle: Puzzle
    }

    /// Decodes every discovered file exactly once (shared across all test methods in this
    /// run via the `static let`), separating out decode failures so a single malformed file
    /// surfaces as one clear, named failure (in `testAllLevelFilesDecodeSuccessfully`) instead
    /// of crashing every other test in the suite.
    private static let decoded: (levels: [DecodedLevel], failures: [DecodeFailure]) = {
        var levels: [DecodedLevel] = []
        var failures: [DecodeFailure] = []
        for file in discoveredFiles {
            do {
                let data = try Data(contentsOf: file.url)
                let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
                levels.append(DecodedLevel(url: file.url, categoryFromPath: file.categoryFromPath, puzzle: puzzle))
            } catch {
                failures.append(DecodeFailure(url: file.url, error: error))
            }
        }
        return (levels, failures)
    }()

    /// Skips the calling test with a clear message when the content-generation pipeline
    /// hasn't produced any level files yet, rather than passing (or failing) vacuously.
    private func skipIfNoLevelsFound() throws {
        if Self.discoveredFiles.isEmpty {
            throw XCTSkip(
                "No level JSON files found under Resources/Levels/<category>/ yet -- " +
                "the content-generation pipeline hasn't run (or hasn't produced output). " +
                "Skipping content-integrity checks."
            )
        }
    }

    // MARK: - Decoding

    func testAllLevelFilesDecodeSuccessfully() throws {
        try skipIfNoLevelsFound()
        if !Self.decoded.failures.isEmpty {
            let details = Self.decoded.failures
                .map { "  - \($0.url.lastPathComponent): \($0.error)" }
                .joined(separator: "\n")
            XCTFail("\(Self.decoded.failures.count) level file(s) failed to decode as Puzzle:\n\(details)")
        }
    }

    // MARK: - Dimensions

    func testSolutionDimensionsMatchDeclaredWidthAndHeight() throws {
        try skipIfNoLevelsFound()
        for level in Self.decoded.levels {
            let puzzle = level.puzzle
            XCTAssertEqual(
                puzzle.solution.count, puzzle.height,
                "level '\(puzzle.id)': solution has \(puzzle.solution.count) rows but height is \(puzzle.height)"
            )
            for (rowIndex, row) in puzzle.solution.enumerated() {
                XCTAssertEqual(
                    row.count, puzzle.width,
                    "level '\(puzzle.id)': solution row \(rowIndex) has \(row.count) characters but width is \(puzzle.width)"
                )
            }
        }
    }

    // MARK: - Clues vs. stored solution

    func testStoredCluesMatchRunsOfStoredSolution() throws {
        try skipIfNoLevelsFound()
        for level in Self.decoded.levels {
            let puzzle = level.puzzle
            let grid = puzzle.solutionGrid

            guard grid.count == puzzle.rowClues.count else {
                XCTFail("level '\(puzzle.id)': rowClues count (\(puzzle.rowClues.count)) doesn't match solution row count (\(grid.count))")
                continue
            }
            for (rowIndex, row) in grid.enumerated() {
                let actual = NonogramSolver.runs(in: row)
                XCTAssertEqual(
                    actual, puzzle.rowClues[rowIndex],
                    "level '\(puzzle.id)': rowClues[\(rowIndex)] = \(puzzle.rowClues[rowIndex]) but solution row's actual runs = \(actual)"
                )
            }

            guard puzzle.width == puzzle.colClues.count else {
                XCTFail("level '\(puzzle.id)': colClues count (\(puzzle.colClues.count)) doesn't match width (\(puzzle.width))")
                continue
            }
            for col in 0..<puzzle.width {
                let column = grid.map { $0[col] }
                let actual = NonogramSolver.runs(in: column)
                XCTAssertEqual(
                    actual, puzzle.colClues[col],
                    "level '\(puzzle.id)': colClues[\(col)] = \(puzzle.colClues[col]) but solution column's actual runs = \(actual)"
                )
            }
        }
    }

    // MARK: - Core fairness guarantee: unique solvability

    func testEveryLevelClueSetHasAUniqueSolutionMatchingStoredSolution() throws {
        try skipIfNoLevelsFound()
        for level in Self.decoded.levels {
            let puzzle = level.puzzle
            let result = NonogramSolver.solve(
                width: puzzle.width, height: puzzle.height,
                rowClues: puzzle.rowClues, colClues: puzzle.colClues
            )
            switch result {
            case .unique(let solvedGrid):
                XCTAssertEqual(
                    solvedGrid, puzzle.solutionGrid,
                    "level '\(puzzle.id)': solver's unique solution does not match the stored solution grid"
                )
            case .multiple:
                XCTFail("level '\(puzzle.id)': clues admit MULTIPLE solutions -- puzzle is ambiguous and unfair")
            case .none:
                XCTFail("level '\(puzzle.id)': clues admit NO valid solution -- puzzle is unsolvable")
            }
        }
    }

    // MARK: - Global uniqueness / placement

    func testAllLevelIDsAreGloballyUnique() throws {
        try skipIfNoLevelsFound()
        let ids = Self.decoded.levels.map(\.puzzle.id)
        var seen = Set<String>()
        var duplicates = Set<String>()
        for id in ids {
            if !seen.insert(id).inserted { duplicates.insert(id) }
        }
        XCTAssertTrue(duplicates.isEmpty, "duplicate level id(s) found across categories: \(duplicates.sorted())")
    }

    func testLevelFilenameMatchesItsPuzzleID() throws {
        try skipIfNoLevelsFound()
        for level in Self.decoded.levels {
            let filenameID = level.url.deletingPathExtension().lastPathComponent
            XCTAssertEqual(
                filenameID, level.puzzle.id,
                "file '\(level.url.lastPathComponent)' decodes to id '\(level.puzzle.id)', which doesn't match its filename"
            )
        }
    }

    func testCategoryFileSystemPlacementMatchesJSONCategoryField() throws {
        try skipIfNoLevelsFound()
        for level in Self.decoded.levels {
            XCTAssertEqual(
                level.categoryFromPath, level.puzzle.category,
                "level '\(level.puzzle.id)' is stored under '\(level.categoryFromPath.rawValue)/' " +
                "but its JSON category field says '\(level.puzzle.category.rawValue)'"
            )
        }
    }

    // MARK: - levels_index.json

    func testLevelsIndexEntryCountMatchesDiscoveredLevelFileCount() throws {
        try skipIfNoLevelsFound()
        guard let levelsDirectory = Self.levelsDirectory else {
            return XCTFail("levels directory unexpectedly nil despite discovered files")
        }
        let indexURL = levelsDirectory.appendingPathComponent("levels_index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return XCTFail("levels_index.json not found at \(indexURL.path) even though \(Self.discoveredFiles.count) level file(s) were found")
        }
        let index = try JSONDecoder().decode(LevelIndex.self, from: Data(contentsOf: indexURL))
        XCTAssertEqual(
            index.levels.count, Self.discoveredFiles.count,
            "levels_index.json lists \(index.levels.count) entries but \(Self.discoveredFiles.count) per-level JSON file(s) were discovered on disk"
        )
    }

    func testLevelsIndexEntriesMatchTheirCorrespondingLevelFiles() throws {
        try skipIfNoLevelsFound()
        guard let levelsDirectory = Self.levelsDirectory else {
            return XCTFail("levels directory unexpectedly nil despite discovered files")
        }
        let indexURL = levelsDirectory.appendingPathComponent("levels_index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw XCTSkip("levels_index.json not found; entry-matching check covered by the count test's failure instead.")
        }
        let index = try JSONDecoder().decode(LevelIndex.self, from: Data(contentsOf: indexURL))
        let puzzlesByID = Dictionary(uniqueKeysWithValues: Self.decoded.levels.map { ($0.puzzle.id, $0.puzzle) })

        for entry in index.levels {
            guard let puzzle = puzzlesByID[entry.id] else {
                XCTFail("levels_index.json references id '\(entry.id)' with no corresponding decoded level file on disk")
                continue
            }
            XCTAssertEqual(entry.category, puzzle.category, "index entry '\(entry.id)': category mismatch")
            XCTAssertEqual(entry.difficulty, puzzle.difficulty, "index entry '\(entry.id)': difficulty mismatch")
            XCTAssertEqual(entry.width, puzzle.width, "index entry '\(entry.id)': width mismatch")
            XCTAssertEqual(entry.height, puzzle.height, "index entry '\(entry.id)': height mismatch")
        }
    }
}
