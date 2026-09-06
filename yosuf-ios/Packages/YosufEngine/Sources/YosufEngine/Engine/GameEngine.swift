import Foundation

/// The single authority over match state. Every rule in the spec — dealing,
/// drawing, discarding/melding, declaring Yosuf, resolving Asaf, scoring,
/// and match end — is implemented here as an explicit, throwing action.
/// No SwiftUI, UIKit, or Foundation networking imports: this type is
/// tested with plain `swift test`, no simulator required.
public enum GameEngine {

    private static let handSize = 5

    // MARK: - Match / round setup

    public static func startMatch(
        players: [Player],
        profile: RuleProfile,
        rng: RNGBox = RNGBox()
    ) throws -> GameState {
        guard players.count >= 2 else { throw GameError.insufficientPlayers }
        guard players.count <= 4 else { throw GameError.tooManyPlayers }

        var state = GameState(
            players: players,
            currentPlayerIndex: 0,
            drawPile: Deck(cards: []),
            discardPile: Deck(cards: []),
            ruleProfile: profile,
            phase: .awaitingDraw(playerID: players[0].id)
        )
        dealNewRound(&state, rng: rng, startingPlayerIndex: 0)
        return state
    }

    /// Resets hands, reshuffles a fresh deck, and deals `handSize` cards to
    /// every player. `startingPlayerIndex` rotates each round.
    private static func dealNewRound(_ state: inout GameState, rng: RNGBox, startingPlayerIndex: Int) {
        var generator = rng
        var deck = Deck.fullDeck()
        deck.shuffle(using: &generator)

        for i in state.players.indices {
            state.players[i].hand = []
        }

        for _ in 0..<handSize {
            for i in state.players.indices {
                if let card = deck.drawTop() {
                    state.players[i].hand.append(card)
                }
            }
        }

        var discard = Deck(cards: [])
        if let firstDiscard = deck.drawTop() {
            discard.push(firstDiscard)
        }

        state.drawPile = deck
        state.discardPile = discard
        state.currentPlayerIndex = startingPlayerIndex
        state.hasDrawnThisTurn = false
        state.pendingYosufCallerID = nil
        state.discardsThisRound = 0
        state.phase = .awaitingDraw(playerID: state.players[startingPlayerIndex].id)
        state.log.append(.cardsDealt)

        if state.ruleProfile.eventCardsEnabled, let event = PartyEventCard.allCases.randomElement(using: &generator) {
            state.roundModifiers = .from(event)
            state.log.append(.eventCardDrawn(event))
        } else {
            state.roundModifiers = .none
        }
    }

    // MARK: - Turn actions

    public static func drawFromDeck(_ state: inout GameState, playerID: PlayerID, rng: RNGBox = RNGBox()) throws {
        try validateTurn(state, playerID: playerID, expectDraw: true)

        if state.drawPile.isEmpty {
            try reshuffleDiscardIntoDrawPile(&state, rng: rng)
        }
        guard let card = state.drawPile.drawTop() else {
            throw GameError.bothPilesEmpty
        }
        let idx = state.index(of: playerID)!
        state.players[idx].hand.append(card)
        state.hasDrawnThisTurn = true
        state.phase = .awaitingDiscard(playerID: playerID)
        state.log.append(.drew(playerID: playerID, fromDiscard: false))
    }

    public static func drawFromDiscard(_ state: inout GameState, playerID: PlayerID) throws {
        try validateTurn(state, playerID: playerID, expectDraw: true)
        guard let card = state.discardPile.drawTop() else {
            throw GameError.bothPilesEmpty
        }
        let idx = state.index(of: playerID)!
        state.players[idx].hand.append(card)
        state.hasDrawnThisTurn = true
        state.phase = .awaitingDiscard(playerID: playerID)
        state.log.append(.drew(playerID: playerID, fromDiscard: true))
    }

    /// Discards one or more cards (a size-1 selection is a plain single
    /// discard; size ≥ `minMeldSize` must be a valid set/run unless this
    /// round's `freeOpeningDiscard` modifier is active for the very first
    /// discard of the round).
    public static func discard(_ state: inout GameState, playerID: PlayerID, cards: [Card]) throws {
        try validateTurn(state, playerID: playerID, expectDraw: false)
        guard !cards.isEmpty else { throw GameError.emptyDiscardSelection }

        let idx = state.index(of: playerID)!
        let hand = state.players[idx].hand
        let handIDs = Set(hand.map(\.id))
        guard cards.allSatisfy({ handIDs.contains($0.id) }) else { throw GameError.cardsNotInHand }

        var isMeld = false
        if cards.count > 1 {
            let allowFree = state.roundModifiers.freeOpeningDiscard && state.discardsThisRound == 0
            if !allowFree {
                guard MeldDetector.validate(cards, minMeldSize: state.ruleProfile.minMeldSize) != nil else {
                    throw GameError.invalidMeld
                }
            }
            isMeld = true
        }

        let discardedIDs = Set(cards.map(\.id))
        state.players[idx].hand.removeAll { discardedIDs.contains($0.id) }
        // Push in the order given so the visible "top" card is the last one listed.
        state.discardPile.push(contentsOf: cards.reversed())

        state.hasDrawnThisTurn = false
        state.discardsThisRound += 1
        state.log.append(.discarded(playerID: playerID, meld: isMeld))

        advanceTurn(&state)
    }

    // MARK: - Yosuf / Asaf resolution

