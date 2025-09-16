import XCTest
@testable import Photo_Booth

class PhotoMetadataServiceTests: XCTestCase {
    
    var photoMetadataService: PhotoMetadataService!
    var mockFileSystemManager: MockFileSystemManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockFileSystemManager = MockFileSystemManager()
        photoMetadataService = PhotoMetadataService(fileSystemManager: mockFileSystemManager)
    }
    
    override func tearDownWithError() throws {
        photoMetadataService = nil
        mockFileSystemManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - EXIF Data Extraction Tests
    
    func testExtractEXIFData() async throws {
        // Given
        let imageData = createTestImageDataWithEXIF()
        
        // When
        let exifData = try await photoMetadataService.extractEXIFData(from: imageData)
        
        // Then
        XCTAssertNotNil(exifData)
        // Note: The actual values will depend on the test image data
        // In a real implementation, you would create test images with known EXIF data
    }
    
    func testExtractEXIFDataWithInvalidData() async throws {
        // Given
        let invalidData = Data()
        
        // When & Then
        do {
            _ = try await photoMetadataService.extractEXIFData(from: invalidData)
            XCTFail("Should have thrown an error for invalid image data")
        } catch {
            XCTAssertTrue(error is PhotoMetadataError)
        }
    }
    
    // MARK: - Photo Quality Assessment Tests
    
    func testAssessPhotoQuality() async throws {
        // Given
        let imageData = createTestImageData()
        
        // When
        let qualityAssessment = try await photoMetadataService.assessPhotoQuality(imageData: imageData)
        
        // Then
        XCTAssertNotNil(qualityAssessment)
        XCTAssertGreaterThan(qualityAssessment.resolution.width, 0)
        XCTAssertGreaterThan(qualityAssessment.resolution.height, 0)
        XCTAssertGreaterThan(qualityAssessment.fileSize, 0)
        XCTAssertGreaterThan(qualityAssessment.aspectRatio, 0)
        XCTAssertGreaterThanOrEqual(qualityAssessment.blurScore, 0)
        XCTAssertGreaterThanOrEqual(qualityAssessment.brightnessScore, 0)
        XCTAssertGreaterThanOrEqual(qualityAssessment.contrastScore, 0)
        XCTAssertGreaterThanOrEqual(qualityAssessment.overallScore, 0)
        XCTAssertLessThanOrEqual(qualityAssessment.overallScore, 100)
    }
    
    func testAssessPhotoQualityWithInvalidData() async throws {
        // Given
        let invalidData = Data()
        
        // When & Then
        do {
            _ = try await photoMetadataService.assessPhotoQuality(imageData: invalidData)
            XCTFail("Should have thrown an error for invalid image data")
        } catch {
            XCTAssertTrue(error is PhotoMetadataError)
        }
    }
    
    func testQualityLevelDetermination() async throws {
        // Given
        let imageData = createTestImageData()
        
        // When
        let qualityAssessment = try await photoMetadataService.assessPhotoQuality(imageData: imageData)
        
        // Then
        XCTAssertTrue(PhotoQualityLevel.allCases.contains(qualityAssessment.qualityLevel))
    }
    
    // MARK: - Photo Tagging Tests
    
    func testGeneratePhotoTags() async throws {
        // Given
        let photo = createMockVehiclePhoto()
        let exifData = createMockEXIFData()
        let qualityAssessment = createMockQualityAssessment()
        
        // When
        let tags = photoMetadataService.generatePhotoTags(
            for: photo,
            exifData: exifData,
            qualityAssessment: qualityAssessment
        )
        
        // Then
        XCTAssertFalse(tags.isEmpty)
        XCTAssertTrue(tags.contains { $0.contains("angle-front") })
        XCTAssertTrue(tags.contains { $0.contains("quality-") })
        XCTAssertTrue(tags.contains { $0.contains("camera-") })
        XCTAssertTrue(tags.contains { $0.contains("morning") || $0.contains("afternoon") || $0.contains("evening") })
    }
    
    func testGeneratePhotoTagsWithMinimalData() async throws {
        // Given
        let photo = createMockVehiclePhoto()
        let exifData = PhotoEXIFData() // Empty EXIF data
        let qualityAssessment = PhotoQualityAssessment() // Empty quality assessment
        
        // When
        let tags = photoMetadataService.generatePhotoTags(
            for: photo,
            exifData: exifData,
            qualityAssessment: qualityAssessment
        )
        
        // Then
        XCTAssertFalse(tags.isEmpty)
        XCTAssertTrue(tags.contains { $0.contains("angle-front") })
        XCTAssertTrue(tags.contains { $0.contains("quality-") })
    }
    
    // MARK: - Performance Tests
    
    func testMetadataExtractionPerformance() throws {
        // Given
        let imageData = createTestImageData()
        let expectation = XCTestExpectation(description: "Metadata extraction performance")
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            do {
                _ = try await photoMetadataService.extractEXIFData(from: imageData)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                // Then
                XCTAssertLessThan(timeElapsed, 1.0, "Metadata extraction should complete within 1 second")
                expectation.fulfill()
            } catch {
                XCTFail("Metadata extraction failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testQualityAssessmentPerformance() throws {
        // Given
        let imageData = createTestImageData()
        let expectation = XCTestExpectation(description: "Quality assessment performance")
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            do {
                _ = try await photoMetadataService.assessPhotoQuality(imageData: imageData)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                // Then
                XCTAssertLessThan(timeElapsed, 2.0, "Quality assessment should complete within 2 seconds")
                expectation.fulfill()
            } catch {
                XCTFail("Quality assessment failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testVerySmallImage() async throws {
        // Given
        let smallImageData = createVerySmallImageData()
        
        // When
        let qualityAssessment = try await photoMetadataService.assessPhotoQuality(imageData: smallImageData)
        
        // Then
        XCTAssertNotNil(qualityAssessment)
        XCTAssertGreaterThan(qualityAssessment.resolution.width, 0)
        XCTAssertGreaterThan(qualityAssessment.resolution.height, 0)
    }
    
    func testVeryLargeImage() async throws {
        // Given
        let largeImageData = createLargeImageData()
        
        // When
        let qualityAssessment = try await photoMetadataService.assessPhotoQuality(imageData: largeImageData)
        
        // Then
        XCTAssertNotNil(qualityAssessment)
        XCTAssertGreaterThan(qualityAssessment.resolution.width, 0)
        XCTAssertGreaterThan(qualityAssessment.resolution.height, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Create a gradient for better quality assessment
            let colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func createTestImageDataWithEXIF() -> Data {
        // Create a test image with basic EXIF data
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
    
    private func createVerySmallImageData() -> Data {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.yellow.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func createLargeImageData() -> Data {
        let size = CGSize(width: 1000, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func createMockVehiclePhoto() -> VehiclePhoto {
        // This would need to be created with Core Data context in a real test
        // For now, we'll create a mock object
        let photo = VehiclePhoto()
        photo.angleType = "front"
        photo.captureDate = Date()
        return photo
    }
    
    private func createMockEXIFData() -> PhotoEXIFData {
        var exifData = PhotoEXIFData()
        exifData.width = 200
        exifData.height = 200
        exifData.cameraMake = "Apple"
        exifData.cameraModel = "iPhone"
        exifData.exposureTime = 1.0/60.0
        exifData.fNumber = 2.8
        exifData.iso = 100
        return exifData
    }
    
    private func createMockQualityAssessment() -> PhotoQualityAssessment {
        var assessment = PhotoQualityAssessment()
        assessment.resolution = CGSize(width: 200, height: 200)
        assessment.fileSize = 50000
        assessment.aspectRatio = 1.0
        assessment.blurScore = 500.0
        assessment.brightnessScore = 0.5
        assessment.contrastScore = 0.3
        assessment.overallScore = 85.0
        assessment.qualityLevel = .good
        return assessment
    }
}

// MARK: - Mock VehiclePhoto for Testing

class MockVehiclePhoto: VehiclePhoto {
    override var angleType: String? {
        get { return "front" }
        set { }
    }
    
    override var captureDate: Date? {
        get { return Date() }
        set { }
    }
}
