import SwiftUI

/// The app's single navigation root. Every push/pop in the app goes through
/// this one `NavigationStack` so the "one consistent transition style" rule
/// is structural, not something each screen has to remember to apply.
struct RootView: View {
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            HomeView()
                .environmentObject(homeViewModel)
        }
        .tint(Theme.accentGold)
        .task {
            await AdManager.shared.requestTrackingAuthorizationIfNeeded()
        }
    }
}
