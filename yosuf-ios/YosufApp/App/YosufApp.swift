import SwiftUI

@main
struct YosufApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                persistence.saveIfNeeded()
            }
        }
    }
}
