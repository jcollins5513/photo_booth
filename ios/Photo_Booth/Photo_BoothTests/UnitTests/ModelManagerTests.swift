import XCTest
import UIKit
@testable import Photo_Booth

/// Unit tests for ModelManager
@MainActor
class ModelManagerTests: XCTestCase {
    
    var modelManager: ModelManager!
    
    override func setUp() {
        super.setUp()
        modelManager = ModelManager()
    }
    
    override func tearDown() {
        modelManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(modelManager)
        XCTAssertFalse(modelManager.isModelLoaded)
        XCTAssertEqual(modelManager.modelAccuracy, 0.0)
        XCTAssertEqual(modelManager.lastInferenceTime, 0.0)
    }
    
    // MARK: - Model Loading Tests
    
    func testLoadModel() async {
        // When
        await modelManager.loadModel()
        
        // Then
        XCTAssertTrue(modelManager.isModelLoaded)
        XCTAssertGreaterThan(modelManager.modelAccuracy, 0.0)
    }
    
    // MARK: - Vehicle Angle Classification Tests
    
    func testClassifyVehicleAngle() async {
        // Given
        await modelManager.loadModel()
        let testImage = createTestImage()
        
        // When
        let result = await modelManager.classifyVehicleAngle(from: testImage)
        
        // Then
        XCTAssertNotNil(result.angle)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }
    
    func testClassifyVehicleAngleWithInvalidImage() async {
        // Given
        await modelManager.loadModel()
        let invalidImage = UIImage()
        
        // When
        let result = await modelManager.classifyVehicleAngle(from: invalidImage)
        
        // Then
        // Should handle invalid image gracefully
        XCTAssertNotNil(result)
    }
    
    // MARK: - Position Detection Tests
    
    func testShouldTriggerCapture() {
        // Given
        let angle = ModelManager.VehicleAngle.front
        let highConfidence: Float = 0.9
        let lowConfidence: Float = 0.5
        
        // When - High confidence
        let shouldCaptureHigh = modelManager.shouldTriggerCapture(for: angle, confidence: highConfidence)
        
        // Then
        XCTAssertTrue(shouldCaptureHigh)
        
        // When - Low confidence
        let shouldCaptureLow = modelManager.shouldTriggerCapture(for: angle, confidence: lowConfidence)
        
        // Then
        XCTAssertFalse(shouldCaptureLow)
    }
    
    func testGetNextAngleInSequence() {
        // Given
        let currentAngle = ModelManager.VehicleAngle.front
        
        // When
        let nextAngle = modelManager.getNextAngleInSequence(currentAngle: currentAngle)
        
        // Then
        XCTAssertNotNil(nextAngle)
        XCTAssertEqual(nextAngle, .frontLeft)
    }
    
    func testGetNextAngleInSequenceWithNil() {
        // Given
        let currentAngle: ModelManager.VehicleAngle? = nil
        
        // When
        let nextAngle = modelManager.getNextAngleInSequence(currentAngle: currentAngle)
        
        // Then
        XCTAssertNotNil(nextAngle)
        XCTAssertEqual(nextAngle, .front)
    }
    
    func testGetNextAngleInSequenceAtEnd() {
        // Given
        let currentAngle = ModelManager.VehicleAngle.rearRight
        
        // When
        let nextAngle = modelManager.getNextAngleInSequence(currentAngle: currentAngle)
        
        // Then
        XCTAssertNil(nextAngle)
    }
    
    // MARK: - Configuration Tests
    
    func testUpdateConfidenceThreshold() {
        // Given
        let newThreshold: Float = 0.9
        
        // When
        modelManager.updateConfidenceThreshold(newThreshold)
        
        // Then
        XCTAssertEqual(modelManager.getConfidenceThreshold(), newThreshold)
    }
    
    func testGetConfidenceThreshold() {
        // Given
        let expectedThreshold: Float = 0.8
        
        // When
        let threshold = modelManager.getConfidenceThreshold()
        
        // Then
        XCTAssertEqual(threshold, expectedThreshold)
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testGetPerformanceMetrics() {
        // Given
        modelManager.lastInferenceTime = 0.05
        modelManager.modelAccuracy = 0.95
        
        // When
        let metrics = modelManager.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.averageInferenceTime, 0.05)
        XCTAssertEqual(metrics.modelAccuracy, 0.95)
    }
    
    func testIsPerformanceAcceptable() {
        // Given
        modelManager.lastInferenceTime = 0.05 // 50ms
        modelManager.modelAccuracy = 0.95
        
        // When
        let isAcceptable = modelManager.isPerformanceAcceptable()
        
        // Then
        XCTAssertTrue(isAcceptable)
    }
    
    func testIsPerformanceNotAcceptable() {
        // Given
        modelManager.lastInferenceTime = 0.2 // 200ms - too slow
        modelManager.modelAccuracy = 0.8 // too low
        
        // When
        let isAcceptable = modelManager.isPerformanceAcceptable()
        
        // Then
        XCTAssertFalse(isAcceptable)
    }
    
    // MARK: - Vehicle Angle Tests
    
    func testVehicleAngleDisplayNames() {
        // Test all angle display names
        XCTAssertEqual(ModelManager.VehicleAngle.front.displayName, "Front")
        XCTAssertEqual(ModelManager.VehicleAngle.frontLeft.displayName, "Front Left")
        XCTAssertEqual(ModelManager.VehicleAngle.frontRight.displayName, "Front Right")
        XCTAssertEqual(ModelManager.VehicleAngle.left.displayName, "Left Side")
        XCTAssertEqual(ModelManager.VehicleAngle.right.displayName, "Right Side")
        XCTAssertEqual(ModelManager.VehicleAngle.rear.displayName, "Rear")
        XCTAssertEqual(ModelManager.VehicleAngle.rearLeft.displayName, "Rear Left")
        XCTAssertEqual(ModelManager.VehicleAngle.rearRight.displayName, "Rear Right")
    }
    
    func testVehicleAngleCaptureOrder() {
        // Test capture order sequence
        let angles = ModelManager.VehicleAngle.allCases.sorted { $0.captureOrder < $1.captureOrder }
        
        XCTAssertEqual(angles[0], .front)
        XCTAssertEqual(angles[1], .frontLeft)
        XCTAssertEqual(angles[2], .frontRight)
        XCTAssertEqual(angles[3], .left)
        XCTAssertEqual(angles[4], .right)
        XCTAssertEqual(angles[5], .rear)
        XCTAssertEqual(angles[6], .rearLeft)
        XCTAssertEqual(angles[7], .rearRight)
    }
    
    // MARK: - Error Handling Tests
    
    func testModelErrorDescriptions() {
        // Test error descriptions
        XCTAssertEqual(ModelManager.ModelError.modelNotFound.errorDescription, "CoreML model file not found")
        XCTAssertEqual(ModelManager.ModelError.modelLoadFailed.errorDescription, "Failed to load CoreML model")
        XCTAssertEqual(ModelManager.ModelError.classificationFailed.errorDescription, "Image classification failed")
        XCTAssertEqual(ModelManager.ModelError.invalidImage.errorDescription, "Invalid image provided for classification")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 224, height: 224) // Standard model input size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
