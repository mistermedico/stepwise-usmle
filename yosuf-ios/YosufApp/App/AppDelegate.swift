import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import os

/// Handles the one-time, UIKit-only startup sequence SwiftUI's `App`
/// protocol doesn't cover directly: AdMob SDK boot, and GDPR (UMP) consent
/// gathering before any ad request is made. ATT itself is requested lazily
/// from `HomeView.onAppear`, since Apple recommends prompting once the
/// user is actually looking at content, not at cold launch.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.yosuf.game", category: "app-lifecycle")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        requestConsentThenStartAds()
        return true
    }

    private func requestConsentThenStartAds() {
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false

        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard let self else { return }
            if let error {
                self.logger.error("UMP consent info update failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in AdManager.shared.start() }
                return
            }

            let formStatus = UMPConsentInformation.sharedInstance.formStatus
            guard formStatus == .available else {
                Task { @MainActor in AdManager.shared.start() }
                return
            }

            UMPConsentForm.load { form, loadError in
                guard let form, loadError == nil else {
                    Task { @MainActor in AdManager.shared.start() }
                    return
                }
                if UMPConsentInformation.sharedInstance.consentStatus == .required {
                    DispatchQueue.main.async {
                        guard let root = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first?.windows.first(where: \.isKeyWindow)?.rootViewController else {
                            Task { @MainActor in AdManager.shared.start() }
                            return
                        }
                        form.present(from: root) { _ in
                            Task { @MainActor in AdManager.shared.start() }
                        }
                    }
                } else {
                    Task { @MainActor in AdManager.shared.start() }
                }
            }
        }
    }
}
