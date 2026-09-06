import Foundation

/// Stable identifiers for the controls the UI tests drive.
///
/// This file is compiled into **both** the app and the UI test bundle, so a
/// renamed control breaks the build rather than silently breaking a test that
/// then hangs waiting for an element that no longer exists.
///
/// Identifiers are for automation only — they are never shown to anyone. The
/// human-facing text still comes from `Localizable.strings`, which is what
/// lets the same test drive the English and Hebrew builds unchanged.
///
/// Every identifier here names a **leaf control**. Putting one on a container
/// is a trap: SwiftUI pushes it down onto the descendants, so a screen-level
/// identifier silently replaces the identifier on every button inside it, and
/// the tests then look for controls that all answer to the same name.
enum A11y {

    enum Home {
        static let start = "home.start"
        static let dailyStart = "home.daily.start"
        static let reports = "home.reports"
        static let achievements = "home.achievements"
        static let settings = "home.settings"

        static func sample(_ rawValue: String) -> String { "home.sample.\(rawValue)" }
        static func difficulty(_ rawValue: String) -> String { "home.difficulty.\(rawValue)" }
        static func scenario(_ rawValue: String) -> String { "home.scenario.\(rawValue)" }
    }

    enum Game {
        static let day = "game.day"
        static let points = "game.points"
        static let abilities = "game.abilities"
        static let playPause = "game.playPause"
        static let speed = "game.speed"
        static let quit = "game.quit"
        static let quitConfirm = "game.quit.confirm"

        static func region(_ rawValue: String) -> String { "game.region.\(rawValue)" }
    }

    enum Tree {
        static let close = "tree.close"
        static let unlock = "tree.unlock"
        static let fold = "tree.fold"

        static func branch(_ rawValue: String) -> String { "tree.branch.\(rawValue)" }
        static func node(_ rawValue: String) -> String { "tree.node.\(rawValue)" }
    }

    enum Report {
        static let title = "report.title"
        static let again = "report.again"
        static let home = "report.home"
    }

    /// Launch arguments the UI tests use to put the app in a known state.
    enum LaunchArgument {
        /// Wipes stored reports and preferences before the first frame, so a
        /// test never inherits another test's history.
        static let resetState = "-uitest-reset-state"
        /// Skips the consent and tracking prompts, which are system alerts and
        /// cannot be driven reliably from a test.
        static let skipConsent = "-uitest-skip-consent"
        /// Shortens the real-time gap between simulated days. It changes only
        /// the timer, never the simulation, so a run plays out exactly as it
        /// would at normal speed — just sooner.
        static let fastClock = "-uitest-fast-clock"
    }
}
