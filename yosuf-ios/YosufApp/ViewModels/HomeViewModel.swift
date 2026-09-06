import Foundation
import YosufEngine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var profile: PlayerProfileSnapshot
    @Published var showDailyChallengeBadge: Bool

    private let profileRepository = PlayerProfileRepository()

    init() {
        let snapshot = PlayerProfileRepository().snapshot()
        profile = snapshot
        let todayKey = DailyChallengeGenerator.scenario().dateKey
        showDailyChallengeBadge = snapshot.lastDailyChallengeDateKey != todayKey
    }

    func refresh() {
        profile = profileRepository.snapshot()
        let todayKey = DailyChallengeGenerator.scenario().dateKey
        showDailyChallengeBadge = profile.lastDailyChallengeDateKey != todayKey
    }

    var rankProgressFraction: Double {
        let tier = profile.rankTier
        guard let remaining = tier.pointsToNext(from: profile.skillRating), remaining > 0 else { return 1.0 }
        // Rough visual progress within the current tier band.
        let bandSize = Double(remaining) + Double(profile.skillRating)
        guard bandSize > 0 else { return 0 }
        return max(0, min(1, 1.0 - Double(remaining) / bandSize))
    }
}
