import CoreData
import os

/// Owns the single `NSPersistentContainer` for match history, achievements,
/// and the local player profile. Repositories below are the only things
/// that talk to Core Data directly — views/view models go through them.
struct PersistenceController {
    static let shared = PersistenceController()

    /// An in-memory store used by SwiftUI previews and unit/UI tests so
    /// they never touch (or pollute) the real on-disk database.
    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer
    private let logger = Logger(subsystem: "com.yosuf.game", category: "persistence")

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Yosuf")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { [logger] description, error in
            if let error {
                // A corrupt/incompatible store must never crash the app on
                // launch — log it and continue with an empty in-memory
                // fallback so match history/achievements just start fresh.
                logger.fault("Failed to load persistent store \(description): \(error.localizedDescription, privacy: .public)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveIfNeeded() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription, privacy: .public)")
        }
    }
}
