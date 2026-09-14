import Foundation

/// Backs the end-of-run "Outbreak Report" screen: the finished state's summary plus
/// a plain-text share string (spec section 2.5, shareable report).
@MainActor
public final class ReportViewModel: ObservableObject {
    public let finalState: GameState
    public let summary: ReportAnalyzer.ReportSummary?
    public let newlyUnlockedAchievementIDs: Set<String>

    public init(finalState: GameState, newlyUnlockedAchievementIDs: Set<String> = []) {
        self.finalState = finalState
        self.summary = ReportAnalyzer.summarize(finalState)
        self.newlyUnlockedAchievementIDs = newlyUnlockedAchievementIDs
    }

    public var shareText: String {
        guard let summary else { return "" }
        let outcomeWord = summary.outcome == .victory ? "Victory" : "Contained"
        return "Pathogen Protocol — \(outcomeWord) on day \(summary.totalDays). "
            + "Peak awareness \(Int(summary.peakAwareness * 100))%, "
            + "final spread \(Int(summary.finalInfectionFraction * 100))%."
    }
}
