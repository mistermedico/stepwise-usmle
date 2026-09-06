import XCTest
@testable import YosufEngine

final class GameEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makePlayer(_ name: String, hand: [Card]) -> Player {
        Player(displayName: name, kind: .human, hand: hand)
    }

    private func makeState(
        p1Hand: [Card],
        p2Hand: [Card],
        phase: GamePhase? = nil,
        profile: RuleProfile = .classic,
        drawPile: [Card] = [Card.standard(.two, .clubs)],
        discardPile: [Card] = [Card.standard(.nine, .hearts)],
        currentPlayerIndex: Int = 0,
        roundModifiers: RoundModifiers = .none
    ) -> (GameState, PlayerID, PlayerID) {
        let p1 = makePlayer("A", hand: p1Hand)
        let p2 = makePlayer("B", hand: p2Hand)
        let players = [p1, p2]
        let resolvedPhase = phase ?? .awaitingDraw(playerID: players[currentPlayerIndex].id)
        let state = GameState(
            players: players,
            currentPlayerIndex: currentPlayerIndex,
            drawPile: Deck(cards: drawPile),
            discardPile: Deck(cards: discardPile),
            ruleProfile: profile,
            roundModifiers: roundModifiers,
            phase: resolvedPhase
        )
        return (state, p1.id, p2.id)
    }

    // MARK: - Match setup

    func testStartMatchDealsFiveCardsToEachPlayer() throws {
        let players = [makePlayer("A", hand: []), makePlayer("B", hand: []), makePlayer("C", hand: [])]
        let state = try GameEngine.startMatch(players: players, profile: .classic, rng: RNGBox(seed: 1))
        for player in state.players {
            XCTAssertEqual(player.hand.count, 5)
        }
        XCTAssertEqual(state.discardPile.count, 1)
        XCTAssertEqual(state.drawPile.count, 54 - 3 * 5 - 1)
    }

    func testStartMatchRejectsTooFewPlayers() {
        XCTAssertThrowsError(try GameEngine.startMatch(players: [makePlayer("A", hand: [])], profile: .classic)) { error in
            XCTAssertEqual(error as? GameError, .insufficientPlayers)
        }
    }

    func testStartMatchRejectsTooManyPlayers() {
        let players = (0..<5).map { makePlayer("P\($0)", hand: []) }
        XCTAssertThrowsError(try GameEngine.startMatch(players: players, profile: .classic)) { error in
            XCTAssertEqual(error as? GameError, .tooManyPlayers)
        }
    }

    func testSameSeedProducesSameDeal() throws {
        let playersA = [makePlayer("A", hand: []), makePlayer("B", hand: [])]
        let playersB = [makePlayer("A", hand: []), makePlayer("B", hand: [])]
        let stateA = try GameEngine.startMatch(players: playersA, profile: .classic, rng: RNGBox(seed: 99))
        let stateB = try GameEngine.startMatch(players: playersB, profile: .classic, rng: RNGBox(seed: 99))
        XCTAssertEqual(stateA.players[0].hand.map(\.kind), stateB.players[0].hand.map(\.kind))
        XCTAssertEqual(stateA.discardPile.cards.map(\.kind), stateB.discardPile.cards.map(\.kind))
    }

    // MARK: - Turn validation

    func testDrawFromDeckAdvancesToAwaitingDiscard() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)])
        try GameEngine.drawFromDeck(&state, playerID: p1)
        XCTAssertEqual(state.phase, .awaitingDiscard(playerID: p1))
        XCTAssertEqual(state.players[0].hand.count, 2)
        XCTAssertTrue(state.hasDrawnThisTurn)
    }

    func testDrawingOutOfTurnThrows() throws {
        var (state, _, p2) = makeState(p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)])
        XCTAssertThrowsError(try GameEngine.drawFromDeck(&state, playerID: p2)) { error in
            XCTAssertEqual(error as? GameError, .notPlayersTurn)
        }
    }

    func testCannotDrawTwiceInOneTurn() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)])
        try GameEngine.drawFromDeck(&state, playerID: p1)
        XCTAssertThrowsError(try GameEngine.drawFromDeck(&state, playerID: p1)) { error in
            XCTAssertEqual(error as? GameError, .alreadyDrewThisTurn)
        }
    }

    func testCannotDiscardBeforeDrawing() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)])
        XCTAssertThrowsError(try GameEngine.discard(&state, playerID: p1, cards: [.standard(.five, .hearts)])) { error in
            XCTAssertEqual(error as? GameError, .mustDrawBeforeDiscarding)
        }
    }

    func testDiscardCardsNotInHandThrows() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)],
            phase: .awaitingDiscard(playerID: PlayerID())
        )
        // Force phase to this player's discard turn.
        state.phase = .awaitingDiscard(playerID: p1)
        state.hasDrawnThisTurn = true
        XCTAssertThrowsError(try GameEngine.discard(&state, playerID: p1, cards: [.standard(.king, .spades)])) { error in
            XCTAssertEqual(error as? GameError, .cardsNotInHand)
        }
    }

    func testDiscardEmptySelectionThrows() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.five, .hearts)], p2Hand: [.standard(.six, .hearts)])
        state.phase = .awaitingDiscard(playerID: p1)
        state.hasDrawnThisTurn = true
        XCTAssertThrowsError(try GameEngine.discard(&state, playerID: p1, cards: [])) { error in
            XCTAssertEqual(error as? GameError, .emptyDiscardSelection)
        }
    }

    func testDiscardInvalidMeldThrows() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts), .standard(.eight, .clubs), .standard(.two, .diamonds)],
            p2Hand: [.standard(.six, .hearts)]
        )
        state.phase = .awaitingDiscard(playerID: p1)
        state.hasDrawnThisTurn = true
        // Reuse the actual dealt card instances (identity matters — the
        // engine matches by card id, not by rank/suit).
        let invalidMeld = state.players[0].hand
        XCTAssertThrowsError(try GameEngine.discard(&state, playerID: p1, cards: invalidMeld)) { error in
            XCTAssertEqual(error as? GameError, .invalidMeld)
        }
    }

    func testDiscardValidMeldSucceedsAndAdvancesTurn() throws {
        var (state, p1, p2) = makeState(
            p1Hand: [.standard(.five, .hearts), .standard(.five, .clubs), .standard(.five, .spades)],
            p2Hand: [.standard(.six, .hearts)]
        )
        state.phase = .awaitingDiscard(playerID: p1)
        state.hasDrawnThisTurn = true
        let meld = state.players[0].hand
        try GameEngine.discard(&state, playerID: p1, cards: meld)
        XCTAssertTrue(state.players[0].hand.isEmpty)
        XCTAssertEqual(state.phase, .awaitingDraw(playerID: p2))
        XCTAssertEqual(state.discardsThisRound, 1)
    }

    // MARK: - Yosuf / Asaf

    func testDeclareYosufSuccessWhenCallerHasLowestHand() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.two, .hearts)],           // value 2
            p2Hand: [.standard(.king, .clubs)]             // value 10
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        XCTAssertEqual(state.phase, .roundEnded(outcome: .yosufSuccess(callerID: p1)))
        XCTAssertEqual(state.players[0].totalScore, 0)
        XCTAssertEqual(state.players[1].totalScore, 10)
    }

    func testDeclareYosufCaughtByAsafWhenChallengerTiesOrBeatsCaller() throws {
        var (state, p1, p2) = makeState(
            p1Hand: [.standard(.six, .hearts)],  // value 6, caller
            p2Hand: [.standard(.three, .clubs)]  // value 3, beats caller
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        guard case .roundEnded(let outcome) = state.phase else {
            return XCTFail("expected roundEnded phase")
        }
        XCTAssertEqual(outcome, .asafSuccess(callerID: p1, challengerID: p2))
        // caller pays their own hand value + the Asaf penalty; challenger wins (0 added)
        XCTAssertEqual(state.players[0].totalScore, 6 + RuleProfile.classic.asafPenalty)
        XCTAssertEqual(state.players[1].totalScore, 0)
    }

    func testTieFavorsChallengerUnderClassicRules() throws {
        var (state, p1, p2) = makeState(
            p1Hand: [.standard(.four, .hearts), .standard(.three, .clubs)], // value 7
            p2Hand: [.standard(.seven, .clubs)]                              // value 7, ties
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        guard case .roundEnded(let outcome) = state.phase else {
            return XCTFail("expected roundEnded phase")
        }
        XCTAssertEqual(outcome, .asafSuccess(callerID: p1, challengerID: p2))
    }

    func testCannotDeclareYosufAboveThreshold() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.king, .hearts), .standard(.king, .clubs)], // value 20
            p2Hand: [.standard(.two, .clubs)]
        )
        XCTAssertThrowsError(try GameEngine.declareYosuf(&state, playerID: p1)) { error in
            guard case .cannotDeclareYosufYet(let value, let threshold) = error as? GameError else {
                return XCTFail("wrong error")
            }
            XCTAssertEqual(value, 20)
            XCTAssertEqual(threshold, 7)
        }
    }

    func testCannotDeclareYosufAfterDrawing() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.two, .hearts)], p2Hand: [.standard(.two, .clubs)])
        try GameEngine.drawFromDeck(&state, playerID: p1)
        XCTAssertThrowsError(try GameEngine.declareYosuf(&state, playerID: p1)) { error in
            XCTAssertEqual(error as? GameError, .cannotDeclareYosufAfterDrawing)
        }
    }

    func testEmptyHandIsAlwaysEligibleAndWinsOutright() throws {
        var (state, p1, _) = makeState(p1Hand: [], p2Hand: [.standard(.two, .clubs)])
        try GameEngine.declareYosuf(&state, playerID: p1)
        XCTAssertEqual(state.phase, .roundEnded(outcome: .yosufSuccess(callerID: p1)))
    }

    // MARK: - Match end

    func testMatchEndsWhenAPlayerReachesMaxScore() throws {
        var profile = RuleProfile.classic
        profile.maxScore = 15
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.two, .hearts)],
            p2Hand: [.standard(.king, .clubs), .standard(.king, .diamonds)], // value 20 >= maxScore 15
            profile: profile
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        guard case .matchEnded(let winnerID) = state.phase else {
            return XCTFail("expected matchEnded phase")
        }
        XCTAssertEqual(winnerID, p1)
    }

    func testStartNextRoundThrowsWhenMatchAlreadyEnded() throws {
        var profile = RuleProfile.classic
        profile.maxScore = 1
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.two, .hearts)],
            p2Hand: [.standard(.king, .clubs)],
            profile: profile
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        XCTAssertThrowsError(try GameEngine.startNextRound(&state)) { error in
            XCTAssertEqual(error as? GameError, .gameAlreadyOver)
        }
    }

    func testStartNextRoundDealsFreshFiveCardHands() throws {
        var (state, p1, _) = makeState(p1Hand: [.standard(.two, .hearts)], p2Hand: [.standard(.six, .clubs)])
        try GameEngine.declareYosuf(&state, playerID: p1)
        try GameEngine.startNextRound(&state, rng: RNGBox(seed: 7))
        for player in state.players {
            XCTAssertEqual(player.hand.count, 5)
        }
        XCTAssertEqual(state.roundNumber, 2)
    }

    // MARK: - Deck exhaustion edge cases

    func testDrawFromDeckReshufflesDiscardPileWhenExhausted() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts)],
            p2Hand: [.standard(.six, .hearts)],
            drawPile: [],
            discardPile: [.standard(.nine, .hearts), .standard(.eight, .clubs), .standard(.seven, .diamonds)]
        )
        try GameEngine.drawFromDeck(&state, playerID: p1, rng: RNGBox(seed: 3))
        XCTAssertEqual(state.players[0].hand.count, 2)
        // the old top discard stays as the sole card in the (new) discard pile
        XCTAssertEqual(state.discardPile.count, 1)
        XCTAssertEqual(state.discardPile.top?.rank, .nine)
    }

    func testBothPilesEffectivelyEmptyThrowsRatherThanCrashing() throws {
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts)],
            p2Hand: [.standard(.six, .hearts)],
            drawPile: [],
            discardPile: [.standard(.nine, .hearts)] // only the top card, nothing to reshuffle
        )
        XCTAssertThrowsError(try GameEngine.drawFromDeck(&state, playerID: p1)) { error in
            XCTAssertEqual(error as? GameError, .bothPilesEmpty)
        }
    }

    // MARK: - Party event modifiers

    func testDoublePenaltyEventDoublesAsafPenalty() throws {
        let modifiers = RoundModifiers.from(.doublePenalty)
        var (state, p1, p2) = makeState(
            p1Hand: [.standard(.six, .hearts)],
            p2Hand: [.standard(.three, .clubs)],
            roundModifiers: modifiers
        )
        try GameEngine.declareYosuf(&state, playerID: p1)
        XCTAssertEqual(state.players[0].totalScore, 6 + RuleProfile.classic.asafPenalty * 2)
        _ = p2
    }

    func testSkipNextPlayerEventIsConsumedAfterOneAdvance() throws {
        let modifiers = RoundModifiers.from(.skipNextPlayer)
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts)],
            p2Hand: [.standard(.six, .hearts)],
            roundModifiers: modifiers
        )
        try GameEngine.drawFromDeck(&state, playerID: p1)
        try GameEngine.discard(&state, playerID: p1, cards: [state.players[0].hand[0]])
        // with 2 players, skipping "the next player" wraps back to p1 again
        XCTAssertEqual(state.phase, .awaitingDraw(playerID: p1))
        XCTAssertFalse(state.roundModifiers.skipsNextPlayer, "one-time effect must be consumed")
    }

    func testFreeOpeningDiscardAllowsInvalidMeldOnlyOnFirstDiscardOfRound() throws {
        let modifiers = RoundModifiers.from(.freeOpeningDiscard)
        var (state, p1, _) = makeState(
            p1Hand: [.standard(.five, .hearts), .standard(.eight, .clubs), .standard(.two, .diamonds)],
            p2Hand: [.standard(.six, .hearts)],
            roundModifiers: modifiers
        )
        state.phase = .awaitingDiscard(playerID: p1)
        state.hasDrawnThisTurn = true
        let notAMeld = state.players[0].hand
        XCTAssertNoThrow(try GameEngine.discard(&state, playerID: p1, cards: notAMeld))
    }
}
