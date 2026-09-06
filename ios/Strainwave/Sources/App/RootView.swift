import SwiftUI
import OutbreakEngine

/// Owns navigation. Every destination is rendered into the same stack with the
/// same transition, which is what keeps the app feeling like one product.
struct RootView: View {

    @EnvironmentObject private var environment: AppEnvironment
    @State private var route: Route = .home

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            switch route {
            case .home:
                HomeView(onStart: start)
                    .transition(.screen)

            case .game(let box):
                GameScreen(
                    setup: box,
                    onFinished: { report, achievements in
                        route = .report(report, achievements)
                    },
                    onQuit: { route = .home }
                )
                .transition(.screen)

            case .report(let report, let achievements):
                ReportView(
                    report: report,
                    freshAchievements: achievements,
                    onPlayAgain: { replay(report) },
                    onHome: { route = .home }
                )
                .transition(.screen)
            }
        }
        .animation(Theme.Motion.screen, value: route)
    }

    private func start(_ setup: GameSetup) {
        route = .game(GameSetupBox(value: setup))
    }

    /// "Run again" keeps the tier, sample and starting world, but rolls a fresh
    /// board — repeating the identical seed would just replay a solved puzzle.
    private func replay(_ report: EpidemicReport) {
        let setup = GameSetup(
            strain: report.strain,
            difficulty: report.difficulty,
            scenario: report.scenario,
            seed: UInt64.random(in: 1...UInt64.max)
        )
        environment.ads.presentInterstitial {
            Task { @MainActor in
                self.route = .game(GameSetupBox(value: setup))
            }
        }
    }
}

/// Builds the run's view model exactly once, from the shared services.
///
/// `@EnvironmentObject` is not readable from a `View.init`, so the model is
/// created on first appearance and held by a small host object. That keeps a
/// single `ReportStore` and `AdManager` for the whole app rather than spawning
/// duplicates per run.
private struct GameScreen: View {

    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var host = GameHost()

    let setup: GameSetupBox
    let onFinished: (EpidemicReport, [Achievement]) -> Void
    let onQuit: () -> Void

    var body: some View {
        Group {
            if let model = host.model {
                // `onFinished` is handed to GameView rather than watched here:
                // this view holds the model but does not observe it, so a
                // change to the run's outcome would never reach an onChange
                // written at this level — and the player would sit on a
                // finished board for ever.
                GameView(model: model, onQuit: onQuit, onFinished: onFinished)
            } else {
                // One frame at most, before the model exists.
                LoadingView()
            }
        }
        .onAppear {
            host.makeIfNeeded(setup: setup.value, environment: environment)
        }
    }
}

/// Holds the run's view model across re-renders.
@MainActor
private final class GameHost: ObservableObject {
    @Published private(set) var model: GameViewModel?

    func makeIfNeeded(setup: GameSetup, environment: AppEnvironment) {
        guard model == nil else { return }
        let created = GameViewModel(
            setup: setup,
            feedback: environment.feedback,
            store: environment.store,
            ads: environment.ads
        )
        model = created
        created.start()
    }
}

/// The brief moment before a run's model exists.
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            ProgressView()
                .tint(Theme.Palette.spread)
        }
        .accessibilityLabel(Text(L.string("common.continue")))
    }
}
