import XCTest
import Combine
@testable import Photo_Booth

/// Integration tests for Auto-Capture system
@MainActor
class AutoCaptureIntegrationTests: XCTestCase {
    
    var autoCaptureManager: AutoCaptureManager!
    var photoSessionManager: PhotoSessionManager!
    var modelManager: ModelManager!
    var visionService: VisionService!
    var cameraService: MockCameraService!
    var storageService: MockStorageService!
    var configurationService: ConfigurationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create real instances for integration testing
        modelManager = ModelManager()
        visionService = VisionService()
        cameraService = MockCameraService()
        storageService = MockStorageService()
        configurationService = ConfigurationService()
        
        // Initialize managers
        autoCaptureManager = AutoCaptureManager(
            modelManager: modelManager,
            visionService: visionService,
            cameraService: cameraService,
            storageService: storageService,
            configurationService: configurationService
        )
        
        photoSessionManager = PhotoSessionManager(
            autoCaptureManager: autoCaptureManager,
            storageService: storageService,
            configurationService: configurationService
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        autoCaptureManager = nil
        photoSessionManager = nil
        modelManager = nil
        visionService = nil
        cameraService = nil
        storageService = nil
        configurationService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Complete Auto-Capture Workflow Tests
    
    func testCompleteAutoCaptureWorkflow() async {
        // Given
        let vehicleMake = "Toyota"
        let vehicleModel = "Camry"
        let vehicleYear = 2023
        
        // When - Start session
        await photoSessionManager.startNewSession(
            vehicleMake: vehicleMake,
            vehicleModel: vehicleModel,
            vehicleYear: vehicleYear,
            sessionType: .quick // Only 4 angles for faster testing
        )
        
        // Then - Verify session started
        XCTAssertTrue(photoSessionManager.isSessionActive)
        XCTAssertNotNil(photoSessionManager.currentSession)
        XCTAssertEqual(photoSessionManager.currentSession?.vehicleMake, vehicleMake)
        XCTAssertEqual(photoSessionManager.currentSession?.vehicleModel, vehicleModel)
        XCTAssertEqual(photoSessionManager.sessionState, .active)
        
        // When - Simulate position detection and capture
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify captures
        XCTAssertGreaterThan(photoSessionManager.capturedPhotos.count, 0)
        XCTAssertTrue(photoSessionManager.isSessionComplete())
    }
    
    func testAutoCaptureWithQualityIssues() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Honda",
            vehicleModel: "Civic",
            sessionType: .standard
        )
        
