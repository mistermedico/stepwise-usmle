import SwiftUI

/// The one screen-transition treatment used everywhere in the app (fade + a small
/// upward slide), so navigation feels like a single polished product rather than a
/// pile of default push/pop animations (spec section 4, closing note).
public extension AnyTransition {
    static var appScreen: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.98)),
            removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.98))
        )
    }
}

public extension View {
    /// Apply to any top-level screen container. Pair with `withAnimation(.appScreenChange)`
    /// around the state change that swaps screens, so insertion/removal actually animate.
    func appScreenTransition() -> some View {
        transition(.appScreen)
    }
}

public extension Animation {
    static var appScreenChange: Animation { .easeInOut(duration: 0.35) }
}
