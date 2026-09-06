import SwiftUI

/// The app's tab bar: Play, Daily Challenge, Gallery, Achievements, Settings.
struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView {
            CategoryListView()
                .tabItem {
                    Label(appViewModel.localization.string("tab.play"), systemImage: "square.grid.2x2.fill")
                }

            DailyChallengeView()
                .tabItem {
                    Label(appViewModel.localization.string("tab.daily"), systemImage: "calendar")
                }

            GalleryView()
                .tabItem {
                    Label(appViewModel.localization.string("tab.gallery"), systemImage: "photo.stack.fill")
                }

            AchievementsView()
                .tabItem {
                    Label(appViewModel.localization.string("tab.achievements"), systemImage: "trophy.fill")
                }

            SettingsView()
                .tabItem {
                    Label(appViewModel.localization.string("tab.settings"), systemImage: "gearshape.fill")
                }
        }
    }
}
