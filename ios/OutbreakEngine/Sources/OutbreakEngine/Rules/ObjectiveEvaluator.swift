import Foundation

/// Evaluates the extra condition attached to a daily challenge.
///
/// Every objective is written so that it can only ever be *broken*, never
/// un-broken. That keeps the check cheap (it runs once per simulated day) and
/// lets the UI show a live "still intact / failed" badge without replaying the run.
public enum ObjectiveEvaluator {

    /// `true` once the objective can no longer be met.
    public static func isBroken(_ objective: ChallengeObjective, state: GameState) -> Bool {
        switch objective {
        case .within(let days):
            return state.day > days

        case .lethalityBelow(let cap):
            return state.peakLethality > cap

        case .undetectedUntilRegions(let count):
            guard state.isDetected else { return false }
            return (state.regionsAtDetection ?? 0) < count

        case .lossesBelow(let fraction):
            guard state.worldPopulation > 0 else { return false }
            return state.totalLost / Double(state.worldPopulation) > fraction

        case .spendAtMost(let points):
            return state.pointsSpent > points
        }
    }

    /// `true` while the objective still holds.
    public static func isSatisfied(_ objective: ChallengeObjective, state: GameState) -> Bool {
        !isBroken(objective, state: state)
    }

    /// Progress toward the objective as a `0...1` fraction, for the HUD meter.
    /// Values approaching 1 mean the player is close to breaking it.
    public static func pressure(_ objective: ChallengeObjective, state: GameState) -> Double {
        switch objective {
        case .within(let days):
            guard days > 0 else { return 1 }
            return min(1, Double(state.day) / Double(days))

        case .lethalityBelow(let cap):
            guard cap > 0 else { return 1 }
            return min(1, state.peakLethality / cap)

        case .undetectedUntilRegions(let count):
            guard count > 0 else { return 0 }
            guard !state.isDetected else {
                return (state.regionsAtDetection ?? 0) >= count ? 0 : 1
            }
            return max(0, 1 - Double(state.infectedRegionCount) / Double(count))

        case .lossesBelow(let fraction):
            guard fraction > 0, state.worldPopulation > 0 else { return 1 }
            return min(1, (state.totalLost / Double(state.worldPopulation)) / fraction)

        case .spendAtMost(let points):
            guard points > 0 else { return 1 }
            return min(1, Double(state.pointsSpent) / Double(points))
        }
    }
}
