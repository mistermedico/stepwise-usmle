import Foundation

/// The end-of-run summary (section 2.5): a title, a timeline and the figures
/// that back both. Built once from a finished `GameState`, then persisted.
public struct EpidemicReport: Equatable, Codable, Hashable, Identifiable, Sendable {

    public let id: UUID
    public let finishedAt: Date
    public let outcome: GameOutcome
    public let title: ReportTitle

    // Set-up
    public let strain: StrainID
    public let difficulty: Difficulty
    public let scenario: StartScenario
    public let originRegion: RegionID
    public let dailyChallengeID: String?
    public let objective: ChallengeObjective?
    public let objectiveMet: Bool?

    // Figures
    public let days: Int
    public let totalInfected: Double
    public let totalLost: Double
    public let worldPopulation: Int
    public let regionsReached: Int
    public let detectionDay: Int?
    public let regionsAtDetection: Int?
    public let peakLethality: Double
    public let researchProgress: Double
    public let pointsSpent: Int
    public let traitsUnlocked: [TraitID]

    /// Milestone events, in order, for the animated timeline.
    public let timeline: [GameEvent]

    public init(state: GameState, finishedAt: Date = Date()) {
        let outcome = state.outcome ?? .defeat(.burnedOut)
        self.id = UUID()
        self.finishedAt = finishedAt
        self.outcome = outcome
        self.strain = state.setup.strain
        self.difficulty = state.setup.difficulty
        self.scenario = state.setup.scenario
        self.originRegion = state.originRegion
        self.dailyChallengeID = state.setup.dailyChallengeID
        self.objective = state.setup.objective
        self.objectiveMet = state.setup.objective.map {
            ObjectiveEvaluator.isSatisfied($0, state: state)
        }
        self.days = state.day
        self.totalInfected = state.totalInfected + state.totalLost
        self.totalLost = state.totalLost
        self.worldPopulation = state.worldPopulation
        self.regionsReached = state.touchedRegions.count
        self.detectionDay = state.detectionDay
        self.regionsAtDetection = state.regionsAtDetection
        self.peakLethality = state.peakLethality
        self.researchProgress = state.researchProgress
        self.pointsSpent = state.pointsSpent
        self.traitsUnlocked = state.unlockedTraits.sorted { $0.rawValue < $1.rawValue }
        self.timeline = state.events.filter { $0.kind.isMilestone }
        self.title = ReportTitle.title(for: state, outcome: outcome)
    }

    public var isVictory: Bool { outcome == .victory }

    /// Share of the world reached, `0...1`.
    public var reachFraction: Double {
        worldPopulation > 0 ? min(1, totalInfected / Double(worldPopulation)) : 0
    }

    /// Share of the world lost, `0...1`.
    public var lossFraction: Double {
        worldPopulation > 0 ? min(1, totalLost / Double(worldPopulation)) : 0
    }

    /// How long the strain went unnoticed, as a share of the run.
    public var stealthFraction: Double {
        guard days > 0 else { return 0 }
        guard let detectionDay else { return 1 }
        return min(1, Double(detectionDay) / Double(days))
    }
}

/// The flavour label stamped on a run.
public enum ReportTitle: String, Codable, Hashable, CaseIterable, Sendable {
    case lightningOutbreak
    case silentOutbreak
    case slowCreep
    case scorchedPath
    case steadyBloom
    case containedEarly
    case solvedInTime
    case burnedOut

    public var localizationKey: String { "report.title.\(rawValue)" }

    /// Picks the label. Order matters: the most characteristic pattern wins.
    public static func title(for state: GameState, outcome: GameOutcome) -> ReportTitle {
        switch outcome {
        case .defeat(let reason):
            switch reason {
            case .burnedOut:
                return state.touchedRegions.count <= 3 ? .containedEarly : .burnedOut
            case .solutionFound:
                return .solvedInTime
            case .objectiveFailed:
                return .containedEarly
            }
        case .victory:
            let losses = state.totalLost
            let reached = state.totalInfected + losses
            let lossShare = reached > 0 ? losses / reached : 0
            let detectionShare = state.day > 0
                ? Double(state.detectionDay ?? state.day) / Double(state.day)
                : 0

            if state.day <= 45 { return .lightningOutbreak }
            if detectionShare >= 0.60 { return .silentOutbreak }
            if lossShare >= 0.60 { return .scorchedPath }
            if state.day >= 140 { return .slowCreep }
            return .steadyBloom
        }
    }
}
