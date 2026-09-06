import Foundation
import CoreData
import OutbreakEngine

/// Reads and writes the player's history.
///
/// Every method is failure-tolerant: a broken row is skipped and logged rather
/// than propagated, because losing a report must never block play.
@MainActor
final class ReportStore: ObservableObject {

    @Published private(set) var reports: [EpidemicReport] = []
    @Published private(set) var earnedAchievements: Set<Achievement> = []

    private let context: NSManagedObjectContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(controller: PersistenceController = .shared) {
        self.context = controller.viewContext
        reload()
    }

    // MARK: Reading

    func reload() {
        reports = loadReports()
        earnedAchievements = loadAchievements()
    }

    private func loadReports(limit: Int = 100) -> [EpidemicReport] {
        let request = StoredReport.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "finishedAt", ascending: false)]
        request.fetchLimit = limit
        do {
            return try context.fetch(request).compactMap { row in
                do {
                    return try decoder.decode(EpidemicReport.self, from: row.payload)
                } catch {
                    AppLogger.persistence.error("Skipping unreadable report: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            AppLogger.persistence.error("Report fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func loadAchievements() -> Set<Achievement> {
        let request = StoredAchievement.fetchRequest()
        do {
            return Set(try context.fetch(request).compactMap { Achievement(rawValue: $0.rawValue) })
        } catch {
            AppLogger.persistence.error("Achievement fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: Writing

    /// Files a finished run and returns the achievements it newly unlocked.
    @discardableResult
    func save(_ report: EpidemicReport) -> [Achievement] {
        guard let row = StoredReport.insert(into: context) else {
            AppLogger.persistence.error("Could not insert a report row")
            return []
        }
        row.id = report.id
        row.finishedAt = report.finishedAt
        row.isVictory = report.isVictory
        row.titleRaw = report.title.rawValue
        row.dailyChallengeID = report.dailyChallengeID
        do {
            row.payload = try encoder.encode(report)
        } catch {
            AppLogger.persistence.error("Could not encode report: \(error.localizedDescription)")
            context.delete(row)
            return []
        }

        Settings.runsFinished += 1
        if let dailyID = report.dailyChallengeID {
            Settings.lastDailyChallengePlayed = dailyID
            if report.isVictory {
                Settings.dailyChallengeWins += 1
            }
        }

        var candidates = Achievement.earned(from: report)
        candidates.formUnion(Achievement.cumulative(dailyChallengesWon: Settings.dailyChallengeWins))
        let fresh = candidates.subtracting(earnedAchievements)

        for achievement in fresh {
            guard let stored = StoredAchievement.insert(into: context) else { continue }
            stored.rawValue = achievement.rawValue
            stored.earnedAt = report.finishedAt
        }

        persist()
        reload()
        // Sorted so the summary screen lists them in a stable order.
        return fresh.sorted { $0.rawValue < $1.rawValue }
    }

    func deleteAll() {
        for entity in [StoredReport.entityName, StoredAchievement.entityName] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            delete.resultType = .resultTypeObjectIDs
            do {
                let result = try context.execute(delete) as? NSBatchDeleteResult
                if let ids = result?.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context]
                    )
                }
            } catch {
                AppLogger.persistence.error("Could not clear \(entity): \(error.localizedDescription)")
            }
        }
        Settings.reset()
        reload()
    }

    // MARK: Derived

    /// Whether today's challenge has already been finished.
    func hasPlayedDailyChallenge(id: String) -> Bool {
        reports.contains { $0.dailyChallengeID == id }
    }

    var victories: Int { reports.filter(\.isVictory).count }

    var fastestVictoryDays: Int? {
        reports.filter(\.isVictory).map(\.days).min()
    }

    private func persist() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.persistence.error("Save failed: \(error.localizedDescription)")
            context.rollback()
        }
    }
}
