import XCTest
@testable import Nonogram

/// Tests for `GameEngine`, the pure per-attempt game logic, using small hand-built
/// fixture puzzles (never depending on any generated JSON content under Resources/Levels).
final class GameEngineTests: XCTestCase {

    // MARK: - Fixtures

    /// A 3x3 "L-shape" with a solution that is trivially unique (not that GameEngine cares —
    /// it only ever consults the puzzle's *stored* clues/solution, never re-derives them):
    ///
    ///   1 1 1      row clues: [3], [1], [1]
    ///   1 0 0      col clues: [3], [1], [1]
    ///   1 0 0
    private func makeLShapePuzzle() -> Puzzle {
        Puzzle(
            id: "fixture-lshape",
            title: LocalizedText(en: "Fixture", he: "בדיקה"),
            category: .objects,
            difficulty: .easy,
            width: 3,
            height: 3,
            solution: ["111", "100", "100"],
            rowClues: [[3], [1], [1]],
            colClues: [[3], [1], [1]],
            colorHex: "#FF0000",
            order: 0
        )
    }

    /// A 2x2 fixture whose first row/column are entirely empty, so `isRowComplete`/
    /// `isColumnComplete` can be exercised against the "empty clue" ([]) case:
    ///
    ///   0 0      row clues: [], [2]
    ///   1 1      col clues: [1], [1]
    private func makePuzzleWithEmptyRow() -> Puzzle {
        Puzzle(
            id: "fixture-emptyrow",
            title: LocalizedText(en: "Fixture2", he: "בדיקה2"),
            category: .objects,
            difficulty: .easy,
            width: 2,
            height: 2,
            solution: ["00", "11"],
            rowClues: [[], [2]],
            colClues: [[1], [1]],
            colorHex: "#00FF00",
            order: 1
        )
    }

    // MARK: - Initial state