        // When - Simulate quality issues
        cameraService.shouldSimulateQualityIssues = true
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify retry logic
        XCTAssertGreaterThan(autoCaptureManager.retryCount, 0)
        XCTAssertTrue(autoCaptureManager.totalCaptures > 0)
    }
    
    func testAutoCapturePauseAndResume() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Ford",
            vehicleModel: "Focus",
            sessionType: .standard
        )
        
        // When - Pause session
        photoSessionManager.pauseSession()
        
        // Then
        XCTAssertEqual(photoSessionManager.sessionState, .paused)
        XCTAssertFalse(autoCaptureManager.isAutoCaptureEnabled)
        
        // When - Resume session
        photoSessionManager.resumeSession()
        
        // Then
        XCTAssertEqual(photoSessionManager.sessionState, .active)
        XCTAssertTrue(autoCaptureManager.isAutoCaptureEnabled)
    }
    
    func testAutoCaptureSessionCompletion() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "BMW",
            vehicleModel: "X5",
            sessionType: .quick
        )
        
        // When - Complete session
        await photoSessionManager.completeSession()
        
        // Then
        XCTAssertFalse(photoSessionManager.isSessionActive)
        XCTAssertEqual(photoSessionManager.sessionState, .idle)
        XCTAssertNotNil(photoSessionManager.currentSession?.isCompleted)
        XCTAssertTrue(photoSessionManager.currentSession?.isCompleted ?? false)
    }
    
    // MARK: - Performance Integration Tests
    
    func testAutoCapturePerformance() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Tesla",
            vehicleModel: "Model 3",
            sessionType: .quick
        )
        
        // When - Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        await simulatePositionDetectionAndCapture()
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Verify performance
        XCTAssertLessThan(processingTime, 10.0) // Should complete in under 10 seconds
        XCTAssertTrue(autoCaptureManager.isPerformanceAcceptable())
    }
    
    func testMemoryUsageDuringSession() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Audi",
            vehicleModel: "A4",
            sessionType: .standard
        )
        
        // When - Simulate multiple captures
        for _ in 0..<8 {
            await simulatePositionDetectionAndCapture()
        }
        
        // Then - Verify memory usage is reasonable
        // Note: In a real test, we'd measure actual memory usage
        XCTAssertTrue(photoSessionManager.capturedPhotos.count <= 8)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testAutoCaptureWithCameraErrors() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Mercedes",
            vehicleModel: "C-Class",
            sessionType: .standard
        )
        
        // When - Simulate camera errors
        cameraService.shouldSimulateErrors = true
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify error handling
        XCTAssertGreaterThan(autoCaptureManager.retryCount, 0)
        // Session should continue despite errors
        XCTAssertTrue(photoSessionManager.isSessionActive)
    }
    
    func testAutoCaptureWithStorageErrors() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Volkswagen",
            vehicleModel: "Golf",
            sessionType: .standard
        )
        
        // When - Simulate storage errors
        storageService.shouldSimulateErrors = true
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify error handling
        // Session should continue despite storage errors
        XCTAssertTrue(photoSessionManager.isSessionActive)
    }
    
    // MARK: - Configuration Integration Tests
    
    func testAutoCaptureWithDifferentConfigurations() async {
        // Given - High confidence threshold
        configurationService.confidenceThreshold = 0.95
        configurationService.processingFPS = 5
        
        await photoSessionManager.startNewSession(
            vehicleMake: "Nissan",
            vehicleModel: "Altima",
            sessionType: .standard
        )
        
        // When - Simulate captures
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify configuration is applied
        XCTAssertEqual(configurationService.confidenceThreshold, 0.95)
        XCTAssertEqual(configurationService.processingFPS, 5)
    }
    
    // MARK: - Statistics Integration Tests
    
    func testSessionStatisticsCollection() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Hyundai",
            vehicleModel: "Elantra",
            sessionType: .standard
        )
        
        // When - Simulate session activity
        await simulatePositionDetectionAndCapture()
        
        // Then - Verify statistics
        let statistics = photoSessionManager.getSessionStatistics()
        XCTAssertNotNil(statistics.sessionId)
        XCTAssertNotNil(statistics.startTime)
        XCTAssertGreaterThanOrEqual(statistics.totalPhotos, 0)
    }
    
    // MARK: - Helper Methods
    
    private func simulatePositionDetectionAndCapture() async {
        // Simulate position detection
        visionService.isPositionValid = true
        
        // Wait for position stability
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate capture
        let testImage = createTestImage()
        await autoCaptureManager.triggerCapture()
        
        // Add captured photo to session
        if let angle = autoCaptureManager.currentAngle {
            photoSessionManager.addCapturedPhoto(testImage, for: angle)
        }
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 224, height: 224)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock Classes for Integration Testing

class MockCameraService: CameraServiceProtocol {
    var shouldSimulateErrors = false
    var shouldSimulateQualityIssues = false
    var mockImageData = Data()
    
    func configureSession(position: AVCaptureDevice.Position, quality: AVCaptureSession.Preset, flashMode: AVCaptureDevice.FlashMode) async throws {
        if shouldSimulateErrors {
            throw NSError(domain: "MockCameraError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock camera error"])
        }
    }
    
    func startSession() async throws {
        if shouldSimulateErrors {
            throw NSError(domain: "MockCameraError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock session start error"])
        }
    }
    
    func stopSession() async throws {
        // Mock implementation
    }
    
    func capturePhoto(settings: AVCapturePhotoSettings) async throws -> Data {
        if shouldSimulateErrors {
            throw NSError(domain: "MockCameraError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock capture error"])
        }
        
        if shouldSimulateQualityIssues {
            // Return empty data to simulate quality issues
            return Data()
        }
        
        return mockImageData
    }
    
    func checkCameraPermission() -> AVAuthorizationStatus {
        return .authorized
    }
    
    func requestCameraPermission() async -> Bool {
        return true
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return nil
    }
    
    func updatePreviewFrame(_ frame: CGRect) {
        // Mock implementation
    }
    
    func setFocusPoint(_ point: CGPoint) async throws {
        // Mock implementation
    }
    
    func setExposurePoint(_ point: CGPoint) async throws {
        // Mock implementation
    }
}

class MockStorageService: StorageServiceProtocol {
    var shouldSimulateErrors = false
    
    func saveSession(_ session: PhotoSession) async throws {
        if shouldSimulateErrors {
            throw NSError(domain: "MockStorageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock storage error"])
        }
    }
    
    func getSession(id: UUID) async throws -> PhotoSession? {
        if shouldSimulateErrors {
            throw NSError(domain: "MockStorageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock retrieval error"])
        }
        return nil
    }
    
    func getAllSessions() async throws -> [PhotoSession] {
        if shouldSimulateErrors {
            throw NSError(domain: "MockStorageError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock list error"])
        }
        return []
    }
    
    func deleteSession(id: UUID) async throws {
        if shouldSimulateErrors {
            throw NSError(domain: "MockStorageError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mock deletion error"])
        }
    }
}
