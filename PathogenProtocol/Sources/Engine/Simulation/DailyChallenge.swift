import Foundation

/// A fixed, special win condition layered on top of a normal run, checked in
/// addition to (not instead of) the standard `WorldResponseRules` outcome.
public enum DailyChallengeObjective: String, Codable, Equatable {
    case winWithoutAnyLockdown
    case winWithinFifteenDays
    case winWithPeakAwarenessBelowHalf

    public var titleKey: String { "daily.objective.\(rawValue)" }

    public func isSatisfied(by state: GameState) -> Bool {
        guard state.outcome == .victory else { return false }
        switch self {
        case .winWithoutAnyLockdown:
            return state.history.allSatisfy { $0.regionsLockedDown == 0 }
        case .winWithinFifteenDays:
            return state.day <= 15
        case .winWithPeakAwarenessBelowHalf:
            return (state.history.map(\.globalAwareness).max() ?? state.globalAwareness) < 0.5
        }
    }
}

public struct DailyChallenge: Equatable {
    public let calendarDay: Int // days since epoch, UTC — the deterministic seed
    public let scenario: WorldScenario
    public let strain: StrainDefinition
    public let difficulty: DifficultyLevel
    public let objective: DailyChallengeObjective
}

/// Produces the same challenge for every player on a given UTC calendar day, and a
/// different one each day — a pure function of the date, never random (spec item 2.4).
public enum DailyChallengeProvider {
    private static let objectives: [DailyChallengeObjective] = [
        .winWithoutAnyLockdown, .winWithinFifteenDays, .winWithPeakAwarenessBelowHalf,
    ]

    public static func challenge(for date: Date, calendar: Calendar = .init(identifier: .gregorian)) -> DailyChallenge {
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let dayNumber = utcCalendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: date).day ?? 0

        let scenario = ScenarioCatalog.all[dayNumber.nonNegativeModulo(ScenarioCatalog.all.count)]
        let strain = StrainCatalog.all[dayNumber.nonNegativeModulo(StrainCatalog.all.count)]
        let difficulty = DifficultyLevel.allCases[dayNumber.nonNegativeModulo(DifficultyLevel.allCases.count)]
        let objective = objectives[dayNumber.nonNegativeModulo(objectives.count)]

        return DailyChallenge(
            calendarDay: dayNumber, scenario: scenario, strain: strain, difficulty: difficulty, objective: objective
        )
    }
}

extension Int {
    /// Standard modulo (never negative), since `%` in Swift can return a negative result.
    func nonNegativeModulo(_ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
