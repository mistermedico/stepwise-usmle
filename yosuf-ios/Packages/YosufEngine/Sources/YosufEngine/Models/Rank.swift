import Foundation

/// Standard card ranks, ordered ace-low for run detection.
public enum Rank: Int, CaseIterable, Codable, Sendable, Comparable, Hashable {
    case ace = 1
    case two, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Point value used for hand-total scoring. Face cards are worth 10,
    /// ace is worth 1, numeric cards are worth their face value.
    public func pointValue(aceHigh: Bool) -> Int {
        switch self {
        case .ace: return aceHigh ? 15 : 1
        case .jack, .queen, .king: return 10
        default: return rawValue
        }
    }

    public var isFace: Bool {
        self == .jack || self == .queen || self == .king
    }
}
