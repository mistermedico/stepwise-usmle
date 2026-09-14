import Foundation
import CoreGraphics

/// Fixed, hand-placed normalized (0...1) positions for the six abstract regions shared
/// by every `WorldScenario`. Deliberately not a real map projection — flat, puzzle-piece
/// shapes laid out for visual balance rather than geographic accuracy (spec section 4).
enum RegionLayout {
    static let positions: [RegionID: CGPoint] = [
        "outland": CGPoint(x: 0.16, y: 0.20),
        "gatecross": CGPoint(x: 0.38, y: 0.32),
        "meridianDelta": CGPoint(x: 0.55, y: 0.55),
        "harborReach": CGPoint(x: 0.78, y: 0.30),
        "duskvale": CGPoint(x: 0.42, y: 0.80),
        "cinderplex": CGPoint(x: 0.80, y: 0.72),
    ]

    static func position(for id: RegionID, in size: CGSize) -> CGPoint {
        let normalized = positions[id] ?? CGPoint(x: 0.5, y: 0.5)
        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}
