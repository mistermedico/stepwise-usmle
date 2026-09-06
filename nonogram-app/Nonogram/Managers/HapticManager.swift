import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Wraps `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator` for the small set of
/// haptic cues the game uses. All calls are no-ops on platforms without UIKit haptics.
final class HapticManager {
    static let shared = HapticManager()

    private let defaults: UserDefaults
    private let hapticsEnabledKey = "com.nonogram.settings.hapticsEnabled"

    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persisted haptics on/off toggle, exposed for `SettingsView`. Defaults to enabled.
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: hapticsEnabledKey) }
    }

    /// Light tap feedback for a normal cell tap/drag-fill.
    func cellTap() {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        lightImpact.prepare()
        lightImpact.impactOccurred()
        #endif
    }

    /// Success feedback for completing a row/column/whole puzzle.
    func success() {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        notification.notificationOccurred(.success)
        #endif
    }

    /// Error feedback for filling a cell that isn't part of the solution.
    func error() {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        notification.notificationOccurred(.error)
        #endif
    }
}
