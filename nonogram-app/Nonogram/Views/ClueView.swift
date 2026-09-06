import SwiftUI

/// Renders one row or column's clue numbers. Fades and strikes through once `GameEngine`
/// reports that line as complete, so the player gets an immediate "you're done with this
/// line" signal without any extra UI chrome.
struct ClueView: View {
    enum Axis {
        case row
        case column
    }

    let numbers: [Int]
    let axis: Axis
    let isComplete: Bool

    var body: some View {
        let displayNumbers = numbers.isEmpty ? [0] : numbers
        Group {
            switch axis {
            case .row:
                HStack(spacing: 3) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayNumbers.enumerated()), id: \.offset) { _, value in
                        clueText(value)
                    }
                }
            case .column:
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayNumbers.enumerated()), id: \.offset) { _, value in
                        clueText(value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clueText(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundColor(isComplete ? Color("TextPrimary").opacity(0.35) : Color("TextPrimary"))
            .strikethrough(isComplete)
    }
}
