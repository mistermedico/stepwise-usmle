import Foundation
import YosufEngine
import os

/// Drives one match end-to-end: wraps `GameEngine` calls, advances bot
/// turns automatically with paced delays for animation, and sequences the
/// Yosuf/Asaf reveal. This is the only place in the app that mutates a
/// `GameState` — views only ever read `@Published` output from here.
@MainActor
final class GameTableViewModel: ObservableObject {
    enum RevealStage: Equatable {
        case none
        case dimming
        case showingCaller
        case showingChallenger(PlayerID)
        case result(RoundOutcome)
    }

    @Published private(set) var state: GameState
    @Published var selectedCardIDs: Set<UUID> = []
    @Published private(set) var revealStage: RevealStage = .none
    @Published private(set) var tableHints: [TableHint] = []
    @Published var lastError: GameError?
    @Published private(set) var isBotThinking = false
    @Published var tableHintsEnabled = true

    let humanPlayerID: PlayerID
    private var opponentMemory = OpponentMemory()
    private let logger = Logger(subsystem: "com.yosuf.game", category: "game-viewmodel")
    private let rngSeed: UInt64

    init(players: [Player], profile: RuleProfile, humanPlayerID: PlayerID, seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.humanPlayerID = humanPlayerID
        self.rngSeed = seed
        self.tableHintsEnabled = (UserDefaults.standard.object(forKey: "settings.tableHintsEnabled") as? Bool) ?? true
        do {
            self.state = try GameEngine.startMatch(players: players, profile: profile, rng: RNGBox(seed: seed))
        } catch {
            // Construction-time failure (bad player count) is a programmer
            // error at the call site, not a runtime condition to recover
            // from silently — surface it loudly during development.
            fatalError("Invalid match setup: \(error)")
        }
        refreshHints()
        Task { await runBotTurnsIfNeeded() }
    }

    var humanPlayer: Player { state.player(with: humanPlayerID)! }
    var isHumansTurn: Bool {
        switch state.phase {
        case .awaitingDraw(let id), .awaitingDiscard(let id): return id == humanPlayerID
        default: return false
        }
    }

    // MARK: - Human actions

