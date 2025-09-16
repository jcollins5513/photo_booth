import CoreData
import Foundation

struct CoreDataStack {
    static let shared = CoreDataStack()

    static var preview: CoreDataStack = {
        let result = CoreDataStack(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleSession = PhotoSession(context: viewContext)
        sampleSession.id = UUID()
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
        container = NSPersistentContainer(name: "VehiclePhotoBooth")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
