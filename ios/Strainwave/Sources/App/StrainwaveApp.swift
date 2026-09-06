import SwiftUI

@main
struct StrainwaveApp: App {

    @StateObject private var environment = AppEnvironment()

    init() {
        // Registered before any view reads a preference.
        Settings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .tint(Theme.Palette.spread)
                .task { await environment.bootstrap() }
        }
    }
}