    func testInitialBoardIsAllEmpty() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        for row in 0..<3 {
            for col in 0..<3 {
                XCTAssertEqual(engine.state(row: row, col: col), .empty, "(\(row),\(col)) should start empty")
            }
        }
        XCTAssertEqual(engine.mistakeCount, 0)
    }

    // MARK: - apply(.fill:)

    func testApplyFillTogglesEmptyAndFilled() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())

        let first = engine.apply(.fill, row: 0, col: 0)
        XCTAssertEqual(first, .filled)
        XCTAssertEqual(engine.state(row: 0, col: 0), .filled)

        let second = engine.apply(.fill, row: 0, col: 0)
        XCTAssertEqual(second, .empty)
        XCTAssertEqual(engine.state(row: 0, col: 0), .empty)
    }

    /// GameEngine's `.fill` case only checks `board[row][col] == .filled`, so filling a
    /// `.marked` cell does NOT clear the mark first -- it goes straight to `.filled`.
    /// This is a real, slightly surprising behavior of the current implementation, tested
    /// explicitly here rather than assumed.
    func testApplyFillOnMarkedCellGoesDirectlyToFilled() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.mark, row: 0, col: 1)
        XCTAssertEqual(engine.state(row: 0, col: 1), .marked)

        let result = engine.apply(.fill, row: 0, col: 1)
        XCTAssertEqual(result, .filled)
        XCTAssertEqual(engine.state(row: 0, col: 1), .filled)
    }

    // MARK: - apply(.mark:)

    func testApplyMarkTogglesEmptyAndMarked() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())

        let first = engine.apply(.mark, row: 1, col: 1)
        XCTAssertEqual(first, .marked)
        XCTAssertEqual(engine.state(row: 1, col: 1), .marked)

        let second = engine.apply(.mark, row: 1, col: 1)
        XCTAssertEqual(second, .empty)
        XCTAssertEqual(engine.state(row: 1, col: 1), .empty)
    }

    /// `.mark`'s toggle condition is only `board[row][col] == .marked ? .empty : .marked`,
    /// so marking a currently-`.filled` cell transitions it straight to `.marked` (it does
    /// not clear/no-op just because the cell was filled). Verified explicitly per instructions.
    func testApplyMarkOnFilledCellTransitionsToMarked() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0) // correct fill, part of solution
        XCTAssertEqual(engine.state(row: 0, col: 0), .filled)

        let result = engine.apply(.mark, row: 0, col: 0)
        XCTAssertEqual(result, .marked)
        XCTAssertEqual(engine.state(row: 0, col: 0), .marked)
    }

    // MARK: - apply(.clear:)

    func testApplyClearAlwaysProducesEmpty() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0)
        XCTAssertEqual(engine.apply(.clear, row: 0, col: 0), .empty)
        XCTAssertEqual(engine.state(row: 0, col: 0), .empty)
    }

    // MARK: - Out-of-bounds

    func testApplyOutOfBoundsIsANoOpAndReturnsEmpty() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        let result = engine.apply(.fill, row: 99, col: 0)
        XCTAssertEqual(result, .empty)
        XCTAssertEqual(engine.mistakeCount, 0)
    }

    // MARK: - Mistake counting

    func testFillingCellNotInSolutionIncrementsMistakeCount() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        // (0,0)..(2,0) and (0,*) are the only solution cells; (1,1) is not part of the solution.
        engine.apply(.fill, row: 1, col: 1)
        XCTAssertEqual(engine.mistakeCount, 1)
    }

    func testFillingCellInSolutionDoesNotIncrementMistakeCount() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0) // part of the solution
        XCTAssertEqual(engine.mistakeCount, 0)
    }

    func testTogglingCorrectFillBackOffDoesNotIncrementMistakeCount() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0) // fill correct cell
        engine.apply(.fill, row: 0, col: 0) // toggle back off
        XCTAssertEqual(engine.mistakeCount, 0)
        XCTAssertEqual(engine.state(row: 0, col: 0), .empty)
    }

    func testMarkActionsNeverIncrementMistakeCount() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.mark, row: 1, col: 1) // not part of solution, but marking never counts
        engine.apply(.mark, row: 1, col: 1) // toggle back off
        engine.apply(.mark, row: 0, col: 0) // part of solution
        XCTAssertEqual(engine.mistakeCount, 0)
    }

    /// The implementation increments `mistakeCount` on every transition *into* an incorrect
    /// `.filled` state, with no de-duplication -- so re-filling the same wrong cell after
    /// clearing it counts as a second mistake. This is a real (if perhaps unintended) quirk
    /// of the current code, verified here rather than assumed.
    func testRefillingSameIncorrectCellIncrementsMistakeCountAgain() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 1, col: 1) // wrong: mistake #1
        engine.apply(.fill, row: 1, col: 1) // toggles back to empty, no change to count
        engine.apply(.fill, row: 1, col: 1) // wrong again: mistake #2
        XCTAssertEqual(engine.mistakeCount, 2)
    }

    // MARK: - isRowComplete / isColumnComplete

    func testIsRowCompleteTrueWhenRunsMatchClue() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        XCTAssertFalse(engine.isRowComplete(0))
        engine.apply(.fill, row: 0, col: 0)
        engine.apply(.fill, row: 0, col: 1)
        engine.apply(.fill, row: 0, col: 2)
        XCTAssertTrue(engine.isRowComplete(0))
    }

    func testIsRowCompleteBecomesFalseAgainWhenDisturbed() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0)
        engine.apply(.fill, row: 0, col: 1)
        engine.apply(.fill, row: 0, col: 2)
        XCTAssertTrue(engine.isRowComplete(0))

        engine.apply(.fill, row: 0, col: 2) // toggle back off
        XCTAssertFalse(engine.isRowComplete(0))
    }

    func testIsColumnCompleteTrueWhenRunsMatchClue() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        XCTAssertFalse(engine.isColumnComplete(0))
        engine.apply(.fill, row: 0, col: 0)
        engine.apply(.fill, row: 1, col: 0)
        engine.apply(.fill, row: 2, col: 0)
        XCTAssertTrue(engine.isColumnComplete(0))
    }

    func testIsColumnCompleteBecomesFalseAgainWhenDisturbed() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0)
        engine.apply(.fill, row: 1, col: 0)
        engine.apply(.fill, row: 2, col: 0)
        XCTAssertTrue(engine.isColumnComplete(0))

        engine.apply(.fill, row: 1, col: 0) // toggle back off
        XCTAssertFalse(engine.isColumnComplete(0))
    }

    /// A row (or column) whose clue is `[]` (all-empty) is "complete" from the very start,
    /// since `NonogramSolver.runs(in:)` on an untouched (all `.empty`) line is also `[]`.
    func testIsRowCompleteTrueForAllEmptyLineFromTheStart() {
        let engine = GameEngine(puzzle: makePuzzleWithEmptyRow())
        XCTAssertTrue(engine.isRowComplete(0)) // clue [] matches an untouched empty row
    }

    func testIsRowCompleteForEmptyLineBecomesFalseIfFilled() {
        let engine = GameEngine(puzzle: makePuzzleWithEmptyRow())
        XCTAssertTrue(engine.isRowComplete(0))
        engine.apply(.fill, row: 0, col: 0)
        XCTAssertFalse(engine.isRowComplete(0))
    }

    // MARK: - isSolved

    func testIsSolvedFalseInitially() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        XCTAssertFalse(engine.isSolved)
    }

    func testIsSolvedFalseWhenIncompleteOrIncorrect() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0)
        XCTAssertFalse(engine.isSolved) // incomplete

        engine.apply(.fill, row: 1, col: 1) // incorrect extra fill
        engine.apply(.fill, row: 0, col: 1)
        engine.apply(.fill, row: 0, col: 2)
        engine.apply(.fill, row: 1, col: 0)
        engine.apply(.fill, row: 2, col: 0)
        XCTAssertFalse(engine.isSolved) // all solution cells filled, but (1,1) is an extra wrong fill
    }

    private func fillEntireSolution(_ engine: GameEngine, puzzle: Puzzle) {
        for row in 0..<puzzle.height {
            for col in 0..<puzzle.width where puzzle.solutionGrid[row][col] {
                engine.apply(.fill, row: row, col: col)
            }
        }
    }

    func testIsSolvedTrueOnlyWhenBoardExactlyMatchesSolution() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        fillEntireSolution(engine, puzzle: puzzle)
        XCTAssertTrue(engine.isSolved)
    }

    /// `.marked` cells never factor into `isSolved` either way: marking every non-solution
    /// cell (instead of leaving it `.empty`) still counts as solved.
    func testIsSolvedIgnoresMarkedCellsEntirely() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        fillEntireSolution(engine, puzzle: puzzle)
        for row in 0..<puzzle.height {
            for col in 0..<puzzle.width where !puzzle.solutionGrid[row][col] {
                engine.apply(.mark, row: row, col: col)
            }
        }
        XCTAssertTrue(engine.isSolved)
    }

    // MARK: - progressFraction

    func testProgressFractionIsZeroAtStart() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        XCTAssertEqual(engine.progressFraction, 0, accuracy: 0.0001)
    }

    func testProgressFractionIsOneWhenSolved() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        fillEntireSolution(engine, puzzle: puzzle)
        XCTAssertEqual(engine.progressFraction, 1.0, accuracy: 0.0001)
    }

    /// L-shape solution has 5 filled cells total (row0 has 3, plus (1,0) and (2,0)).
    /// Filling exactly 2 of them correctly should report a proportional 2/5 progress,
    /// and an extra *incorrect* fill elsewhere must not move the needle at all.
    func testProgressFractionIsProportionalToCorrectlyFilledCellsOnly() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        XCTAssertEqual(engine.totalSolutionCells, 5)

        engine.apply(.fill, row: 0, col: 0)
        engine.apply(.fill, row: 0, col: 1)
        XCTAssertEqual(engine.progressFraction, 2.0 / 5.0, accuracy: 0.0001)

        engine.apply(.fill, row: 1, col: 1) // incorrect fill, not part of the solution
        XCTAssertEqual(engine.progressFraction, 2.0 / 5.0, accuracy: 0.0001, "wrong fills must not affect progress")
    }

    // MARK: - revealRow / revealColumn

    func testRevealRowProducesFullyCorrectRow() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        engine.revealRow(1)
        for col in 0..<puzzle.width {
            let expected: CellState = puzzle.solutionGrid[1][col] ? .filled : .marked
            XCTAssertEqual(engine.state(row: 1, col: col), expected)
        }
    }

    func testRevealColumnProducesFullyCorrectColumn() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        engine.revealColumn(1)
        for row in 0..<puzzle.height {
            let expected: CellState = puzzle.solutionGrid[row][1] ? .filled : .marked
            XCTAssertEqual(engine.state(row: row, col: 1), expected)
        }
    }

    // MARK: - revealHintCell

    func testRevealHintCellReturnsCoordinateMatchingSolutionAfterward() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        guard let coordinate = engine.revealHintCell() else {
            return XCTFail("expected a hint on a fresh board")
        }
        let expectedState: CellState = puzzle.solutionGrid[coordinate.row][coordinate.col] ? .filled : .marked
        XCTAssertEqual(engine.state(row: coordinate.row, col: coordinate.col), expectedState)
    }

    func testRevealHintCellReturnsNilWhenBoardAlreadyFullyCorrect() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        fillEntireSolution(engine, puzzle: puzzle)
        XCTAssertTrue(engine.isSolved)
        XCTAssertNil(engine.revealHintCell())
        // Calling repeatedly stays nil (idempotent no-op once correct).
        XCTAssertNil(engine.revealHintCell())
    }

    func testRevealHintCellEventuallySolvesTheBoardWhenCalledRepeatedly() {
        let puzzle = makeLShapePuzzle()
        let engine = GameEngine(puzzle: puzzle)
        var iterations = 0
        while engine.revealHintCell() != nil {
            iterations += 1
            XCTAssertLessThan(iterations, puzzle.width * puzzle.height + 1, "hint loop should terminate")
        }
        XCTAssertTrue(engine.isSolved)
    }

    // MARK: - incorrectCells

    func testIncorrectCellsEmptyOnAFreshBoard() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        XCTAssertTrue(engine.incorrectCells().isEmpty)
    }

    func testIncorrectCellsReturnsExactlyTheWronglyFilledCoordinates() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0) // correct, should not appear
        engine.apply(.fill, row: 1, col: 1) // wrong
        engine.apply(.fill, row: 2, col: 2) // wrong

        let incorrect = engine.incorrectCells()
        XCTAssertEqual(incorrect.count, 2)
        XCTAssertTrue(incorrect.contains { $0.row == 1 && $0.col == 1 })
        XCTAssertTrue(incorrect.contains { $0.row == 2 && $0.col == 2 })
        XCTAssertFalse(incorrect.contains { $0.row == 0 && $0.col == 0 })
    }

    func testIncorrectCellsEmptyWhenNoMistakesEvenIfIncomplete() {
        let engine = GameEngine(puzzle: makeLShapePuzzle())
        engine.apply(.fill, row: 0, col: 0) // correct, board still incomplete overall
        XCTAssertTrue(engine.incorrectCells().isEmpty)
    }
}
