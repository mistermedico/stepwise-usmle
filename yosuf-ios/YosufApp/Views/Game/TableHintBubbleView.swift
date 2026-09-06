import SwiftUI
import YosufEngine

/// A single "table reading" hint bubble. Fades in, holds briefly, then
/// fades out on its own — never a permanent fixture on screen.
struct TableHintBubbleView: View {
    let hint: TableHint
    let players: [Player]
    @State private var isVisible = true

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.spacingM)
            .padding(.vertical, Theme.spacingS)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
            .opacity(isVisible ? 1 : 0)
            .id(hintIdentity)
            .task(id: hintIdentity) {
                isVisible = true
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeOut(duration: 0.4)) { isVisible = false }
            }
    }

    private var hintIdentity: String { "\(hint)" }

    private var message: String {
        switch hint {
        case .yourHandIsClose:
            return String(localized: "hint.yourHandIsClose")
        case .opponentLikelyClose(let playerID, _):
            let name = players.first { $0.id == playerID }?.displayName ?? String(localized: "game.opponent")
            return String(format: String(localized: "hint.opponentLikelyCloseFormat"), name)
        case .rankRunningCold:
            return String(localized: "hint.rankRunningCold")
        case .unclaimedJokerOnTop:
            return String(localized: "hint.unclaimedJoker")
        }
    }
}
