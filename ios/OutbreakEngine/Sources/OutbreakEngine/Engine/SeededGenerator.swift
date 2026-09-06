import Foundation

/// Deterministic pseudo-random generator (SplitMix64).
///
/// Every random decision in the simulation flows through this type so that a
/// run is fully reproducible from `(seed, player inputs)`. That property is what
/// makes the daily challenge identical for every player and what lets the unit
/// tests assert exact board states.
public struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {

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

    /// Uniform value in `0..<1`.
    public mutating func unit() -> Double {
        // 53 significant bits keeps the result exactly representable in Double.
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// Returns `true` with the given probability. Probabilities outside `0...1`
    /// are clamped rather than trapping, because rule coefficients are tuned data.
    public mutating func chance(_ probability: Double) -> Bool {
        guard probability > 0 else { return false }
        guard probability < 1 else { return true }
        return unit() < probability
    }

    /// Uniform integer in `range`. Returns `range.lowerBound` for empty ranges.
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// Picks an element deterministically; `nil` only for an empty collection.
    public mutating func pick<T>(_ elements: [T]) -> T? {
        guard !elements.isEmpty else { return nil }
        return elements[int(in: 0...(elements.count - 1))]
    }
}

public extension SeededGenerator {
    /// Stable seed derived from an arbitrary string (FNV-1a 64).
    ///
    /// `String.hashValue` is intentionally *not* used: it is salted per process
    /// and would give every device a different "daily" challenge.
    static func seed(from text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in Array(text.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }
}
