import SwiftUI
import YosufEngine

/// The full Yosuf/Asaf reveal sequence: dim → reveal caller's hand → reveal
/// challenger's hand (only if an Asaf catch happened) → gold glow (win) or
/// a red "shatter" flash (caught), per spec.
struct YosufRevealOverlay: View {
    @ObservedObject var viewModel: GameTableViewModel
    let cardSkin: CardSkin
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: Theme.spacingL) {
                switch viewModel.revealStage {
                case .none:
                    EmptyView()
                case .dimming:
                    ProgressView().tint(.white)
                case .showingCaller:
                    revealedHand(for: callerID, labelKey: "reveal.callerHand")
                case .showingChallenger(let challengerID):
                    revealedHand(for: challengerID, labelKey: "reveal.challengerHand")
                case .result(let outcome):
                    resultContent(outcome)
                }
            }
            .padding(Theme.spacingL)
        }
        .transition(.opacity)
    }

    private var callerID: PlayerID? {
        viewModel.state.pendingYosufCallerID
    }

    private func revealedHand(for playerID: PlayerID?, labelKey: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.spacingM) {
            Text(labelKey)
                .font(.headline)
                .foregroundStyle(.white)
            if let playerID, let player = viewModel.state.player(with: playerID) {
                Text(player.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentGold)
                HStack(spacing: -10) {
                    ForEach(player.hand) { card in
                        CardFaceView(card: card, skin: cardSkin, isFaceUp: true)
                            .frame(width: 52)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(String(format: String(localized: "reveal.handValueFormat"), HandEvaluator.handValue(player.hand, aceHigh: viewModel.state.ruleProfile.aceHigh)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private func resultContent(_ outcome: RoundOutcome) -> some View {
        let humanWon = outcome.winnerID(is: viewModel.humanPlayerID)
        VStack(spacing: Theme.spacingM) {
            Image(systemName: humanWon ? "crown.fill" : "xmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(humanWon ? Theme.accentGold : Theme.dangerRed)
                .shadow(color: (humanWon ? Theme.accentGold : Theme.dangerRed).opacity(0.7), radius: 20)

            Text(resultTitleKey(outcome))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            scoreboard

            Button {
                onDismiss()
            } label: {
                Text(viewModel.state.isMatchOver ? "reveal.finish" : "reveal.nextRound")
            }
            .buttonStyle(.primary)
            .padding(.top, Theme.spacingM)
        }
    }

    private func resultTitleKey(_ outcome: RoundOutcome) -> LocalizedStringKey {
        switch outcome {
        case .yosufSuccess: return "reveal.yosufSuccess"
        case .asafSuccess: return "reveal.asafCaught"
        }
    }

    private var scoreboard: some View {
        VStack(spacing: Theme.spacingXS) {
            ForEach(viewModel.state.players) { player in
                HStack {
                    Text(player.displayName).foregroundStyle(.white)
                    Spacer()
                    Text("\(player.totalScore)").foregroundStyle(Theme.accentGold)
                }
                .font(.subheadline)
            }
        }
        .padding(Theme.spacingM)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
    }
}

private extension RoundOutcome {
    func winnerID(is candidate: PlayerID) -> Bool {
        switch self {
        case .yosufSuccess(let callerID): return callerID == candidate
        case .asafSuccess(_, let challengerID): return challengerID == candidate
        }
    }
}
