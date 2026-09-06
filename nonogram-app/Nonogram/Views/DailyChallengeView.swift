import SwiftUI

/// Today's shared puzzle plus the player's streak, reusing the same `GameView`/`BoardView`
/// stack as regular levels.
struct DailyChallengeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = DailyChallengeViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(appViewModel.localization.string("tab.daily"))
                .onAppear(perform: reload)
        }
    }

    private func reload() {
        viewModel.load(completedDailyDates: appViewModel.progress.dailyChallengeCompletedDates)
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
                        onFinished: { _ in
                            appViewModel.recordDailyChallengeCompletion(
                                dateKey: DailyChallengeViewModel.dateKey(for: Date())
                            )
                            viewModel.markCompletedToday()
                        }
                    )
                }
            }
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(appViewModel.localization.string("daily.unavailable"))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var streakHeader: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text(appViewModel.localization.formatted("daily.streakFormat", viewModel.streak))
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
            Text(appViewModel.localization.string("daily.alreadyCompleted"))
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color("BackgroundPrimary"))
    }
}
