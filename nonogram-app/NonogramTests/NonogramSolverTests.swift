import XCTest
@testable import Nonogram

final class NonogramSolverTests: XCTestCase {

    // MARK: - runs(in:)

    func testRunsAllFalseLineIsEmpty() {
        XCTAssertEqual(NonogramSolver.runs(in: [false, false, false, false]), [])
    }

    func testRunsLineEndingFilledWithNoTrailingGap() {
        XCTAssertEqual(NonogramSolver.runs(in: [false, false, true, true]), [2])
    }

    func testRunsLineStartingFilled() {
        XCTAssertEqual(NonogramSolver.runs(in: [true, true, false, false]), [2])
    }

    func testRunsMultipleRunsWithSingleCellGaps() {
        XCTAssertEqual(NonogramSolver.runs(in: [true, false, true, false, true]), [1, 1, 1])
    }

    func testRunsFullyFilledLine() {
        XCTAssertEqual(NonogramSolver.runs(in: [true, true, true, true]), [4])
    }

    func testRunsMixedStartAndEndFilledWithGapBetween() {
        // Starts filled, ends filled, with an internal multi-cell run too.
        XCTAssertEqual(NonogramSolver.runs(in: [true, false, true, true, false, true]), [1, 2, 1])
    }

    // MARK: - solve: unique

    /// A 5x5 "plus" pattern. `[5]` forces row 2 fully filled and column 2 fully filled by
    /// trivial line-solving alone; every other line then has a single already-known filled
    /// cell that fully accounts for its `[1]` clue, forcing the rest of that line empty.
    /// This is resolvable by propagation alone with no guessing, and has exactly one solution:
    ///
    ///   0 0 1 0 0
    ///   0 0 1 0 0
    ///   1 1 1 1 1
    ///   0 0 1 0 0
    ///   0 0 1 0 0
    private let plusRowClues: [[Int]] = [[1], [1], [5], [1], [1]]
    private let plusColClues: [[Int]] = [[1], [1], [5], [1], [1]]
    private let plusSolution: [[Bool]] = [
        [false, false, true, false, false],
        [false, false, true, false, false],
        [true, true, true, true, true],
        [false, false, true, false, false],
        [false, false, true, false, false]
    ]

    func testSolveReturnsUniqueForPlusPattern() {
        let result = NonogramSolver.solve(width: 5, height: 5, rowClues: plusRowClues, colClues: plusColClues)
        guard case let .unique(solution) = result else {
            return XCTFail("expected .unique, got \(result)")
        }
        XCTAssertEqual(solution, plusSolution)
    }

    // MARK: - solve: multiple (ambiguous)

    /// The classic minimal ambiguous nonogram: a 2x2 grid with row clues [[1],[1]] and
    /// col clues [[1],[1]] has exactly two valid solutions (the two diagonals), so no
    /// amount of correct logic can determine which one is "the" answer.
    func testSolveReturnsMultipleForAmbiguous2x2() {
        let result = NonogramSolver.solve(width: 2, height: 2, rowClues: [[1], [1]], colClues: [[1], [1]])
        XCTAssertEqual(result, .multiple)
    }

    // MARK: - solve: none (unsolvable)

    /// A clue of `[5]` cannot fit in a line of length 3 at all.
    func testSolveReturnsNoneWhenRowClueCannotFitInWidth() {
        let result = NonogramSolver.solve(width: 3, height: 1, rowClues: [[5]], colClues: [[], [], []])
        XCTAssertEqual(result, .none)
    }

    /// Row clues demand 4 total filled cells (2+2) while column clues only allow 2 total
    /// (1+1) -- the totals are mutually contradictory, so no grid can satisfy both.
    func testSolveReturnsNoneForContradictoryRowColumnTotals() {
        let result = NonogramSolver.solve(width: 2, height: 2, rowClues: [[2], [2]], colClues: [[1], [1]])
        XCTAssertEqual(result, .none)
    }

    /// Mismatched clue-array counts vs. declared dimensions are also rejected as `.none`.
    func testSolveReturnsNoneWhenClueCountsDoNotMatchDimensions() {
        let result = NonogramSolver.solve(width: 2, height: 2, rowClues: [[1]], colClues: [[1], [1]])
        XCTAssertEqual(result, .none)
    }

    // MARK: - solvableByPropagationAlone

    func testSolvableByPropagationAloneTrueForPlusPattern() {
        XCTAssertTrue(
            NonogramSolver.solvableByPropagationAlone(
                width: 5, height: 5, rowClues: plusRowClues, colClues: plusColClues
            )
        )
    }

    /// The ambiguous 2x2 case is the textbook example of a puzzle line-solving cannot
    /// finish alone: a clue of `[1]` in a line of length 2 never forces any single cell
    /// (the two placements don't overlap), so propagation makes zero progress and every
    /// cell remains unknown -- exactly the "needs guessing" situation this predicate exists
    /// to detect, independent of whether solve() ultimately finds one, many, or (as here)
    /// multiple solutions.
    func testSolvableByPropagationAloneFalseForAmbiguous2x2() {
        XCTAssertFalse(
            NonogramSolver.solvableByPropagationAlone(width: 2, height: 2, rowClues: [[1], [1]], colClues: [[1], [1]])
        )
    }

    /// A directly-forced single-line case: clue `[5]` in a width-5 line has only one
    /// possible placement (the whole line filled), so a 1x5 puzzle is fully resolved by
    /// propagation alone.
    func testSolvableByPropagationAloneTrueForFullyForcedSingleLine() {
        XCTAssertTrue(
            NonogramSolver.solvableByPropagationAlone(width: 5, height: 1, rowClues: [[5]], colClues: [[1], [1], [1], [1], [1]])
        )
    }

    /// An unsolvable clue set (contradiction found during propagation) is, by definition,
    /// not "solvable by propagation alone" -- propagation itself reports failure.
    func testSolvableByPropagationAloneFalseWhenUnsolvable() {
        XCTAssertFalse(
            NonogramSolver.solvableByPropagationAlone(width: 3, height: 1, rowClues: [[5]], colClues: [[], [], []])
        )
    }
}
