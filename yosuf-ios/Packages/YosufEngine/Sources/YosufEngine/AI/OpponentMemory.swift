import Foundation

/// Per-match, per-bot memory the caller (view model) threads through turns.
/// Kept outside `OpponentEngine`'s pure functions so those stay stateless
/// and trivially testable; this struct is the only mutable piece.
public struct OpponentMemory: Sendable {
    public var consecutiveEligibleTurns: [PlayerID: Int]

    public init() {
        consecutiveEligibleTurns = [:]
    }
}
