import Foundation
import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport
import os

/// Central AdMob integration point. Every ad surface (interstitial between
/// matches, rewarded, optional home banner) goes through this type so ad
/// logic never leaks into views/view models, and so a future IAP
/// "remove ads" purchase only has to flip `adsRemoved` in one place.
@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    private let logger = Logger(subsystem: "com.yosuf.game", category: "ads")

    /// TEST IDs from Google's official documentation — safe to ship in
    /// debug builds, MUST be swapped for the real AdMob unit IDs created in
    /// App Store Connect / AdMob console before release (see APPLE_SETUP.md).
    private enum AdUnitID {
        static let interstitial = "ca-app-pub-3940256099942544/4411468910" // TEST
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"     // TEST
        static let banner = "ca-app-pub-3940256099942544/2934735716"       // TEST
    }

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady = false
    /// Flip to true once a future "remove ads" IAP is purchased; every ad
    /// call below becomes a no-op immediately.
    @Published var adsRemoved = false

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var matchesPlayedSinceLastInterstitial = 0
    private let interstitialFrequency = 2 // show at most once every N completed matches

    override private init() {
        super.init()
    }

    /// Call once from the app delegate after ATT + UMP consent are resolved.
    func start() {
        GADMobileAds.sharedInstance().start { [weak self] status in
            self?.logger.info("AdMob SDK initialized: \(String(describing: status.adapterStatusesByClassName))")
            self?.loadInterstitial()
            self?.loadRewarded()
        }
    }

    /// Requests App Tracking Transparency permission (required before any
    /// personalized ad request on iOS 14.5+). GDPR/UMP consent is expected
    /// to already have been resolved via the Google UMP SDK before this runs.
    func requestTrackingAuthorizationIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // MARK: - Interstitial (shown between matches)

    private func loadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdUnitID.interstitial, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                self.logger.error("Interstitial failed to load: \(error.localizedDescription, privacy: .public)")
                self.isInterstitialReady = false
                return
            }
            self.interstitial = ad
            self.interstitial?.fullScreenContentDelegate = self
            self.isInterstitialReady = true
        }
    }

    /// Call after a match ends. Rate-limited so ads don't show after every
    /// single match — only every `interstitialFrequency` matches.
    func presentInterstitialIfDue(from viewController: UIViewController) {
        guard !adsRemoved else { return }
        matchesPlayedSinceLastInterstitial += 1
        guard matchesPlayedSinceLastInterstitial >= interstitialFrequency else { return }
        guard let interstitial else { return }
        interstitial.present(fromRootViewController: viewController)
        matchesPlayedSinceLastInterstitial = 0
    }

    // MARK: - Rewarded (optional bonus, e.g. an extra hint or cosmetic)

    private func loadRewarded() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdUnitID.rewarded, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                self.logger.error("Rewarded ad failed to load: \(error.localizedDescription, privacy: .public)")
                self.isRewardedReady = false
                return
            }
            self.rewarded = ad
            self.rewarded?.fullScreenContentDelegate = self
            self.isRewardedReady = true
        }
    }

    func presentRewarded(from viewController: UIViewController, onReward: @escaping () -> Void) {
        guard !adsRemoved, let rewarded else { return }
        rewarded.present(fromRootViewController: viewController) {
            onReward()
        }
    }

    // MARK: - Banner ad unit ID (the `GADBannerView` itself lives in SwiftUI
    // via a small `UIViewRepresentable` wrapper in the Home screen file, so
    // this manager only hands out the configured unit ID).

    var bannerAdUnitID: String { AdUnitID.banner }
}

extension AdManager: GADFullScreenContentDelegate {
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {}

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logger.error("Ad failed to present: \(error.localizedDescription, privacy: .public)")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad === interstitial { loadInterstitial() }
        if ad === (rewarded as GADFullScreenPresentingAd?) { loadRewarded() }
    }
}
