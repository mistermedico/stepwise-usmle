import SwiftUI

/// Applies the one shared screen-transition treatment and the language-driven layout
/// direction for full RTL support (spec sections 4 and 6/8).
struct RootView: View {
    @StateObject private var router = AppRouter()
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        ZStack {
            switch router.screen {
            case .home:
                HomeView(onStart: { viewModel in
                    withAnimation(.appScreenChange) { router.startGame(viewModel) }
                })
                .id("home")
                .appScreenTransition()
            case .playing(let gameViewModel):
                GameScreenView(
                    viewModel: gameViewModel,
                    onFinished: { finalState, newlyUnlocked in
                        withAnimation(.appScreenChange) {
                            router.showReport(finalState: finalState, newlyUnlockedAchievementIDs: newlyUnlocked)
                        }
                    }
                )
                .id("playing")
                .appScreenTransition()
            case .report(let reportViewModel):
                OutbreakReportView(viewModel: reportViewModel, onDone: {
                    withAnimation(.appScreenChange) { router.returnHome() }
                })
                .id("report")
                .appScreenTransition()
            }
        }
        .environment(\.layoutDirection, localization.currentLanguage.layoutDirection)
        .preferredColorScheme(nil) // follow system, per spec section 9 (full Light/Dark support)
    }
}
