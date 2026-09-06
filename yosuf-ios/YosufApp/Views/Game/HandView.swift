import SwiftUI
import YosufEngine

struct HandView: View {
    let cards: [Card]
    let selectedIDs: Set<UUID>
    let skin: CardSkin
    let onTap: (Card) -> Void

    var body: some View {
        HStack(spacing: -12) {
            ForEach(cards) { card in
                CardFaceView(card: card, skin: skin, isFaceUp: true)
                    .frame(width: 58)
                    .offset(y: selectedIDs.contains(card.id) ? -16 : 0)
                    .zIndex(selectedIDs.contains(card.id) ? 1 : 0)
                    .shadow(color: selectedIDs.contains(card.id) ? Theme.accentGold.opacity(0.6) : .clear, radius: 6)
                    .onTapGesture { onTap(card) }
                    .animation(Theme.cardDealAnimation, value: selectedIDs)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.cardDealAnimation, value: cards.map(\.id))
        .frame(minHeight: 100)
        .padding(.horizontal, Theme.spacingL)
    }
}
