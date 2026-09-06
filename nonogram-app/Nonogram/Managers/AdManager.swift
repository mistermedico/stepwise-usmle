import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// What a rewarded ad unlocks for the player.
enum RewardKind: Equatable {
    case extraLife
    case extraBooster(BoosterType)
    case doubleDailyReward
}

/// Ad surface the rest of the app talks to. Kept as a protocol so views/view models never
/// import GoogleMobileAds directly and the app builds fine whether or not that SPM package
/// has been added yet (see the two conformances below).
protocol AdManaging: AnyObject {
    /// Requests the ATT authorization (iOS 14.5+) if it hasn't been decided yet. Call once,
    /// early, after the player has seen some of the app (not on cold launch) per Apple guidance.
    func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void)

    func loadInterstitial()
    /// Shows a preloaded interstitial if the internal cadence says it's time and one is ready.
    /// `completion` fires once the ad is dismissed (or immediately with `false` if none was shown).
    func showInterstitialIfReady(completion: @escaping (_ shown: Bool) -> Void)

    /// Called once per level completion so the manager can track "every 3rd level" cadence
    /// internally; use this instead of calling `showInterstitialIfReady` directly from views.
    func registerLevelCompletion(completion: @escaping (_ shown: Bool) -> Void)

    func loadRewarded(for kind: RewardKind)
    /// Shows a rewarded ad if ready. `completion(true)` means the reward should be granted.
    func showRewarded(for kind: RewardKind, completion: @escaping (Bool) -> Void)
}

// MARK: - GDPR / UMP consent integration point
//
// Before requesting ATT or loading any ad (interstitial or rewarded) for a user in a region
// covered by GDPR/UK/US state privacy laws, Google's User Messaging Platform (UMP) SDK should
// run first to collect/refresh consent (`UMPConsentInformation.sharedInstance.requestConsentInfoUpdate`
// then present the consent form if `UMPConsentInformation.sharedInstance.formStatus == .available`).
// That flow is out of scope here — this manager assumes consent has already been resolved by
// the time it's asked to load an ad. TODO: add the UMP SDK (bundled with GoogleMobileAds) and
// run its consent flow at app launch, gating `loadInterstitial()`/`loadRewarded(for:)` on it,
// right before the ATT prompt below (ATT should follow, not precede, UMP consent).

#if canImport(GoogleMobileAds)

/// Real GoogleMobileAds-backed implementation. Uses Google's published TEST ad unit IDs so the
/// app never serves live ads during development.
final class GoogleAdManager: NSObject, AdManaging {
    // TODO: replace with production ad unit ID before release.
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    // TODO: replace with production ad unit ID before release.
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var pendingRewardKind: RewardKind?
    private var pendingRewardCompletion: ((Bool) -> Void)?
    private var pendingInterstitialCompletion: ((Bool) -> Void)?

    /// Show an interstitial after every 3rd level completion.
    private let interstitialCadence = 3
    private var levelsCompletedSinceLastInterstitial = 0

    override init() {
        super.init()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void) {
        #if canImport(AppTrackingTransparency)
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
        #else
        completion()
        #endif
    }

    func loadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("AdManager: interstitial failed to load: \(error.localizedDescription)")
                return
            }
            self.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    func registerLevelCompletion(completion: @escaping (Bool) -> Void) {
        levelsCompletedSinceLastInterstitial += 1
        guard levelsCompletedSinceLastInterstitial >= interstitialCadence else {
            completion(false)
            return
        }
        levelsCompletedSinceLastInterstitial = 0
        showInterstitialIfReady(completion: completion)
    }

    func showInterstitialIfReady(completion: @escaping (Bool) -> Void) {
        guard let interstitial,
              let root = Self.topViewController() else {
            completion(false)
            return
        }
        pendingInterstitialCompletion = completion
        interstitial.present(fromRootViewController: root)
    }

    func loadRewarded(for kind: RewardKind) {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("AdManager: rewarded ad failed to load: \(error.localizedDescription)")
                return
            }
            self.rewarded = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    func showRewarded(for kind: RewardKind, completion: @escaping (Bool) -> Void) {
        guard let rewarded, let root = Self.topViewController() else {
            completion(false)
            return
        }
        pendingRewardKind = kind
        pendingRewardCompletion = completion
        rewarded.present(fromRootViewController: root) { [weak self] in
            // Reward earned — actual granting happens in `pendingRewardCompletion`, called
            // again from `adDidDismissFullScreenContent` with `true` once dismissed, matching
            // the "watch to completion" contract callers expect.
            self?.rewardEarned = true
        }
    }

    private var rewardEarned = false

    private static func topViewController() -> UIViewControllerType? {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        #else
        nil
        #endif
    }
}

#if canImport(UIKit)
import UIKit
private typealias UIViewControllerType = UIViewController
#endif

extension GoogleAdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            interstitial = nil
            loadInterstitial() // preload the next one
            pendingInterstitialCompletion?(true)
            pendingInterstitialCompletion = nil
        } else {
            rewarded = nil
            pendingRewardCompletion?(rewardEarned)
            pendingRewardCompletion = nil
            pendingRewardKind = nil
            rewardEarned = false
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd {
            interstitial = nil
            pendingInterstitialCompletion?(false)
            pendingInterstitialCompletion = nil
        } else {
            rewarded = nil
            pendingRewardCompletion?(false)
            pendingRewardCompletion = nil
        }
    }
}

#else

/// No-op stand-in used until the GoogleMobileAds SPM package is added to the project. Every
/// call reports "not available" so the rest of the app can be written and built against
/// `AdManaging` immediately, with real ads slotting in later with zero call-site changes.
final class NoOpAdManager: AdManaging {
    /// Show an interstitial after every 3rd level completion (mirrors `GoogleAdManager`'s cadence
    /// so switching implementations doesn't change game feel).
    private let interstitialCadence = 3
    private var levelsCompletedSinceLastInterstitial = 0

    func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void) {
        completion()
    }

    func loadInterstitial() {
        // no-op: nothing to preload without the ads SDK
    }

    func registerLevelCompletion(completion: @escaping (Bool) -> Void) {
        levelsCompletedSinceLastInterstitial += 1
        if levelsCompletedSinceLastInterstitial >= interstitialCadence {
            levelsCompletedSinceLastInterstitial = 0
        }
        completion(false)
    }

    func showInterstitialIfReady(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func loadRewarded(for kind: RewardKind) {
        // no-op
    }

    func showRewarded(for kind: RewardKind, completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}

#endif

/// Convenience factory so call sites (e.g. `AppViewModel`) never branch on `#if canImport`.
enum AdManagerFactory {
    static func make() -> AdManaging {
        #if canImport(GoogleMobileAds)
        return GoogleAdManager()
        #else
        return NoOpAdManager()
        #endif
    }
}
