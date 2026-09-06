import SwiftUI

/// The full "play a puzzle" screen: toolbar (lives/boosters/mode), the board itself, and the
/// win/lives-depleted overlays. Used both from level select and from the daily challenge, each
/// of which constructs its own `GameViewModel` for the puzzle in question.
struct GameView: View {
    @StateObject var viewModel: GameViewModel
    /// Fired when the player taps Continue on the win screen. Passes whether the level was
    /// solved with zero mistakes, since `AppViewModel.recordLevelCompletion` (already called
    /// internally by `GameViewModel` as soon as it's solved) doesn't hand that back to the view.
    var onFinished: ((Bool) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color("BackgroundPrimary").ignoresSafeArea()

            VStack(spacing: 0) {
                GameToolbarView(viewModel: viewModel, onPause: { showSettings = true })
                BoardView(viewModel: viewModel)
            }

            if viewModel.showWinOverlay {
                WinView(
                    puzzle: viewModel.puzzle,
                    mistakeCount: viewModel.mistakeCount,
                    onContinue: {
                        onFinished?(viewModel.mistakeCount == 0)
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .navigationTitle(viewModel.puzzle.title.localized(for: viewModel.appViewModel.localization.languageCode))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showLivesDepletedSheet) {
            LivesDepletedView(onLifeGranted: {})
                .presentationDetents([.medium])
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showWinOverlay)
    }
}
