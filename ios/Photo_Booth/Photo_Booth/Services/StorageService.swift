import Foundation
import CoreData

/// Storage service implementation
class StorageService: @unchecked Sendable, StorageServiceProtocol {
    
    // MARK: - Properties
    
    private let persistentContainer: NSPersistentContainer
    private let fileSystemManager: FileSystemManagerProtocol
    
    // MARK: - Initialization
    
    init(persistentContainer: NSPersistentContainer, fileSystemManager: FileSystemManagerProtocol) {
        self.persistentContainer = persistentContainer
        self.fileSystemManager = fileSystemManager
    }
    
    // MARK: - Photo Session Management
    
    func savePhotoSession(
        id: UUID,
        vehicleIdentifier: String,
        startDate: Date,
        status: String,
        totalAngles: Int16,
        completedAngles: Int16
    ) async throws -> PhotoSession {
        
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Check if session already exists
                    let fetchRequest: NSFetchRequest<PhotoSession> = PhotoSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    if let existingSession = try context.fetch(fetchRequest).first {
                        // Update existing session
                        existingSession.vehicleIdentifier = vehicleIdentifier
                        existingSession.startDate = startDate
                        existingSession.status = status
                        existingSession.totalAngles = totalAngles
                        existingSession.completedAngles = completedAngles
                        
                        try context.save()
                        continuation.resume(returning: existingSession)
                    } else {
                        // Create new session
                        let session = PhotoSession(context: context)
                        session.id = id.uuidString
                        session.vehicleIdentifier = vehicleIdentifier
                        session.startDate = startDate
                        session.status = status
                        session.totalAngles = totalAngles
                        session.completedAngles = completedAngles
                        
                        try context.save()
                        continuation.resume(returning: session)
                    }
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    func saveSession(_ session: PhotoSession) async throws {
        let context = persistentContainer.viewContext
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    func getPhotoSession(id: UUID) async throws -> PhotoSession? {
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<PhotoSession> = PhotoSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    let sessions = try context.fetch(fetchRequest)
                    continuation.resume(returning: sessions.first)
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    func updatePhotoSession(
        id: UUID,
        status: String?,
        completedAngles: Int16?
    ) async throws -> PhotoSession {
        
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<PhotoSession> = PhotoSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    guard let session = try context.fetch(fetchRequest).first else {
                        continuation.resume(throwing: StorageServiceError.sessionNotFound)
                        return
                    }
                    
                    if let status = status {
                        session.status = status
                    }
                    
                    if let completedAngles = completedAngles {
                        session.completedAngles = completedAngles
                    }
                    
                    try context.save()
                    continuation.resume(returning: session)
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Vehicle Photo Management
    
    func saveVehiclePhoto(
        id: UUID,
        sessionId: UUID,
        angle: String,
        imageData: Data,
        timestamp: Date
    ) async throws -> VehiclePhoto {
        
        // Save image to file system first
        let fileName = "\(id.uuidString).jpg"
        let filePath = try await fileSystemManager.saveImage(data: imageData, fileName: fileName)
        
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Get the photo session
                    let sessionFetchRequest: NSFetchRequest<PhotoSession> = PhotoSession.fetchRequest()
                    sessionFetchRequest.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
                    
                    guard let session = try context.fetch(sessionFetchRequest).first else {
                        continuation.resume(throwing: StorageServiceError.sessionNotFound)
                        return
                    }
                    
                    // Create vehicle photo entity
                    let photo = VehiclePhoto(context: context)
                    photo.id = id.uuidString
                    photo.session = session
                    photo.angleType = angle
                    photo.filePath = filePath
                    photo.captureDate = timestamp
                    
                    try context.save()
                    continuation.resume(returning: photo)
                } catch {
                    continuation.resume(throwing: StorageServiceError.saveFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func getVehiclePhoto(id: UUID) async throws -> VehiclePhoto? {
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<VehiclePhoto> = VehiclePhoto.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    let photos = try context.fetch(fetchRequest)
                    continuation.resume(returning: photos.first)
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    func getPhotosForSession(sessionId: UUID) async throws -> [VehiclePhoto] {
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<VehiclePhoto> = VehiclePhoto.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "session.id == %@", sessionId as CVarArg)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "captureDate", ascending: true)]
                    
                    let photos = try context.fetch(fetchRequest)
                    continuation.resume(returning: photos)
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Deletion Methods
    
    func deletePhotoSession(id: UUID) async throws {
        let context = persistentContainer.viewContext
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Get the session
                    let sessionFetchRequest: NSFetchRequest<PhotoSession> = PhotoSession.fetchRequest()
                    sessionFetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    guard let session = try context.fetch(sessionFetchRequest).first else {
                        continuation.resume(throwing: StorageServiceError.sessionNotFound)
                        return
                    }
                    
                    // Delete associated photos
                    let photoFetchRequest: NSFetchRequest<VehiclePhoto> = VehiclePhoto.fetchRequest()
                    photoFetchRequest.predicate = NSPredicate(format: "session.id == %@", id as CVarArg)
                    
                    let photos = try context.fetch(photoFetchRequest)
                    for photo in photos {
                        // Delete file from file system
                        if let filePath = photo.filePath {
                            let fileSystemManager = self.fileSystemManager
                            Task {
                                try? await fileSystemManager.deleteImage(filePath: filePath)
                            }
                        }
                        context.delete(photo)
                    }
                    
                    // Delete the session
                    context.delete(session)
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageServiceError.deleteFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func deleteVehiclePhoto(id: UUID) async throws {
        let context = persistentContainer.viewContext
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<VehiclePhoto> = VehiclePhoto.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    guard let photo = try context.fetch(fetchRequest).first else {
                        continuation.resume(throwing: StorageServiceError.photoNotFound)
                        return
                    }
                    
                    // Delete file from file system
                    if let filePath = photo.filePath {
                        let fileSystemManager = self.fileSystemManager
                        Task {
                            try? await fileSystemManager.deleteImage(filePath: filePath)
                        }
                    }
                    
                    context.delete(photo)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageServiceError.deleteFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Additional Methods for Gallery
    
    func getAllPhotos() async throws -> [VehiclePhoto] {
        let context = persistentContainer.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<VehiclePhoto> = VehiclePhoto.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "captureDate", ascending: false)]
                    
                    let photos = try context.fetch(fetchRequest)
                    continuation.resume(returning: photos)
                } catch {
                    continuation.resume(throwing: StorageServiceError.coreDataError(error.localizedDescription))
                }
            }
        }
    }
    
    func getPhotoData(id: UUID) async throws -> Data {
        guard let photo = try await getVehiclePhoto(id: id) else {
            throw StorageServiceError.photoNotFound
        }
        
        guard let filePath = photo.filePath else {
            throw StorageServiceError.fileSystemError("Photo file path not found")
        }
        
        return try await fileSystemManager.loadImage(filePath: filePath)
    }
    
    func deletePhoto(id: UUID) async throws {
        try await deleteVehiclePhoto(id: id)
    }
}
