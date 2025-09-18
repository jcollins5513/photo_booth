import XCTest
import Combine
@testable import Photo_Booth

/// Unit tests for AutoCaptureManager
@MainActor
class AutoCaptureManagerTests: XCTestCase {
    
    var autoCaptureManager: AutoCaptureManager!
    var mockModelManager: MockModelManager!
    var mockVisionService: MockVisionService!
    var mockCameraService: MockCameraService!
    var mockStorageService: MockStorageService!
    var mockConfigurationService: MockConfigurationService!
    
    override func setUp() {
        super.setUp()
        
        // Create mock dependencies
        mockModelManager = MockModelManager()
        mockVisionService = MockVisionService()
        mockCameraService = MockCameraService()
        mockStorageService = MockStorageService()
        mockConfigurationService = MockConfigurationService()
        
        // Initialize AutoCaptureManager with mocks
        autoCaptureManager = AutoCaptureManager(
            modelManager: mockModelManager,
            visionService: mockVisionService,
            cameraService: mockCameraService,
            storageService: mockStorageService,
            configurationService: mockConfigurationService
        )
    }
    
    override func tearDown() {
        autoCaptureManager = nil
        mockModelManager = nil
        mockVisionService = nil
        mockCameraService = nil
        mockStorageService = nil
        mockConfigurationService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(autoCaptureManager)
        XCTAssertFalse(autoCaptureManager.isAutoCaptureEnabled)
        XCTAssertNil(autoCaptureManager.currentSession)
        XCTAssertEqual(autoCaptureManager.sessionProgress, 0.0)
        XCTAssertEqual(autoCaptureManager.captureStatus, .idle)
    }
    
    // MARK: - Session Management Tests
    
    func testStartAutoCaptureSession() async {
        // Given
        let session = PhotoSession()
        session.id = UUID()
        session.vehicleMake = "Toyota"
        session.vehicleModel = "Camry"
        
        // When
        await autoCaptureManager.startAutoCaptureSession(session)
        
        // Then
        XCTAssertTrue(autoCaptureManager.isAutoCaptureEnabled)
        XCTAssertNotNil(autoCaptureManager.currentSession)
        XCTAssertEqual(autoCaptureManager.currentSession?.vehicleMake, "Toyota")
        XCTAssertEqual(autoCaptureManager.currentSession?.vehicleModel, "Camry")
        XCTAssertEqual(autoCaptureManager.captureStatus, .positioning)
        XCTAssertNotNil(autoCaptureManager.sessionStartTime)
    }
    
    func testStopAutoCaptureSession() async {
        // Given
        let session = PhotoSession()
        session.id = UUID()
        await autoCaptureManager.startAutoCaptureSession(session)
        
        // When
        autoCaptureManager.stopAutoCaptureSession()
        
        // Then
        XCTAssertFalse(autoCaptureManager.isAutoCaptureEnabled)
        XCTAssertNil(autoCaptureManager.currentSession)
        XCTAssertEqual(autoCaptureManager.captureStatus, .idle)
        XCTAssertEqual(autoCaptureManager.sessionProgress, 0.0)
    }
    
    func testPauseAndResumeSession() async {
        // Given
        let session = PhotoSession()
        session.id = UUID()
        await autoCaptureManager.startAutoCaptureSession(session)
        
        // When - Pause
        autoCaptureManager.pauseAutoCaptureSession()
        
        // Then
        XCTAssertFalse(autoCaptureManager.isAutoCaptureEnabled)
        XCTAssertEqual(autoCaptureManager.captureStatus, .paused)
        
        // When - Resume
        autoCaptureManager.resumeAutoCaptureSession()
        
        // Then
        XCTAssertTrue(autoCaptureManager.isAutoCaptureEnabled)
        XCTAssertEqual(autoCaptureManager.captureStatus, .positioning)
    }
    
    // MARK: - Position Detection Tests
    
    func testPositionChangeHandling() async {
        // Given
        let session = PhotoSession()
        session.id = UUID()
        await autoCaptureManager.startAutoCaptureSession(session)
        
        // When - Valid position
        mockVisionService.isPositionValid = true
        await autoCaptureManager.handlePositionChange(isValid: true)
        
        // Then
        XCTAssertEqual(autoCaptureManager.captureStatus, .ready)
        
        // When - Invalid position
        mockVisionService.isPositionValid = false
        await autoCaptureManager.handlePositionChange(isValid: false)
        
        // Then
        XCTAssertEqual(autoCaptureManager.captureStatus, .positioning)
    }
    
    // MARK: - Quality Assessment Tests
    
    func testQualityAssessment() async {
        // Given
        let testImage = createTestImage()
        
        // When
        let result = await autoCaptureManager.assessCaptureQuality(testImage)
        
        // Then
        XCTAssertNotNil(result)
        // Note: In a real test, we'd validate the quality assessment logic
    }
    
    // MARK: - Statistics Tests
    
    func testSessionStatistics() async {
        // Given
        let session = PhotoSession()
        session.id = UUID()
        await autoCaptureManager.startAutoCaptureSession(session)
        
        // When
        let statistics = autoCaptureManager.getSessionStatistics()
        
        // Then
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics["totalCaptures"] as? Int, 0)
        XCTAssertEqual(statistics["successfulCaptures"] as? Int, 0)
        XCTAssertEqual(statistics["retryCount"] as? Int, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock Classes

class MockModelManager: ModelManager {
    var mockClassificationResult: (angle: ModelManager.VehicleAngle?, confidence: Float) = (.front, 0.8)
    
    override func classifyVehicleAngle(from image: UIImage) async -> (angle: ModelManager.VehicleAngle?, confidence: Float) {
        return mockClassificationResult
    }
}

class MockVisionService: VisionService {
    var isPositionValid = false
    
    override func isReadyForCapture() -> Bool {
        return isPositionValid
    }
}

class MockCameraService: CameraServiceProtocol {
    var mockImageData = Data()
    
    func configureSession(position: AVCaptureDevice.Position, quality: AVCaptureSession.Preset, flashMode: AVCaptureDevice.FlashMode) async throws {
        // Mock implementation
    }
    
    func startSession() async throws {
        // Mock implementation
    }
    
    func stopSession() async throws {
        // Mock implementation
    }
    
    func capturePhoto(settings: AVCapturePhotoSettings) async throws -> Data {
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
    func saveSession(_ session: PhotoSession) async throws {
        // Mock implementation
    }
    
    func getSession(id: UUID) async throws -> PhotoSession? {
        return nil
    }
    
    func getAllSessions() async throws -> [PhotoSession] {
        return []
    }
    
    func deleteSession(id: UUID) async throws {
        // Mock implementation
    }
}

class MockConfigurationService: ConfigurationService {
    override var confidenceThreshold: Float {
        get { return 0.8 }
        set { }
    }
}
