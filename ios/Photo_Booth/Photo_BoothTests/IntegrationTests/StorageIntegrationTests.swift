import XCTest
import CoreData
@testable import Photo_Booth

/// Integration tests for storage and data persistence
/// These tests MUST FAIL before implementation
class StorageIntegrationTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var storageService: StorageServiceProtocol!
    var fileSystemManager: FileSystemManagerProtocol!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
        
        // These will fail until services are implemented
        storageService = StorageService()
        fileSystemManager = FileSystemManager()
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
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
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
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // When: Retrieving photo session
        let retrievedSession = try await storageService.getPhotoSession(id: sessionId)
        
        // Then: Session should be retrieved correctly
        XCTAssertNotNil(retrievedSession, "Session should be retrieved")
        XCTAssertEqual(retrievedSession.id, sessionId, "Retrieved session ID should match")
        XCTAssertEqual(retrievedSession.vehicleIdentifier, vehicleIdentifier, "Retrieved vehicle identifier should match")
        XCTAssertEqual(retrievedSession.totalAngles, 8, "Retrieved total angles should match")
    }
    
    func testPhotoSessionUpdate() async throws {
        // Given: A saved photo session
        let sessionId = UUID()
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Update",
            startDate: Date(),
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // When: Updating session
        try await storageService.updatePhotoSession(
            id: sessionId,
            completedAngles: 4,
            status: "active"
        )
        
        // Then: Session should be updated
        let updatedSession = try await storageService.getPhotoSession(id: sessionId)
        XCTAssertEqual(updatedSession.completedAngles, 4, "Completed angles should be updated")
        XCTAssertEqual(updatedSession.status, "active", "Status should remain active")
    }
    
    func testPhotoSessionCompletion() async throws {
        // Given: A saved photo session
        let sessionId = UUID()
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Complete",
            startDate: Date(),
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // When: Completing session
        try await storageService.updatePhotoSession(
            id: sessionId,
            completedAngles: 8,
            status: "completed"
        )
        
        // Then: Session should be completed
        let completedSession = try await storageService.getPhotoSession(id: sessionId)
        XCTAssertEqual(completedSession.completedAngles, 8, "All angles should be completed")
        XCTAssertEqual(completedSession.status, "completed", "Session should be completed")
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
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // When: Saving vehicle photo
        let photo = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angleType: angleType,
            imageData: imageData,
            confidence: 0.95,
            isAutoCaptured: true
        )
        
        // Then: Photo should be saved
        XCTAssertNotNil(photo, "Photo should be saved")
        XCTAssertEqual(photo.id, photoId, "Photo ID should match")
        XCTAssertEqual(photo.angleType, angleType.rawValue, "Angle type should match")
        XCTAssertEqual(photo.confidenceScore, 0.95, "Confidence score should match")
        XCTAssertTrue(photo.isAutoCaptured, "Auto captured flag should match")
        XCTAssertNotNil(photo.filePath, "File path should be set")
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
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // Save photo
        let savedPhoto = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angleType: angleType,
            imageData: imageData,
            confidence: 0.95,
            isAutoCaptured: true
        )
        
        // When: Retrieving vehicle photo
        let retrievedPhoto = try await storageService.getVehiclePhoto(id: photoId)
        
        // Then: Photo should be retrieved correctly
        XCTAssertNotNil(retrievedPhoto, "Photo should be retrieved")
        XCTAssertEqual(retrievedPhoto.id, photoId, "Retrieved photo ID should match")
        XCTAssertEqual(retrievedPhoto.angleType, angleType.rawValue, "Retrieved angle type should match")
        XCTAssertEqual(retrievedPhoto.confidenceScore, 0.95, "Retrieved confidence score should match")
    }
    
    func testVehiclePhotoListRetrieval() async throws {
        // Given: A session with multiple photos
        let sessionId = UUID()
        let angleTypes = [PhotoAngleType.front, PhotoAngleType.side, PhotoAngleType.rear]
        
        // Create session first
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Test Vehicle Multiple Photos",
            startDate: Date(),
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // Save multiple photos
        for (index, angleType) in angleTypes.enumerated() {
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angleType: angleType,
                imageData: createTestImageData(),
                confidence: 0.9,
                isAutoCaptured: true
            )
        }
        
        // When: Retrieving photos for session
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        // Then: All photos should be retrieved
        XCTAssertEqual(photos.count, angleTypes.count, "All photos should be retrieved")
        
        let retrievedAngleTypes = photos.map { PhotoAngleType(rawValue: $0.angleType)! }
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
            fileName: fileName,
            sessionId: sessionId
        )
        
        // Then: File should be stored
        XCTAssertNotNil(filePath, "File path should be returned")
        XCTAssertTrue(filePath.contains(fileName), "File path should contain file name")
        XCTAssertTrue(filePath.contains(sessionId.uuidString), "File path should contain session ID")
        
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
            fileName: fileName,
            sessionId: sessionId
        )
        
        // When: Deleting image file
        try await fileSystemManager.deleteImage(filePath: filePath)
        
        // Then: File should be deleted
        do {
            _ = try await fileSystemManager.loadImage(filePath: filePath)
            XCTFail("Should throw error when loading deleted file")
        } catch FileSystemManagerError.fileNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw fileNotFound error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSessionDirectoryCreation() async throws {
        // Given: A session ID
        let sessionId = UUID()
        
        // When: Creating session directory
        let directoryPath = try await fileSystemManager.createSessionDirectory(sessionId: sessionId)
        
        // Then: Directory should be created
        XCTAssertNotNil(directoryPath, "Directory path should be returned")
        XCTAssertTrue(directoryPath.contains(sessionId.uuidString), "Directory path should contain session ID")
        
        // When: Checking if directory exists
        let exists = try await fileSystemManager.directoryExists(path: directoryPath)
        
        // Then: Directory should exist
        XCTAssertTrue(exists, "Directory should exist")
    }
    
    func testSessionDirectoryCleanup() async throws {
        // Given: A session directory with files
        let sessionId = UUID()
        let directoryPath = try await fileSystemManager.createSessionDirectory(sessionId: sessionId)
        
        // Add some files to the directory
        let imageData = createTestImageData()
        _ = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: "test1.jpg",
            sessionId: sessionId
        )
        _ = try await fileSystemManager.saveImage(
            data: imageData,
            fileName: "test2.jpg",
            sessionId: sessionId
        )
        
        // When: Cleaning up session directory
        try await fileSystemManager.cleanupSessionDirectory(sessionId: sessionId)
        
        // Then: Directory should be empty or deleted
        let exists = try await fileSystemManager.directoryExists(path: directoryPath)
        XCTAssertFalse(exists, "Directory should be cleaned up")
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
            totalAngles: 8,
            completedAngles: 4,
            status: "active"
        )
        
        // When: Creating new storage service (simulating app restart)
        let newStorageService = StorageService()
        
        // Then: Data should persist
        let persistedSession = try await newStorageService.getPhotoSession(id: sessionId)
        XCTAssertNotNil(persistedSession, "Session should persist across app restarts")
        XCTAssertEqual(persistedSession.vehicleIdentifier, vehicleIdentifier, "Vehicle identifier should persist")
        XCTAssertEqual(persistedSession.completedAngles, 4, "Completed angles should persist")
    }
    
    func testDataConsistency() async throws {
        // Given: A session with photos
        let sessionId = UUID()
        let angleTypes = [PhotoAngleType.front, PhotoAngleType.side, PhotoAngleType.rear]
        
        // Create session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "Consistency Test Vehicle",
            startDate: Date(),
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // Add photos
        for angleType in angleTypes {
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angleType: angleType,
                imageData: createTestImageData(),
                confidence: 0.9,
                isAutoCaptured: true
            )
        }
        
        // When: Updating session completed angles
        try await storageService.updatePhotoSession(
            id: sessionId,
            completedAngles: Int16(angleTypes.count),
            status: "active"
        )
        
        // Then: Data should be consistent
        let session = try await storageService.getPhotoSession(id: sessionId)
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        XCTAssertEqual(session.completedAngles, Int16(photos.count), "Completed angles should match photo count")
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
        } catch FileSystemManagerError.fileNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw fileNotFound error")
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
                angleType: .front,
                imageData: invalidData,
                confidence: 0.9,
                isAutoCaptured: true
            )
            XCTFail("Should throw error for invalid image data")
        } catch StorageServiceError.invalidImageData {
            // Expected error
            XCTAssertTrue(true, "Should throw invalidImageData error")
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
                totalAngles: 8,
                completedAngles: 0,
                status: "active"
            )
            
            // Add photos
            for j in 0..<photosPerSession {
                let angleType = PhotoAngleType.allCases[j]
                _ = try await storageService.saveVehiclePhoto(
                    id: UUID(),
                    sessionId: sessionId,
                    angleType: angleType,
                    imageData: createTestImageData(),
                    confidence: 0.9,
                    isAutoCaptured: true
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
            totalAngles: 8,
            completedAngles: 0,
            status: "active"
        )
        
        // Add photos
        for i in 0..<photoCount {
            let angleType = PhotoAngleType.allCases[i % PhotoAngleType.allCases.count]
            _ = try await storageService.saveVehiclePhoto(
                id: UUID(),
                sessionId: sessionId,
                angleType: angleType,
                imageData: createTestImageData(),
                confidence: 0.9,
                isAutoCaptured: true
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
