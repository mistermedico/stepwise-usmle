import Foundation
import SwiftUI
import UIKit

/// Ad placements the game uses (section 7).
enum AdPlacement {
    /// Between runs, frequency-capped.
    case interstitial
    /// Opt-in only: evolution points, or a research setback.
    case rewarded
    /// Optional strip at the bottom of the home screen.
    case banner
}

/// What a rewarded view can pay out.
enum AdReward: Equatable {
    case evolutionPoints(Int)
    case researchSetback
    case strainUnlock(String)
}

/// The surface every view uses. Keeping this behind a protocol means the game
/// screens never import an SDK, and previews/tests get a silent implementation.
///
/// Main-actor isolated: every placement reads consent state and presents a view
/// controller, both of which belong on the main thread anyway.
@MainActor
protocol AdServing: AnyObject {
    var isInterstitialReady: Bool { get }
    var isRewardedReady: Bool { get }
    var isBannerEnabled: Bool { get }

    func configure()
    func preload()
    /// Shows an interstitial if one is ready and the frequency cap allows it.
    /// The completion always runs, shown or not, so game flow never stalls.
    func presentInterstitial(completion: @escaping () -> Void)
    /// Shows a rewarded view. `granted` is `false` when the player dismissed it
    /// early or nothing was available.
    func presentRewarded(completion: @escaping (_ granted: Bool) -> Void)
}

/// Ad unit identifiers.
///
/// These are Google's public **test** identifiers. Swap them for the real units
/// before the first App Store submission — `docs/RELEASE.md` lists exactly where.
enum AdUnits {
    static let isUsingTestUnits = true

    /// TEST unit — replace before release.
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    /// TEST unit — replace before release.
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    /// TEST unit — replace before release.
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    /// TEST application identifier — replace in `Info.plist` (`GADApplicationIdentifier`).
    static let application = "ca-app-pub-3940256099942544~1458002511"
}

/// Frequency and reward policy, kept out of the SDK adapter so it can be reasoned
/// about (and changed) without touching networking code.
enum AdPolicy {
    /// An interstitial is offered at most once every this many finished runs.
    static let runsBetweenInterstitials = 3
    /// Points paid out by a rewarded view.
    static let rewardedPoints = 12
    /// Days of research a rewarded view can undo.
    static let rewardedResearchSetback = 8.0
}

/// Coordinates placements, applies the policy, and delegates presentation to
/// whichever network adapter is compiled in.
@MainActor
final class AdManager: ObservableObject, AdServing {

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady = false
    /// The banner slot stays closed until consent has been resolved, so the
    /// layout never reserves space for an ad that will not arrive.
    @Published private(set) var isBannerEnabled = false

    private let adapter: AdNetworkAdapter
    private let consent: ConsentManager
    private var runsSinceLastInterstitial = 0

    /// `adapter` defaults to `nil` rather than to `makeAdapter()`: a default
    /// argument is evaluated outside the actor, and picking the adapter is
    /// main-actor work.
    init(consent: ConsentManager, adapter: AdNetworkAdapter? = nil) {
        self.consent = consent
        self.adapter = adapter ?? AdManager.makeAdapter()
    }

    static func makeAdapter() -> AdNetworkAdapter {
        #if canImport(GoogleMobileAds)
        return GoogleAdMobAdapter()
        #else
        // The SDK is not linked in this configuration. Everything still works;
        // ad slots simply do nothing. See docs/RELEASE.md to add the package.
        return DisabledAdAdapter()
        #endif
    }

    func configure() {
        isBannerEnabled = consent.hasResolvedConsent && consent.canRequestAds
        guard consent.canRequestAds else {
            AppLogger.ads.info("Consent not granted; ad requests suppressed")
            return
        }
        adapter.start { [weak self] in
            self?.preload()
        }
    }

    func preload() {
        guard consent.canRequestAds else { return }
        adapter.loadInterstitial(unitID: AdUnits.interstitial) { [weak self] ready in
            Task { @MainActor in self?.isInterstitialReady = ready }
        }
        adapter.loadRewarded(unitID: AdUnits.rewarded) { [weak self] ready in
            Task { @MainActor in self?.isRewardedReady = ready }
        }
    }

    /// Called once per finished run so the frequency cap can advance.
    func recordFinishedRun() {
        runsSinceLastInterstitial += 1
    }

    func presentInterstitial(completion: @escaping () -> Void) {
        guard consent.canRequestAds,
              isInterstitialReady,
              runsSinceLastInterstitial >= AdPolicy.runsBetweenInterstitials,
              let presenter = UIApplication.shared.topViewController() else {
            completion()
            return
        }
        runsSinceLastInterstitial = 0
        isInterstitialReady = false
        // The adapter is deliberately not actor-isolated, so that the AdMob
        // delegate callbacks it receives stay compilable. Hop back here.
        adapter.presentInterstitial(from: presenter) { [weak self] in
            Task { @MainActor in
                completion()
                self?.preload()
            }
        }
    }

    func presentRewarded(completion: @escaping (Bool) -> Void) {
        guard consent.canRequestAds,
              isRewardedReady,
              let presenter = UIApplication.shared.topViewController() else {
            AppLogger.ads.info("Rewarded view unavailable")
            completion(false)
            return
        }
        isRewardedReady = false
        adapter.presentRewarded(from: presenter) { [weak self] granted in
            Task { @MainActor in
                completion(granted)
                self?.preload()
            }
        }
    }
}

/// The seam between the game and whichever ad SDK is linked.
///
/// Intentionally *not* main-actor isolated: an SDK delivers its callbacks from
/// its own delegate methods, and forcing isolation here would make the real
/// adapter uncompilable. `AdManager` hops back to the main actor instead.
protocol AdNetworkAdapter: AnyObject {
    func start(completion: @escaping () -> Void)
    func loadInterstitial(unitID: String, completion: @escaping (Bool) -> Void)
    func loadRewarded(unitID: String, completion: @escaping (Bool) -> Void)
    func presentInterstitial(from presenter: UIViewController, completion: @escaping () -> Void)
    func presentRewarded(from presenter: UIViewController, completion: @escaping (Bool) -> Void)
}

/// Used when the ad SDK is not linked, in previews, and in tests.
final class DisabledAdAdapter: AdNetworkAdapter {
    func start(completion: @escaping () -> Void) { completion() }
    func loadInterstitial(unitID: String, completion: @escaping (Bool) -> Void) { completion(false) }
    func loadRewarded(unitID: String, completion: @escaping (Bool) -> Void) { completion(false) }
    func presentInterstitial(from presenter: UIViewController, completion: @escaping () -> Void) {
        completion()
    }
    func presentRewarded(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}

extension UIApplication {
    /// Finds the view controller an ad should be presented from.
    func topViewController() -> UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
