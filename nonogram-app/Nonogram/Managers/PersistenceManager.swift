import Foundation

/// Local-only save data (UserDefaults). There's no account system, so everything lives
/// on-device — this is also called out in the privacy policy since it means we never
/// transmit gameplay data anywhere.
final class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults: UserDefaults
    private let progressKey = "com.nonogram.playerProgress.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProgress() -> PlayerProgress {
        guard let data = defaults.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode(PlayerProgress.self, from: data) else {
            return PlayerProgress()
        }
        return decoded
    }

    func saveProgress(_ progress: PlayerProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: progressKey)
    }

    /// Applies real-time life regeneration based on elapsed wall-clock time since the last
    /// save, so lives refill even while the app isn't running.
    func regenerateLivesIfNeeded(_ progress: inout PlayerProgress, now: Date = Date()) {
        guard progress.lives < PlayerProgress.Constants.maxLives else {
            progress.lastLifeRegenerationDate = now
            return
        }
        let elapsed = now.timeIntervalSince(progress.lastLifeRegenerationDate)
        guard elapsed > 0 else { return }

        let regenerated = Int(elapsed / PlayerProgress.Constants.lifeRegenerationInterval)
        guard regenerated > 0 else { return }

        progress.lives = min(PlayerProgress.Constants.maxLives, progress.lives + regenerated)
        let consumedTime = TimeInterval(regenerated) * PlayerProgress.Constants.lifeRegenerationInterval
        progress.lastLifeRegenerationDate = progress.lastLifeRegenerationDate.addingTimeInterval(consumedTime)
    }

    /// Updates the daily streak given a new "played" event, using calendar-day granularity
    /// so timezone changes mid-session can't be gamed for extra streak credit.
    func registerPlaySession(_ progress: inout PlayerProgress, now: Date = Date()) {
        let calendar = Calendar.current
        defer { progress.lastPlayedDate = now }

        guard let lastPlayed = progress.lastPlayedDate else {
            progress.currentStreak = 1
            progress.longestStreak = max(progress.longestStreak, 1)
            return
        }

        let lastDay = calendar.startOfDay(for: lastPlayed)
        let today = calendar.startOfDay(for: now)
        let dayDelta = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        switch dayDelta {
        case 0:
            break // already played today, streak unchanged
        case 1:
            progress.currentStreak += 1
            progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
        default:
            progress.currentStreak = 1
        }
    }
}
