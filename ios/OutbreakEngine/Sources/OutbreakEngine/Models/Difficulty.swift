import Foundation

/// The three named challenge tiers.
///
/// Every tuning value the global-response engine reads lives here, so a rule can
/// be re-verified at each tier by swapping a single value in a test.
public enum Difficulty: String, CaseIterable, Codable, Hashable, Sendable {
    case breezy   // "קליל"
    case tense    // "מאתגר"
    case lethal   // "קטלני"

    public var titleKey: String { "difficulty.\(rawValue).title" }
    public var detailKey: String { "difficulty.\(rawValue).detail" }

    /// Scales every in-territory growth coefficient.
    public var spreadMultiplier: Double {
        switch self {
        case .breezy: return 1.20
        case .tense: return 1.00
        case .lethal: return 0.85
        }
    }

    /// Scales the awareness rule (rule 2).
    public var awarenessMultiplier: Double {
        switch self {
        case .breezy: return 0.70
        case .tense: return 1.00
        case .lethal: return 1.45
        }
    }

    /// Global awareness at which laboratories begin accruing research (rule 3).
    public var researchThreshold: Double {
        switch self {
        case .breezy: return 18
        case .tense: return 12
        case .lethal: return 6
        }
    }

    /// Research points added per day once the threshold is crossed (rule 3).
    /// A solution completes at 100 points, so this is also the fastest possible
    /// countdown the player can face.
    public var researchRatePerDay: Double {
        switch self {
        case .breezy: return 0.55
        case .tense: return 0.85
        case .lethal: return 1.30
        }
    }

    /// Regional awareness at which transport is suspended (rule 4).
    public var lockdownThreshold: Double {
        switch self {
        case .breezy: return 55
        case .tense: return 42
        case .lethal: return 30
        }
    }

    /// Regional awareness at which land borders close as well (rule 4).
    public var borderClosureThreshold: Double { lockdownThreshold + 18 }

    /// Awareness must fall this far below the threshold before a suspension lifts.
    public var lockdownReleaseMargin: Double { 12 }

    /// Baseline evolution points granted each day (rule 6).
    public var basePointsPerDay: Double {
        switch self {
        case .breezy: return 0.85
        case .tense: return 0.60
        case .lethal: return 0.45
        }
    }

    /// Extra points per territory currently carrying the strain.
    public var pointsPerInfectedRegion: Double {
        switch self {
        case .breezy: return 0.30
        case .tense: return 0.22
        case .lethal: return 0.16
        }
    }

    /// Evolution points the run opens with.
    public var startingPoints: Int {
        switch self {
        case .breezy: return 12
        case .tense: return 8
        case .lethal: return 5
        }
    }
}
