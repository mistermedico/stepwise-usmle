import SwiftUI
import Foundation

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
                    // Skip ad SDK startup entirely when XCTest is hosting this app (unit
                    // or UI tests). The Google Mobile Ads SDK aborts the process if
                    // GADApplicationIdentifier isn't a real, valid AdMob App ID, which the
                    // test/CI Info.plist doesn't need and shouldn't have to provide —
                    // confirmed by a real crash in CI (see README's build-status note).
                    guard !isRunningUnderXCTest else { return }
                    ConsentManager.shared.requestConsentAndStartAds {}
                }
        }
    }

    private var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
