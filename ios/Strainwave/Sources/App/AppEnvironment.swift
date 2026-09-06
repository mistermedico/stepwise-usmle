import Foundation
import SwiftUI

/// Composition root. One object owns every service so views receive exactly what
/// they need and nothing constructs a dependency on the side.
@MainActor
final class AppEnvironment: ObservableObject {

    let consent: ConsentManager
    let ads: AdManager
    let store: ReportStore
    let feedback: FeedbackProviding

    /// `ConsentManager` and `ReportStore` are built here rather than defaulted
    /// in the parameter list: a default argument is always evaluated in a
    /// nonisolated context, so a main-actor type cannot be one.
    init(
        store: ReportStore? = nil,
        feedback: FeedbackProviding = SoundManager.shared
    ) {
        let consent = ConsentManager()
        self.consent = consent
        self.ads = AdManager(consent: consent)
        self.store = store ?? ReportStore()
        self.feedback = feedback
    }

    /// One-time launch work. Runs off the first frame so nothing blocks the
    /// initial render.
    func bootstrap() async {
        Settings.registerDefaults()
        AppLogger.lifecycle.info("Launching")
        await consent.resolve()
        ads.configure()
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(store: store, ads: ads, feedback: feedback)
    }

    /// A fully wired environment with an in-memory store, for previews.
    static var preview: AppEnvironment {
        AppEnvironment(
            store: ReportStore(controller: PersistenceController(inMemory: true)),
            feedback: SilentFeedback()
        )
    }
}
