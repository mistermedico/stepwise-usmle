import CoreData

/// Thin Core Data stack (spec section 9). Two entities only — completed-run history
/// and unlocked achievements — so this stays simple and easy to reason about.
public final class PersistenceController {
    public static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews and unit/UI tests, so nothing ever
    /// touches disk outside of the real app.
    public static let preview: PersistenceController = PersistenceController(inMemory: true)

    public let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PersistenceModel")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                // A failed store load is unrecoverable — history/achievements would
                // silently vanish otherwise, which is worse than a loud crash in debug.
                assertionFailure("Core Data store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public var viewContext: NSManagedObjectContext { container.viewContext }

    public func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            assertionFailure("Failed to save Core Data context: \(error)")
        }
    }
}
