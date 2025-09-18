import XCTest
import Combine
@testable import Photo_Booth

/// Unit tests for PhotoSessionManager
@MainActor
class PhotoSessionManagerTests: XCTestCase {
    
    var photoSessionManager: PhotoSessionManager!
    var mockAutoCaptureManager: MockAutoCaptureManager!
    var mockStorageService: MockStorageService!
    var mockConfigurationService: MockConfigurationService!
    
    override func setUp() {
        super.setUp()
        
        // Create mock dependencies
        mockAutoCaptureManager = MockAutoCaptureManager()
        mockStorageService = MockStorageService()
        mockConfigurationService = MockConfigurationService()
        
        // Initialize PhotoSessionManager with mocks
        photoSessionManager = PhotoSessionManager(
            autoCaptureManager: mockAutoCaptureManager,
            storageService: mockStorageService,
            configurationService: mockConfigurationService
        )
    }
    
    override func tearDown() {
        photoSessionManager = nil
        mockAutoCaptureManager = nil
        mockStorageService = nil
        mockConfigurationService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(photoSessionManager)
        XCTAssertNil(photoSessionManager.currentSession)
        XCTAssertEqual(photoSessionManager.sessionState, .idle)
        XCTAssertEqual(photoSessionManager.sessionProgress, 0.0)
        XCTAssertFalse(photoSessionManager.isSessionActive)
    }
    
    // MARK: - Session Lifecycle Tests
    
    func testStartNewSession() async {
        // Given
        let vehicleMake = "Toyota"
        let vehicleModel = "Camry"
        let vehicleYear = 2023
        
        // When
        await photoSessionManager.startNewSession(
            vehicleMake: vehicleMake,
            vehicleModel: vehicleModel,
            vehicleYear: vehicleYear,
            sessionType: .standard
        )
        
        // Then
        XCTAssertTrue(photoSessionManager.isSessionActive)
        XCTAssertNotNil(photoSessionManager.currentSession)
        XCTAssertEqual(photoSessionManager.currentSession?.vehicleMake, vehicleMake)
        XCTAssertEqual(photoSessionManager.currentSession?.vehicleModel, vehicleModel)
        XCTAssertEqual(photoSessionManager.currentSession?.vehicleYear, vehicleYear)
        XCTAssertEqual(photoSessionManager.sessionState, .active)
    }
    
    func testPauseSession() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        photoSessionManager.pauseSession()
        
