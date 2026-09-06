import SwiftUI
import YosufEngine

/// One of the two center piles (closed draw pile or open discard pile).
struct PileView: View {
    let title: String
    let card: Card?
    let count: Int
    let skin: CardSkin

    var body: some View {
        VStack(spacing: Theme.spacingXS) {
            ZStack {
                if let card {
                    CardFaceView(card: card, skin: skin, isFaceUp: true)
                } else if count > 0 {
                    CardFaceView(card: .standard(.ace, .spades), skin: skin, isFaceUp: false)
                } else {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.white.opacity(0.4))
                        .aspectRatio(0.68, contentMode: .fit)
                }
            }
            .frame(width: 64)
            .rotation3DEffect(.degrees(count > 0 ? 0 : 90), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.25), value: card?.id)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(Theme.accentGold)
        }
    }
}
