import SwiftUI

/// The puzzle grid itself: column clues on top, row clues on the leading edge, cells in the
/// middle. Supports a single continuous drag across cells (standard nonogram UX — you paint
/// a whole run without lifting your finger) and pinch-to-zoom for boards that don't
/// comfortably fit at a fixed cell size.
struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel

    private let cellSize: CGFloat = 28

    @State private var draggingCoordinate: GridCoordinate?
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    private var puzzle: Puzzle { viewModel.puzzle }

    private var rowClueWidth: CGFloat {
        let maxCount = puzzle.rowClues.map { max($0.count, 1) }.max() ?? 1
        return min(max(CGFloat(maxCount) * 16 + 12, 36), 96)
    }

    private var columnClueHeight: CGFloat {
        let maxCount = puzzle.colClues.map { max($0.count, 1) }.max() ?? 1
        return min(max(CGFloat(maxCount) * 14 + 8, 28), 84)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            gridContent
                .scaleEffect(zoomScale, anchor: .topLeading)
                .padding(12)
        }
        // IMPORTANT: the puzzle grid's own spatial layout (which clue lines up with which
        // row/column) must never mirror for Hebrew RTL, even though the rest of the app's
        // chrome (tab bar, buttons, text alignment) correctly mirrors — so this view alone
        // opts back out to a fixed left-to-right layout direction.
        .environment(\.layoutDirection, .leftToRight)
        .simultaneousGesture(magnificationGesture)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastZoomScale * value
                zoomScale = min(max(proposed, 0.6), 2.5)
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
            }
    }

    private var gridContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: rowClueWidth, height: columnClueHeight)
                ForEach(0..<puzzle.width, id: \.self) { col in
                    ClueView(
                        numbers: puzzle.colClues[col],
                        axis: .column,
                        isComplete: viewModel.isColumnComplete(col)
                    )
                    .frame(width: cellSize, height: columnClueHeight)
                }
            }
            ForEach(0..<puzzle.height, id: \.self) { row in
                HStack(spacing: 0) {
                    ClueView(
                        numbers: puzzle.rowClues[row],
                        axis: .row,
                        isComplete: viewModel.isRowComplete(row)
                    )
                    .frame(width: rowClueWidth, height: cellSize)

                    ForEach(0..<puzzle.width, id: \.self) { col in
                        let coordinate = GridCoordinate(row: row, col: col)
                        CellView(
                            state: viewModel.cellState(row: row, col: col),
                            colorHex: puzzle.colorHex,
                            isFlaggedIncorrect: viewModel.flaggedIncorrectCells.contains(coordinate),
                            isHintHighlight: viewModel.lastRevealedCell == coordinate,
                            showThickTrailingBorder: (col + 1) % 5 == 0 && col != puzzle.width - 1,
                            showThickBottomBorder: (row + 1) % 5 == 0 && row != puzzle.height - 1
                        )
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .background(Color("BackgroundPrimary"))
        .coordinateSpace(name: "grid")
        .gesture(paintGesture)
    }

    /// A single `DragGesture` with zero minimum distance doubles as both "tap a cell" (a drag
    /// that never leaves its starting cell) and "paint across cells" (a longer drag), which
    /// keeps the gesture surface simple: `GameViewModel` just needs begin/continue/end.
    private var paintGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("grid"))
            .onChanged { value in
                guard let coordinate = cellCoordinate(at: value.location) else { return }
                if draggingCoordinate == nil {
                    draggingCoordinate = coordinate
                    viewModel.beginDrag(row: coordinate.row, col: coordinate.col)
                } else if draggingCoordinate != coordinate {
                    draggingCoordinate = coordinate
                    viewModel.continueDrag(row: coordinate.row, col: coordinate.col)
                }
            }
            .onEnded { _ in
                draggingCoordinate = nil
                viewModel.endDrag()
            }
    }

    private func cellCoordinate(at point: CGPoint) -> GridCoordinate? {
        let x = point.x - rowClueWidth
        let y = point.y - columnClueHeight
        guard x >= 0, y >= 0 else { return nil }

        let col = Int(x / cellSize)
        let row = Int(y / cellSize)
        guard row >= 0, row < puzzle.height, col >= 0, col < puzzle.width else { return nil }
        return GridCoordinate(row: row, col: col)
    }
}
