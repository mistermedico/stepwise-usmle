import Foundation

/// The achievement tree (section 2.6). Each case is evaluated purely from a
/// finished `EpidemicReport`, so unlocks can be recomputed from stored history
/// if the list ever grows.
public enum Achievement: String, CaseIterable, Codable, Hashable, Sendable {
    case firstBloom
    case lightningStrike
    case ghostStrain
    case untouchedWorld
    case coldBloodedRun
    case desertBloom
    case islandStart
    case hubStart
    case allRegionsReached
    case gentleTouch
    case fullTree
    case thrifty
    case lethalTier
    case dailyRegular
    case perfectDaily

    public var titleKey: String { "achievement.\(rawValue).title" }
    public var detailKey: String { "achievement.\(rawValue).detail" }

    /// Achievements that need history rather than a single run.
    public var isCumulative: Bool {
        switch self {
        case .dailyRegular: return true
        default: return false
        }
    }

    /// Evaluates the achievements a single finished run earns.
    public static func earned(from report: EpidemicReport) -> Set<Achievement> {
        var earned: Set<Achievement> = []
        guard report.isVictory else {
            // One consolation unlock: reaching every territory, win or lose.
            if report.regionsReached == RegionCatalog.all.count {
                earned.insert(.allRegionsReached)
            }
            return earned
        }

        earned.insert(.firstBloom)

        if report.regionsReached == RegionCatalog.all.count {
            earned.insert(.allRegionsReached)
        }
        if report.days <= 45 {
            earned.insert(.lightningStrike)
        }
        // Never noticed until the world was already more than half consumed.
        if report.stealthFraction >= 0.60 {
            earned.insert(.ghostStrain)
        }
        if report.detectionDay == nil {
            earned.insert(.untouchedWorld)
        }
        if report.lossFraction <= 0.05 {
            earned.insert(.gentleTouch)
        }
        if report.strain == .rime {
            earned.insert(.coldBloodedRun)
        }
        if report.strain == .cinder {
            earned.insert(.desertBloom)
        }
        if report.scenario == .isolatedIsland {
            earned.insert(.islandStart)
        }
        if report.scenario == .transitHub {
            earned.insert(.hubStart)
        }
        if report.traitsUnlocked.count >= TraitCatalog.all.count {
            earned.insert(.fullTree)
        }
        if report.pointsSpent <= 60 {
            earned.insert(.thrifty)
        }
        if report.difficulty == .lethal {
            earned.insert(.lethalTier)
        }
        if report.dailyChallengeID != nil, report.objectiveMet == true {
            earned.insert(.perfectDaily)
        }
        return earned
    }

    /// Cumulative achievements that depend on the whole history.
    public static func cumulative(dailyChallengesWon: Int) -> Set<Achievement> {
        dailyChallengesWon >= 5 ? [.dailyRegular] : []
    }
}
