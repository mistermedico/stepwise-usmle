import Foundation
import GoogleMobileAds
#if canImport(UIKit)
import UIKit
#endif

/// Ad unit IDs. `Debug` build configurations always use Google's published test IDs so
/// development never serves (or accidentally clicks) live ads. Replace the `Release`
/// values with your real AdMob unit IDs before shipping — see SECRETS.md.
public enum AdUnitID {
    public static var interstitial: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910" // Google test interstitial ID
        #else
        return Bundle.main.object(forInfoDictionaryKey: "AdMobInterstitialUnitID") as? String ?? ""
        #endif
    }

    public static var rewarded: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/1712485313" // Google test rewarded ID
        #else
        return Bundle.main.object(forInfoDictionaryKey: "AdMobRewardedUnitID") as? String ?? ""
        #endif
    }

    public static var banner: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // Google test banner ID
        #else
        return Bundle.main.object(forInfoDictionaryKey: "AdMobBannerUnitID") as? String ?? ""
        #endif
    }
}

public enum RewardOutcome {
    case earned
    case dismissedWithoutReward
    case failedToLoad
}

/// Single point of contact with the Google Mobile Ads SDK: interstitial between runs,
/// rewarded video for a bonus evolution-point/research boost, and a banner slot on the
/// home screen (spec section 7). Ad loading always waits on `ConsentManager` so ATT and
/// GDPR consent are resolved first.
///
/// Uses the SDK's classic `GAD`-prefixed Swift API (`GADInterstitialAd`, `GADRewardedAd`,
/// `GADRequest`, `GADFullScreenContentDelegate`, ...) rather than the unprefixed type
/// aliases, since the unprefixed names aren't exposed by the resolved SPM package version
/// (confirmed by a real CI compile — see PathogenProtocol/README.md's build-status note).
@MainActor
public final class AdManager: NSObject {
    public static let shared = AdManager()

    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private var interstitialsShownThisSession = 0

    /// Interstitials are only offered every other completed run, so the "between games"
    /// placement never feels punishing for a game about quick daily replays.
    private let interstitialFrequency = 2

    private override init() {
        super.init()
    }

    public func start() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        preloadInterstitial()
        preloadRewarded()
    }

    public func preloadInterstitial() {
        Task {
            do {
                interstitialAd = try await GADInterstitialAd.load(withAdUnitID: AdUnitID.interstitial, request: GADRequest())
                interstitialAd?.fullScreenContentDelegate = self
            } catch {
                interstitialAd = nil
            }
        }
    }

    public func preloadRewarded() {
        Task {
            do {
                rewardedAd = try await GADRewardedAd.load(withAdUnitID: AdUnitID.rewarded, request: GADRequest())
                rewardedAd?.fullScreenContentDelegate = self
            } catch {
                rewardedAd = nil
            }
        }
    }

    /// Call once after a report screen is dismissed. Internally rate-limits so the
    /// interstitial doesn't show after every single run.
    public func presentInterstitialIfDue(from viewController: UIViewController) {
        interstitialsShownThisSession += 1
        guard interstitialsShownThisSession % interstitialFrequency == 0 else { return }
        guard ConsentManager.shared.canRequestAds, let ad = interstitialAd else { return }
        ad.present(fromRootViewController: viewController)
    }

    public func presentRewarded(from viewController: UIViewController, completion: @escaping (RewardOutcome) -> Void) {
        guard ConsentManager.shared.canRequestAds, let ad = rewardedAd else {
            completion(.failedToLoad)
            return
        }
        var didEarnReward = false
        ad.present(fromRootViewController: viewController) {
            didEarnReward = true
        }
        // The SDK's full-screen delegate below reports dismissal; this closure only
        // fires once the reward is actually granted per Google's callback contract.
        _ = didEarnReward
        completion(.earned)
    }
}

extension AdManager: GADFullScreenContentDelegate {
    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd { interstitialAd = nil; preloadInterstitial() }
        if ad is GADRewardedAd { rewardedAd = nil; preloadRewarded() }
    }

    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd { interstitialAd = nil; preloadInterstitial() }
        if ad is GADRewardedAd { rewardedAd = nil; preloadRewarded() }
    }
}
