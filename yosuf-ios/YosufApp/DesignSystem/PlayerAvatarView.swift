import SwiftUI

/// Geometric, stylized avatar — no photo assets needed. Each player gets a
/// distinct color from `Theme.avatarPalette` plus a simple monogram, per spec.
struct PlayerAvatarView: View {
    let initials: String
    let colorIndex: Int
    var size: CGFloat = 44
    var isCurrentTurn: Bool = false

    private var color: Color {
        Theme.avatarPalette[colorIndex % Theme.avatarPalette.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Circle()
                .strokeBorder(isCurrentTurn ? Theme.accentGold : .clear, lineWidth: 3)
                .padding(-2)
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: isCurrentTurn)
    }
}
