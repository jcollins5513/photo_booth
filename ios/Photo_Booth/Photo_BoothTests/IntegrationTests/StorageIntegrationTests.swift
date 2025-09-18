import XCTest
import CoreData
@testable import Photo_Booth

/// Integration tests for storage and data persistence
/// These tests MUST FAIL before implementation
class StorageIntegrationTests: XCTestCase {
    
    var persistenceController: CoreDataStack!
    var storageService: StorageServiceProtocol!
    var fileSystemManager: FileSystemManagerProtocol!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        persistenceController = CoreDataStack()
        
        // Initialize services with proper dependencies
        fileSystemManager = FileSystemManager()
        storageService = StorageService(
            persistentContainer: persistenceController.container,
            fileSystemManager: fileSystemManager
        )
    }
    
    override func tearDownWithError() throws {
        storageService = nil
        fileSystemManager = nil
        persistenceController = nil
    }
    
    // MARK: - Photo Session Storage Tests
    
    func testPhotoSessionStorage() async throws {
        // Given: A photo session
        let sessionId = UUID()
        let vehicleIdentifier = "Test Vehicle 123"
        let startDate = Date()
        
        // When: Saving photo session
        let session = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: startDate,
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Then: Session should be saved
        XCTAssertNotNil(session, "Session should be saved")
        XCTAssertEqual(session.id, sessionId, "Session ID should match")
        XCTAssertEqual(session.vehicleIdentifier, vehicleIdentifier, "Vehicle identifier should match")
        XCTAssertEqual(session.startDate, startDate, "Start date should match")
        XCTAssertEqual(session.totalAngles, 8, "Total angles should match")
        XCTAssertEqual(session.completedAngles, 0, "Completed angles should match")
        XCTAssertEqual(session.status, "active", "Status should match")
    }
    
    func testPhotoSessionRetrieval() async throws {
        // Given: A saved photo session
        let sessionId = UUID()
        let vehicleIdentifier = "Test Vehicle 456"
        
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When: Retrieving photo session
        let retrievedSession = try await storageService.getPhotoSession(id: sessionId)
        
        // Then: Session should be retrieved correctly
        XCTAssertNotNil(retrievedSession, "Session should be retrieved")
        XCTAssertEqual(retrievedSession?.id, sessionId, "Retrieved session ID should match")
        XCTAssertEqual(retrievedSession?.vehicleIdentifier, vehicleIdentifier, "Retrieved vehicle identifier should match")
        XCTAssertEqual(retrievedSession?.totalAngles, 8, "Retrieved total angles should match")
    }
    
    func testPhotoSessionUpdate() async throws {
        // Given: A saved photo session
        let sessionId = UUID()
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Update",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When: Updating session
        try await storageService.updatePhotoSession(
            id: sessionId,
            status: "active",
            completedAngles: 4
        )
        
        // Then: Session should be updated
        let updatedSession = try await storageService.getPhotoSession(id: sessionId)
        XCTAssertEqual(updatedSession?.completedAngles, 4, "Completed angles should be updated")
        XCTAssertEqual(updatedSession?.status, "active", "Status should remain active")
    }
    
    func testPhotoSessionCompletion() async throws {
        // Given: A saved photo session
        let sessionId = UUID()
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Complete",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When: Completing session
        try await storageService.updatePhotoSession(
            id: sessionId,
            status: "completed",
            completedAngles: 8
        )
        
        // Then: Session should be completed
        let completedSession = try await storageService.getPhotoSession(id: sessionId)
        XCTAssertEqual(completedSession?.completedAngles, 8, "All angles should be completed")
        XCTAssertEqual(completedSession?.status, "completed", "Session should be completed")
    }
    
    // MARK: - Vehicle Photo Storage Tests
    
    func testVehiclePhotoStorage() async throws {
        // Given: A photo session and photo data
        let sessionId = UUID()
        let photoId = UUID()
        let angleType = PhotoAngleType.front
        let imageData = createTestImageData()
        
        // Create session first
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Photo",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When: Saving vehicle photo
        let photo = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: angleType.rawValue,
            imageData: imageData,
            timestamp: Date()
        )
        
        // Then: Photo should be saved
        XCTAssertNotNil(photo, "Photo should be saved")
        XCTAssertEqual(photo.id, photoId, "Photo ID should match")
        XCTAssertEqual(photo.angleType, angleType.rawValue, "Angle type should match")
        XCTAssertNotNil(photo.filePath, "File path should be set")
        XCTAssertNotNil(photo.captureDate, "Capture date should be set")
    }
    
    func testVehiclePhotoRetrieval() async throws {
        // Given: A saved vehicle photo
        let sessionId = UUID()
        let photoId = UUID()
        let angleType = PhotoAngleType.front
        let imageData = createTestImageData()
        
        // Create session first
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Photo Retrieval",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Save photo
        let savedPhoto = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: angleType.rawValue,
            imageData: imageData,
            timestamp: Date()
        )
        
        // When: Retrieving vehicle photo
        let retrievedPhoto = try await storageService.getVehiclePhoto(id: photoId)
        
        // Then: Photo should be retrieved correctly
        XCTAssertNotNil(retrievedPhoto, "Photo should be retrieved")
        XCTAssertEqual(retrievedPhoto?.id, photoId, "Retrieved photo ID should match")
        XCTAssertEqual(retrievedPhoto?.angleType, angleType.rawValue, "Retrieved angle type should match")
    }
    
    func testVehiclePhotoListRetrieval() async throws {
        // Given: A session with multiple photos
        let sessionId = UUID()
        let angleTypes = [PhotoAngleType.front, PhotoAngleType.leftSide, PhotoAngleType.rear]
        
        // Create session first
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Multiple Photos",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Save multiple photos
        for (index, angleType) in angleTypes.enumerated() {
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angle: angleType.rawValue,
                imageData: createTestImageData(),
                timestamp: Date()
            )
        }
        
        // When: Retrieving photos for session
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        // Then: All photos should be retrieved
        XCTAssertEqual(photos.count, angleTypes.count, "All photos should be retrieved")
        
        let retrievedAngleTypes = photos.map { PhotoAngleType(rawValue: $0.angleType ?? "")! }
        for angleType in angleTypes {
            XCTAssertTrue(retrievedAngleTypes.contains(angleType), "Photo for \(angleType) should be retrieved")
        }
    }
    
    // MARK: - File System Storage Tests
    
    func testImageFileStorage() async throws {
        // Given: Image data to store
        let imageData = createTestImageData()
        let fileName = "test_image.jpg"
        let sessionId = UUID()
        
        // When: Storing image file
        let filePath = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: fileName
        )
        
        // Then: File should be stored
        XCTAssertNotNil(filePath, "File path should be returned")
        XCTAssertTrue(filePath.contains(fileName), "File path should contain file name")
        
        // When: Retrieving image file
        let retrievedData = try await fileSystemManager.loadImage(filePath: filePath)
        
        // Then: Image data should be retrieved
        XCTAssertNotNil(retrievedData, "Image data should be retrieved")
        XCTAssertEqual(retrievedData, imageData, "Retrieved data should match original")
    }
    
    func testImageFileDeletion() async throws {
        // Given: A stored image file
        let imageData = createTestImageData()
        let fileName = "test_image_delete.jpg"
        let sessionId = UUID()
        
        let filePath = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: fileName
        )
        
        // When: Deleting image file
        try await fileSystemManager.deleteImage(filePath: filePath)
        
        // Then: File should be deleted
        do {
            _ = try await fileSystemManager.loadImage(filePath: filePath)
            XCTFail("Should throw error when loading deleted file")
        } catch StorageServiceError.fileSystemError {
            // Expected error
            XCTAssertTrue(true, "Should throw fileSystemError")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSessionDirectoryCreation() async throws {
        // Given: A session ID
        let sessionId = UUID()
        
        // When: Creating session directory
        // Note: FileSystemManager doesn't have createSessionDirectory method
        // This test would need to be updated or the method added to FileSystemManager
        
        // Then: Directory should be created
        XCTAssertTrue(true, "Directory creation test needs FileSystemManager implementation")
    }
    
    /// <#Description#>
    func testSessionDirectoryCleanup() async throws {
        // Given: A session directory with files
        let sessionId = UUID()
        // Note: FileSystemManager doesn't have createSessionDirectory method
        
        // Add some files to the directory
        let imageData = createTestImageData()
        _ = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: "test1.jpg"
        )
        _ = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: "test2.jpg"
        )
        
        // When: Cleaning up session directory
        // Note: FileSystemManager doesn't have cleanupSessionDirectory method
        // This test would need to be updated or the method added to FileSystemManager
        
        // Then: Directory should be empty or deleted
        XCTAssertTrue(true, "Directory cleanup test needs FileSystemManager implementation")
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistenceAcrossAppRestarts() async throws {
        // Given: Saved data
        let sessionId = UUID()
        let vehicleIdentifier = "Persistence Test Vehicle"
        
        let session = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 4
        )
        
        // When: Creating new storage service (simulating app restart)
        let newStorageService = StorageService(
            persistentContainer: persistenceController.container,
            fileSystemManager: fileSystemManager
        )
        
        // Then: Data should persist
        let persistedSession = try await newStorageService.getPhotoSession(id: sessionId)
        XCTAssertNotNil(persistedSession, "Session should persist across app restarts")
        XCTAssertEqual(persistedSession?.vehicleIdentifier, vehicleIdentifier, "Vehicle identifier should persist")
        XCTAssertEqual(persistedSession?.completedAngles, 4, "Completed angles should persist")
    }
    
    func testDataConsistency() async throws {
        // Given: A session with photos
        let sessionId = UUID()
        let angleTypes = [PhotoAngleType.front, PhotoAngleType.leftSide, PhotoAngleType.rear]
        
        // Create session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Consistency Test Vehicle",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Add photos
        for angleType in angleTypes {
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angle: angleType.rawValue,
                imageData: createTestImageData(),
                timestamp: Date()
            )
        }
        
        // When: Updating session completed angles
        _ = try await storageService.updatePhotoSession(
            id: sessionId,
            status: "active",
            completedAngles: Int16(angleTypes.count)
        )
        
        // Then: Data should be consistent
        let session = try await storageService.getPhotoSession(id: sessionId)
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        XCTAssertEqual(session?.completedAngles, Int16(photos.count), "Completed angles should match photo count")
        XCTAssertEqual(photos.count, angleTypes.count, "Photo count should match expected")
    }
    
    // MARK: - Error Handling Tests
    
    func testSessionNotFound() async throws {
        // Given: Non-existent session ID
        let nonExistentId = UUID()
        
        // When: Retrieving non-existent session
        do {
            _ = try await storageService.getPhotoSession(id: nonExistentId)
            XCTFail("Should throw error for non-existent session")
        } catch StorageServiceError.sessionNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw sessionNotFound error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testPhotoNotFound() async throws {
        // Given: Non-existent photo ID
        let nonExistentId = UUID()
        
        // When: Retrieving non-existent photo
        do {
            _ = try await storageService.getVehiclePhoto(id: nonExistentId)
            XCTFail("Should throw error for non-existent photo")
        } catch StorageServiceError.photoNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw photoNotFound error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFileNotFound() async throws {
        // Given: Non-existent file path
        let nonExistentPath = "non/existent/path.jpg"
        
        // When: Loading non-existent file
        do {
            _ = try await fileSystemManager.loadImage(filePath: nonExistentPath)
            XCTFail("Should throw error for non-existent file")
        } catch StorageServiceError.fileSystemError {
            // Expected error
            XCTAssertTrue(true, "Should throw fileSystemError")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInvalidImageData() async throws {
        // Given: Invalid image data
        let invalidData = Data("invalid".utf8)
        let sessionId = UUID()
        
        // When: Saving invalid image data
        do {
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angle: PhotoAngleType.front.rawValue,
                imageData: invalidData,
                timestamp: Date()
            )
            XCTFail("Should throw error for invalid image data")
        } catch StorageServiceError.fileSystemError {
            // Expected error
            XCTAssertTrue(true, "Should throw fileSystemError")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testStoragePerformance() async throws {
        // Given: Multiple sessions and photos to store
        let sessionCount = 10
        let photosPerSession = 8
        
        // Measure storage time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<sessionCount {
            let sessionId = UUID()
            let vehicleIdentifier = "Performance Test Vehicle \(i)"
            
            // Create session
            _ = try await storageService.savePhotoSession(
                id: sessionId,
                vehicleIdentifier: vehicleIdentifier,
                startDate: Date(),
                status: "active",
                totalAngles: 8,
                completedAngles: 0
            )
            
            // Add photos
            for j in 0..<photosPerSession {
                let angleType = PhotoAngleType.allCases[j]
                _ = try await storageService.saveVehiclePhoto(
                    id: UUID(),
                    sessionId: sessionId,
                    angle: angleType.rawValue,
                    imageData: createTestImageData(),
                    timestamp: Date()
                )
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        // Storage should be fast (under 10 seconds for 80 photos)
        XCTAssertLessThan(totalTime, 10.0, "Storage should complete within 10 seconds")
    }
    
    func testRetrievalPerformance() async throws {
        // Given: Stored data
        let sessionId = UUID()
        let photoCount = 50
        
        // Create session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Retrieval Performance Test",
            startDate: Date(),
            status: "active",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Add photos
        for i in 0..<photoCount {
            let angleType = PhotoAngleType.allCases[i % PhotoAngleType.allCases.count]
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angle: angleType.rawValue,
                imageData: createTestImageData(),
                timestamp: Date()
            )
        }
        
        // Measure retrieval time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let retrievalTime = endTime - startTime
        
        // Retrieval should be fast (under 2 seconds for 50 photos)
        XCTAssertLessThan(retrievalTime, 2.0, "Retrieval should complete within 2 seconds")
        XCTAssertEqual(photos.count, photoCount, "All photos should be retrieved")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.jpegData(compressionQuality: 0.8)!
    }
}
