import SwiftUI

/// Renders a puzzle's solution as a tiny grid of tinted squares — the "collection album"
/// visual for a solved level. No bitmap art is shipped; this draws directly from the
/// puzzle's `solution` grid and `colorHex`, so it's essentially free to produce for any size.
struct PuzzleThumbnailView: View {
    let puzzle: Puzzle
    /// Overrides the puzzle's own color, used to render a neutral gray "not solved yet" version.
    var tintOverride: Color?

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(puzzle.width)
            let cellHeight = size.height / CGFloat(puzzle.height)
            let fillColor = tintOverride ?? Color(hex: puzzle.colorHex)

            for (row, rowString) in puzzle.solution.enumerated() {
                for (col, char) in rowString.enumerated() where char == "1" {
                    let rect = CGRect(
                        x: CGFloat(col) * cellWidth,
                        y: CGFloat(row) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    )
                    context.fill(Path(rect), with: .color(fillColor))
                }
            }
        }
        .aspectRatio(CGFloat(puzzle.width) / CGFloat(puzzle.height), contentMode: .fit)
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
