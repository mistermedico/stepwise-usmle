import SwiftUI

@main
struct CardioFocusApp: App {
    @StateObject private var bootstrap = Bootstrap()
    var body: some Scene {
        WindowGroup {
            Group {
                if let store = bootstrap.store { RootView().environmentObject(store) }
                else { ContentUnavailableView("Unable to load lessons", systemImage: "exclamationmark.triangle", description: Text("The bundled curriculum could not be opened. Reinstall the app or contact support.")) }
            }
            .tint(Theme.green)
        }
    }
}

@MainActor
final class Bootstrap: ObservableObject {
    let store: StudyStore?
    init() {
        if let curriculum = try? Curriculum.load() {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let defaults = UserDefaults(suiteName: "cardiofocus.ui-testing")!
                defaults.removePersistentDomain(forName: "cardiofocus.ui-testing")
                store = StudyStore(curriculum: curriculum, defaults: defaults)
            } else { store = StudyStore(curriculum: curriculum) }
        } else { store = nil }
    }
}

enum Theme {
    static let green = Color(red: 0.08, green: 0.35, blue: 0.29)
    static let dark = Color(red: 0.06, green: 0.22, blue: 0.20)
    static let pale = Color(red: 0.86, green: 0.92, blue: 0.77)
}

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    var body: some View {
        TabView {
            NavigationStack { StudyHomeView() }.tabItem { Label("Learn", systemImage: "heart.text.square") }
            NavigationStack { PracticeSetupView() }.tabItem { Label("Practice", systemImage: "checkmark.circle") }
            NavigationStack { FlashcardsView() }.tabItem { Label("Cards", systemImage: "rectangle.on.rectangle") }
            NavigationStack { ProgressViewScreen() }.tabItem { Label("Progress", systemImage: "chart.bar") }
            NavigationStack { AboutView() }.tabItem { Label("About", systemImage: "info.circle") }
        }
        .safeAreaInset(edge: .top) {
            if let warning = store.persistenceWarning {
                Text(warning).font(.caption).padding(8).frame(maxWidth: .infinity).background(.yellow.opacity(0.2))
            }
        }
    }
}
