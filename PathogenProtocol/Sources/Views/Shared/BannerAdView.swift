import SwiftUI
import GoogleMobileAds

/// Optional home-screen banner slot (spec section 7). Not embedded in `HomeView` by
/// default — drop `BannerAdView()` into the layout wherever the banner should sit if
/// you want it live; it no-ops safely (renders empty) until `ConsentManager` clears ads.
struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdUnitID.banner
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if ConsentManager.shared.canRequestAds {
            banner.load(Request())
        }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
