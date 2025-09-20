import CoreData
import Foundation

struct CoreDataStack {
    static let shared = CoreDataStack()

    static var preview: CoreDataStack = {
        let result = CoreDataStack(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleSession = PhotoSession(context: viewContext)
        sampleSession.id = UUID().uuidString
        sampleSession.vehicleIdentifier = "Sample Vehicle"
        sampleSession.startDate = Date()
        sampleSession.status = "completed"
        sampleSession.totalAngles = 8
        sampleSession.completedAngles = 8
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer
    
    // Alias for compatibility
    var persistentContainer: NSPersistentContainer {
        return container
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CoreDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure migration options
            let storeDescription = container.persistentStoreDescriptions.first!
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        
        let containerRef = container
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // If migration fails, try to delete and recreate the store
                if error.code == 134140 { // Migration failed error
                    Self.handleMigrationFailure(container: containerRef)
                } else {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    private static func handleMigrationFailure(container: NSPersistentContainer) {
        // Get the store URL
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            fatalError("Could not get store URL")
        }
        
        // Delete the existing store
        do {
            try FileManager.default.removeItem(at: storeURL)
            print("Deleted existing store due to migration failure")
        } catch {
            print("Failed to delete store: \(error)")
        }
        
        // Reload the store
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error after store recreation \(error), \(error.userInfo)")
            }
        })
    }
}
