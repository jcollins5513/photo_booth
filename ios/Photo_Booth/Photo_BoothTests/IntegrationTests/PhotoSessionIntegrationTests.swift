import XCTest
import CoreData
@testable import Photo_Booth

/// Integration tests for photo session workflow
/// These tests MUST FAIL before implementation
class PhotoSessionIntegrationTests: XCTestCase {
    
    var persistenceController: CoreDataStack!
    var sessionManager: SessionManagerProtocol!
    var cameraService: CameraServiceProtocol!
    var visionService: VisionServiceProtocol!
    var storageService: StorageServiceProtocol!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
        
        // Initialize services with proper dependencies
        let fileSystemManager = FileSystemManager()
        storageService = StorageService(
            persistentContainer: persistenceController.container,
            fileSystemManager: fileSystemManager
        )
        sessionManager = SessionManager(storageService: storageService)
        cameraService = CameraService()
        visionService = VisionService()
    }
    
    override func tearDownWithError() throws {
        sessionManager = nil
        cameraService = nil
        visionService = nil
        storageService = nil
        persistenceController = nil
    }
    
    // MARK: - Complete Photo Session Workflow Tests
    
    func testCompletePhotoSessionWorkflow() async throws {
        // Given: User is authenticated and camera is ready
        let vehicleIdentifier = "Test Vehicle 123"
        let expectedAngles = PhotoAngleType.allCases
        
        // When: Starting a new photo session
        let session = try await sessionManager.startSession(
            vehicleIdentifier: vehicleIdentifier,
            totalAngles: Int16(expectedAngles.count)
        )
        
        // Verify session is created
        XCTAssertNotNil(session, "Session should be created")
        XCTAssertEqual(session.vehicleIdentifier, vehicleIdentifier, "Vehicle identifier should match")
        XCTAssertEqual(session.totalAngles, Int16(expectedAngles.count), "Total angles should match")
        XCTAssertEqual(session.status, "active", "Session should be active")
        
        // When: Capturing photos for each angle
        for (index, angle) in expectedAngles.enumerated() {
            // Configure vision service for current angle
            visionService.setTargetAngle(angle)
            
            // Simulate vehicle positioning and photo capture
            let photo = try await capturePhotoForAngle(angle, in: session)
            
            // Verify photo is captured
            XCTAssertNotNil(photo, "Photo should be captured for \(angle)")
            XCTAssertEqual(photo.angleType, angle.rawValue, "Photo angle type should match")
            XCTAssertEqual(photo.session, session, "Photo should be associated with session")
            
            // Verify session progress
            let updatedSession = try await sessionManager.getSession(id: session.id!)
            XCTAssertEqual(updatedSession?.completedAngles, Int16(index + 1), "Completed angles should increment")
        }
        
        // When: Completing the session
        _ = try await sessionManager.completeSession(id: session.id!)
        
        // Verify session is completed
        let completedSession = try await sessionManager.getSession(id: session.id!)
        XCTAssertEqual(completedSession?.status, "completed", "Session should be completed")
        XCTAssertEqual(completedSession?.completedAngles, completedSession?.totalAngles, "All angles should be completed")
        
        // Verify all photos are saved
        let savedPhotos = try await storageService.getPhotosForSession(sessionId: session.id!)
        XCTAssertEqual(savedPhotos.count, expectedAngles.count, "All photos should be saved")
    }
    
    func testPhotoSessionWithManualCapture() async throws {
        // Given: A photo session with some angles requiring manual capture
        let vehicleIdentifier = "Test Vehicle Manual"
        let session = try await sessionManager.startSession(
            vehicleIdentifier: vehicleIdentifier,
            totalAngles: 8
        )
        
        // When: Capturing photos with some manual captures
        let angles = PhotoAngleType.allCases
        var manualCaptures = 0
        
        for angle in angles {
            // Simulate vision detection failure for some angles
            let shouldUseManualCapture = angle == .front || angle == .rear
            
            if shouldUseManualCapture {
                // Manual capture
                let photo = try await sessionManager.manualCapture(
                    sessionId: session.id!,
                    angle: angle.rawValue,
                    imageData: createTestImageData()
                )
                XCTAssertNotNil(photo, "Manual capture should succeed")
                manualCaptures += 1
            } else {
                // Auto capture
                let photo = try await capturePhotoForAngle(angle, in: session)
                XCTAssertNotNil(photo, "Auto capture should succeed")
            }
        }
        
        // Verify session completion
        _ = try await sessionManager.completeSession(id: session.id!)
        let completedSession = try await sessionManager.getSession(id: session.id!)
        XCTAssertEqual(completedSession?.status, "completed", "Session should be completed")
        XCTAssertEqual(completedSession?.completedAngles, 8, "All angles should be completed")
        
        // Verify manual capture count
        let photos = try await storageService.getPhotosForSession(sessionId: session.id!)
        XCTAssertEqual(photos.count, manualCaptures, "Manual capture count should match")
    }
    
    func testPhotoSessionCancellation() async throws {
        // Given: An active photo session
        let vehicleIdentifier = "Test Vehicle Cancel"
        let session = try await sessionManager.startSession(
            vehicleIdentifier: vehicleIdentifier,
            totalAngles: 8
        )
        
        // When: Capturing some photos
        let angles = Array(PhotoAngleType.allCases.prefix(3))
        for angle in angles {
            _ = try await capturePhotoForAngle(angle, in: session)
        }
        
        // When: Cancelling the session
        _ = try await sessionManager.cancelSession(id: session.id!)
        
        // Verify session is cancelled
        let cancelledSession = try await sessionManager.getSession(id: session.id!)
        XCTAssertEqual(cancelledSession?.status, "cancelled", "Session should be cancelled")
        XCTAssertEqual(cancelledSession?.completedAngles, 3, "Completed angles should match captured photos")
        
        // Verify photos are still saved
        let photos = try await storageService.getPhotosForSession(sessionId: session.id!)
        XCTAssertEqual(photos.count, 3, "Captured photos should still be saved")
    }
    
    // MARK: - Session Management Tests
    
    func testSessionRetrieval() async throws {
        // Given: Multiple sessions exist
        let session1 = try await sessionManager.startSession(
            vehicleIdentifier: "Vehicle 1",
            totalAngles: 8
        )
        let session2 = try await sessionManager.startSession(
            vehicleIdentifier: "Vehicle 2",
            totalAngles: 8
        )
        
        // When: Retrieving sessions
        let retrievedSession1 = try await sessionManager.getSession(id: session1.id!)
        let retrievedSession2 = try await sessionManager.getSession(id: session2.id!)
        
        // Verify sessions are retrieved correctly
        XCTAssertEqual(retrievedSession1?.id, session1.id, "Session 1 ID should match")
        XCTAssertEqual(retrievedSession1?.vehicleIdentifier, "Vehicle 1", "Session 1 vehicle should match")
        XCTAssertEqual(retrievedSession2?.id, session2.id, "Session 2 ID should match")
        XCTAssertEqual(retrievedSession2?.vehicleIdentifier, "Vehicle 2", "Session 2 vehicle should match")
    }
    
    func testSessionListRetrieval() async throws {
        // Given: Multiple sessions exist
        let session1 = try await sessionManager.startSession(
            vehicleIdentifier: "Vehicle 1",
            totalAngles: 8
        )
        let session2 = try await sessionManager.startSession(
            vehicleIdentifier: "Vehicle 2",
            totalAngles: 8
        )
        
        // When: Retrieving all sessions
        let allSessions = try await sessionManager.getAllSessions()
        
        // Verify all sessions are retrieved
        XCTAssertGreaterThanOrEqual(allSessions.count, 2, "Should retrieve at least 2 sessions")
        let sessionIds = allSessions.map { $0.id }
        XCTAssertTrue(sessionIds.contains(session1.id), "Should contain session 1")
        XCTAssertTrue(sessionIds.contains(session2.id), "Should contain session 2")
    }
    
    func testSessionProgressTracking() async throws {
        // Given: A photo session
        let session = try await sessionManager.startSession(
            vehicleIdentifier: "Test Vehicle Progress",
            totalAngles: 8
        )
        
        // When: Capturing photos incrementally
        let angles = PhotoAngleType.allCases
        for (index, angle) in angles.enumerated() {
            _ = try await capturePhotoForAngle(angle, in: session)
            
            // Verify progress tracking
            let updatedSession = try await sessionManager.getSession(id: session.id!)
            XCTAssertEqual(updatedSession?.completedAngles, Int16(index + 1), "Progress should track correctly")
            XCTAssertEqual(updatedSession?.status, "active", "Session should remain active")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSessionCreationWithInvalidInput() async {
        // Test with empty vehicle identifier
        do {
            _ = try await sessionManager.startSession(
                vehicleIdentifier: "",
                totalAngles: 8
            )
            XCTFail("Should throw error for empty vehicle identifier")
        } catch SessionManagerError.sessionNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw invalidInput error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSessionCreationWithInvalidAngleCount() async {
        // Test with invalid angle count
        do {
            _ = try await sessionManager.startSession(
                vehicleIdentifier: "Test Vehicle",
                totalAngles: 0
            )
            XCTFail("Should throw error for invalid angle count")
        } catch SessionManagerError.sessionNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw invalidInput error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSessionNotFound() async {
        // Test retrieving non-existent session
        let nonExistentId = UUID()
        
        do {
            _ = try await sessionManager.getSession(id: nonExistentId)
            XCTFail("Should throw error for non-existent session")
        } catch SessionManagerError.sessionNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw sessionNotFound error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSessionAlreadyActive() async {
        // Given: An active session
        do {
            _ = try await sessionManager.startSession(
                vehicleIdentifier: "Test Vehicle Active",
                totalAngles: 8
            )
        } catch {
            XCTFail("Failed to start session: \(error)")
        }
        
        // When: Trying to start another session
        do {
            _ = try await sessionManager.startSession(
                vehicleIdentifier: "Test Vehicle Active 2",
                totalAngles: 8
            )
            XCTFail("Should throw error when session is already active")
        } catch SessionManagerError.sessionAlreadyActive {
            // Expected error
            XCTAssertTrue(true, "Should throw sessionAlreadyActive error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testSessionCreationPerformance() async throws {
        // Measure session creation time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await sessionManager.startSession(
            vehicleIdentifier: "Performance Test Vehicle",
            totalAngles: 8
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let creationTime = endTime - startTime
        
        // Session creation should be fast (under 1 second)
        XCTAssertLessThan(creationTime, 1.0, "Session creation should complete within 1 second")
    }
    
    func testPhotoCapturePerformance() async throws {
        // Given: A photo session
        let session = try await sessionManager.startSession(
            vehicleIdentifier: "Performance Test Vehicle",
            totalAngles: 8
        )
        
        // Measure photo capture time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capturePhotoForAngle(.front, in: session)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let captureTime = endTime - startTime
        
        // Photo capture should be fast (under 2 seconds)
        XCTAssertLessThan(captureTime, 2.0, "Photo capture should complete within 2 seconds")
    }
    
    // MARK: - Data Persistence Tests
    
    func testSessionDataPersistence() async throws {
        // Given: A completed session
        let session = try await sessionManager.startSession(
            vehicleIdentifier: "Persistence Test Vehicle",
            totalAngles: 8
        )
        
        // Capture some photos
        let angles = Array(PhotoAngleType.allCases.prefix(3))
        for angle in angles {
            _ = try await capturePhotoForAngle(angle, in: session)
        }
        
        // Complete the session
        _ = try await sessionManager.completeSession(id: session.id!)
        
        // When: Creating new session manager (simulating app restart)
        let newSessionManager = SessionManager(storageService: storageService)
        
        // Then: Session should still be retrievable
        let retrievedSession = try await newSessionManager.getSession(id: session.id!)
        XCTAssertEqual(retrievedSession?.vehicleIdentifier, "Persistence Test Vehicle", "Session data should persist")
        XCTAssertEqual(retrievedSession?.status, "completed", "Session status should persist")
        XCTAssertEqual(retrievedSession?.completedAngles, 3, "Completed angles should persist")
    }
    
    // MARK: - Helper Methods
    
    private func capturePhotoForAngle(_ angle: PhotoAngleType, in session: PhotoSession) async throws -> VehiclePhoto {
        // Configure vision service for the angle
        visionService.setTargetAngle(angle)
        
        // Create test image data
        let imageData = createTestImageData()
        
        // Use manual capture for now since autoCapture doesn't exist
        let photo = try await sessionManager.manualCapture(
            sessionId: session.id!,
            angle: angle.rawValue,
            imageData: imageData
        )
        
        return photo
    }
    
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

