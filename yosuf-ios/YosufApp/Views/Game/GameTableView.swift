import SwiftUI
import YosufEngine

struct GameTableView: View {
    @StateObject private var viewModel: GameTableViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.tableHintsEnabled") private var tableHintsEnabled = true
    @AppStorage("settings.cardSkin") private var cardSkinRaw = CardSkin.classic.rawValue

    private var cardSkin: CardSkin { CardSkin(rawValue: cardSkinRaw) ?? .classic }

    init(profile: RuleProfile, opponentCount: Int) {
        let humanID = PlayerID()
        var players = [Player(id: humanID, displayName: String(localized: "game.you"), kind: .human, avatarColorIndex: 0)]
        let bots: [(OpponentDifficulty, OpponentPersonality)] = [
            (.intermediate, .balanced), (.advanced, .aggressive), (.beginner, .cautious)
        ]
        for index in 0..<opponentCount {
            let (difficulty, personality) = bots[index % bots.count]
            players.append(Player(
                displayName: "\(String(localized: "game.bot")) \(index + 1)",
                kind: .bot(difficulty: difficulty, personality: personality),
                avatarColorIndex: index + 1
            ))
        }
        _viewModel = StateObject(wrappedValue: GameTableViewModel(players: players, profile: profile, humanPlayerID: humanID))
    }

    /// Used for the Daily Challenge, where the players and RNG seed must be
    /// the exact fixed scenario every player sees on a given date — never
    /// the randomly-generated lineup the default initializer builds.
    init(players: [Player], humanPlayerID: PlayerID, profile: RuleProfile, seed: UInt64) {
        _viewModel = StateObject(wrappedValue: GameTableViewModel(
            players: players, profile: profile, humanPlayerID: humanPlayerID, seed: seed
        ))
    }

    var body: some View {
        ZStack {
            Theme.tableFelt.ignoresSafeArea()
            VStack(spacing: Theme.spacingM) {
                opponentsRow
                Spacer()
                centerPiles
                Spacer()
                if tableHintsEnabled, let hint = viewModel.tableHints.first {
                    TableHintBubbleView(hint: hint, players: viewModel.state.players)
                }
                handAndControls
            }
            .padding(Theme.spacingM)
            .opacity(viewModel.revealStage == .none ? 1 : 0.15)
            .animation(.easeInOut(duration: 0.3), value: viewModel.revealStage)

            if viewModel.revealStage != .none {
                YosufRevealOverlay(viewModel: viewModel, cardSkin: cardSkin, onDismiss: {
                    let matchWasOver = viewModel.state.isMatchOver
                    viewModel.dismissRevealAndContinue()
                    if matchWasOver { dismiss() }
                })
            }
        }
        .navigationBarBackButtonHidden(viewModel.revealStage != .none)
        .alert(item: Binding(get: { viewModel.lastError.map(IdentifiableError.init) }, set: { _ in viewModel.lastError = nil })) { wrapped in
            Alert(title: Text("game.error.title"), message: Text(wrapped.error.localizedDescription))
        }
    }

    private var opponentsRow: some View {
        HStack(spacing: Theme.spacingM) {
            ForEach(viewModel.state.players.filter { $0.id != viewModel.humanPlayerID }) { player in
                OpponentSeatView(player: player, isCurrentTurn: isCurrentTurn(player.id), isThinking: viewModel.isBotThinking && isCurrentTurn(player.id))
            }
        }
    }

    private func isCurrentTurn(_ id: PlayerID) -> Bool {
        switch viewModel.state.phase {
        case .awaitingDraw(let pid), .awaitingDiscard(let pid): return pid == id
        default: return false
        }
    }

    private var centerPiles: some View {
        HStack(spacing: Theme.spacingXL) {
            PileView(title: String(localized: "game.drawPile"), card: nil, count: viewModel.state.drawPile.count, skin: cardSkin)
                .onTapGesture { if viewModel.isHumansTurn { viewModel.humanDraw(fromDiscard: false) } }

            PileView(title: String(localized: "game.discardPile"), card: viewModel.state.discardPile.top, count: viewModel.state.discardPile.count, skin: cardSkin)
                .onTapGesture { if viewModel.isHumansTurn { viewModel.humanDraw(fromDiscard: true) } }
        }
    }

    private var handAndControls: some View {
        VStack(spacing: Theme.spacingS) {
            HandView(
                cards: viewModel.humanPlayer.hand,
                selectedIDs: viewModel.selectedCardIDs,
                skin: cardSkin,
                onTap: viewModel.toggleCardSelection
            )

            HStack(spacing: Theme.spacingM) {
                Button {
                    viewModel.humanDeclareYosuf()
                } label: {
                    Text("game.declareYosuf")
                }
                .buttonStyle(.primary)
                .disabled(!canDeclareYosuf)

                Button {
                    viewModel.humanDiscardSelected()
                } label: {
                    Text("game.discard")
                }
                .buttonStyle(.destructive)
                .disabled(!canDiscard)
            }
        }
    }

    private var canDeclareYosuf: Bool {
        viewModel.isHumansTurn
            && HandEvaluator.isEligibleToDeclareYosuf(hand: viewModel.humanPlayer.hand, profile: viewModel.state.ruleProfile)
            && isAwaitingDraw
    }

    private var isAwaitingDraw: Bool {
        if case .awaitingDraw = viewModel.state.phase { return true }
        return false
    }

    private var canDiscard: Bool {
        guard viewModel.isHumansTurn, !viewModel.selectedCardIDs.isEmpty else { return false }
        if case .awaitingDiscard = viewModel.state.phase { return true }
        return false
    }
}

private struct IdentifiableError: Identifiable {
    let error: GameError
    var id: String { error.localizedDescription }
}
