import Foundation
@testable import Photo_Booth

/// Shared test utilities for all test classes
class TestUtilities {
    static let sharedCoreDataStack: CoreDataStack = {
        return CoreDataStack(inMemory: true)
    }()
    
    static func createMockPhotoSession(id: UUID) -> PhotoSession {
        let context = sharedCoreDataStack.container.viewContext
        
        let session = PhotoSession(context: context)
        session.id = id
        session.vehicleIdentifier = "TEST123"
        session.startDate = Date()
        session.status = "completed"
        session.totalAngles = 8
        session.completedAngles = 8
        
        return session
    }
    
    static func createMockVehiclePhoto(id: UUID) -> VehiclePhoto {
        let context = sharedCoreDataStack.container.viewContext
        
        let photo = VehiclePhoto(context: context)
        photo.id = id
        photo.angleType = "front"
        photo.captureDate = Date()
        photo.fileName = "test_photo.jpg"
        photo.filePath = "/test/path/test_photo.jpg"
        photo.fileSize = 50000
        photo.imageWidth = 200
        photo.imageHeight = 200
        photo.confidenceScore = 0.95
        photo.isAutoCaptured = true
        
        return photo
    }
    
    static func createMockVehiclePhotos(sessionId: UUID, count: Int = 3) -> [VehiclePhoto] {
        let context = sharedCoreDataStack.container.viewContext
        
        var photos: [VehiclePhoto] = []
        for i in 0..<count {
            let photo = VehiclePhoto(context: context)
            photo.id = UUID()
            photo.angleType = ["front", "side", "rear"][i % 3]
            photo.captureDate = Date()
            photo.fileName = "test_photo_\(i).jpg"
            photo.filePath = "/test/path/test_photo_\(i).jpg"
            photo.fileSize = 50000
            photo.imageWidth = 200
            photo.imageHeight = 200
            photo.confidenceScore = 0.95
            photo.isAutoCaptured = true
            photos.append(photo)
        }
        return photos
    }
}
