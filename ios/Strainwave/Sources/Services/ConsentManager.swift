import Foundation
import UIKit
import AppTrackingTransparency
import AdSupport

/// App Tracking Transparency and the EU consent flow (section 7).
///
/// Order matters and is fixed by policy: the privacy-message form is resolved
/// first, then the system tracking prompt, and only then may an ad be requested.
@MainActor
final class ConsentManager: ObservableObject {

    /// `true` once the consent form has been resolved one way or the other.
    @Published private(set) var hasResolvedConsent = false
    /// `true` when ad requests are permitted. Non-personalised ads still count.
    @Published private(set) var canRequestAds = false
    @Published private(set) var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined

    /// Runs the whole flow. Safe to call more than once.
    func resolve() async {
        await resolvePrivacyForm()
        await requestTrackingAuthorisationIfNeeded()
        AppLogger.consent.info(
            "Consent resolved. Ads allowed: \(self.canRequestAds), tracking: \(self.trackingStatus.rawValue)"
        )
    }

    /// Re-opens the privacy options form, for the Settings screen. Available
    /// only where the messaging SDK is linked and the region requires it.
    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        await withCheckedContinuation { continuation in
            guard let presenter = UIApplication.shared.topViewController() else {
                continuation.resume()
                return
            }
            UMPConsentForm.presentPrivacyOptionsForm(from: presenter) { error in
                if let error {
                    AppLogger.consent.error("Privacy options failed: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
        #else
        AppLogger.consent.info("Messaging SDK not linked; nothing to present")
        #endif
    }

    // MARK: Steps

    private func resolvePrivacyForm() async {
        #if canImport(UserMessagingPlatform)
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false

        await withCheckedContinuation { continuation in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    AppLogger.consent.error("Consent update failed: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                guard let presenter = UIApplication.shared.topViewController() else {
                    continuation.resume()
                    return
                }
                UMPConsentForm.loadAndPresentIfRequired(from: presenter) { formError in
                    if let formError {
                        AppLogger.consent.error("Consent form failed: \(formError.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        canRequestAds = UMPConsentInformation.sharedInstance.canRequestAds
        #else
        // Without the messaging SDK there is no form to show. Requests are
        // allowed and remain non-personalised.
        canRequestAds = true
        #endif
        hasResolvedConsent = true
    }

    private func requestTrackingAuthorisationIfNeeded() async {
        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else {
            trackingStatus = current
            return
        }
        trackingStatus = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
