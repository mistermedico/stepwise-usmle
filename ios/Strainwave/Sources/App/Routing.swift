import SwiftUI
import OutbreakEngine

/// A `GameSetup` wrapped so it can drive a SwiftUI `fullScreenCover`/route.
struct GameSetupBox: Identifiable, Equatable {
    let id = UUID()
    let value: GameSetup
}

/// The three top-level destinations. Kept as a plain enum so the root can render
/// them in one `ZStack` and apply a single shared transition (section 4: the
/// whole app moves the same way).
enum Route: Equatable {
    case home
    case game(GameSetupBox)
    case report(EpidemicReport, [Achievement])

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.game(let a), .game(let b)):
            return a == b
        case (.report(let a, _), .report(let b, _)):
            return a.id == b.id
        default:
            return false
        }
    }
}

extension AnyTransition {
    /// The one screen transition used everywhere: a cross-fade with a small
    /// vertical drift, so the app always feels like a single surface.
    static var screen: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 16)),
            removal: .opacity.combined(with: .offset(y: -10))
        )
    }
}