    func humanDraw(fromDiscard: Bool) {
        guard isHumansTurn, case .awaitingDraw = state.phase else { return }
        do {
            if fromDiscard {
                try GameEngine.drawFromDiscard(&state, playerID: humanPlayerID)
            } else {
                try GameEngine.drawFromDeck(&state, playerID: humanPlayerID, rng: RNGBox())
            }
            HapticsManager.shared.dealCard()
            SoundManager.shared.dealCard()
        } catch let error as GameError {
            lastError = error
        } catch {
            logger.fault("Unexpected error on draw: \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleCardSelection(_ card: Card) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
        HapticsManager.shared.selectionChanged()
    }

    func humanDiscardSelected() {
        guard isHumansTurn, case .awaitingDiscard = state.phase else { return }
        let cards = humanPlayer.hand.filter { selectedCardIDs.contains($0.id) }
        do {
            try GameEngine.discard(&state, playerID: humanPlayerID, cards: cards)
            selectedCardIDs.removeAll()
            HapticsManager.shared.discard()
            SoundManager.shared.discard()
            refreshHints()
            Task { await runBotTurnsIfNeeded() }
        } catch let error as GameError {
            lastError = error
        } catch {
            logger.fault("Unexpected error on discard: \(error.localizedDescription, privacy: .public)")
        }
    }

    func humanDeclareYosuf() {
        guard isHumansTurn, case .awaitingDraw = state.phase else { return }
        Task { await performYosufDeclaration(by: humanPlayerID) }
    }

    // MARK: - Bot loop

    private func runBotTurnsIfNeeded() async {
        while !state.isMatchOver {
            guard case .roundEnded = state.phase else {
                guard let currentID = currentTurnPlayerID(), state.player(with: currentID)?.isBot == true else { return }
                await performBotTurn(currentID)
                continue
            }
            return // let the UI show the reveal / "next round" prompt
        }
    }

    private func currentTurnPlayerID() -> PlayerID? {
        switch state.phase {
        case .awaitingDraw(let id), .awaitingDiscard(let id): return id
        default: return nil
        }
    }

    private func performBotTurn(_ botID: PlayerID) async {
        guard let player = state.player(with: botID), case .bot(let difficulty, let personality) = player.kind else { return }
        isBotThinking = true
        defer { isBotThinking = false }

        try? await Task.sleep(nanoseconds: 400_000_000) // brief pause so bot moves feel intentional, not instant

        if case .awaitingDraw = state.phase {
            let action = OpponentEngine.decideDrawAction(
                botID: botID, hand: player.hand, topDiscard: state.discardPile.top,
                difficulty: difficulty, personality: personality, profile: state.ruleProfile,
                memory: &opponentMemory
            )
            do {
                switch action {
                case .declareYosuf:
                    await performYosufDeclaration(by: botID)
                    return
                case .drawFromDeck:
                    try GameEngine.drawFromDeck(&state, playerID: botID, rng: RNGBox())
                case .drawFromDiscard:
                    if state.discardPile.isEmpty {
                        try GameEngine.drawFromDeck(&state, playerID: botID, rng: RNGBox())
                    } else {
                        try GameEngine.drawFromDiscard(&state, playerID: botID)
                    }
                }
            } catch let error as GameError {
                // Should be unreachable in real play (card count is conserved
                // across the whole match), but surface it rather than
                // silently retrying forever if it ever does happen.
                logger.fault("Bot draw failed unexpectedly: \(String(describing: error), privacy: .public)")
                lastError = error
                return
            } catch {
                return
            }
        }

        try? await Task.sleep(nanoseconds: 350_000_000)

        if case .awaitingDiscard = state.phase, let freshPlayer = state.player(with: botID) {
            let cards = OpponentEngine.decideDiscard(hand: freshPlayer.hand, difficulty: difficulty, profile: state.ruleProfile)
            do {
                try GameEngine.discard(&state, playerID: botID, cards: cards)
                refreshHints()
            } catch let error as GameError {
                logger.fault("Bot discard failed unexpectedly: \(String(describing: error), privacy: .public)")
                lastError = error
            } catch {
                // no-op
            }
        }
    }

    // MARK: - Yosuf / reveal sequencing

    private func performYosufDeclaration(by playerID: PlayerID) async {
        revealStage = .dimming
        HapticsManager.shared.preRevealPulse()
        SoundManager.shared.preRevealTension()
        try? await Task.sleep(nanoseconds: 500_000_000)

        revealStage = .showingCaller
        try? await Task.sleep(nanoseconds: UInt64(Theme.revealStageDelay * 1_000_000_000))

        do {
            try GameEngine.declareYosuf(&state, playerID: playerID)
        } catch let error as GameError {
            lastError = error
            revealStage = .none
            return
        } catch {
            revealStage = .none
            return
        }

        guard case .roundEnded(let outcome) = state.phase else { return }

        if case .asafSuccess(_, let challengerID) = outcome {
            revealStage = .showingChallenger(challengerID)
            try? await Task.sleep(nanoseconds: UInt64(Theme.revealStageDelay * 1_000_000_000))
        }

        revealStage = .result(outcome)
        if outcome.winnerID == humanPlayerID {
            HapticsManager.shared.yosufWin()
            SoundManager.shared.yosufWin()
        } else {
            HapticsManager.shared.asafCaught()
            SoundManager.shared.asafCaught()
        }
    }

    func dismissRevealAndContinue() {
        revealStage = .none
        if state.isMatchOver {
            finalizeMatchRecordingIfNeeded()
        } else {
            do {
                try GameEngine.startNextRound(&state, rng: RNGBox())
                refreshHints()
                Task { await runBotTurnsIfNeeded() }
            } catch {
                logger.error("Failed to start next round: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private var didRecordMatch = false
    private func finalizeMatchRecordingIfNeeded() {
        guard !didRecordMatch, case .matchEnded(let winnerID) = state.phase else { return }
        didRecordMatch = true
        let didWin = winnerID == humanPlayerID
        let toughestBot = state.players.compactMap { player -> OpponentDifficulty? in
            if case .bot(let difficulty, _) = player.kind { return difficulty }
            return nil
        }.max { $0.baseYosufThreshold < $1.baseYosufThreshold } ?? .beginner

        PlayerProfileRepository().recordMatchResult(didWin: didWin, opponentDifficulty: toughestBot)
        GameHistoryRepository().recordMatch(
            rulesProfileID: state.ruleProfile.id,
            didWin: didWin,
            finalScore: humanPlayer.totalScore,
            roundsPlayed: state.roundNumber,
            opponentSummary: state.players.filter { $0.id != humanPlayerID }.map(\.displayName).joined(separator: ", ")
        )
        AchievementEvaluator.evaluateAfterMatch(state: state, humanID: humanPlayerID, didWin: didWin)
    }

    // MARK: - Table reader hints

    private func refreshHints() {
        guard tableHintsEnabled else { tableHints = []; return }
        tableHints = TableReader.generateHints(
            observerID: humanPlayerID,
            observerHand: humanPlayer.hand,
            publicPlayerCardCounts: state.players.map { ($0.id, $0.hand.count) },
            discardHistory: state.discardPile.cards,
            profile: state.ruleProfile
        )
    }
}

private extension RoundOutcome {
    var winnerID: PlayerID {
        switch self {
        case .yosufSuccess(let callerID): return callerID
        case .asafSuccess(_, let challengerID): return challengerID
        }
    }
}
