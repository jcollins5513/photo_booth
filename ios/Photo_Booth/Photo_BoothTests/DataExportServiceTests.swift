import XCTest
@testable import Photo_Booth

class DataExportServiceTests: XCTestCase {
    
    var dataExportService: DataExportService!
    var mockFileSystemManager: MockFileSystemManager!
    var mockStorageService: MockStorageService!
    var mockMetadataService: MockPhotoMetadataService!
    static var sharedCoreDataStack: CoreDataStack!
    
    override class func setUp() {
        super.setUp()
        sharedCoreDataStack = CoreDataStack(inMemory: true)
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockFileSystemManager = MockFileSystemManager()
        mockStorageService = MockStorageService()
    }
    
    private func setupDataExportService() async {
        mockMetadataService = await MockPhotoMetadataService(fileSystemManager: mockFileSystemManager)
        dataExportService = DataExportService(
            fileSystemManager: mockFileSystemManager,
            storageService: mockStorageService,
            metadataService: mockMetadataService
        )
    }
    
    override func tearDownWithError() throws {
        dataExportService = nil
        mockFileSystemManager = nil
        mockStorageService = nil
        mockMetadataService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Session Export Tests
    
    func testExportSessionAsZIP() async throws {
        // Given
        await setupDataExportService()
        let sessionId = UUID()
        let session = createMockPhotoSession(id: sessionId)
        let photos = createMockVehiclePhotos(sessionId: sessionId)
        
        mockStorageService.mockSession = session
        mockStorageService.mockPhotos = photos
        
        // When
        let exportURL = try await dataExportService.exportSession(sessionId: sessionId, format: .zip)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }
    
    func testExportSessionAsJSON() async throws {
        // Given
        await setupDataExportService()
        let sessionId = UUID()
        let session = createMockPhotoSession(id: sessionId)
        let photos = createMockVehiclePhotos(sessionId: sessionId)
        
        mockStorageService.mockSession = session
        mockStorageService.mockPhotos = photos
        
        // When
        let exportURL = try await dataExportService.exportSession(sessionId: sessionId, format: .json)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "json")
        
        // Verify JSON content
        let jsonData = try Data(contentsOf: exportURL)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertNotNil(jsonObject?["session"])
        XCTAssertNotNil(jsonObject?["photos"])
    }
    
    func testExportSessionAsCSV() async throws {
        // Given
        await setupDataExportService()
        let sessionId = UUID()
        let session = createMockPhotoSession(id: sessionId)
        let photos = createMockVehiclePhotos(sessionId: sessionId)
        
        mockStorageService.mockSession = session
        mockStorageService.mockPhotos = photos
        
        // When
        let exportURL = try await dataExportService.exportSession(sessionId: sessionId, format: .csv)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "csv")
        
