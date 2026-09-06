import Foundation

/// Rule-based (not ML) difficulty tiers. Each tier is a table of concrete
/// numeric thresholds consumed by `OpponentEngine` — never a black box.
public enum OpponentDifficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case beginner
    case intermediate
    case advanced
    case expert

    /// Hand value at/below which the bot will declare Yosuf, before
    /// personality risk adjustment is applied.
    public var baseYosufThreshold: Int {
        switch self {
        case .beginner: return 5      // only calls on very safe hands
        case .intermediate: return 6
        case .advanced: return 7      // calls right at the legal threshold
        case .expert: return 7
        }
    }

    /// Whether the bot keeps a running count of which ranks/suits have
    /// been discarded, to estimate the odds an Asaf challenge would succeed.
    public var usesCardCounting: Bool {
        self == .expert
    }

    /// Whether the bot looks one meld ahead (deciding to hold a card that
    /// doesn't reduce this turn's discard but sets up a bigger meld later).
    public var planksAheadForMelds: Bool {
        self == .advanced || self == .expert
    }

    /// Extra turns of hesitation before calling Yosuf even when eligible,
    /// simulating caution. 0 for bots that call the instant they can.
    public var cautionDelayTurns: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 1
        case .expert: return 0 // expert is precise, not timid
        }
    }
}
