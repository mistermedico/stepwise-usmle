import XCTest
@testable import YosufEngine

final class DailyChallengeGeneratorTests: XCTestCase {
    func testSameDateProducesIdenticalScenario() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let a = DailyChallengeGenerator.scenario(for: date, calendar: calendar)
        let b = DailyChallengeGenerator.scenario(for: date, calendar: calendar)

        XCTAssertEqual(a.seed, b.seed)
        XCTAssertEqual(a.dateKey, b.dateKey)
        XCTAssertEqual(a.ruleProfile, b.ruleProfile)
        XCTAssertEqual(a.opponents.map(\.difficulty), b.opponents.map(\.difficulty))
        XCTAssertEqual(a.opponents.map(\.personality), b.opponents.map(\.personality))
    }

    func testDifferentDatesTypicallyProduceDifferentSeeds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!

        let a = DailyChallengeGenerator.scenario(for: day1, calendar: calendar)
        let b = DailyChallengeGenerator.scenario(for: day2, calendar: calendar)
        XCTAssertNotEqual(a.seed, b.seed)
    }

    func testScenarioDeckShuffleIsFullyReproducibleFromSeed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let scenario = DailyChallengeGenerator.scenario(for: date, calendar: calendar)

        var genA = SeededGenerator(seed: scenario.seed)
        var genB = SeededGenerator(seed: scenario.seed)
        var deckA = Deck.fullDeck()
        var deckB = Deck.fullDeck()
        deckA.shuffle(using: &genA)
        deckB.shuffle(using: &genB)
        XCTAssertEqual(deckA.cards.map(\.kind), deckB.cards.map(\.kind))
    }
}
