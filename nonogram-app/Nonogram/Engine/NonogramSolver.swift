import Foundation

/// Standalone Nonogram solving engine, independent of any specific puzzle's stored solution.
///
/// This is the module responsible for the genre's core fairness guarantee: a puzzle's row/column
/// clues alone must resolve to exactly one possible grid. `PuzzleGenerator` (offline, see
/// `Scripts/generate_levels.py`) uses the equivalent algorithm to reject any candidate pattern
/// that doesn't have a unique solution before it's ever shipped; `NonogramSolverTests` re-runs
/// this Swift implementation against every bundled level as a build-time safety net.
enum NonogramSolver {

    /// Computes the run-length clue for a single boolean line, e.g. `[T,T,F,T]` -> `[2, 1]`.
    /// An all-empty line has the (representable) clue `[]`.
    static func runs(in line: [Bool]) -> [Int] {
        var result: [Int] = []
        var current = 0
        for cell in line {
            if cell {
                current += 1
            } else if current > 0 {
                result.append(current)
                current = 0
            }
        }
        if current > 0 { result.append(current) }
        return result
    }

    enum SolveResult: Equatable {
        case unique([[Bool]])
        case multiple
        case none
    }

    /// Determines whether `rowClues`/`colClues` alone admit exactly one solution grid.
    /// Uses constraint propagation to a fixed point, then falls back to bounded backtracking
    /// (capped at finding 2 solutions, since we only need to distinguish unique/not-unique).
    static func solve(width: Int, height: Int, rowClues: [[Int]], colClues: [[Int]]) -> SolveResult {
        guard rowClues.count == height, colClues.count == width else { return .none }

        var grid = Array(repeating: Array(repeating: CellValue.unknown, count: width), count: height)
        guard propagate(&grid, rowClues: rowClues, colClues: colClues) else { return .none }

        var solutions: [[[Bool]]] = []
        search(grid, rowClues: rowClues, colClues: colClues, solutions: &solutions, limit: 2)

        switch solutions.count {
        case 0: return .none
        case 1: return .unique(solutions[0])
        default: return .multiple
        }
    }

    /// Rough difficulty signal: whether the puzzle can be fully resolved by line-solving alone
    /// (no guessing), which corresponds to the genre's "easy/medium" logic techniques.
    static func solvableByPropagationAlone(width: Int, height: Int, rowClues: [[Int]], colClues: [[Int]]) -> Bool {
        var grid = Array(repeating: Array(repeating: CellValue.unknown, count: width), count: height)
        guard propagate(&grid, rowClues: rowClues, colClues: colClues) else { return false }
        return grid.allSatisfy { row in row.allSatisfy { $0 != .unknown } }
    }

    // MARK: - Internal representation

    private enum CellValue: Equatable {
        case unknown
        case filled
        case empty
    }

    /// Re-solves every row and column from its clues plus currently-known cells, narrowing
    /// `unknown` cells, until nothing changes. Returns false on contradiction (an unsatisfiable
    /// line), which is the normal way a backtracking guess gets rejected.
    @discardableResult
    private static func propagate(_ grid: inout [[CellValue]], rowClues: [[Int]], colClues: [[Int]]) -> Bool {
        let height = grid.count
        let width = grid.first?.count ?? 0
        var changed = true

        while changed {
            changed = false

            for row in 0..<height {
                guard let solved = solveLine(length: width, clues: rowClues[row], known: grid[row]) else {
                    return false
                }
                if solved != grid[row] {
                    grid[row] = solved
                    changed = true
                }
            }

            for col in 0..<width {
                let column = (0..<height).map { grid[$0][col] }
                guard let solved = solveLine(length: height, clues: colClues[col], known: column) else {
                    return false
                }
                if solved != column {
                    for row in 0..<height { grid[row][col] = solved[row] }
                    changed = true
                }
            }
        }
        return true
    }

    /// Enumerates every placement of `clues` in a line of `length` consistent with `known`,
    /// then intersects them: a cell resolves only where every valid placement agrees.
    /// Returns nil if no placement satisfies `known` (a contradiction).
    private static func solveLine(length: Int, clues: [Int], known: [CellValue]) -> [CellValue]? {
        let blocks = clues.filter { $0 > 0 }

        if blocks.isEmpty {
            let allEmpty = Array(repeating: CellValue.empty, count: length)
            return matches(allEmpty, known: known) ? allEmpty : nil
        }

        var intersection: [CellValue]?

        func place(blockIndex: Int, start: Int, current: [CellValue]) {
            if blockIndex == blocks.count {
                var candidate = current
                for i in start..<length { candidate[i] = .empty }
                guard matches(candidate, known: known) else { return }
                intersection = merge(intersection, candidate)
                return
            }

            let blockLength = blocks[blockIndex]
            let remainingMin = blocks[(blockIndex + 1)...].reduce(0) { $0 + $1 + 1 }
            let maxStart = length - remainingMin - blockLength
            guard start <= maxStart else { return }

            var position = start
            while position <= maxStart {
                var candidate = current
                for i in start..<position { candidate[i] = .empty }
                for i in position..<(position + blockLength) { candidate[i] = .filled }
                let nextGap = position + blockLength
                let nextStart = min(nextGap + 1, length)
                if nextGap < length { candidate[nextGap] = .empty }

                if prefixCompatible(candidate, known: known, upTo: nextStart) {
                    place(blockIndex: blockIndex + 1, start: nextStart, current: candidate)
                }
                position += 1
            }
        }

        place(blockIndex: 0, start: 0, current: Array(repeating: .unknown, count: length))
        return intersection
    }

    private static func matches(_ candidate: [CellValue], known: [CellValue]) -> Bool {
        for i in 0..<known.count where known[i] != .unknown && known[i] != candidate[i] {
            return false
        }
        return true
    }

    private static func prefixCompatible(_ candidate: [CellValue], known: [CellValue], upTo: Int) -> Bool {
        for i in 0..<upTo where known[i] != .unknown && candidate[i] != .unknown && known[i] != candidate[i] {
            return false
        }
        return true
    }

    private static func merge(_ lhs: [CellValue]?, _ rhs: [CellValue]) -> [CellValue] {
        guard let lhs else { return rhs }
        var result = lhs
        for i in 0..<result.count where result[i] != rhs[i] {
            result[i] = .unknown
        }
        return result
    }

    // MARK: - Backtracking (only reached when propagation alone can't finish the grid)

    private static func search(
        _ grid: [[CellValue]],
        rowClues: [[Int]],
        colClues: [[Int]],
        solutions: inout [[[Bool]]],
        limit: Int
    ) {
        guard solutions.count < limit else { return }

        guard let (row, col) = firstUnknown(grid) else {
            solutions.append(grid.map { $0.map { $0 == .filled } })
            return
        }

        for guess in [CellValue.filled, CellValue.empty] {
            var attempt = grid
            attempt[row][col] = guess
            if propagate(&attempt, rowClues: rowClues, colClues: colClues) {
                search(attempt, rowClues: rowClues, colClues: colClues, solutions: &solutions, limit: limit)
            }
            if solutions.count >= limit { return }
        }
    }

    private static func firstUnknown(_ grid: [[CellValue]]) -> (Int, Int)? {
        for row in grid.indices {
            for col in grid[row].indices where grid[row][col] == .unknown {
                return (row, col)
            }
        }
        return nil
    }
}
