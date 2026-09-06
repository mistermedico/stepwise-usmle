import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var matches: [MatchHistoryItem] = []

    private let repository = GameHistoryRepository()

    func load() {
        matches = repository.recentMatches()
    }
}
