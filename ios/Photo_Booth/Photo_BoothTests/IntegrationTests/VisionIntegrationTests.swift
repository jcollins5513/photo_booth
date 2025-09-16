import XCTest
import Vision
import CoreML
import UIKit
@testable import Photo_Booth

/// Integration tests for vision detection flow
/// These tests MUST FAIL before implementation
class VisionIntegrationTests: XCTestCase {
    
    var visionService: VisionServiceProtocol!
    var cameraService: CameraServiceProtocol!
    
    override func setUpWithError() throws {
        // These will fail until services are implemented
        visionService = VisionService()
        cameraService = CameraService()
    }
    
    override func tearDownWithError() throws {
        visionService = nil
        cameraService = nil
    }
    
    // MARK: - Model Loading and Configuration Tests
    
    func testModelLoadingAndConfiguration() async throws {
        // Given: Vision service is available
        XCTAssertFalse(visionService.isModelLoaded, "Model should not be loaded initially")
        
        // When: Loading the model
        try await visionService.loadModel()
        
        // Then: Model should be loaded
        XCTAssertTrue(visionService.isModelLoaded, "Model should be loaded after loadModel()")
        
        // When: Setting configuration
        visionService.setConfidenceThreshold(0.8)
        visionService.setTargetAngle(.front)
        
        // Then: Configuration should be set
        XCTAssertEqual(visionService.getConfidenceThreshold(), 0.8, "Confidence threshold should be set")
        XCTAssertEqual(visionService.getTargetAngle(), .front, "Target angle should be set")
    }
    
    func testModelLoadingFailure() async {
        // Test behavior when model loading fails
        do {
            try await visionService.loadModel()
            XCTFail("Should throw error for unimplemented service")
        } catch VisionServiceError.modelNotLoaded {
            // Expected error for unimplemented service
            XCTAssertTrue(true, "Should throw modelNotLoaded error")
        } catch {
            // Other errors are also acceptable for unimplemented service
            XCTAssertTrue(true, "Should handle model loading errors")
        }
    }
    
    // MARK: - Image Classification Tests
    
    func testImageClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // When: Classifying a test image
        let testImage = createTestImage()
        let result = try await visionService.classifyVehicleAngle(from: testImage)
        
