import Foundation

/// A personality layers a risk-tolerance table on top of a difficulty tier —
/// same decision engine, different config, per spec.
public enum OpponentPersonality: String, CaseIterable, Codable, Sendable, Hashable {
    case cautious
    case balanced
    case aggressive

    /// Added to the difficulty's base Yosuf threshold (can be negative).
    /// A cautious bot waits for a safer margin; an aggressive one calls earlier.
    public var thresholdAdjustment: Int {
        switch self {
        case .cautious: return -1
        case .balanced: return 0
        case .aggressive: return 1
        }
    }

    /// Probability (0...1) the bot draws from the discard pile instead of
    /// the closed deck when the discard's top card would help it, even if
    /// a set-based play from the deck might be marginally safer.
    public var discardPileGreed: Double {
        switch self {
        case .cautious: return 0.35
        case .balanced: return 0.55
        case .aggressive: return 0.75
        }
    }

    /// Probability the bot keeps a card that doesn't help this turn's
    /// discard because it might complete a meld in 1-2 more turns.
    public var meldPatience: Double {
        switch self {
        case .cautious: return 0.6
        case .balanced: return 0.4
        case .aggressive: return 0.2
        }
    }
}
