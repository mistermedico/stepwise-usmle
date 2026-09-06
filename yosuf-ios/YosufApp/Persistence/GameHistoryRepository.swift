import CoreData
import YosufEngine

struct MatchHistoryItem: Identifiable {
    let id: UUID
    let date: Date
    let rulesProfileID: RuleProfile.ProfileKind
    let didWin: Bool
    let finalScore: Int
    let roundsPlayed: Int
    let opponentSummary: String
    let wasDailyChallenge: Bool
}

/// Reads and writes match history. Never exposes `NSManagedObject` outside
/// this file — everything else in the app deals with plain `MatchHistoryItem`.
struct GameHistoryRepository {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func recordMatch(
        rulesProfileID: RuleProfile.ProfileKind,
        didWin: Bool,
        finalScore: Int,
        roundsPlayed: Int,
        opponentSummary: String,
        wasDailyChallenge: Bool = false
    ) {
        let entity = MatchHistoryEntity(context: context)
        entity.id = UUID()
        entity.date = Date()
        entity.rulesProfileID = rulesProfileID.rawValue
        entity.didWin = didWin
        entity.finalScore = Int32(finalScore)
        entity.roundsPlayed = Int32(roundsPlayed)
        entity.opponentSummary = opponentSummary
        entity.wasDailyChallenge = wasDailyChallenge
        PersistenceController.shared.saveIfNeeded()
    }

    func recentMatches(limit: Int = 50) -> [MatchHistoryItem] {
        let request = MatchHistoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { entity -> MatchHistoryItem? in
            guard let id = entity.id, let date = entity.date,
                  let profileID = entity.rulesProfileID.flatMap(RuleProfile.ProfileKind.init(rawValue:)) else {
                return nil
            }
            return MatchHistoryItem(
                id: id, date: date, rulesProfileID: profileID,
                didWin: entity.didWin, finalScore: Int(entity.finalScore),
                roundsPlayed: Int(entity.roundsPlayed),
                opponentSummary: entity.opponentSummary ?? "",
                wasDailyChallenge: entity.wasDailyChallenge
            )
        }
    }
}
