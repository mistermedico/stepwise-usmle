import Foundation

/// Launch-argument switches, read once at start-up.
///
/// Only the UI tests pass these. They exist so a test can start from a known
/// state without the app growing a debug menu or a build configuration that
/// differs from the one that ships.
enum LaunchOptions {

    private static let arguments = Set(CommandLine.arguments)

    /// Clear stored reports, achievements and preferences before the first frame.
    static var shouldResetState: Bool {
        arguments.contains(A11y.LaunchArgument.resetState)
    }

    /// Skip the consent and tracking prompts. They are system alerts, and a
    /// test cannot dismiss them reliably on every OS version.
    static var shouldSkipConsent: Bool {
        arguments.contains(A11y.LaunchArgument.skipConsent)
    }

    /// Multiplier on the real-time gap between simulated days. Only the timer
    /// changes; the simulation is untouched.
    static var dayIntervalScale: Double {
        arguments.contains(A11y.LaunchArgument.fastClock) ? 0.05 : 1
    }

    /// True when the app is being driven by the UI test bundle at all.
    static var isUITest: Bool {
        shouldResetState || shouldSkipConsent
            || arguments.contains(A11y.LaunchArgument.fastClock)
    }
}
