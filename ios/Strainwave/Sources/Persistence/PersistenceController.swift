import Foundation
import CoreData

/// Core Data stack with a **programmatically declared** model.
///
/// A code-defined `NSManagedObjectModel` is used rather than a `.xcdatamodeld`
/// bundle: the schema is then reviewable in a diff, cannot drift from the
/// entity classes, and needs no editor to change.
final class PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "Strainwave",
            managedObjectModel: PersistenceController.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error {
                // A missing store must never crash the game: the player loses
                // saved reports, not the ability to play.
                AppLogger.persistence.error(
                    "Store failed to load at \(description.url?.absoluteString ?? "unknown"): \(error.localizedDescription)"
                )
                return
            }
            AppLogger.persistence.info("Store ready")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Builds the schema. Two entities, both flat — the run's detail lives in a
    /// JSON payload so adding a field to `EpidemicReport` never needs a migration.
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let report = NSEntityDescription()
        report.name = StoredReport.entityName
        report.managedObjectClassName = NSStringFromClass(StoredReport.self)
        report.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("finishedAt", .dateAttributeType, optional: false),
            attribute("isVictory", .booleanAttributeType, optional: false),
            attribute("titleRaw", .stringAttributeType, optional: false),
            attribute("dailyChallengeID", .stringAttributeType, optional: true),
            attribute("payload", .binaryDataAttributeType, optional: false)
        ]
        // One row per run; the id is the natural key.
        report.uniquenessConstraints = [["id"]]

        let achievement = NSEntityDescription()
        achievement.name = StoredAchievement.entityName
        achievement.managedObjectClassName = NSStringFromClass(StoredAchievement.self)
        achievement.properties = [
            attribute("rawValue", .stringAttributeType, optional: false),
            attribute("earnedAt", .dateAttributeType, optional: false)
        ]
        achievement.uniquenessConstraints = [["rawValue"]]

        model.entities = [report, achievement]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let description = NSAttributeDescription()
        description.name = name
        description.attributeType = type
        description.isOptional = optional
        return description
    }
}

/// One archived run. The full report travels as JSON in `payload`.
@objc(StrainwaveStoredReport)
final class StoredReport: NSManagedObject {
    static let entityName = "StoredReport"

    @NSManaged var id: UUID
    @NSManaged var finishedAt: Date
    @NSManaged var isVictory: Bool
    @NSManaged var titleRaw: String
    @NSManaged var dailyChallengeID: String?
    @NSManaged var payload: Data

    static func fetchRequest() -> NSFetchRequest<StoredReport> {
        NSFetchRequest<StoredReport>(entityName: entityName)
    }

    /// Inserts by entity name rather than by class, which stays correct even if
    /// more than one model is loaded in the process.
    static func insert(into context: NSManagedObjectContext) -> StoredReport? {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? StoredReport
    }
}

/// One unlocked achievement.
@objc(StrainwaveStoredAchievement)
final class StoredAchievement: NSManagedObject {
    static let entityName = "StoredAchievement"

    @NSManaged var rawValue: String
    @NSManaged var earnedAt: Date

    static func fetchRequest() -> NSFetchRequest<StoredAchievement> {
        NSFetchRequest<StoredAchievement>(entityName: entityName)
    }

    static func insert(into context: NSManagedObjectContext) -> StoredAchievement? {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? StoredAchievement
    }
}
