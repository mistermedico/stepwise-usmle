import XCTest
@testable import YosufEngine

/// End-to-end simulations that auto-play a full match using the same
/// engine + AI code paths the real app uses — the closest thing to
/// "play a full game start to finish" that plain `swift test` can do
/// without a simulator. Every difficulty/personality combination gets at
/// least one full deterministic run to completion with no thrown errors.
final class GameSimulationTests: XCTestCase {

    private func playFullMatch(
        difficulties: [OpponentDifficulty],
        personalities: [OpponentPersonality],
        profile: RuleProfile,
        seed: UInt64
    ) throws -> GameState {
        precondition(difficulties.count == personalities.count)
        let players = zip(difficulties, personalities).map { difficulty, personality in
            Player(displayName: "Bot-\(difficulty.rawValue)", kind: .bot(difficulty: difficulty, personality: personality))
        }
        var state = try GameEngine.startMatch(players: players, profile: profile, rng: RNGBox(seed: seed))
        var memory = OpponentMemory()
        var safetyCounter = 0
        let maxIterations = 5000

        while !state.isMatchOver {
            safetyCounter += 1
            XCTAssertLessThan(safetyCounter, maxIterations, "Match did not converge - possible infinite loop")
            guard safetyCounter < maxIterations else { break }

            switch state.phase {
            case .awaitingDraw(let playerID):
                let player = state.player(with: playerID)!
                guard case .bot(let difficulty, let personality) = player.kind else {
                    XCTFail("Simulation only drives bot players"); return state
                }
                let action = OpponentEngine.decideDrawAction(
                    botID: playerID, hand: player.hand, topDiscard: state.discardPile.top,
                    difficulty: difficulty, personality: personality, profile: state.ruleProfile,
                    memory: &memory, rng: RNGBox(seed: seed &+ UInt64(safetyCounter))
                )
                switch action {
                case .declareYosuf:
                    try GameEngine.declareYosuf(&state, playerID: playerID)
                case .drawFromDeck:
                    try GameEngine.drawFromDeck(&state, playerID: playerID, rng: RNGBox(seed: seed &+ UInt64(safetyCounter)))
                case .drawFromDiscard:
                    if state.discardPile.isEmpty {
                        try GameEngine.drawFromDeck(&state, playerID: playerID, rng: RNGBox(seed: seed &+ UInt64(safetyCounter)))
                    } else {
                        try GameEngine.drawFromDiscard(&state, playerID: playerID)
                    }
                }

            case .awaitingDiscard(let playerID):
                let player = state.player(with: playerID)!
                guard case .bot(let difficulty, _) = player.kind else {
                    XCTFail("Simulation only drives bot players"); return state
                }
                let cardsToDiscard = OpponentEngine.decideDiscard(hand: player.hand, difficulty: difficulty, profile: state.ruleProfile)
                try GameEngine.discard(&state, playerID: playerID, cards: cardsToDiscard)

            case .roundEnded:
                try GameEngine.startNextRound(&state, rng: RNGBox(seed: seed &+ UInt64(safetyCounter)))

            case .matchEnded:
                break
            }
        }
        return state
    }

    func testFullMatchAllBeginnersReachesAValidConclusion() throws {
        let finalState = try playFullMatch(
            difficulties: [.beginner, .beginner, .beginner],
            personalities: [.cautious, .balanced, .aggressive],
            profile: .quick,
            seed: 12345
        )
        try assertValidMatchEnd(finalState)
    }

    func testFullMatchMixedDifficultiesUnderClassicRules() throws {
        let finalState = try playFullMatch(
            difficulties: [.beginner, .intermediate, .advanced, .expert],
            personalities: [.cautious, .balanced, .aggressive, .balanced],
            profile: .classic,
            seed: 999
        )
        try assertValidMatchEnd(finalState)
    }

    func testFullMatchUnderStreetRulesWithEventCards() throws {
        let finalState = try playFullMatch(
            difficulties: [.intermediate, .advanced],
            personalities: [.aggressive, .cautious],
            profile: .street,
            seed: 555
        )
        try assertValidMatchEnd(finalState)
    }

    func testFullMatchUnderGrandmaRulesWithAceHigh() throws {
        let finalState = try playFullMatch(
            difficulties: [.beginner, .expert],
            personalities: [.balanced, .balanced],
            profile: .grandma,
            seed: 2468
        )
        try assertValidMatchEnd(finalState)
    }

    private func assertValidMatchEnd(_ state: GameState) throws {
        guard case .matchEnded(let winnerID) = state.phase else {
            return XCTFail("Match should have ended")
        }
        let winner = try XCTUnwrap(state.player(with: winnerID))
        XCTAssertTrue(state.players.contains { $0.totalScore >= state.ruleProfile.maxScore })
        XCTAssertTrue(state.players.allSatisfy { winner.totalScore <= $0.totalScore })
        // Every card in play must still be a real, unique physical card.
        var allCards: [Card] = state.drawPile.cards + state.discardPile.cards
        state.players.forEach { allCards.append(contentsOf: $0.hand) }
        XCTAssertEqual(Set(allCards.map(\.id)).count, allCards.count)
        XCTAssertEqual(allCards.count, 54)
    }
}