        // Then
        XCTAssertEqual(photoSessionManager.sessionState, .paused)
    }
    
    func testResumeSession() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        photoSessionManager.pauseSession()
        
        // When
        photoSessionManager.resumeSession()
        
        // Then
        XCTAssertEqual(photoSessionManager.sessionState, .active)
    }
    
    func testStopSession() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        photoSessionManager.stopSession()
        
        // Then
        XCTAssertFalse(photoSessionManager.isSessionActive)
        XCTAssertEqual(photoSessionManager.sessionState, .idle)
    }
    
    func testCompleteSession() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        await photoSessionManager.completeSession()
        
        // Then
        XCTAssertFalse(photoSessionManager.isSessionActive)
        XCTAssertEqual(photoSessionManager.sessionState, .idle)
        XCTAssertNotNil(photoSessionManager.currentSession?.isCompleted)
        XCTAssertTrue(photoSessionManager.currentSession?.isCompleted ?? false)
    }
    
    // MARK: - Photo Management Tests
    
    func testAddCapturedPhoto() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        let testImage = createTestImage()
        let angle = ModelManager.VehicleAngle.front
        
        // When
        photoSessionManager.addCapturedPhoto(testImage, for: angle)
        
        // Then
        XCTAssertEqual(photoSessionManager.capturedPhotos.count, 1)
        XCTAssertNotNil(photoSessionManager.capturedPhotos[angle])
    }
    
    func testRemovePhoto() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        let testImage = createTestImage()
        let angle = ModelManager.VehicleAngle.front
        photoSessionManager.addCapturedPhoto(testImage, for: angle)
        
        // When
        photoSessionManager.removePhoto(for: angle)
        
        // Then
        XCTAssertEqual(photoSessionManager.capturedPhotos.count, 0)
        XCTAssertNil(photoSessionManager.capturedPhotos[angle])
    }
    
    // MARK: - Progress and Validation Tests
    
    func testSessionProgress() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When - Add some photos
        let testImage = createTestImage()
        photoSessionManager.addCapturedPhoto(testImage, for: .front)
        photoSessionManager.addCapturedPhoto(testImage, for: .left)
        
        // Then
        XCTAssertGreaterThan(photoSessionManager.sessionProgress, 0.0)
        XCTAssertLessThanOrEqual(photoSessionManager.sessionProgress, 1.0)
    }
    
    func testIsSessionComplete() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .quick // Only 4 angles required
        )
        
        // When - Add all required photos
        let testImage = createTestImage()
        for angle in [.front, .left, .right, .rear] {
            photoSessionManager.addCapturedPhoto(testImage, for: angle)
        }
        
        // Then
        XCTAssertTrue(photoSessionManager.isSessionComplete())
    }
    
    func testGetMissingAngles() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        let testImage = createTestImage()
        photoSessionManager.addCapturedPhoto(testImage, for: .front)
        
        // When
        let missingAngles = photoSessionManager.getMissingAngles()
        
        // Then
        XCTAssertFalse(missingAngles.contains(.front))
        XCTAssertTrue(missingAngles.contains(.left))
        XCTAssertTrue(missingAngles.contains(.right))
        XCTAssertTrue(missingAngles.contains(.rear))
    }
    
    func testGetCapturedAngles() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        let testImage = createTestImage()
        photoSessionManager.addCapturedPhoto(testImage, for: .front)
        photoSessionManager.addCapturedPhoto(testImage, for: .left)
        
        // When
        let capturedAngles = photoSessionManager.getCapturedAngles()
        
        // Then
        XCTAssertEqual(capturedAngles.count, 2)
        XCTAssertTrue(capturedAngles.contains(.front))
        XCTAssertTrue(capturedAngles.contains(.left))
    }
    
    // MARK: - Quality Management Tests
    
    func testAddQualityIssues() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        let angle = ModelManager.VehicleAngle.front
        let issues = ["Image too dark", "Low contrast"]
        
        // When
        photoSessionManager.addQualityIssues(issues, for: angle)
        
        // Then
        let retrievedIssues = photoSessionManager.getQualityIssues(for: angle)
        XCTAssertEqual(retrievedIssues, issues)
    }
    
    // MARK: - Statistics Tests
    
    func testGetSessionStatistics() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        let statistics = photoSessionManager.getSessionStatistics()
        
        // Then
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics.totalPhotos, 0)
        XCTAssertNotNil(statistics.sessionId)
    }
    
    func testExportSessionData() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        let exportData = photoSessionManager.exportSessionData()
        
        // Then
        XCTAssertNotNil(exportData)
        XCTAssertEqual(exportData["vehicleMake"] as? String, "Toyota")
        XCTAssertEqual(exportData["vehicleModel"] as? String, "Camry")
        XCTAssertEqual(exportData["totalPhotos"] as? Int, 0)
    }
    
    // MARK: - Reset Tests
    
    func testReset() async {
        // Given
        await photoSessionManager.startNewSession(
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            sessionType: .standard
        )
        
        // When
        photoSessionManager.reset()
        
        // Then
        XCTAssertNil(photoSessionManager.currentSession)
        XCTAssertEqual(photoSessionManager.sessionState, .idle)
        XCTAssertEqual(photoSessionManager.sessionProgress, 0.0)
        XCTAssertFalse(photoSessionManager.isSessionActive)
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

class MockAutoCaptureManager: AutoCaptureManager {
    var mockCurrentSession: PhotoSession?
    var mockSessionProgress: Float = 0.0
    var mockSessionState: PhotoSessionManager.SessionState = .idle
    var mockIsCapturing = false
    var mockCaptureStatus: AutoCaptureManager.CaptureStatus = .idle
    
    override var currentSession: PhotoSession? {
        get { return mockCurrentSession }
        set { mockCurrentSession = newValue }
    }
    
    override var sessionProgress: Float {
        get { return mockSessionProgress }
        set { mockSessionProgress = newValue }
    }
    
    override var isCapturing: Bool {
        get { return mockIsCapturing }
        set { mockIsCapturing = newValue }
    }
    
    override var captureStatus: AutoCaptureManager.CaptureStatus {
        get { return mockCaptureStatus }
        set { mockCaptureStatus = newValue }
    }
    
    override func startAutoCaptureSession(_ session: PhotoSession) async {
        mockCurrentSession = session
        mockSessionProgress = 0.0
    }
    
    override func stopAutoCaptureSession() {
        mockCurrentSession = nil
        mockSessionProgress = 0.0
    }
    
    override func pauseAutoCaptureSession() {
        mockCaptureStatus = .paused
    }
    
    override func resumeAutoCaptureSession() {
        mockCaptureStatus = .positioning
    }
}
