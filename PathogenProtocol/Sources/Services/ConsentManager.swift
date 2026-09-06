import Foundation
import AppTrackingTransparency
import UserMessagingPlatform

/// Resolves both required gates before any ad request goes out: Apple's App Tracking
/// Transparency prompt, and Google's User Messaging Platform consent form for
/// GDPR/UK/US state-privacy regions (spec section 7).
@MainActor
public final class ConsentManager {
    public static let shared = ConsentManager()

    private init() {}

    /// True once UMP reports it's safe to request ads (either consent was obtained,
    /// or the user is outside a region that requires it).
    public var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    /// Call once at launch, before `AdManager.start()`. Requests the UMP consent form
    /// when required, then requests the ATT prompt on iOS 14.5+, then starts ads.
    public func requestConsentAndStartAds(completion: @escaping () -> Void) {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard error == nil else {
                completion()
                return
            }
            ConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                self?.requestTrackingAuthorization {
                    AdManager.shared.start()
                    completion()
                }
            }
        }
    }

    private func requestTrackingAuthorization(completion: @escaping () -> Void) {
        if #available(iOS 14.5, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { completion() }
            }
        } else {
            completion()
        }
    }
}
