import Foundation

/// The once-a-day shared puzzle (section 2.4).
///
/// Everything about a challenge is derived from its date string, so every player
/// on every device gets the same strain, the same board seed and the same extra
/// condition — with no server, no clock skew and no network call.
public struct DailyChallenge: Equatable, Codable, Hashable, Sendable {
    /// `yyyy-MM-dd` in UTC. Doubles as the persistence key.
    public let id: String
    public let setup: GameSetup
    public let objective: ChallengeObjective

    public init(id: String, setup: GameSetup, objective: ChallengeObjective) {
        self.id = id
        self.setup = setup
        self.objective = objective
    }

    /// Builds the challenge for a given day.
    public static func challenge(for date: Date, calendar: Calendar = .utcCalendar) -> DailyChallenge {
        let id = identifier(for: date, calendar: calendar)
        return challenge(id: id)
    }

    /// Builds the challenge for a `yyyy-MM-dd` identifier. Exposed for tests and
    /// for replaying a stored report.
    public static func challenge(id: String) -> DailyChallenge {
        var generator = SeededGenerator(seed: SeededGenerator.seed(from: "outbreak-daily-\(id)"))

        let strain = generator.pick(StrainCatalog.freeStrains.map(\.id)) ?? .drift
        let difficulty = generator.pick(Difficulty.allCases) ?? .tense
        let scenario = generator.pick(StartScenario.allCases) ?? .wildcard
        let objective = objective(for: difficulty, using: &generator)
        // The board seed is drawn from the same stream, so it is fixed for the day.
        let boardSeed = generator.next()

        let setup = GameSetup(
            strain: strain,
            difficulty: difficulty,
            scenario: scenario,
            seed: boardSeed,
            objective: objective,
            dailyChallengeID: id
        )
        return DailyChallenge(id: id, setup: setup, objective: objective)
    }

    /// Picks an extra condition and scales it to the difficulty tier, so a
    /// "lethal" day never also gets the tightest possible budget.
    private static func objective(
        for difficulty: Difficulty,
        using generator: inout SeededGenerator
    ) -> ChallengeObjective {
        let slack: Double
        switch difficulty {
        case .breezy: slack = 1.30
        case .tense: slack = 1.00
        case .lethal: slack = 0.80
        }

        switch generator.int(in: 0...4) {
        case 0:
            return .within(days: Int((110.0 * slack).rounded()))
        case 1:
            return .lethalityBelow(cap: (2.5 * slack * 10).rounded() / 10)
        case 2:
            return .undetectedUntilRegions(count: max(2, Int((4.0 * slack).rounded())))
        case 3:
            return .lossesBelow(fraction: (0.35 * slack * 100).rounded() / 100)
        default:
            return .spendAtMost(points: Int((90.0 * slack).rounded()))
        }
    }

    /// `yyyy-MM-dd` for a date, in UTC.
    public static func identifier(for date: Date, calendar: Calendar = .utcCalendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2026
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public extension Calendar {
    /// A Gregorian calendar pinned to UTC. Using the device calendar here would
    /// hand players in different time zones different "daily" challenges.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
