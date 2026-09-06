import SwiftUI

/// A single board cell. Purely presentational — all gesture handling happens once, at the
/// `BoardView` level, so continuous drag-to-paint works across cell boundaries.
struct CellView: View {
    let state: CellState
    let colorHex: String
    let isFlaggedIncorrect: Bool
    let isHintHighlight: Bool
    let showThickTrailingBorder: Bool
    let showThickBottomBorder: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
                .overlay(
                    Rectangle()
                        .stroke(Color("GridLine"), lineWidth: 0.5)
                )
                .overlay(alignment: .trailing) {
                    if showThickTrailingBorder {
                        Rectangle().fill(Color("GridLine")).frame(width: 1.5)
                    }
                }
                .overlay(alignment: .bottom) {
                    if showThickBottomBorder {
                        Rectangle().fill(Color("GridLine")).frame(height: 1.5)
                    }
                }

            if state == .marked {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color("TextPrimary").opacity(0.55))
            }

            if isFlaggedIncorrect {
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
            }

            if isHintHighlight {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .scaleEffect(state == .filled ? 1.06 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.5), value: state)
        .animation(.easeOut(duration: 0.2), value: isFlaggedIncorrect)
    }

    private var fillColor: Color {
        switch state {
        case .empty, .marked:
            return Color("BackgroundSecondary")
        case .filled:
            return Color(hex: colorHex)
        }
    }
}
