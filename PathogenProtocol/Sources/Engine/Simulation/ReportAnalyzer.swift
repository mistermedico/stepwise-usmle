import Foundation

/// Turns a finished run's recorded `history` into the shareable "Outbreak Report"
/// title (spec section 2.5). Pure function of the final `GameState` — no randomness,
/// so the same run always earns the same title.
public enum ReportAnalyzer {
    private static let lightningVictoryDayThreshold = 14
    private static let silentOutbreakAwarenessCeiling = 0.3
    private static let earlyContainmentDayThreshold = 6
    private static let nearMissInfectionFloor = 0.7

    public static func character(for state: GameState) -> OutbreakCharacter? {
        guard let outcome = state.outcome else { return nil }
        let peakAwareness = state.history.map(\.globalAwareness).max() ?? state.globalAwareness

        switch outcome {
        case .victory:
            if peakAwareness < silentOutbreakAwarenessCeiling { return .silentOutbreak }
            if state.day <= lightningVictoryDayThreshold { return .lightningOutbreak }
            return .grindingSiege
        case .defeat:
            if state.globalInfectionFraction >= nearMissInfectionFloor { return .nearMiss }
            if state.day <= earlyContainmentDayThreshold { return .containedEarly }
            return .containedEarly
        }
    }

    public struct ReportSummary {
        public let character: OutbreakCharacter
        public let outcome: GameOutcome
        public let totalDays: Int
        public let peakAwareness: Double
        public let finalInfectionFraction: Double
        public let regionsFullyLost: Int
    }

    public static func summarize(_ state: GameState) -> ReportSummary? {
        guard let outcome = state.outcome, let character = character(for: state) else { return nil }
        let peakAwareness = state.history.map(\.globalAwareness).max() ?? state.globalAwareness
        let regionsFullyLost = state.regionStates.values.filter { $0.infectionLevel >= 0.99 }.count
        return ReportSummary(
            character: character,
            outcome: outcome,
            totalDays: state.day,
            peakAwareness: peakAwareness,
            finalInfectionFraction: state.globalInfectionFraction,
            regionsFullyLost: regionsFullyLost
        )
    }
}
