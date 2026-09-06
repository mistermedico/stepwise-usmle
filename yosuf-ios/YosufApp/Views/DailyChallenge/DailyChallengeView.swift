import SwiftUI
import YosufEngine

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()
    @State private var startChallenge = false
    @State private var players: [Player] = []
    @State private var humanID: PlayerID?

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentGold)

            Text("dailyChallenge.title")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("dailyChallenge.explanation")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacingL)

            if viewModel.alreadyCompletedToday {
                EmptyStateView(
                    systemImage: "checkmark.seal.fill",
                    titleKey: "dailyChallenge.done.title",
                    messageKey: "dailyChallenge.done.message"
                )
            } else {
                Button {
                    let result = viewModel.makePlayers(humanName: String(localized: "game.you"))
                    players = result.players
                    humanID = result.humanID
                    startChallenge = true
                } label: {
                    Text("dailyChallenge.play")
                }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.spacingXL)
            }

            Spacer()
        }
        .padding(.top, Theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.tableFelt.ignoresSafeArea())
        .navigationTitle(String(localized: "home.dailyChallenge"))
        .navigationDestination(isPresented: $startChallenge) {
            if let humanID {
                GameTableView(
                    players: players, humanPlayerID: humanID,
                    profile: viewModel.scenario.ruleProfile, seed: viewModel.scenario.seed
                )
                .onDisappear {
                    viewModel.recordCompletion(finalScore: 0)
                }
            }
        }
    }
}
