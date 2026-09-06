import SwiftUI

/// Today's shared puzzle plus the player's streak, reusing the same `GameView`/`BoardView`
/// stack as regular levels.
struct DailyChallengeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: DailyChallengeViewModel

    init() {
        // Placeholder AppViewModel here is immediately replaced by `configure(with:)` in
        // `onAppear`, mirroring the same construction-order constraint noted in GalleryView.
        _viewModel = StateObject(wrappedValue: DailyChallengeViewModel(appViewModel: AppViewModel()))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "tab.daily"))
                .onAppear {
                    viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let puzzle = viewModel.puzzle {
            VStack(spacing: 0) {
                streakHeader
                if viewModel.isCompletedToday {
                    completedState(puzzle: puzzle)
                } else {
                    GameView(
                        viewModel: GameViewModel(puzzle: puzzle, appViewModel: appViewModel),
                        onFinished: {
                            viewModel.recordCompletion(flawless: true) // GameView already recorded the level itself; flawless flag re-derived below.
                        }
                    )
                }
            }
        } else if viewModel.isLoading {
            ProgressView()
        } else {
            Text(String(localized: "daily.unavailable"))
                .foregroundColor(.secondary)
        }
    }

    private var streakHeader: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text(String(format: String(localized: "daily.streakFormat"), viewModel.streak))
                .font(.subheadline.bold())
            Spacer()
        }
        .padding()
        .background(Color("BackgroundSecondary"))
    }

    private func completedState(puzzle: Puzzle) -> some View {
        VStack(spacing: 16) {
            Spacer()
            PuzzleThumbnailView(puzzle: puzzle)
                .frame(width: 160, height: 160)
            Text(String(localized: "daily.alreadyCompleted"))
                .font(.headline)
            Spacer()
        }
    }
}