    /// Declares Yosuf and immediately resolves the round: reveals every
    /// hand, determines whether any other player ties or beats the
    /// caller's total (an automatic "Asaf!" catch), and applies scoring.
    public static func declareYosuf(_ state: inout GameState, playerID: PlayerID) throws {
        guard state.player(with: playerID) != nil else { throw GameError.playerNotFound }
        switch state.phase {
        case .roundEnded: throw GameError.roundAlreadyOver
        case .matchEnded: throw GameError.gameAlreadyOver
        case .awaitingDraw(let expected):
            guard expected == playerID else { throw GameError.notPlayersTurn }
        case .awaitingDiscard:
            throw GameError.cannotDeclareYosufAfterDrawing
        }
        guard !state.hasDrawnThisTurn else { throw GameError.cannotDeclareYosufAfterDrawing }

        let caller = state.player(with: playerID)!
        let callerValue = HandEvaluator.handValue(caller.hand, aceHigh: state.ruleProfile.aceHigh)
        guard callerValue <= state.ruleProfile.yosufThreshold else {
            throw GameError.cannotDeclareYosufYet(currentValue: callerValue, threshold: state.ruleProfile.yosufThreshold)
        }

        state.pendingYosufCallerID = playerID
        state.log.append(.yosufDeclared(playerID: playerID))

        let others = state.players.filter { $0.id != playerID }
        let challengerCandidates = others
            .map { ($0, HandEvaluator.handValue($0.hand, aceHigh: state.ruleProfile.aceHigh)) }
            .filter { state.ruleProfile.tieFavorsChallenger ? $0.1 <= callerValue : $0.1 < callerValue }
            .sorted { $0.1 < $1.1 }

        let outcome: RoundOutcome
        if let (challenger, _) = challengerCandidates.first {
            outcome = .asafSuccess(callerID: playerID, challengerID: challenger.id)
            state.log.append(.asafDeclared(challengerID: challenger.id, callerID: playerID))
        } else {
            outcome = .yosufSuccess(callerID: playerID)
        }

        applyScoring(&state, outcome: outcome)
        state.log.append(.roundEnded(outcome: outcome))
        state.phase = .roundEnded(outcome: outcome)
    }

    private static func applyScoring(_ state: inout GameState, outcome: RoundOutcome) {
        let winnerID: PlayerID
        switch outcome {
        case .yosufSuccess(let callerID):
            winnerID = callerID
        case .asafSuccess(_, let challengerID):
            winnerID = challengerID
        }

        for i in state.players.indices {
            let player = state.players[i]
            if player.id == winnerID {
                continue // round winner adds nothing
            }
            let handValue = HandEvaluator.handValue(player.hand, aceHigh: state.ruleProfile.aceHigh)
            if case .asafSuccess(let callerID, _) = outcome, player.id == callerID {
                let penalty = Int(Double(state.ruleProfile.asafPenalty) * state.roundModifiers.penaltyMultiplier)
                state.players[i].totalScore += handValue + penalty
            } else {
                state.players[i].totalScore += handValue
            }
        }

        if state.players.contains(where: { $0.totalScore >= state.ruleProfile.maxScore }) {
            let matchWinner = state.players.min { $0.totalScore < $1.totalScore }!
            state.phase = .matchEnded(winnerID: matchWinner.id)
            state.log.append(.matchEnded(winnerID: matchWinner.id))
        }
    }

    /// Starts the next round after a `.roundEnded` phase. No-op (throws) if
    /// the match has already concluded.
    public static func startNextRound(_ state: inout GameState, rng: RNGBox = RNGBox()) throws {
        guard case .roundEnded = state.phase else {
            if case .matchEnded = state.phase { throw GameError.gameAlreadyOver }
            throw GameError.roundAlreadyOver
        }
        state.roundNumber += 1
        let nextStart = (state.currentPlayerIndex + 1) % state.players.count
        dealNewRound(&state, rng: rng, startingPlayerIndex: nextStart)
    }

    // MARK: - Helpers

    private static func validateTurn(_ state: GameState, playerID: PlayerID, expectDraw: Bool) throws {
        guard !state.isMatchOver else { throw GameError.gameAlreadyOver }
        switch state.phase {
        case .awaitingDraw(let expected):
            guard expected == playerID else { throw GameError.notPlayersTurn }
            guard expectDraw else { throw GameError.mustDrawBeforeDiscarding }
        case .awaitingDiscard(let expected):
            guard expected == playerID else { throw GameError.notPlayersTurn }
            guard !expectDraw else { throw GameError.alreadyDrewThisTurn }
        case .roundEnded, .matchEnded:
            throw GameError.roundAlreadyOver
        }
    }

    private static func reshuffleDiscardIntoDrawPile(_ state: inout GameState, rng: RNGBox) throws {
        guard let top = state.discardPile.top else { throw GameError.bothPilesEmpty }
        let rest = Array(state.discardPile.cards.dropFirst())
        guard !rest.isEmpty else { throw GameError.bothPilesEmpty }
        var generator = rng
        var newDrawPile = Deck(cards: rest)
        newDrawPile.shuffle(using: &generator)
        state.drawPile = newDrawPile
        state.discardPile = Deck(cards: [top])
    }

    private static func advanceTurn(_ state: inout GameState) {
        let count = state.players.count
        let step = state.roundModifiers.reversedOrder ? -1 : 1
        var next = (state.currentPlayerIndex + step + count) % count
        if state.roundModifiers.skipsNextPlayer {
            next = (next + step + count) % count
            state.roundModifiers.skipsNextPlayer = false // one-time effect, consumed here
        }
        state.currentPlayerIndex = next
        state.phase = .awaitingDraw(playerID: state.players[next].id)
    }
}
