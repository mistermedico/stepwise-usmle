import SwiftUI

@main
struct NonogramApp: App {
    // Owns all shared state for the lifetime of the process; every screen reads/writes
    // progress through this single instance via @EnvironmentObject.
    @StateObject private var appViewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .environment(\.layoutDirection, appViewModel.localization.layoutDirection)
                .preferredColorScheme(nil) // follow the system appearance, never lock one in
                .onAppear {
                    appViewModel.onAppLaunch()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Recompute regenerated lives whenever the app comes back to the foreground,
                // since regeneration is wall-clock based and keeps ticking while backgrounded.
                appViewModel.refreshLivesRegeneration()
            case .background, .inactive:
                appViewModel.persist()
            @unknown default:
                break
            }
        }
    }
}
