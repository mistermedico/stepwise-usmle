import Foundation

/// Reference-type wrapper around a `RandomNumberGenerator` so it can be
/// threaded through the engine without generic `inout` gymnastics, and
/// swapped for a seeded generator in tests / the Daily Challenge.
public final class RNGBox: RandomNumberGenerator {
    private var boxed: any RandomNumberGenerator

    public init(seed: UInt64) {
        boxed = SeededGenerator(seed: seed)
    }

    public init() {
        boxed = SystemRandomNumberGenerator()
    }

    public func next() -> UInt64 {
        boxed.next()
    }
}
