import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over `UIFeedbackGenerator` so the rest of the app never touches UIKit
/// haptics directly — keeps the feature testable/mockable and gives one place to
/// tune feel (spec section 5).
public final class HapticManager {
    public static let shared = HapticManager()

    private init() {}

    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    /// The slow, gentle "the outbreak is alive" pulse used while a run is in progress.
    public func ambientPulse() {
        #if canImport(UIKit)
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.35)
        #endif
    }

    public func upgradeUnlocked() {
        #if canImport(UIKit)
        mediumImpact.prepare()
        mediumImpact.impactOccurred(intensity: 0.8)
        #endif
    }

    public func awarenessSpike() {
        #if canImport(UIKit)
        notification.prepare()
        notification.notificationOccurred(.warning)
        #endif
    }

    public func victory() {
        #if canImport(UIKit)
        notification.prepare()
        notification.notificationOccurred(.success)
        #endif
    }

    public func defeat() {
        #if canImport(UIKit)
        notification.prepare()
        notification.notificationOccurred(.error)
        #endif
    }
}
