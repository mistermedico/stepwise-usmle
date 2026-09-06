import CoreData
import Foundation

/// A single completed run, as saved for the "gallery of past reports" (spec section 2.5).
public struct SavedOutbreakReport: Identifiable {
    public let id: UUID
    public let completedAt: Date
    public let day: Int
    public let outcome: GameOutcome
    public let character: OutbreakCharacter
    public let scenarioID: String
    public let strainID: String
    public let difficulty: DifficultyLevel
    public let peakAwareness: Double
    public let finalInfectionFraction: Double
}

/// Reads and writes `OutbreakReportEntity` rows. Kept separate from `PersistenceController`
/// so view models depend on a small, purpose-built API instead of raw `NSManagedObjectContext`.
public final class GameHistoryStore {
    public static let shared = GameHistoryStore()

    private let controller: PersistenceController

    public init(controller: PersistenceController = .shared) {
        self.controller = controller
    }

    @discardableResult
    public func save(finalState: GameState) -> SavedOutbreakReport? {
        guard let summary = ReportAnalyzer.summarize(finalState) else { return nil }
        let context = controller.viewContext
        let entity = OutbreakReportEntity(context: context)
        let id = UUID()
        entity.id = id
        entity.completedAt = Date()
        entity.day = Int32(summary.totalDays)
        entity.outcomeRaw = summary.outcome.rawValue
        entity.characterRaw = summary.character.rawValue
        entity.scenarioID = finalState.scenario.id
        entity.strainID = finalState.strain.id
        entity.difficultyRaw = finalState.difficulty.rawValue
        entity.peakAwareness = summary.peakAwareness
        entity.finalInfectionFraction = summary.finalInfectionFraction
        controller.save()

        return SavedOutbreakReport(
            id: id, completedAt: entity.completedAt, day: summary.totalDays, outcome: summary.outcome,
            character: summary.character, scenarioID: finalState.scenario.id, strainID: finalState.strain.id,
            difficulty: finalState.difficulty, peakAwareness: summary.peakAwareness,
            finalInfectionFraction: summary.finalInfectionFraction
        )
    }

    public func fetchAll() -> [SavedOutbreakReport] {
        let request = OutbreakReportEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        guard let entities = try? controller.viewContext.fetch(request) else { return [] }
        return entities.compactMap { entity in
            guard let outcome = GameOutcome(rawValue: entity.outcomeRaw),
                  let character = OutbreakCharacter(rawValue: entity.characterRaw),
                  let difficulty = DifficultyLevel(rawValue: entity.difficultyRaw) else { return nil }
            return SavedOutbreakReport(
                id: entity.id, completedAt: entity.completedAt, day: Int(entity.day), outcome: outcome,
                character: character, scenarioID: entity.scenarioID, strainID: entity.strainID,
                difficulty: difficulty, peakAwareness: entity.peakAwareness,
                finalInfectionFraction: entity.finalInfectionFraction
            )
        }
    }
}
