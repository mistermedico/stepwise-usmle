import SwiftUI

/// Shown once `GameViewModel.isSolved` flips to true: a short celebratory overlay (glow +
/// zoomed-out board peeking through) that settles into a summary card with mistake count,
/// a "flawless" badge when earned, and a Continue button back to level select.
struct WinView: View {
    let puzzle: Puzzle
    let mistakeCount: Int
    let onContinue: () -> Void

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var appeared = false

    private var isFlawless: Bool { mistakeCount == 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: puzzle.colorHex).opacity(0.55), .clear],
                center: .center,
                startRadius: 0,
                endRadius: appeared ? 260 : 40
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 18) {
                PuzzleThumbnailView(puzzle: puzzle)
                    .frame(width: 140, height: 140)
                    .shadow(radius: 12)

                Text(appViewModel.localization.string("win.title"))
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text(puzzle.title.localized(for: appViewModel.localization.languageCode))
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                if isFlawless {
                    Label(appViewModel.localization.string("win.flawless"), systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.9))
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                } else {
                    Text(appViewModel.localization.formatted("win.mistakes", mistakeCount))
                        .foregroundColor(.white.opacity(0.85))
                }

                Button(action: onContinue) {
                    Text(appViewModel.localization.string("win.continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: puzzle.colorHex))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
