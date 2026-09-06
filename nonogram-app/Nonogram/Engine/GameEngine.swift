import Foundation

/// Pure, UI-agnostic game logic for a single puzzle attempt: applying marks, detecting
/// completed lines (so the UI can strike through satisfied clues), counting mistakes,
/// and deciding when the board matches the puzzle's unique solution.
///
/// Kept independent of SwiftUI/Combine so it can be unit tested in isolation.
final class GameEngine {
    let puzzle: Puzzle
    private(set) var board: [[CellState]]
    private(set) var mistakeCount: Int = 0

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.board = Array(
            repeating: Array(repeating: CellState.empty, count: puzzle.width),
            count: puzzle.height
        )
    }

    /// Applies a mark action to a cell. Filling a cell that isn't part of the solution
    /// counts as a mistake; marking (X) never does, since it's just player bookkeeping.
    @discardableResult
    func apply(_ action: MarkAction, row: Int, col: Int) -> CellState {
        guard board.indices.contains(row), board[row].indices.contains(col) else {
            return .empty
        }

        let solutionFilled = puzzle.solutionGrid[row][col]
        let newState: CellState
        switch action {
        case .fill:
            newState = board[row][col] == .filled ? .empty : .filled
        case .mark:
            newState = board[row][col] == .marked ? .empty : .marked
        case .clear:
            newState = .empty
        }

        if newState == .filled && !solutionFilled {
            mistakeCount += 1
        }

        board[row][col] = newState
        return newState
    }

    func state(row: Int, col: Int) -> CellState {
        board[row][col]
    }

    /// A row/column is "complete" when its filled cells exactly match the solution's
    /// run pattern, regardless of any `.marked` cells — this is what lets the UI
    /// strike through a clue as soon as it's satisfied.
    func isRowComplete(_ row: Int) -> Bool {
        NonogramSolver.runs(in: board[row].map { $0 == .filled }) == puzzle.rowClues[row]
    }

    func isColumnComplete(_ col: Int) -> Bool {
        let column = (0..<puzzle.height).map { board[$0][col] == .filled }
        return NonogramSolver.runs(in: column) == puzzle.colClues[col]
    }

    /// The puzzle is solved when every filled cell matches the (guaranteed unique) solution.
    /// Marked (X) cells are ignored entirely.
    var isSolved: Bool {
        for row in 0..<puzzle.height {
            for col in 0..<puzzle.width {
                if (board[row][col] == .filled) != puzzle.solutionGrid[row][col] {
                    return false
                }
            }
        }
        return true
    }

    var filledCount: Int {
        board.reduce(0) { $0 + $1.filter { $0 == .filled }.count }
    }

    var totalSolutionCells: Int {
        puzzle.solutionGrid.reduce(0) { $0 + $1.filter { $0 }.count }
    }

    var progressFraction: Double {
        guard totalSolutionCells > 0 else { return 0 }
        let correctFilled = zip(board, puzzle.solutionGrid).reduce(0) { partial, pair in
            let (boardRow, solutionRow) = pair
            return partial + zip(boardRow, solutionRow).filter { $0 == .filled && $1 }.count
        }
        return Double(correctFilled) / Double(totalSolutionCells)
    }

    // MARK: - Boosters

    /// Solves an entire row using the puzzle's known solution (the "reveal row" booster).
    func revealRow(_ row: Int) {
        for col in 0..<puzzle.width {
            board[row][col] = puzzle.solutionGrid[row][col] ? .filled : .marked
        }
    }

    func revealColumn(_ col: Int) {
        for row in 0..<puzzle.height {
            board[row][col] = puzzle.solutionGrid[row][col] ? .filled : .marked
        }
    }

    /// Reveals a single incorrect or empty cell (the "hint" booster). Returns the cell revealed,
    /// preferring cells the player hasn't touched yet, then incorrect fills.
    @discardableResult
    func revealHintCell() -> (row: Int, col: Int)? {
        for row in 0..<puzzle.height {
            for col in 0..<puzzle.width {
                let shouldBeFilled = puzzle.solutionGrid[row][col]
                let current = board[row][col]
                if shouldBeFilled && current != .filled {
                    board[row][col] = .filled
                    return (row, col)
                }
                if !shouldBeFilled && current == .filled {
                    board[row][col] = .marked
                    return (row, col)
                }
            }
        }
        return nil
    }

    /// Returns the coordinates of every currently-filled cell that contradicts the solution,
    /// for the "check errors" booster, without revealing what the correct value should be.
    func incorrectCells() -> [(row: Int, col: Int)] {
        var result: [(Int, Int)] = []
        for row in 0..<puzzle.height {
            for col in 0..<puzzle.width {
                if board[row][col] == .filled && !puzzle.solutionGrid[row][col] {
                    result.append((row, col))
                }
            }
        }
        return result
    }
}
