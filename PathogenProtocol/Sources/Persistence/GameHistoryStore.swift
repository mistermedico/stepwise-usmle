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
        let completedAt = Date()
        entity.id = id
        entity.completedAt = completedAt
        entity.day = Int32(summary.totalDays)
        entity.outcomeRaw = summary.outcome.rawValue
        entity.characterRaw = summary.character.rawValue
        entity.scenarioID = finalState.scenario.id
        entity.strainID = finalState.strain.id
        entity.difficultyRaw = finalState.difficulty.rawValue
        entity.peakAwareness = summary.peakAwareness
        entity.finalInfectionFraction = summary.finalInfectionFraction
        controller.save()

        // Built from the values just assigned above rather than read back from `entity`:
        // Core Data's generated properties are Optional for every object-typed attribute
        // (String/Date/UUID) regardless of the model's "Optional" flag, so re-reading them
        // here would mean immediately unwrapping values we just set ourselves.
        return SavedOutbreakReport(
            id: id, completedAt: completedAt, day: summary.totalDays, outcome: summary.outcome,
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
            guard let id = entity.id,
                  let completedAt = entity.completedAt,
                  let outcomeRaw = entity.outcomeRaw, let outcome = GameOutcome(rawValue: outcomeRaw),
                  let characterRaw = entity.characterRaw, let character = OutbreakCharacter(rawValue: characterRaw),
                  let scenarioID = entity.scenarioID,
                  let strainID = entity.strainID,
                  let difficultyRaw = entity.difficultyRaw, let difficulty = DifficultyLevel(rawValue: difficultyRaw)
            else { return nil }
            return SavedOutbreakReport(
                id: id, completedAt: completedAt, day: Int(entity.day), outcome: outcome,
                character: character, scenarioID: scenarioID, strainID: strainID,
                difficulty: difficulty, peakAwareness: entity.peakAwareness,
                finalInfectionFraction: entity.finalInfectionFraction
            )
        }
    }
}
