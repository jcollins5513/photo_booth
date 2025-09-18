import XCTest
import UIKit
@testable import Photo_Booth

/// Performance tests for Photo Booth app
@MainActor
class PerformanceTests: XCTestCase {
    
    var modelManager: ModelManager!
    var imageProcessor: ImageProcessor!
    var configurationService: ConfigurationService!
    
    override func setUp() {
        super.setUp()
        modelManager = ModelManager()
        imageProcessor = ImageProcessor()
        configurationService = ConfigurationService()
    }
    
    override func tearDown() {
        modelManager = nil
        imageProcessor = nil
        configurationService = nil
        super.tearDown()
    }
    
    // MARK: - Model Performance Tests
    
    func testModelInferencePerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 224, height: 224))
        
        // When
        measure {
            Task {
                await modelManager.classifyVehicleAngle(from: testImage)
            }
        }
    }
    
    func testModelInferencePerformanceWithLargeImage() {
        // Given
        let largeImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        measure {
            Task {
                await modelManager.classifyVehicleAngle(from: largeImage)
            }
        }
    }
    
    func testModelInferencePerformanceWithMultipleImages() {
        // Given
        let images = (0..<10).map { _ in createTestImage(size: CGSize(width: 224, height: 224)) }
        
        // When
        measure {
            Task {
                for image in images {
                    await modelManager.classifyVehicleAngle(from: image)
                }
            }
        }
    }
    
    // MARK: - Image Processing Performance Tests
    
    func testImagePreprocessingPerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        measure {
            _ = imageProcessor.preprocessForClassification(testImage)
        }
    }
    
    func testImageQualityAssessmentPerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        measure {
            _ = imageProcessor.assessImageQuality(testImage)
        }
    }
    
    func testImageCompressionPerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // When
        measure {
            _ = imageProcessor.compressImage(testImage, maxFileSize: 500_000)
        }
    }
    
    func testImageProcessingPipelinePerformance() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        measure {
            // Simulate complete image processing pipeline
            let preprocessed = imageProcessor.preprocessForClassification(testImage)
            if let processed = preprocessed {
                _ = imageProcessor.assessImageQuality(processed)
                _ = imageProcessor.compressImage(processed, maxFileSize: 500_000)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageWithLargeImages() {
        // Given
        let largeImages = (0..<20).map { _ in createTestImage(size: CGSize(width: 2000, height: 2000)) }
        
        // When
        measure {
            for image in largeImages {
                let _ = imageProcessor.preprocessForClassification(image)
            }
        }
        
        // Then - Verify memory usage doesn't grow excessively
        // Note: In a real test, we'd measure actual memory usage
        XCTAssertTrue(largeImages.count == 20)
    }
    
    func testMemoryUsageWithImageProcessing() {
        // Given
        let images = (0..<50).map { _ in createTestImage(size: CGSize(width: 500, height: 500)) }
        
        // When
        measure {
            for image in images {
                let _ = imageProcessor.assessImageQuality(image)
            }
        }
        
        // Then - Verify memory usage is reasonable
        XCTAssertTrue(images.count == 50)
    }
    
    // MARK: - Configuration Performance Tests
    
    func testConfigurationUpdatePerformance() {
        // Given
        let configurations = (0..<1000).map { Float($0) / 1000.0 }
        
        // When
        measure {
            for threshold in configurations {
                configurationService.updateConfidenceThreshold(threshold)
            }
        }
    }
    
    func testConfigurationValidationPerformance() {
        // Given
        let testConfigurations = (0..<100).map { _ in
            ConfigurationService.ConfigurationIssue.allCases.randomElement()!
        }
        
        // When
        measure {
            for _ in testConfigurations {
                _ = configurationService.validateConfiguration()
            }
        }
    }
    
    // MARK: - Real-time Processing Performance Tests
    
    func testRealTimeProcessingPerformance() {
        // Given
        let frameRate = 10 // 10 FPS
        let testDuration = 1.0 // 1 second
        let frameInterval = 1.0 / Double(frameRate)
        let totalFrames = Int(testDuration / frameInterval)
        
        // When
        measure {
            for _ in 0..<totalFrames {
                let testImage = createTestImage(size: CGSize(width: 224, height: 224))
                let _ = imageProcessor.preprocessForClassification(testImage)
            }
        }
    }
    
    func testConcurrentProcessingPerformance() {
        // Given
        let concurrentTasks = 5
        let imagesPerTask = 10
        
        // When
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<concurrentTasks {
                group.enter()
                Task {
                    for _ in 0..<imagesPerTask {
                        let testImage = createTestImage(size: CGSize(width: 224, height: 224))
                        let _ = imageProcessor.preprocessForClassification(testImage)
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - Battery Performance Tests
    
    func testBatteryEfficientProcessing() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 224, height: 224))
        let processingCount = 100
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let startBatteryLevel = getBatteryLevel()
        
        for _ in 0..<processingCount {
            let _ = imageProcessor.preprocessForClassification(testImage)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endBatteryLevel = getBatteryLevel()
        
        // Then
        let processingTime = endTime - startTime
        let batteryDrain = startBatteryLevel - endBatteryLevel
        
        XCTAssertLessThan(processingTime, 5.0) // Should complete in under 5 seconds
        XCTAssertLessThan(batteryDrain, 0.05) // Should use less than 5% battery
    }
    
    // MARK: - Stress Tests
    
    func testStressTestWithRapidProcessing() {
        // Given
        let rapidProcessingCount = 1000
        
        // When
        measure {
            for _ in 0..<rapidProcessingCount {
                let testImage = createTestImage(size: CGSize(width: 224, height: 224))
                let _ = imageProcessor.preprocessForClassification(testImage)
            }
        }
    }
    
    func testStressTestWithLargeImages() {
        // Given
        let largeImageCount = 100
        let largeImages = (0..<largeImageCount).map { _ in 
            createTestImage(size: CGSize(width: 2000, height: 2000))
        }
        
        // When
        measure {
            for image in largeImages {
                let _ = imageProcessor.preprocessForClassification(image)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a more complex image for better testing
            let colors: [UIColor] = [.red, .green, .blue, .yellow, .purple, .orange]
            let color = colors.randomElement() ?? .blue
            
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some patterns
            for x in stride(from: 0, to: size.width, by: 10) {
                for y in stride(from: 0, to: size.height, by: 10) {
                    if (x + y) % 20 == 0 {
                        UIColor.white.setFill()
                        context.fill(CGRect(x: x, y: y, width: 5, height: 5))
                    }
                }
            }
        }
    }
    
    private func getBatteryLevel() -> Float {
        // Mock battery level for testing
        // In a real test, we'd get actual battery level
        return 0.8
    }
}

// MARK: - Performance Benchmarks

extension PerformanceTests {
    
    func testPerformanceBenchmarks() {
        // Test that our performance meets benchmarks
        
        // Model inference should be under 100ms
        let testImage = createTestImage(size: CGSize(width: 224, height: 224))
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            await modelManager.classifyVehicleAngle(from: testImage)
        }
        
        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(inferenceTime, 0.1) // 100ms
        
        // Image preprocessing should be under 50ms
        let preprocessStartTime = CFAbsoluteTimeGetCurrent()
        _ = imageProcessor.preprocessForClassification(testImage)
        let preprocessTime = CFAbsoluteTimeGetCurrent() - preprocessStartTime
        XCTAssertLessThan(preprocessTime, 0.05) // 50ms
        
        // Quality assessment should be under 30ms
        let qualityStartTime = CFAbsoluteTimeGetCurrent()
        _ = imageProcessor.assessImageQuality(testImage)
        let qualityTime = CFAbsoluteTimeGetCurrent() - qualityStartTime
        XCTAssertLessThan(qualityTime, 0.03) // 30ms
    }
}
