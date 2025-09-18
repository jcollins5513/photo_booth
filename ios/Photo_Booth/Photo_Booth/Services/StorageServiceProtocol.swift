import Foundation
import CoreData

/// Protocol defining the storage service interface
protocol StorageServiceProtocol {
    /// Save a photo session to storage
    func savePhotoSession(
        id: UUID,
        vehicleIdentifier: String,
        startDate: Date,
        status: String,
        totalAngles: Int16,
        completedAngles: Int16
    ) async throws -> PhotoSession
    
    /// Save a complete photo session
    func saveSession(_ session: PhotoSession) async throws
    
    /// Get a photo session by ID
    func getPhotoSession(id: UUID) async throws -> PhotoSession?
    
    /// Update an existing photo session
    func updatePhotoSession(
        id: UUID,
        status: String?,
        completedAngles: Int16?
    ) async throws -> PhotoSession
    
    /// Save a vehicle photo
    func saveVehiclePhoto(
        id: UUID,
        sessionId: UUID,
        angle: String,
        imageData: Data,
        timestamp: Date
    ) async throws -> VehiclePhoto
    
    /// Get a vehicle photo by ID
    func getVehiclePhoto(id: UUID) async throws -> VehiclePhoto?
    
    /// Get all photos for a session
    func getPhotosForSession(sessionId: UUID) async throws -> [VehiclePhoto]
    
    /// Delete a photo session and all associated photos
    func deletePhotoSession(id: UUID) async throws
    
    /// Delete a vehicle photo
    func deleteVehiclePhoto(id: UUID) async throws
    
    /// Get all photos
    func getAllPhotos() async throws -> [VehiclePhoto]
    
    /// Get photo data by ID
    func getPhotoData(id: UUID) async throws -> Data
    
    /// Delete photo by ID (alias for deleteVehiclePhoto)
    func deletePhoto(id: UUID) async throws
}

/// Protocol defining the file system manager interface
protocol FileSystemManagerProtocol {
    /// Save image data to file system
    func saveImage(data: Data, fileName: String) async throws -> String
    
    /// Load image data from file system
    func loadImage(filePath: String) async throws -> Data
    
    /// Delete image file from file system
    func deleteImage(filePath: String) async throws
    
    /// Get file URL for a given file name
    func getFileURL(fileName: String) -> URL
    
    /// Check if file exists
    func fileExists(filePath: String) -> Bool
    
    /// Save image with organized folder structure
    func saveImageWithOrganization(data: Data, sessionId: UUID, angle: String, quality: PhotoQuality) async throws -> String
    
    /// Get session directory URL
    func getSessionDirectory(sessionId: UUID) -> URL
    
    /// Get export directory URL
    func getExportDirectory() -> URL
    
    /// Get backup directory URL
    func getBackupDirectory() -> URL
    
    /// Get storage information
    func getStorageInfo() async -> StorageInfo
    
    /// Cleanup old export files
    func cleanupOldExports(olderThan days: Int) async throws
}

/// Storage service errors
enum StorageServiceError: Error, LocalizedError {
    case sessionNotFound
    case photoNotFound
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    case invalidData
    case coreDataError(String)
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Photo session not found"
        case .photoNotFound:
            return "Vehicle photo not found"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .loadFailed(let message):
            return "Failed to load: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .invalidData:
            return "Invalid data provided"
        case .coreDataError(let message):
            return "Core Data error: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}
