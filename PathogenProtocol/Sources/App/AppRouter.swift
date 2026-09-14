import Foundation

/// Top-level navigation state. Deliberately a tiny hand-rolled router instead of
/// `NavigationStack` paths, since the app only ever has three full-screen states.
@MainActor
final class AppRouter: ObservableObject {
    enum Screen {
        case home
        case playing(GameViewModel)
        case report(ReportViewModel)
    }

    @Published var screen: Screen = .home

    func startGame(_ viewModel: GameViewModel) {
        screen = .playing(viewModel)
    }

    func showReport(finalState: GameState, newlyUnlockedAchievementIDs: Set<String>) {
        screen = .report(ReportViewModel(finalState: finalState, newlyUnlockedAchievementIDs: newlyUnlockedAchievementIDs))
    }

    func returnHome() {
        screen = .home
    }
}
