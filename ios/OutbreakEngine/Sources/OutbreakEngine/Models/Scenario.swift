import Foundation

/// The "starting world" variant chosen before a run (section 2.3).
public enum StartScenario: String, CaseIterable, Codable, Hashable, Sendable {
    /// A remote territory: slow, but nobody is watching.
    case isolatedIsland
    /// A transit hub: fast, and everybody is watching.
    case transitHub
    /// Let the board decide.
    case wildcard

    public var titleKey: String { "scenario.\(rawValue).title" }
    public var detailKey: String { "scenario.\(rawValue).detail" }

    /// Applied to awareness growth for the whole run — the trade-off that makes
    /// the choice interesting.
    public var awarenessModifier: Double {
        switch self {
        case .isolatedIsland: return 0.75
        case .transitHub: return 1.25
        case .wildcard: return 1.0
        }
    }

    /// Applied to cross-territory travel probabilities.
    public var travelModifier: Double {
        switch self {
        case .isolatedIsland: return 0.80
        case .transitHub: return 1.35
        case .wildcard: return 1.0
        }
    }
}

/// Extra win condition layered on top of "consume the world".
public enum ChallengeObjective: Equatable, Codable, Hashable, Sendable {
    /// Finish within a day budget.
    case within(days: Int)
    /// Never let summed lethality rise above a cap.
    case lethalityBelow(cap: Double)
    /// Stay unnoticed until at least N territories carry the strain.
    case undetectedUntilRegions(count: Int)
    /// Keep total losses under a share of world population.
    case lossesBelow(fraction: Double)
    /// Win having spent no more than a point budget.
    case spendAtMost(points: Int)

    public var localizationKey: String {
        switch self {
        case .within: return "objective.within"
        case .lethalityBelow: return "objective.lethalityBelow"
        case .undetectedUntilRegions: return "objective.undetectedUntilRegions"
        case .lossesBelow: return "objective.lossesBelow"
        case .spendAtMost: return "objective.spendAtMost"
        }
    }

    /// The single number shown in the objective string.
    public var displayValue: Double {
        switch self {
        case .within(let days): return Double(days)
        case .lethalityBelow(let cap): return cap
        case .undetectedUntilRegions(let count): return Double(count)
        case .lossesBelow(let fraction): return fraction * 100
        case .spendAtMost(let points): return Double(points)
        }
    }
}

/// A fully specified run set-up.
public struct GameSetup: Equatable, Codable, Hashable, Sendable {
    public var strain: StrainID
    public var difficulty: Difficulty
    public var scenario: StartScenario
    public var seed: UInt64
    /// Present only for the daily challenge.
    public var objective: ChallengeObjective?
    /// Identifier of the daily challenge this run belongs to, if any (`yyyy-MM-dd`).
    public var dailyChallengeID: String?

    public init(
        strain: StrainID = .drift,
        difficulty: Difficulty = .tense,
        scenario: StartScenario = .wildcard,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max),
        objective: ChallengeObjective? = nil,
        dailyChallengeID: String? = nil
    ) {
        self.strain = strain
        self.difficulty = difficulty
        self.scenario = scenario
        self.seed = seed
        self.objective = objective
        self.dailyChallengeID = dailyChallengeID
    }

    public var isDailyChallenge: Bool { dailyChallengeID != nil }
}
