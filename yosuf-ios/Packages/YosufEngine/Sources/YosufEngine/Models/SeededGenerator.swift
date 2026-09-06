import Foundation

/// Deterministic RandomNumberGenerator (SplitMix64) so a shuffle can be
/// reproduced exactly from a seed — used for the Daily Challenge, where
/// every player must see the identical deck and opponent lineup.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // Avoid the degenerate all-zero state.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Deterministic seed derived from a calendar day, so all players get
    /// the same Daily Challenge deck on the same date.
    public static func dailySeed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(components.year ?? 2024)
        let m = UInt64(components.month ?? 1)
        let d = UInt64(components.day ?? 1)
        return (y &* 10000 &+ m &* 100 &+ d) &* 0x2545F4914F6CDD1D
    }
}
