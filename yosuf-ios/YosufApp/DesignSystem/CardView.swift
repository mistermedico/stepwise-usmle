import SwiftUI
import YosufEngine

/// Renders a single playing card face (or back). Two skins per spec —
/// classic and neon — selected via `CardSkin`, both available from launch.
enum CardSkin: String, CaseIterable, Identifiable, Hashable {
    case classic
    case neon
    var id: String { rawValue }
    var displayNameKey: String { "settings.skin.\(rawValue)" }
}

struct CardFaceView: View {
    let card: Card
    var skin: CardSkin = .classic
    var isFaceUp: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
            .fill(isFaceUp ? Theme.cardFace : backColor)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: skin == .neon ? 1.5 : 1)
            )
            .overlay {
                if isFaceUp {
                    faceContent
                } else {
                    backGlyph
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .aspectRatio(0.68, contentMode: .fit)
            .accessibilityLabel(isFaceUp ? accessibilityDescription : Text("card.facedown", tableName: nil, bundle: .main, comment: ""))
    }

    private var backColor: Color { skin == .neon ? .black : Theme.cardBack }
    private var borderColor: Color { skin == .neon ? Theme.accentGold : Color.black.opacity(0.15) }

    @ViewBuilder private var faceContent: some View {
        VStack(spacing: 2) {
            switch card.kind {
            case .standard(let rank, let suit):
                Text(rankSymbol(rank))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(suitColor(suit, skin: skin))
                Text(suit.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(suitColor(suit, skin: skin))
            case .joker:
                Text("★")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.accentGold)
            }
        }
    }

    private var backGlyph: some View {
        Image(systemName: skin == .neon ? "bolt.fill" : "suit.spade.fill")
            .font(.system(size: 20))
            .foregroundStyle(Theme.accentGold.opacity(0.8))
    }

    private func rankSymbol(_ rank: Rank) -> String {
        switch rank {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rank.rawValue)"
        }
    }

    private func suitColor(_ suit: Suit, skin: CardSkin) -> Color {
        if skin == .neon {
            return suit.isRed ? Color(red: 1, green: 0.25, blue: 0.55) : Color(red: 0.35, green: 0.95, blue: 1)
        }
        return suit.isRed ? Theme.dangerRed : Theme.textPrimary
    }

    private var accessibilityDescription: Text {
        switch card.kind {
        case .standard(let rank, let suit):
            return Text("\(rankSymbol(rank)) \(suit.rawValue)")
        case .joker:
            return Text("card.joker")
        }
    }
}
