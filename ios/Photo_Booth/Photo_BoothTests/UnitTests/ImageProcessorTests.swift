import XCTest
import UIKit
@testable import Photo_Booth

/// Unit tests for ImageProcessor
class ImageProcessorTests: XCTestCase {
    
    var imageProcessor: ImageProcessor!
    
    override func setUp() {
        super.setUp()
        imageProcessor = ImageProcessor()
    }
    
    override func tearDown() {
        imageProcessor = nil
        super.tearDown()
    }
    
    // MARK: - Image Preprocessing Tests
    
    func testPreprocessForClassification() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 500, height: 300))
        
        // When
        let processedImage = imageProcessor.preprocessForClassification(testImage)
        
        // Then
        XCTAssertNotNil(processedImage)
        XCTAssertEqual(processedImage?.size, CGSize(width: 224, height: 224))
    }
    
    func testPreprocessForClassificationWithNilImage() {
        // Given
        let nilImage: UIImage? = nil
        
        // When
        let processedImage = imageProcessor.preprocessForClassification(nilImage!)
        
        // Then
        XCTAssertNil(processedImage)
    }
    
    // MARK: - Image Quality Assessment Tests
    
    func testAssessImageQuality() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 100, height: 100))
        
        // When
        let qualityAssessment = imageProcessor.assessImageQuality(testImage)
        
        // Then
        XCTAssertGreaterThanOrEqual(qualityAssessment.score, 0.0)
        XCTAssertLessThanOrEqual(qualityAssessment.score, 1.0)
        XCTAssertNotNil(qualityAssessment.issues)
    }
    
    func testAssessImageQualityWithBlurryImage() {
        // Given
        let blurryImage = createBlurryImage()
        
        // When
        let qualityAssessment = imageProcessor.assessImageQuality(blurryImage)
        
        // Then
        XCTAssertLessThan(qualityAssessment.score, 1.0)
        XCTAssertTrue(qualityAssessment.issues.contains(.blurry))
    }
    
    func testAssessImageQualityWithDarkImage() {
        // Given
        let darkImage = createDarkImage()
        
        // When
        let qualityAssessment = imageProcessor.assessImageQuality(darkImage)
        
        // Then
        XCTAssertLessThan(qualityAssessment.score, 1.0)
        XCTAssertTrue(qualityAssessment.issues.contains(.tooDark))
    }
    
    func testAssessImageQualityWithBrightImage() {
        // Given
        let brightImage = createBrightImage()
        
        // When
        let qualityAssessment = imageProcessor.assessImageQuality(brightImage)
        
        // Then
        XCTAssertLessThan(qualityAssessment.score, 1.0)
        XCTAssertTrue(qualityAssessment.issues.contains(.tooBright))
    }
    
    // MARK: - Image Compression Tests
    
    func testCompressImage() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        let maxFileSize = 100_000 // 100KB
        
        // When
        let compressedData = imageProcessor.compressImage(testImage, maxFileSize: maxFileSize)
        
        // Then
        XCTAssertNotNil(compressedData)
        XCTAssertLessThanOrEqual(compressedData?.count ?? 0, maxFileSize)
    }
    
    func testCompressImageWithSmallImage() {
        // Given
        let smallImage = createTestImage(size: CGSize(width: 100, height: 100))
        let maxFileSize = 1_000_000 // 1MB
        
        // When
        let compressedData = imageProcessor.compressImage(smallImage, maxFileSize: maxFileSize)
        
        // Then
        XCTAssertNotNil(compressedData)
        XCTAssertLessThanOrEqual(compressedData?.count ?? 0, maxFileSize)
    }
    
    // MARK: - Quality Issue Tests
    
    func testQualityIssueDisplayNames() {
        // Test all quality issue display names
        XCTAssertEqual(ImageProcessor.QualityIssue.blurry.displayName, "Image is blurry")
        XCTAssertEqual(ImageProcessor.QualityIssue.tooDark.displayName, "Image is too dark")
        XCTAssertEqual(ImageProcessor.QualityIssue.tooBright.displayName, "Image is too bright")
        XCTAssertEqual(ImageProcessor.QualityIssue.lowContrast.displayName, "Image has low contrast")
        XCTAssertEqual(ImageProcessor.QualityIssue.motionBlur.displayName, "Image has motion blur")
        XCTAssertEqual(ImageProcessor.QualityIssue.outOfFocus.displayName, "Image is out of focus")
    }
    
    func testQualityIssueSuggestions() {
        // Test quality issue suggestions
        XCTAssertEqual(ImageProcessor.QualityIssue.blurry.suggestion, "Hold device steady and ensure good lighting")
        XCTAssertEqual(ImageProcessor.QualityIssue.tooDark.suggestion, "Move to a brighter area or adjust lighting")
        XCTAssertEqual(ImageProcessor.QualityIssue.tooBright.suggestion, "Move to a shaded area or reduce lighting")
        XCTAssertEqual(ImageProcessor.QualityIssue.lowContrast.suggestion, "Ensure good lighting and clear vehicle visibility")
    }
    
    // MARK: - Edge Cases Tests
    
    func testPreprocessWithZeroSizeImage() {
        // Given
        let zeroSizeImage = createTestImage(size: CGSize.zero)
        
        // When
        let processedImage = imageProcessor.preprocessForClassification(zeroSizeImage)
        
        // Then
        XCTAssertNil(processedImage)
    }
    
    func testAssessQualityWithZeroSizeImage() {
        // Given
        let zeroSizeImage = createTestImage(size: CGSize.zero)
        
        // When
        let qualityAssessment = imageProcessor.assessImageQuality(zeroSizeImage)
        
        // Then
        XCTAssertEqual(qualityAssessment.score, 0.0)
        XCTAssertTrue(qualityAssessment.issues.contains(.blurry))
    }
    
    // MARK: - Performance Tests
    
    func testPreprocessingPerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = imageProcessor.preprocessForClassification(testImage)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(processingTime, 1.0) // Should complete in less than 1 second
    }
    
    func testQualityAssessmentPerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = imageProcessor.assessImageQuality(testImage)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(processingTime, 1.0) // Should complete in less than 1 second
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createBlurryImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a simple pattern that would be considered blurry
            for x in stride(from: 0, to: size.width, by: 2) {
                for y in stride(from: 0, to: size.height, by: 2) {
                    UIColor.black.setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
    
    private func createDarkImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createBrightImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
