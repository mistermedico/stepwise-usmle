import Foundation

/// Picks "today's" puzzle deterministically from the full puzzle pool so every player sees
/// the same daily puzzle on the same calendar day, changing at local midnight, with no
/// server round-trip required.
final class DailyChallengeViewModel: ObservableObject {
    @Published private(set) var puzzle: Puzzle?
    @Published private(set) var isCompletedToday = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private let appViewModel: AppViewModel
    private let loader: PuzzleLoader

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current // "local midnight" boundary, not UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init(appViewModel: AppViewModel, loader: PuzzleLoader = PuzzleLoader()) {
        self.appViewModel = appViewModel
        self.loader = loader
    }

    static func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    /// Consecutive days (ending today, or yesterday if today hasn't been played yet) with a
    /// completed daily challenge.
    var streak: Int {
        let calendar = Calendar.current
        let completedDates = appViewModel.progress.dailyChallengeCompletedDates
        var cursor = Date()

        if !completedDates.contains(Self.dateKey(for: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while completedDates.contains(Self.dateKey(for: cursor)) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return count
    }

    func load(now: Date = Date()) {
        isLoading = true
        loadError = nil
        do {
            let puzzles = try loader.loadAllPuzzles().sorted { $0.id < $1.id }
            guard !puzzles.isEmpty else {
                puzzle = nil
                isLoading = false
                return
            }
            let key = Self.dateKey(for: now)
            let index = Int(Self.stableHash(key) % UInt64(puzzles.count))
            puzzle = puzzles[index]
            isCompletedToday = appViewModel.progress.dailyChallengeCompletedDates.contains(key)
        } catch {
            loadError = "\(error)"
            puzzle = nil
        }
        isLoading = false
    }

    func recordCompletion(now: Date = Date(), flawless: Bool) {
        guard let puzzle else { return }
        let key = Self.dateKey(for: now)
        appViewModel.recordDailyChallengeCompletion(dateKey: key)
        // Completing the daily puzzle also counts toward its category's normal progression —
        // a deliberate bonus, since the daily pick can land on a level the player hasn't
        // reached yet in that category's linear order.
        appViewModel.recordLevelCompletion(levelID: puzzle.id, flawless: flawless)
        isCompletedToday = true
    }

    /// Deterministic (not process-random) string hash — Swift's built-in `Hashable`/`hashValue`
    /// is seeded per-process for hash-flooding protection, so it must NOT be used here: every
    /// player's device needs to land on the exact same puzzle for the same date key.
    /// Standard FNV-1a over the UTF-8 bytes.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}
