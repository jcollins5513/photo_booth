import XCTest
import CoreData
@testable import Photo_Booth

class StorageServiceTests: XCTestCase {
    
    var storageService: StorageService!
    var mockFileSystemManager: MockFileSystemManager!
    var persistentContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "VehiclePhotoBooth")
        let description = persistentContainer.persistentStoreDescriptions.first!
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        // Create mock file system manager
        mockFileSystemManager = MockFileSystemManager()
        
        // Initialize storage service
        storageService = StorageService(
            persistentContainer: persistentContainer,
            fileSystemManager: mockFileSystemManager
        )
    }
    
    override func tearDownWithError() throws {
        storageService = nil
        mockFileSystemManager = nil
        persistentContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Photo Session Management Tests
    
    func testSavePhotoSession() async throws {
        // Given
        let sessionId = UUID()
        let vehicleIdentifier = "TEST123"
        let startDate = Date()
        let status = "in_progress"
        let totalAngles: Int16 = 8
        let completedAngles: Int16 = 0
        
        // When
        let savedSession = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: startDate,
            status: status,
            totalAngles: totalAngles,
            completedAngles: completedAngles
        )
        
        // Then
        XCTAssertEqual(savedSession.id, sessionId)
        XCTAssertEqual(savedSession.vehicleIdentifier, vehicleIdentifier)
        XCTAssertEqual(savedSession.startDate, startDate)
        XCTAssertEqual(savedSession.status, status)
        XCTAssertEqual(savedSession.totalAngles, totalAngles)
        XCTAssertEqual(savedSession.completedAngles, completedAngles)
    }
    
    func testGetPhotoSession() async throws {
        // Given
        let sessionId = UUID()
        let vehicleIdentifier = "TEST123"
        let startDate = Date()
        let status = "in_progress"
        let totalAngles: Int16 = 8
        let completedAngles: Int16 = 0
        
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: startDate,
            status: status,
            totalAngles: totalAngles,
            completedAngles: completedAngles
        )
        
        // When
        let retrievedSession = try await storageService.getPhotoSession(id: sessionId)
        
        // Then
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.id, sessionId)
        XCTAssertEqual(retrievedSession?.vehicleIdentifier, vehicleIdentifier)
    }
    
    func testGetNonExistentPhotoSession() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedSession = try await storageService.getPhotoSession(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedSession)
    }
    
    func testUpdatePhotoSession() async throws {
        // Given
        let sessionId = UUID()
        let vehicleIdentifier = "TEST123"
        let startDate = Date()
        let status = "in_progress"
        let totalAngles: Int16 = 8
        let completedAngles: Int16 = 0
        
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: vehicleIdentifier,
            startDate: startDate,
            status: status,
            totalAngles: totalAngles,
            completedAngles: completedAngles
        )
        
        // When
        let updatedSession = try await storageService.updatePhotoSession(
            id: sessionId,
            status: "completed",
            completedAngles: 8
        )
        
        // Then
        XCTAssertEqual(updatedSession.status, "completed")
        XCTAssertEqual(updatedSession.completedAngles, 8)
    }
    
    func testUpdateNonExistentPhotoSession() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When & Then
        do {
            _ = try await storageService.updatePhotoSession(
                id: nonExistentId,
                status: "completed",
                completedAngles: 8
            )
            XCTFail("Should have thrown an error for non-existent session")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    // MARK: - Vehicle Photo Management Tests
    
    func testSaveVehiclePhoto() async throws {
        // Given
        let sessionId = UUID()
        let photoId = UUID()
        let angle = "front"
        let imageData = createTestImageData()
        let timestamp = Date()
        
        // First create a session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When
        let savedPhoto = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: angle,
            imageData: imageData,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(savedPhoto.id, photoId)
        XCTAssertEqual(savedPhoto.angleType, angle)
        XCTAssertEqual(savedPhoto.captureDate, timestamp)
        XCTAssertNotNil(savedPhoto.filePath)
        XCTAssertNotNil(savedPhoto.session)
        XCTAssertEqual(savedPhoto.session?.id, sessionId)
    }
    
    func testSaveVehiclePhotoWithNonExistentSession() async throws {
        // Given
        let nonExistentSessionId = UUID()
        let photoId = UUID()
        let angle = "front"
        let imageData = createTestImageData()
        let timestamp = Date()
        
        // When & Then
        do {
            _ = try await storageService.saveVehiclePhoto(
                id: photoId,
                sessionId: nonExistentSessionId,
                angle: angle,
                imageData: imageData,
                timestamp: timestamp
            )
            XCTFail("Should have thrown an error for non-existent session")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func testGetVehiclePhoto() async throws {
        // Given
        let sessionId = UUID()
        let photoId = UUID()
        let angle = "front"
        let imageData = createTestImageData()
        let timestamp = Date()
        
        // Create session and photo
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: angle,
            imageData: imageData,
            timestamp: timestamp
        )
        
        // When
        let retrievedPhoto = try await storageService.getVehiclePhoto(id: photoId)
        
        // Then
        XCTAssertNotNil(retrievedPhoto)
        XCTAssertEqual(retrievedPhoto?.id, photoId)
        XCTAssertEqual(retrievedPhoto?.angleType, angle)
    }
    
    func testGetPhotosForSession() async throws {
        // Given
        let sessionId = UUID()
        let photoId1 = UUID()
        let photoId2 = UUID()
        let imageData = createTestImageData()
        
        // Create session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // Create photos
        _ = try await storageService.saveVehiclePhoto(
            id: photoId1,
            sessionId: sessionId,
            angle: "front",
            imageData: imageData,
            timestamp: Date()
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId2,
            sessionId: sessionId,
            angle: "side",
            imageData: imageData,
            timestamp: Date()
        )
        
        // When
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        // Then
        XCTAssertEqual(photos.count, 2)
        XCTAssertTrue(photos.contains { $0.id == photoId1 })
        XCTAssertTrue(photos.contains { $0.id == photoId2 })
    }
    
    func testGetPhotoData() async throws {
        // Given
        let sessionId = UUID()
        let photoId = UUID()
        let imageData = createTestImageData()
        
        // Create session and photo
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: "front",
            imageData: imageData,
            timestamp: Date()
        )
        
        // When
        let retrievedData = try await storageService.getPhotoData(id: photoId)
        
        // Then
        XCTAssertEqual(retrievedData, imageData)
    }
    
    // MARK: - Deletion Tests
    
    func testDeletePhotoSession() async throws {
        // Given
        let sessionId = UUID()
        let photoId = UUID()
        let imageData = createTestImageData()
        
        // Create session and photo
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: "front",
            imageData: imageData,
            timestamp: Date()
        )
        
        // When
        try await storageService.deletePhotoSession(id: sessionId)
        
        // Then
        let retrievedSession = try await storageService.getPhotoSession(id: sessionId)
        let retrievedPhoto = try await storageService.getVehiclePhoto(id: photoId)
        
        XCTAssertNil(retrievedSession)
        XCTAssertNil(retrievedPhoto)
    }
    
    func testDeleteVehiclePhoto() async throws {
        // Given
        let sessionId = UUID()
        let photoId = UUID()
        let imageData = createTestImageData()
        
        // Create session and photo
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId,
            sessionId: sessionId,
            angle: "front",
            imageData: imageData,
            timestamp: Date()
        )
        
        // When
        try await storageService.deleteVehiclePhoto(id: photoId)
        
        // Then
        let retrievedPhoto = try await storageService.getVehiclePhoto(id: photoId)
        XCTAssertNil(retrievedPhoto)
    }
    
    func testDeleteNonExistentPhotoSession() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When & Then
        do {
            try await storageService.deletePhotoSession(id: nonExistentId)
            XCTFail("Should have thrown an error for non-existent session")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func testDeleteNonExistentVehiclePhoto() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When & Then
        do {
            try await storageService.deleteVehiclePhoto(id: nonExistentId)
            XCTFail("Should have thrown an error for non-existent photo")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    // MARK: - Gallery Tests
    
    func testGetAllPhotos() async throws {
        // Given
        let sessionId1 = UUID()
        let sessionId2 = UUID()
        let photoId1 = UUID()
        let photoId2 = UUID()
        let imageData = createTestImageData()
        
        // Create sessions and photos
        _ = try await storageService.savePhotoSession(
            id: sessionId1,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.savePhotoSession(
            id: sessionId2,
            vehicleIdentifier: "TEST456",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId1,
            sessionId: sessionId1,
            angle: "front",
            imageData: imageData,
            timestamp: Date()
        )
        
        _ = try await storageService.saveVehiclePhoto(
            id: photoId2,
            sessionId: sessionId2,
            angle: "side",
            imageData: imageData,
            timestamp: Date()
        )
        
        // When
        let allPhotos = try await storageService.getAllPhotos()
        
        // Then
        XCTAssertEqual(allPhotos.count, 2)
        XCTAssertTrue(allPhotos.contains { $0.id == photoId1 })
        XCTAssertTrue(allPhotos.contains { $0.id == photoId2 })
    }
    
    // MARK: - Error Handling Tests
    
    func testFileSystemErrorHandling() async throws {
        // Given
        mockFileSystemManager.shouldThrowError = true
        let sessionId = UUID()
        let photoId = UUID()
        let imageData = createTestImageData()
        
        // Create session
        _ = try await storageService.savePhotoSession(
            id: sessionId,
            vehicleIdentifier: "TEST123",
            startDate: Date(),
            status: "in_progress",
            totalAngles: 8,
            completedAngles: 0
        )
        
        // When & Then
        do {
            _ = try await storageService.saveVehiclePhoto(
                id: photoId,
                sessionId: sessionId,
                angle: "front",
                imageData: imageData,
                timestamp: Date()
            )
            XCTFail("Should have thrown an error when file system fails")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        // Create a simple test image
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
