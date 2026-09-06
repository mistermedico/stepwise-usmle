import SwiftUI
import UIKit

/// The optional home-screen banner.
///
/// Like the rest of the ad layer, this compiles with or without the SDK: with
/// it, a real banner is hosted; without it, the slot renders nothing at all.
struct BannerAdView: View {
    var body: some View {
        #if canImport(GoogleMobileAds)
        BannerRepresentable()
        #else
        Color.clear.frame(height: 0)
        #endif
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

private struct BannerRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner)
        view.adUnitID = AdUnits.banner
        view.rootViewController = UIApplication.shared.topViewController()
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = UIApplication.shared.topViewController()
        }
    }
}
#endif
