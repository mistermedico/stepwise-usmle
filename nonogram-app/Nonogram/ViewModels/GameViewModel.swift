import Combine
import Foundation

/// Simple (row, col) coordinate used throughout the view layer for drag tracking and
/// highlight sets. `GameEngine` itself works in plain (Int, Int) tuples, which aren't
/// `Hashable`, so this is the UI-side wrapper around them.
struct GridCoordinate: Hashable {
    let row: Int
    let col: Int
}

/// Drives a single puzzle-solving session: wraps a `GameEngine`, republishes board state for
/// SwiftUI, and fans out feedback (sound/haptics), life loss, booster consumption, and
/// level-completion bookkeeping through to `AppViewModel`.
final class GameViewModel: ObservableObject {
    enum InputMode {
        case fill
        case mark
    }

    let puzzle: Puzzle
    let appViewModel: AppViewModel

    @Published private(set) var board: [[CellState]]
    @Published var inputMode: InputMode = .fill
    @Published private(set) var isSolved = false
    @Published private(set) var mistakeCount = 0
    @Published private(set) var progressFraction: Double = 0
    @Published var showWinOverlay = false
    @Published var showLivesDepletedSheet = false
    /// Cells flagged by the "check errors" booster; the view fades this out after a short delay.
    @Published private(set) var flaggedIncorrectCells: Set<GridCoordinate> = []
    /// Most recently revealed/hinted cell, so the view can draw a brief highlight pulse.
    @Published private(set) var lastRevealedCell: GridCoordinate?

    private let engine: GameEngine
    private let soundManager: SoundManager
    private let hapticManager: HapticManager
    /// While dragging across cells we paint every still-untouched cell to the state the drag
    /// started with (rather than re-toggling each one individually), which is the standard,
    /// expected nonogram drag-to-paint behavior.
    private var dragPaintState: CellState?

    init(
        puzzle: Puzzle,
        appViewModel: AppViewModel,
        soundManager: SoundManager? = nil,
        hapticManager: HapticManager? = nil
    ) {
        self.puzzle = puzzle
        self.appViewModel = appViewModel
        self.soundManager = soundManager ?? appViewModel.soundManager
        self.hapticManager = hapticManager ?? appViewModel.hapticManager
        self.engine = GameEngine(puzzle: puzzle)
        self.board = engine.board
        self.mistakeCount = engine.mistakeCount
        self.progressFraction = engine.progressFraction
    }

    // MARK: - Read-only board queries for the view

    func cellState(row: Int, col: Int) -> CellState {
        board[row][col]
    }

    func isRowComplete(_ row: Int) -> Bool {
        engine.isRowComplete(row)
    }

    func isColumnComplete(_ col: Int) -> Bool {
        engine.isColumnComplete(col)
    }

    var remainingLives: Int {
        appViewModel.progress.lives
    }

    func remainingBoosterCount(_ type: BoosterType) -> Int {
        appViewModel.progress.boosterCounts[type] ?? 0
    }

    // MARK: - Input

    /// A plain tap: toggles the cell between empty and the current mode's target state.
    func tap(row: Int, col: Int) {
        guard canInteract else { return }
        applyCurrentMode(row: row, col: col)
    }

    func beginDrag(row: Int, col: Int) {
        guard canInteract else { return }
        let resultState = applyCurrentMode(row: row, col: col)
        dragPaintState = resultState
    }

    /// Called as the drag gesture crosses into a new cell.
    func continueDrag(row: Int, col: Int) {
        guard canInteract, let paintState = dragPaintState else { return }
        let current = engine.state(row: row, col: col)
        guard current != paintState else { return }

        switch paintState {
        case .empty:
            _ = engine.apply(.clear, row: row, col: col)
            syncPublishedState()
        case .filled, .marked:
            // Only paint cells that are still untouched, so dragging back over already-painted
            // cells doesn't clear them or double-count mistakes.
            guard current == .empty else { return }
            _ = applyCurrentMode(row: row, col: col)
        }
    }

    func endDrag() {
        dragPaintState = nil
    }

    private var canInteract: Bool {
        !isSolved && appViewModel.progress.lives > 0
    }

    @discardableResult
    private func applyCurrentMode(row: Int, col: Int) -> CellState {
        apply(inputMode == .fill ? .fill : .mark, row: row, col: col)
    }

    @discardableResult
    private func apply(_ action: MarkAction, row: Int, col: Int) -> CellState {
        let mistakesBefore = engine.mistakeCount
        let newState = engine.apply(action, row: row, col: col)
        syncPublishedState()

        if engine.mistakeCount > mistakesBefore {
            soundManager.play(.wrongFill)
            hapticManager.error()
            appViewModel.consumeLife()
            if appViewModel.progress.lives <= 0 {
                showLivesDepletedSheet = true
            }
        } else if newState == .filled {
            soundManager.play(.cellFill)
            hapticManager.cellTap()
        } else {
            hapticManager.cellTap()
        }

        announceLineCompletionIfNeeded(row: row, col: col)
        evaluateSolved()
        return newState
    }

    private func announceLineCompletionIfNeeded(row: Int, col: Int) {
        if engine.isRowComplete(row) || engine.isColumnComplete(col) {
            soundManager.play(.lineComplete)
            hapticManager.success()
        }
    }

    private func evaluateSolved() {
        mistakeCount = engine.mistakeCount
        progressFraction = engine.progressFraction
        guard engine.isSolved, !isSolved else { return }

        isSolved = true
        soundManager.play(.levelComplete)
        hapticManager.success()
        appViewModel.recordLevelCompletion(levelID: puzzle.id, flawless: engine.mistakeCount == 0)
        appViewModel.adManager.registerLevelCompletion { _ in }
        showWinOverlay = true
    }

    private func syncPublishedState() {
        board = (0..<puzzle.height).map { row in
            (0..<puzzle.width).map { col in engine.state(row: row, col: col) }
        }
    }

    // MARK: - Boosters

    /// Reveals the first not-yet-complete row (falling back to a column), consuming one
    /// `revealLine` charge. The UI doesn't ask the player to pick a line up front — it just
    /// reveals the next useful one, which keeps the control surface simple.
    func useRevealLineBooster() {
        guard appViewModel.consumeBooster(.revealLine) else { return }
        if let row = (0..<puzzle.height).first(where: { !engine.isRowComplete($0) }) {
            engine.revealRow(row)
        } else if let col = (0..<puzzle.width).first(where: { !engine.isColumnComplete($0) }) {
            engine.revealColumn(col)
        }
        syncPublishedState()
        soundManager.play(.lineComplete)
        hapticManager.success()
        evaluateSolved()
    }

    /// Flags currently-incorrect fills without revealing the right answer. The view is
    /// expected to clear the highlight (`clearErrorFlags()`) after a short delay.
    func useCheckErrorsBooster() {
        guard appViewModel.consumeBooster(.checkErrors) else { return }
        flaggedIncorrectCells = Set(engine.incorrectCells().map { GridCoordinate(row: $0.row, col: $0.col) })
        hapticManager.cellTap()
    }

    func clearErrorFlags() {
        flaggedIncorrectCells = []
    }

    func useHintBooster() {
        guard appViewModel.consumeBooster(.hintCell) else { return }
        if let revealed = engine.revealHintCell() {
            lastRevealedCell = GridCoordinate(row: revealed.row, col: revealed.col)
        }
        syncPublishedState()
        hapticManager.success()
        evaluateSolved()
    }

    // MARK: - Lives sheet

    func dismissLivesDepletedSheet() {
        showLivesDepletedSheet = false
    }
}
