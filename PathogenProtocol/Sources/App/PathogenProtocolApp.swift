import SwiftUI

@main
struct PathogenProtocolApp: App {
    init() {
        // Ad SDK start is deferred until ConsentManager resolves ATT/UMP consent —
        // see ConsentManager.requestConsentAndStartAds, called from RootView's first
        // appearance so the very first frame isn't blocked on a network round trip.
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    ConsentManager.shared.requestConsentAndStartAds {}
                }
        }
    }
}