        // Verify CSV content
        let csvContent = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(csvContent.contains("Session ID"))
        XCTAssertTrue(csvContent.contains("Photo ID"))
        XCTAssertTrue(csvContent.contains(sessionId.uuidString))
    }
    
    func testExportSessionWithNonExistentSession() async throws {
        // Given
        await setupDataExportService()
        let nonExistentSessionId = UUID()
        mockStorageService.mockSession = nil
        
        // When & Then
        do {
            _ = try await dataExportService.exportSession(sessionId: nonExistentSessionId, format: .json)
            XCTFail("Should have thrown an error for non-existent session")
        } catch {
            XCTAssertTrue(error is DataExportError)
        }
    }
    
    // MARK: - Individual Photo Export Tests
    
    func testExportPhotoOriginal() async throws {
        // Given
        await setupDataExportService()
        let photoId = UUID()
        let photo = createMockVehiclePhoto(id: photoId)
        let imageData = createTestImageData()
        
        mockStorageService.mockPhoto = photo
        mockStorageService.mockPhotoData = imageData
        
        // When
        let exportURL = try await dataExportService.exportPhoto(photoId: photoId, format: .original)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "jpg")
        
        let exportedData = try Data(contentsOf: exportURL)
        XCTAssertEqual(exportedData, imageData)
    }
    
    func testExportPhotoHighQuality() async throws {
        // Given
        await setupDataExportService()
        let photoId = UUID()
        let photo = createMockVehiclePhoto(id: photoId)
        let imageData = createTestImageData()
        
        mockStorageService.mockPhoto = photo
        mockStorageService.mockPhotoData = imageData
        
        // When
        let exportURL = try await dataExportService.exportPhoto(photoId: photoId, format: .highQuality)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "jpg")
        XCTAssertTrue(exportURL.lastPathComponent.contains("_hq"))
    }
    
    func testExportPhotoMediumQuality() async throws {
        // Given
        await setupDataExportService()
        let photoId = UUID()
        let photo = createMockVehiclePhoto(id: photoId)
        let imageData = createTestImageData()
        
        mockStorageService.mockPhoto = photo
        mockStorageService.mockPhotoData = imageData
        
        // When
        let exportURL = try await dataExportService.exportPhoto(photoId: photoId, format: .mediumQuality)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "jpg")
        XCTAssertTrue(exportURL.lastPathComponent.contains("_mq"))
    }
    
    func testExportPhotoLowQuality() async throws {
        // Given
        await setupDataExportService()
        let photoId = UUID()
        let photo = createMockVehiclePhoto(id: photoId)
        let imageData = createTestImageData()
        
        mockStorageService.mockPhoto = photo
        mockStorageService.mockPhotoData = imageData
        
        // When
        let exportURL = try await dataExportService.exportPhoto(photoId: photoId, format: .lowQuality)
        
        // Then
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.pathExtension == "jpg")
        XCTAssertTrue(exportURL.lastPathComponent.contains("_lq"))
    }
    
    func testExportPhotoWithNonExistentPhoto() async throws {
        // Given
        await setupDataExportService()
        let nonExistentPhotoId = UUID()
        mockStorageService.mockPhoto = nil
        
        // When & Then
        do {
            _ = try await dataExportService.exportPhoto(photoId: nonExistentPhotoId, format: .original)
            XCTFail("Should have thrown an error for non-existent photo")
        } catch {
            XCTAssertTrue(error is DataExportError)
        }
    }
    
    // MARK: - Cloud Storage Integration Tests
    
    func testUploadToCloudStorage() async throws {
        // Given
        await setupDataExportService()
        let testFileURL = createTestFile()
        let cloudService = CloudStorageService.iCloud
        
        // When
        let cloudURL = try await dataExportService.uploadToCloudStorage(fileURL: testFileURL, service: cloudService)
        
        // Then
        XCTAssertNotNil(cloudURL)
        XCTAssertTrue(cloudURL.contains("cloud.example.com"))
        XCTAssertTrue(cloudURL.contains(testFileURL.lastPathComponent))
    }
    
    func testCreateShareableLink() async throws {
        // Given
        await setupDataExportService()
        let testFileURL = createTestFile()
        
        // When
        let shareableLink = try await dataExportService.createShareableLink(for: testFileURL)
        
        // Then
        XCTAssertNotNil(shareableLink)
        XCTAssertTrue(shareableLink.contains("share.example.com"))
        XCTAssertTrue(shareableLink.contains(testFileURL.lastPathComponent))
    }
    
    // MARK: - QR Code Generation Tests
    
    func testGenerateQRCode() async throws {
        // Given
        await setupDataExportService()
        let testFileURL = createTestFile()
        
        // When
        let qrCodeImage = try await dataExportService.generateQRCode(for: testFileURL)
        
        // Then
        XCTAssertNotNil(qrCodeImage)
        XCTAssertGreaterThan(qrCodeImage.size.width, 0)
        XCTAssertGreaterThan(qrCodeImage.size.height, 0)
    }
    
    func testGenerateQRCodeWithInvalidURL() async throws {
        // Given
        await setupDataExportService()
        let invalidURL = URL(string: "invalid://url")!
        
        // When & Then
        do {
            _ = try await dataExportService.generateQRCode(for: invalidURL)
            XCTFail("Should have thrown an error for invalid URL")
        } catch {
            XCTAssertTrue(error is DataExportError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testExportPerformance() throws {
        // Given
        let sessionId = UUID()
        let session = createMockPhotoSession(id: sessionId)
        let photos = createMockVehiclePhotos(sessionId: sessionId, count: 10)
        
        mockStorageService.mockSession = session
        mockStorageService.mockPhotos = photos
        
        let expectation = XCTestExpectation(description: "Export performance")
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            do {
                _ = try await dataExportService.exportSession(sessionId: sessionId, format: .json)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                // Then
                XCTAssertLessThan(timeElapsed, 5.0, "Export should complete within 5 seconds")
                expectation.fulfill()
            } catch {
                XCTFail("Export failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func createTestFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_file.txt")
        try? "Test content".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createMockPhotoSession(id: UUID) -> PhotoSession {
        // Use the shared Core Data stack for testing
        let context = Self.sharedCoreDataStack.container.viewContext
        
        let session = PhotoSession(context: context)
        session.vehicleIdentifier = "TEST123"
        session.startDate = Date()
        session.status = "completed"
        session.totalAngles = 8
        session.completedAngles = 8
        
        return session
    }
    
    private func createMockVehiclePhoto(id: UUID) -> VehiclePhoto {
        // Use the shared Core Data stack for testing
        let context = Self.sharedCoreDataStack.container.viewContext
        
        let photo = VehiclePhoto(context: context)
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
    
    private func createMockVehiclePhotos(sessionId: UUID, count: Int = 3) -> [VehiclePhoto] {
        // Use the shared Core Data stack for testing
        let context = Self.sharedCoreDataStack.container.viewContext
        
        var photos: [VehiclePhoto] = []
        for i in 0..<count {
            let photo = VehiclePhoto(context: context)
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

// MARK: - Mock Services

class MockStorageService: StorageServiceProtocol {
    var mockSession: PhotoSession?
    var mockPhoto: VehiclePhoto?
    var mockPhotos: [VehiclePhoto] = []
    var mockPhotoData: Data = Data()
    
    func savePhotoSession(id: UUID, vehicleIdentifier: String, startDate: Date, status: String, totalAngles: Int16, completedAngles: Int16) async throws -> PhotoSession {
        return mockSession ?? PhotoSession()
    }
    
    func getPhotoSession(id: UUID) async throws -> PhotoSession? {
        return mockSession
    }
    
    func updatePhotoSession(id: UUID, status: String?, completedAngles: Int16?) async throws -> PhotoSession {
        return mockSession ?? PhotoSession()
    }
    
    func saveVehiclePhoto(id: UUID, sessionId: UUID, angle: String, imageData: Data, timestamp: Date) async throws -> VehiclePhoto {
        return mockPhoto ?? VehiclePhoto()
    }
    
    func getVehiclePhoto(id: UUID) async throws -> VehiclePhoto? {
        return mockPhoto
    }
    
    func getPhotosForSession(sessionId: UUID) async throws -> [VehiclePhoto] {
        return mockPhotos
    }
    
    func deletePhotoSession(id: UUID) async throws {
        // Mock implementation
    }
    
    func deleteVehiclePhoto(id: UUID) async throws {
        // Mock implementation
    }
    
    func getAllPhotos() async throws -> [VehiclePhoto] {
        return mockPhotos
    }
    
    func getPhotoData(id: UUID) async throws -> Data {
        return mockPhotoData
    }
    
    func deletePhoto(id: UUID) async throws {
        // Mock implementation
    }
}

class MockPhotoMetadataService: PhotoMetadataService, @unchecked Sendable {
    override func extractEXIFData(from imageData: Data) async throws -> PhotoEXIFData {
        var exifData = PhotoEXIFData()
        exifData.width = 200
        exifData.height = 200
        exifData.cameraMake = "Apple"
        exifData.cameraModel = "iPhone"
        return exifData
    }
    
    override func assessPhotoQuality(imageData: Data) async throws -> PhotoQualityAssessment {
        var assessment = PhotoQualityAssessment()
        assessment.resolution = CGSize(width: 200, height: 200)
        assessment.fileSize = imageData.count
        assessment.aspectRatio = 1.0
        assessment.blurScore = 500.0
        assessment.brightnessScore = 0.5
        assessment.contrastScore = 0.3
        assessment.overallScore = 85.0
        assessment.qualityLevel = .good
        return assessment
    }
}
