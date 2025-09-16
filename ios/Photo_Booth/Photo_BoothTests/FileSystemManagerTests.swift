import XCTest
@testable import Photo_Booth

class FileSystemManagerTests: XCTestCase {
    
    var fileSystemManager: FileSystemManager!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Initialize FileSystemManager with test directory
        fileSystemManager = FileSystemManager()
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        fileSystemManager = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic File Operations Tests
    
    func testSaveAndLoadImage() async throws {
        // Given
        let testImageData = createTestImageData()
        let fileName = "test_image.jpg"
        
        // When
        let savedPath = try await fileSystemManager.saveImage(data: testImageData, fileName: fileName)
        let loadedData = try await fileSystemManager.loadImage(filePath: savedPath)
        
        // Then
        XCTAssertEqual(loadedData, testImageData)
        XCTAssertTrue(fileSystemManager.fileExists(filePath: savedPath))
    }
    
    func testDeleteImage() async throws {
        // Given
        let testImageData = createTestImageData()
        let fileName = "test_image.jpg"
        let savedPath = try await fileSystemManager.saveImage(data: testImageData, fileName: fileName)
        
        // When
        try await fileSystemManager.deleteImage(filePath: savedPath)
        
        // Then
        XCTAssertFalse(fileSystemManager.fileExists(filePath: savedPath))
    }
    
    func testFileExists() async throws {
        // Given
        let testImageData = createTestImageData()
        let fileName = "test_image.jpg"
        let savedPath = try await fileSystemManager.saveImage(data: testImageData, fileName: fileName)
        
        // When & Then
        XCTAssertTrue(fileSystemManager.fileExists(filePath: savedPath))
        
        // Test non-existent file
        let nonExistentPath = tempDirectory.appendingPathComponent("non_existent.jpg").path
        XCTAssertFalse(fileSystemManager.fileExists(filePath: nonExistentPath))
    }
    
    // MARK: - Enhanced Photo Organization Tests
    
    func testSaveImageWithOrganization() async throws {
        // Given
        let testImageData = createTestImageData()
        let sessionId = UUID()
        let angle = "front"
        let quality = PhotoQuality.high
        
        // When
        let savedPath = try await fileSystemManager.saveImageWithOrganization(
            data: testImageData,
            sessionId: sessionId,
            angle: angle,
            quality: quality
        )
        
        // Then
        XCTAssertTrue(fileSystemManager.fileExists(filePath: savedPath))
        XCTAssertTrue(savedPath.contains(sessionId.uuidString))
        XCTAssertTrue(savedPath.contains(angle))
        XCTAssertTrue(savedPath.contains(quality.rawValue))
    }
    
    func testGetSessionDirectory() {
        // Given
        let sessionId = UUID()
        
        // When
        let sessionDir = fileSystemManager.getSessionDirectory(sessionId: sessionId)
        
        // Then
        XCTAssertTrue(sessionDir.path.contains(sessionId.uuidString))
        XCTAssertTrue(sessionDir.path.contains("Sessions"))
    }
    
    func testGetExportDirectory() {
        // When
        let exportDir = fileSystemManager.getExportDirectory()
        
        // Then
        XCTAssertTrue(exportDir.path.contains("Exports"))
    }
    
    func testGetBackupDirectory() {
        // When
        let backupDir = fileSystemManager.getBackupDirectory()
        
        // Then
        XCTAssertTrue(backupDir.path.contains("Backups"))
    }
    
    // MARK: - Storage Management Tests
    
    func testGetStorageInfo() async throws {
        // Given
        let testImageData = createTestImageData()
        let fileName = "test_image.jpg"
        _ = try await fileSystemManager.saveImage(data: testImageData, fileName: fileName)
        
        // When
        let storageInfo = await fileSystemManager.getStorageInfo()
        
        // Then
        XCTAssertGreaterThan(storageInfo.totalUsed, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.availableSpace, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.imagesCount, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.sessionsCount, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.usagePercentage, 0)
        XCTAssertLessThanOrEqual(storageInfo.usagePercentage, 100)
    }
    
