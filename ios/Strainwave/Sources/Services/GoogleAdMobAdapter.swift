#if canImport(GoogleMobileAds)
import Foundation
import UIKit
import GoogleMobileAds

/// The real AdMob adapter.
///
/// This file compiles only when the Google Mobile Ads package is linked, so the
/// project builds and every test runs with or without the SDK. Adding the
/// dependency (see `docs/RELEASE.md`) is all it takes to switch it on.
final class GoogleAdMobAdapter: NSObject, AdNetworkAdapter {

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var interstitialCompletion: (() -> Void)?
    private var rewardedCompletion: ((Bool) -> Void)?
    private var didEarnReward = false

    func start(completion: @escaping () -> Void) {
        GADMobileAds.sharedInstance().start { status in
            AppLogger.ads.info("Ad SDK ready: \(status.adapterStatusesByClassName.count) adapters")
            completion()
        }
    }

    func loadInterstitial(unitID: String, completion: @escaping (Bool) -> Void) {
        GADInterstitialAd.load(withAdUnitID: unitID, request: GADRequest()) { [weak self] ad, error in
            if let error {
                AppLogger.ads.error("Interstitial load failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            self?.interstitial = ad
            ad?.fullScreenContentDelegate = self
            completion(ad != nil)
        }
    }

    func loadRewarded(unitID: String, completion: @escaping (Bool) -> Void) {
        GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest()) { [weak self] ad, error in
            if let error {
                AppLogger.ads.error("Rewarded load failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            self?.rewarded = ad
            ad?.fullScreenContentDelegate = self
            completion(ad != nil)
        }
    }

    func presentInterstitial(from presenter: UIViewController, completion: @escaping () -> Void) {
        guard let interstitial else {
            completion()
            return
        }
        interstitialCompletion = completion
        interstitial.present(fromRootViewController: presenter)
    }

    func presentRewarded(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewarded else {
            completion(false)
            return
        }
        rewardedCompletion = completion
        didEarnReward = false
        rewarded.present(fromRootViewController: presenter) { [weak self] in
            self?.didEarnReward = true
        }
    }
}

extension GoogleAdMobAdapter: GADFullScreenContentDelegate {

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        finish(granted: didEarnReward)
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AppLogger.ads.error("Presentation failed: \(error.localizedDescription)")
        finish(granted: false)
    }

    /// Always drains both completions so the game never waits on an ad callback
    /// that will not arrive.
    private func finish(granted: Bool) {
        interstitial = nil
        rewarded = nil

        let interstitialDone = interstitialCompletion
        let rewardedDone = rewardedCompletion
        interstitialCompletion = nil
        rewardedCompletion = nil

        interstitialDone?()
        rewardedDone?(granted)
    }
}
#endif
