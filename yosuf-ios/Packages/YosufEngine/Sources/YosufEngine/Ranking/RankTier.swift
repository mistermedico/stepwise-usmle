import Foundation

/// Named skill tiers, evenly spaced above a 1000-point starting rating.
public enum RankTier: String, CaseIterable, Codable, Sendable, Comparable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case champion

    private static let thresholds: [(RankTier, Int)] = [
        (.bronze, 0), (.silver, 1000), (.gold, 1200),
        (.platinum, 1450), (.diamond, 1750), (.champion, 2100)
    ]

    public static func forRating(_ rating: Int) -> RankTier {
        thresholds.last { rating >= $0.1 }?.0 ?? .bronze
    }

    /// Points needed to reach the next tier, or nil if already at the top.
    public func pointsToNext(from rating: Int) -> Int? {
        guard let currentIndex = Self.thresholds.firstIndex(where: { $0.0 == self }) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < Self.thresholds.count else { return nil }
        return max(0, Self.thresholds[nextIndex].1 - rating)
    }

    public var displayNameKey: String { "rank.\(rawValue).name" }

    private var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    public static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.order < rhs.order
    }
}
