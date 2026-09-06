import SwiftUI

/// Single source of truth for color, spacing, radius, and shadow tokens so
/// every screen (home, rule profile cards, achievements, settings...) is
/// visibly built from the same design language rather than styled ad hoc.
enum Theme {
    // MARK: Colors (all defined for both light and dark via Asset Catalog
    // color sets named identically below; these are the semantic accessors
    // the rest of the app should use instead of raw Color literals).

    // Each color set below carries its own light + dark appearance in the
    // asset catalog, so a single semantic name is enough everywhere.
    static let tableFelt = Color("TableFelt")
    static let woodRail = Color("WoodRail")
    static let cardFace = Color("CardFace")
    static let cardBack = Color("CardBack")
    static let accentGold = Color("AccentGold")
    static let dangerRed = Color("DangerRed")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let surfaceElevated = Color("SurfaceElevated")

    static let avatarPalette: [Color] = [
        Color("AvatarBlue"), Color("AvatarCoral"), Color("AvatarTeal"),
        Color("AvatarViolet"), Color("AvatarAmber"), Color("AvatarRose")
    ]

    // MARK: Geometry

    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24

    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: Double = 0.18
    static let shadowYOffset: CGFloat = 4

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: Motion

    /// The one consistent screen-transition animation used everywhere
    /// (per spec: a single transition style, not a different one per screen).
    static let screenTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .trailing)),
        removal: .opacity.combined(with: .move(edge: .leading))
    )
    static let screenAnimation: Animation = .easeInOut(duration: 0.32)

    static let cardDealAnimation: Animation = .interpolatingSpring(stiffness: 220, damping: 20)
    static let revealStageDelay: Double = 0.55
}

extension View {
    /// A standard "card-like" surface used for rule profile cards,
    /// achievement tiles, and settings rows — one shared visual identity.
    func themedSurface(cornerRadius: CGFloat = Theme.cornerRadiusMedium) -> some View {
        self
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(Theme.shadowOpacity), radius: Theme.shadowRadius, y: Theme.shadowYOffset)
    }

    /// Applies the app-wide single screen transition + animation.
    func withScreenTransition() -> some View {
        self.transition(Theme.screenTransition)
    }
}
