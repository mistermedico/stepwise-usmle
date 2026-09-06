import Foundation

/// The four standard playing card suits.
public enum Suit: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case hearts
    case diamonds
    case clubs
    case spades

    public var id: String { rawValue }

    /// True for hearts/diamonds — used purely for card-face rendering.
    public var isRed: Bool {
        self == .hearts || self == .diamonds
    }

    public var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }
}