    func testCleanupOldExports() async throws {
        // Given
        let exportDir = fileSystemManager.getExportDirectory()
        let oldFile = exportDir.appendingPathComponent("old_export.zip")
        let newFile = exportDir.appendingPathComponent("new_export.zip")
        
        // Create old file (simulate by creating and then modifying date)
        try "old content".write(to: oldFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-86400 * 8)], ofItemAtPath: oldFile.path)
        
        // Create new file
        try "new content".write(to: newFile, atomically: true, encoding: .utf8)
        
        // When
        try await fileSystemManager.cleanupOldExports(olderThan: 7)
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    }
    
    // MARK: - Image Compression Tests
    
    func testImageCompression() async throws {
        // Given
        let testImageData = createTestImageData()
        let sessionId = UUID()
        let angle = "front"
        
        // When - Test different quality levels
        let highQualityPath = try await fileSystemManager.saveImageWithOrganization(
            data: testImageData,
            sessionId: sessionId,
            angle: angle,
            quality: .high
        )
        
        let mediumQualityPath = try await fileSystemManager.saveImageWithOrganization(
            data: testImageData,
            sessionId: sessionId,
            angle: "side",
            quality: .medium
        )
        
        let lowQualityPath = try await fileSystemManager.saveImageWithOrganization(
            data: testImageData,
            sessionId: sessionId,
            angle: "rear",
            quality: .low
        )
        
        // Then
        let highQualityData = try await fileSystemManager.loadImage(filePath: highQualityPath)
        let mediumQualityData = try await fileSystemManager.loadImage(filePath: mediumQualityPath)
        let lowQualityData = try await fileSystemManager.loadImage(filePath: lowQualityPath)
        
        // High quality should be largest, low quality should be smallest
        XCTAssertGreaterThan(highQualityData.count, mediumQualityData.count)
        XCTAssertGreaterThan(mediumQualityData.count, lowQualityData.count)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveImageWithInvalidData() async throws {
        // Given
        let invalidData = Data()
        let fileName = "invalid.jpg"
        
        // When & Then
        do {
            _ = try await fileSystemManager.saveImage(data: invalidData, fileName: fileName)
            XCTFail("Should have thrown an error for invalid data")
        } catch {
            // Expected to throw an error
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func testLoadNonExistentImage() async throws {
        // Given
        let nonExistentPath = tempDirectory.appendingPathComponent("non_existent.jpg").path
        
        // When & Then
        do {
            _ = try await fileSystemManager.loadImage(filePath: nonExistentPath)
            XCTFail("Should have thrown an error for non-existent file")
        } catch {
            // Expected to throw an error
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

// MARK: - Mock FileSystemManager for Testing

class MockFileSystemManager: FileSystemManagerProtocol {
    var savedImages: [String: Data] = [:]
    var shouldThrowError = false
    
    func saveImage(data: Data, fileName: String) async throws -> String {
        if shouldThrowError {
            throw StorageServiceError.fileSystemError("Mock error")
        }
        let path = "mock_path_\(fileName)"
        savedImages[path] = data
        return path
    }
    
    func loadImage(filePath: String) async throws -> Data {
        if shouldThrowError {
            throw StorageServiceError.fileSystemError("Mock error")
        }
        guard let data = savedImages[filePath] else {
            throw StorageServiceError.fileSystemError("File not found")
        }
        return data
    }
    
    func deleteImage(filePath: String) async throws {
        if shouldThrowError {
            throw StorageServiceError.fileSystemError("Mock error")
        }
        savedImages.removeValue(forKey: filePath)
    }
    
    func getFileURL(fileName: String) -> URL {
        return URL(fileURLWithPath: "mock_path_\(fileName)")
    }
    
    func fileExists(filePath: String) -> Bool {
        return savedImages[filePath] != nil
    }
    
    func saveImageWithOrganization(data: Data, sessionId: UUID, angle: String, quality: PhotoQuality) async throws -> String {
        let fileName = "\(sessionId.uuidString)_\(angle)_\(quality.rawValue).jpg"
        return try await saveImage(data: data, fileName: fileName)
    }
    
    func getSessionDirectory(sessionId: UUID) -> URL {
        return URL(fileURLWithPath: "mock_sessions/\(sessionId.uuidString)")
    }
    
    func getExportDirectory() -> URL {
        return URL(fileURLWithPath: "mock_exports")
    }
    
    func getBackupDirectory() -> URL {
        return URL(fileURLWithPath: "mock_backups")
    }
    
    func getStorageInfo() async -> StorageInfo {
        let totalUsed = savedImages.values.reduce(0) { $0 + $1.count }
        return StorageInfo(
            totalUsed: Int64(totalUsed),
            availableSpace: 1000000,
            imagesCount: savedImages.count,
            sessionsCount: 0
        )
    }
    
    func cleanupOldExports(olderThan days: Int) async throws {
        // Mock implementation - no actual cleanup
    }
}
