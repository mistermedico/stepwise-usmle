import Foundation
import SwiftUI
import OutbreakEngine

/// Backs the control panel: the run set-up, today's challenge, and the shelf of
/// past reports.
@MainActor
final class HomeViewModel: ObservableObject {

    @Published var strain: StrainID = .drift
    @Published var difficulty: Difficulty = .tense
    @Published var scenario: StartScenario = .wildcard

    /// Strains beyond the free set that the player has opened.
    @Published private(set) var unlockedStrains: Set<StrainID>

    private let store: ReportStore
    private let ads: AdManager
    private let feedback: FeedbackProviding
    private let now: () -> Date

    init(
        store: ReportStore,
        ads: AdManager,
        feedback: FeedbackProviding,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.ads = ads
        self.feedback = feedback
        self.now = now
        self.unlockedStrains = Set(Settings.unlockedStrains.compactMap(StrainID.init(rawValue:)))
    }

    // MARK: Daily challenge

    var todaysChallenge: DailyChallenge {
        DailyChallenge.challenge(for: now())
    }

    var hasPlayedTodaysChallenge: Bool {
        store.hasPlayedDailyChallenge(id: todaysChallenge.id)
    }

    // MARK: Set-up

    /// A run built from the current picker selection.
    func makeSetup() -> GameSetup {
        GameSetup(
            strain: strain,
            difficulty: difficulty,
            scenario: scenario,
            seed: UInt64.random(in: 1...UInt64.max)
        )
    }

    func isPlayable(_ id: StrainID) -> Bool {
        !StrainCatalog.strain(id).requiresUnlock || unlockedStrains.contains(id)
    }

    /// Offers a rewarded view to open a gated sample. The same entry point a
    /// future in-app purchase will use.
    func unlockStrain(_ id: StrainID) {
        guard StrainCatalog.strain(id).requiresUnlock, !unlockedStrains.contains(id) else { return }
        ads.presentRewarded { [weak self] granted in
            Task { @MainActor in
                guard let self, granted else { return }
                self.unlockedStrains.insert(id)
                Settings.unlockedStrains = Set(self.unlockedStrains.map(\.rawValue))
                self.feedback.play(.abilityUnlocked)
                AppLogger.game.info("Unlocked strain \(id.rawValue)")
            }
        }
    }

    /// Falls back to a playable sample if the selection is gated.
    func normaliseSelection() {
        guard !isPlayable(strain) else { return }
        strain = StrainCatalog.freeStrains.first?.id ?? .drift
    }

    // MARK: Shelf

    var recentReports: [EpidemicReport] {
        Array(store.reports.prefix(8))
    }

    var hasHistory: Bool { !store.reports.isEmpty }
    var victories: Int { store.victories }
    var runsFinished: Int { Settings.runsFinished }
    var fastestVictoryDays: Int? { store.fastestVictoryDays }
}