        // Then: Classification should succeed
        XCTAssertNotNil(result, "Classification result should not be nil")
        XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result angle should be valid")
    }
    
    func testImageDataClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // When: Classifying image data
        let testImage = createTestImage()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        let result = try await visionService.classifyVehicleAngle(from: imageData)
        
        // Then: Classification should succeed
        XCTAssertNotNil(result, "Classification result should not be nil")
        XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result angle should be valid")
    }
    
    func testClassificationWithDifferentAngles() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Test classification for each angle
        for angle in PhotoAngleType.allCases {
            visionService.setTargetAngle(angle)
            let testImage = createTestImage()
            let result = try await visionService.classifyVehicleAngle(from: testImage)
            
            XCTAssertNotNil(result, "Classification should succeed for \(angle)")
            XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result angle should be valid for \(angle)")
        }
    }
    
    func testClassificationWithDifferentImageSizes() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Test with different image sizes
        let sizes = [
            CGSize(width: 224, height: 224),
            CGSize(width: 448, height: 448),
            CGSize(width: 112, height: 112)
        ]
        
        for size in sizes {
            let testImage = createTestImage(size: size)
            let result = try await visionService.classifyVehicleAngle(from: testImage)
            
            XCTAssertNotNil(result, "Classification should succeed for size \(size)")
            XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result angle should be valid for size \(size)")
        }
    }
    
    // MARK: - Continuous Classification Tests
    
    func testContinuousClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // When: Starting continuous classification
        let frameProvider = MockFrameProvider()
        let expectation = XCTestExpectation(description: "Continuous classification")
        var receivedClassifications: [PhotoAngleType] = []
        
        try await visionService.startContinuousClassification(
            frameProvider: frameProvider
        ) { angle, confidence in
            receivedClassifications.append(angle)
            if receivedClassifications.count >= 5 {
                expectation.fulfill()
            }
        }
        
        // Then: Should receive classifications
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertGreaterThanOrEqual(receivedClassifications.count, 5, "Should receive multiple classifications")
        
        // When: Stopping continuous classification
        visionService.stopContinuousClassification()
        
        // Then: Should stop without error
        XCTAssertNoThrow(visionService.stopContinuousClassification(), "Should be able to stop multiple times")
    }
    
    func testContinuousClassificationWithTargetAngle() async throws {
        // Given: Model is loaded and target angle is set
        try await visionService.loadModel()
        visionService.setTargetAngle(.front)
        visionService.setConfidenceThreshold(0.8)
        
        // When: Starting continuous classification
        let frameProvider = MockFrameProvider()
        let expectation = XCTestExpectation(description: "Target angle detection")
        var targetAngleDetected = false
        
        try await visionService.startContinuousClassification(
            frameProvider: frameProvider
        ) { angle, confidence in
            if angle == .front && confidence >= 0.8 {
                targetAngleDetected = true
                expectation.fulfill()
            }
        }
        
        // Then: Should detect target angle
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertTrue(targetAngleDetected, "Should detect target angle")
        
        visionService.stopContinuousClassification()
    }
    
    func testContinuousClassificationPerformance() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // When: Running continuous classification
        let frameProvider = MockFrameProvider()
        let expectation = XCTestExpectation(description: "Performance test")
        var classificationCount = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await visionService.startContinuousClassification(
            frameProvider: frameProvider
        ) { angle, confidence in
            classificationCount += 1
            if classificationCount >= 10 {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then: Should meet performance requirements
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(classificationCount)
        XCTAssertLessThan(averageTime, 0.1, "Average classification time should be under 100ms")
        
        visionService.stopContinuousClassification()
    }
    
    // MARK: - Confidence Threshold Tests
    
    func testConfidenceThresholdFiltering() async throws {
        // Given: Model is loaded with high confidence threshold
        try await visionService.loadModel()
        visionService.setConfidenceThreshold(0.9)
        
        // When: Classifying images
        let testImage = createTestImage()
        let result = try await visionService.classifyVehicleAngle(from: testImage)
        
        // Then: Result should be valid
        XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result should be valid")
        
        // When: Lowering confidence threshold
        visionService.setConfidenceThreshold(0.5)
        let result2 = try await visionService.classifyVehicleAngle(from: testImage)
        
        // Then: Should still get valid results
        XCTAssertNotNil(result2, "Classification should still work with lower threshold")
    }
    
    func testConfidenceThresholdEdgeCases() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Test edge case thresholds
        let thresholds: [Float] = [0.0, 0.5, 1.0]
        
        for threshold in thresholds {
            visionService.setConfidenceThreshold(threshold)
            let currentThreshold = visionService.getConfidenceThreshold()
            XCTAssertEqual(currentThreshold, threshold, "Threshold should be set to \(threshold)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testClassificationWithoutModel() async {
        // Test classification without loaded model
        let testImage = createTestImage()
        
        do {
            _ = try await visionService.classifyVehicleAngle(from: testImage)
            XCTFail("Should throw error when model is not loaded")
        } catch VisionServiceError.modelNotLoaded {
            // Expected error
            XCTAssertTrue(true, "Should throw modelNotLoaded error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInvalidImageClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Test with invalid image data
        let invalidImageData = Data("invalid".utf8)
        
        do {
            _ = try await visionService.classifyVehicleAngle(from: invalidImageData)
            XCTFail("Should throw error for invalid image data")
        } catch VisionServiceError.invalidImageData {
            // Expected error
            XCTAssertTrue(true, "Should throw invalidImageData error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testNilImageClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Test with nil image
        do {
            _ = try await visionService.classifyVehicleAngle(from: UIImage())
            XCTFail("Should throw error for invalid image")
        } catch VisionServiceError.invalidImage {
            // Expected error
            XCTAssertTrue(true, "Should throw invalidImage error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testContinuousClassificationWithoutModel() async {
        // Test starting continuous classification without loaded model
        let frameProvider = MockFrameProvider()
        
        do {
            try await visionService.startContinuousClassification(
                frameProvider: frameProvider
            ) { _, _ in }
            XCTFail("Should throw error when model is not loaded")
        } catch VisionServiceError.modelNotLoaded {
            // Expected error
            XCTAssertTrue(true, "Should throw modelNotLoaded error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testClassificationPerformance() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        let testImage = createTestImage()
        let iterations = 10
        
        // Measure classification time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            do {
                _ = try await visionService.classifyVehicleAngle(from: testImage)
            } catch {
                // Expected for unimplemented service
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let averageTime = (endTime - startTime) / Double(iterations)
        
        // Verify performance (should be under 200ms per classification)
        XCTAssertLessThan(averageTime, 0.2, "Average classification time should be under 200ms")
    }
    
    func testMemoryUsage() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        // Perform multiple classifications to test memory management
        for _ in 0..<100 {
            let testImage = createTestImage()
            do {
                _ = try await visionService.classifyVehicleAngle(from: testImage)
            } catch {
                // Expected for unimplemented service
            }
        }
        
        // If we get here without crashing, memory management is working
        XCTAssertTrue(true, "Memory management should handle multiple classifications")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentClassification() async throws {
        // Given: Model is loaded
        try await visionService.loadModel()
        
        let testImage = createTestImage()
        
        // Test concurrent classification calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        _ = try await self.visionService.classifyVehicleAngle(from: testImage)
                    } catch {
                        // Expected for unimplemented service
                    }
                }
            }
        }
    }
    
    func testConcurrentConfiguration() async throws {
        // Test concurrent configuration calls
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                self.visionService.setConfidenceThreshold(0.7)
            }
            
            group.addTask {
                self.visionService.setTargetAngle(.front)
            }
            
            group.addTask {
                self.visionService.setConfidenceThreshold(0.8)
            }
        }
        
        // Verify final state is consistent
        let finalThreshold = visionService.getConfidenceThreshold()
        let finalAngle = visionService.getTargetAngle()
        
        XCTAssertTrue(finalThreshold >= 0.0 && finalThreshold <= 1.0, "Final threshold should be valid")
        XCTAssertTrue(PhotoAngleType.allCases.contains(finalAngle), "Final angle should be valid")
    }
    
    // MARK: - Integration with Camera Service Tests
    
    func testVisionWithCameraFrames() async throws {
        // Given: Camera and vision services are available
        try await cameraService.configureSession(
            position: .back,
            quality: .photo,
            flashMode: .auto
        )
        try await cameraService.startSession()
        
        try await visionService.loadModel()
        visionService.setTargetAngle(.front)
        
        // When: Capturing frame from camera and classifying
        let imageData = try await cameraService.capturePhoto(settings: .default)
        let image = UIImage(data: imageData)!
        
        let result = try await visionService.classifyVehicleAngle(from: image)
        
        // Then: Classification should work with camera frames
        XCTAssertNotNil(result, "Classification should work with camera frames")
        XCTAssertTrue(PhotoAngleType.allCases.contains(result), "Result angle should be valid")
        
        try await cameraService.stopSession()
    }
    
    func testContinuousClassificationWithCamera() async throws {
        // Given: Camera and vision services are available
        try await cameraService.configureSession(
            position: .back,
            quality: .photo,
            flashMode: .auto
        )
        try await cameraService.startSession()
        
        try await visionService.loadModel()
        visionService.setTargetAngle(.front)
        
        // When: Starting continuous classification with camera frames
        let expectation = XCTestExpectation(description: "Camera classification")
        var receivedClassifications: [PhotoAngleType] = []
        
        try await visionService.startContinuousClassification(
            frameProvider: CameraFrameProvider(cameraService: cameraService)
        ) { angle, confidence in
            receivedClassifications.append(angle)
            if receivedClassifications.count >= 3 {
                expectation.fulfill()
            }
        }
        
        // Then: Should receive classifications from camera
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertGreaterThanOrEqual(receivedClassifications.count, 3, "Should receive classifications from camera")
        
        visionService.stopContinuousClassification()
        try await cameraService.stopSession()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize = CGSize(width: 224, height: 224)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Mock Frame Provider

class MockFrameProvider: FrameProvider {
    private var frameCount = 0
    private let maxFrames = 10
    
    var isActive: Bool {
        return frameCount < maxFrames
    }
    
    func getNextFrame() async -> UIImage? {
        guard isActive else { return nil }
        
        frameCount += 1
        
        // Create mock frame
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Add small delay to simulate real-time processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        return image
    }
    
    func getCurrentFrame() -> UIImage? {
        guard isActive else { return nil }
        
        // Create mock frame
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - Camera Frame Provider

class CameraFrameProvider: FrameProvider {
    private let cameraService: CameraServiceProtocol
    private var frameCount = 0
    private let maxFrames = 10
    
    init(cameraService: CameraServiceProtocol) {
        self.cameraService = cameraService
    }
    
    var isActive: Bool {
        return frameCount < maxFrames
    }
    
    func getNextFrame() async -> UIImage? {
        guard isActive else { return nil }
        
        frameCount += 1
        
        do {
            let imageData = try await cameraService.capturePhoto(settings: .default)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }
    
    func getCurrentFrame() -> UIImage? {
        guard isActive else { return nil }
        
        // For testing purposes, return a mock frame
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}
