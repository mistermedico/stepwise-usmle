import SwiftUI
import YosufEngine

struct OpponentSeatView: View {
    let player: Player
    let isCurrentTurn: Bool
    let isThinking: Bool

    var body: some View {
        VStack(spacing: Theme.spacingXS) {
            PlayerAvatarView(initials: initials, colorIndex: player.avatarColorIndex, size: 40, isCurrentTurn: isCurrentTurn)
            Text(player.displayName)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
            HStack(spacing: 2) {
                Image(systemName: "rectangle.stack.fill").font(.caption2)
                Text("\(player.hand.count)")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.8))
            if isThinking {
                ThinkingDotsView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var initials: String {
        String(player.displayName.prefix(2)).uppercased()
    }
}

private struct ThinkingDotsView: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.accentGold)
                    .frame(width: 4, height: 4)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
