import Foundation
import Vision
import CoreML
import UIKit

// MARK: - Vision Service Contract

/// Protocol defining the vision service interface for vehicle angle detection
protocol VisionServiceProtocol {
    
    // MARK: - Model Management
    
    /// Load CoreML model for vehicle angle classification
    /// - Throws: VisionServiceError if model loading fails
    func loadModel() async throws
    
    /// Check if model is loaded and ready
    /// - Returns: True if model is loaded and ready for inference
    var isModelLoaded: Bool { get }
    
    // MARK: - Image Classification
    
    /// Classify vehicle angle from image
    /// - Parameter image: Input image for classification
    /// - Returns: Classification result with confidence scores
    func classifyVehicleAngle(from image: UIImage) async throws -> VehicleAngleClassification
    
    /// Classify vehicle angle from image data
    /// - Parameter imageData: Input image data for classification
    /// - Returns: Classification result with confidence scores
    func classifyVehicleAngle(from imageData: Data) async throws -> VehicleAngleClassification
    
    /// Start continuous classification for real-time detection
    /// - Parameters:
    ///   - frameProvider: Source of camera frames
    ///   - completion: Completion handler for each classification result
    func startContinuousClassification(
        frameProvider: FrameProvider,
        completion: @escaping (VehicleAngleClassification) -> Void
    ) async throws
    
    /// Stop continuous classification
    func stopContinuousClassification()
    
    // MARK: - Configuration
    
    /// Set confidence threshold for auto-capture
    /// - Parameter threshold: Confidence threshold (0.0-1.0)
    func setConfidenceThreshold(_ threshold: Double)
    
    /// Get current confidence threshold
    /// - Returns: Current confidence threshold
    func getConfidenceThreshold() -> Double
    
    /// Set target angle for detection
    /// - Parameter angle: Target angle to detect
    func setTargetAngle(_ angle: PhotoAngleType)
    
    /// Get current target angle
    /// - Returns: Current target angle
    func getTargetAngle() -> PhotoAngleType
}

// MARK: - Supporting Types

/// Vehicle angle classification result
struct VehicleAngleClassification {
    let angle: PhotoAngleType
    let confidence: Double
    let allConfidences: [PhotoAngleType: Double]
    let processingTime: TimeInterval
    let timestamp: Date
    
    /// Check if classification meets confidence threshold
    /// - Parameter threshold: Confidence threshold to check against
    /// - Returns: True if confidence meets threshold
    func meetsThreshold(_ threshold: Double) -> Bool {
        return confidence >= threshold
    }
    
    /// Get confidence for specific angle
    /// - Parameter angle: Angle to get confidence for
    /// - Returns: Confidence score for the angle
    func confidence(for angle: PhotoAngleType) -> Double {
        return allConfidences[angle] ?? 0.0
    }
}

/// Frame provider protocol for continuous classification
protocol FrameProvider {
    /// Get next frame for classification
    /// - Returns: Next image frame or nil if no more frames
    func getNextFrame() async -> UIImage?
    
    /// Check if frame provider is active
    /// - Returns: True if frame provider is active
    var isActive: Bool { get }
}

/// Photo angle type enumeration
enum PhotoAngleType: String, CaseIterable {
    case front = "front"
    case frontLeft = "front_left"
    case frontRight = "front_right"
    case side = "side"
    case rearRight = "rear_right"
    case rear = "rear"
    case rearLeft = "rear_left"
    case oppositeSide = "opposite_side"
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .front: return "Front View"
        case .frontLeft: return "Front Left 3/4"
        case .frontRight: return "Front Right 3/4"
        case .side: return "Side View"
        case .rearRight: return "Rear Right 3/4"
        case .rear: return "Rear View"
        case .rearLeft: return "Rear Left 3/4"
        case .oppositeSide: return "Opposite Side"
        }
    }
    
    /// Angle in degrees for reference
    var angleDegrees: Int {
        switch self {
        case .front: return 0
        case .frontLeft: return 45
        case .frontRight: return -45
        case .side: return 90
        case .rearRight: return -135
        case .rear: return 180
        case .rearLeft: return 135
        case .oppositeSide: return 270
        }
    }
}

/// Vision service errors
enum VisionServiceError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case classificationFailed(String)
    case invalidImage
    case invalidImageData
    case continuousClassificationNotStarted
    case frameProviderNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Vision model not loaded"
        case .modelLoadFailed(let message):
            return "Model loading failed: \(message)"
        case .classificationFailed(let message):
            return "Classification failed: \(message)"
        case .invalidImage:
            return "Invalid image provided"
        case .invalidImageData:
            return "Invalid image data provided"
        case .continuousClassificationNotStarted:
            return "Continuous classification not started"
        case .frameProviderNotAvailable:
            return "Frame provider not available"
        }
    }
}

// MARK: - Contract Tests

/// Contract tests for vision service implementation
class VisionServiceContractTests {
    
    private let visionService: VisionServiceProtocol
    
    init(visionService: VisionServiceProtocol) {
        self.visionService = visionService
    }
    
    /// Test model loading
    func testModelLoading() async throws {
        // Test model loading
        try await visionService.loadModel()
        
        // Verify model is loaded
        XCTAssertTrue(visionService.isModelLoaded, "Model should be loaded after loadModel()")
    }
    
    /// Test image classification
    func testImageClassification() async throws {
        // Load model first
        try await visionService.loadModel()
        
        // Create test image (implementation specific)
        let testImage = createTestImage()
        
        // Test classification
        let result = try await visionService.classifyVehicleAngle(from: testImage)
        
        // Verify result
        XCTAssertNotNil(result, "Classification result should not be nil")
        XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0, "Confidence should be between 0.0 and 1.0")
        XCTAssertTrue(PhotoAngleType.allCases.contains(result.angle), "Result angle should be valid")
        XCTAssertEqual(result.allConfidences.count, PhotoAngleType.allCases.count, "All confidences should be present")
    }
    
    /// Test image data classification
    func testImageDataClassification() async throws {
        // Load model first
        try await visionService.loadModel()
        
        // Create test image data
        let testImage = createTestImage()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        
        // Test classification
        let result = try await visionService.classifyVehicleAngle(from: imageData)
        
        // Verify result
        XCTAssertNotNil(result, "Classification result should not be nil")
        XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0, "Confidence should be between 0.0 and 1.0")
    }
    
    /// Test confidence threshold configuration
    func testConfidenceThreshold() async throws {
        // Test default threshold
        let defaultThreshold = visionService.getConfidenceThreshold()
        XCTAssertTrue(defaultThreshold >= 0.0 && defaultThreshold <= 1.0, "Default threshold should be valid")
        
        // Test setting threshold
        let newThreshold = 0.8
        visionService.setConfidenceThreshold(newThreshold)
        
        let updatedThreshold = visionService.getConfidenceThreshold()
        XCTAssertEqual(updatedThreshold, newThreshold, "Threshold should be updated")
    }
    
    /// Test target angle configuration
    func testTargetAngleConfiguration() async throws {
        // Test default target angle
        let defaultAngle = visionService.getTargetAngle()
        XCTAssertTrue(PhotoAngleType.allCases.contains(defaultAngle), "Default target angle should be valid")
        
        // Test setting target angle
        let newAngle = PhotoAngleType.front
        visionService.setTargetAngle(newAngle)
        
        let updatedAngle = visionService.getTargetAngle()
        XCTAssertEqual(updatedAngle, newAngle, "Target angle should be updated")
    }
    
    /// Test continuous classification lifecycle
    func testContinuousClassificationLifecycle() async throws {
        // Load model first
        try await visionService.loadModel()
        
        // Create mock frame provider
        let frameProvider = MockFrameProvider()
        
        // Test starting continuous classification
        let expectation = XCTestExpectation(description: "Continuous classification")
        var receivedClassifications: [VehicleAngleClassification] = []
        
        try await visionService.startContinuousClassification(
            frameProvider: frameProvider
        ) { classification in
            receivedClassifications.append(classification)
            if receivedClassifications.count >= 3 {
                expectation.fulfill()
            }
        }
        
        // Wait for classifications
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify classifications received
        XCTAssertGreaterThanOrEqual(receivedClassifications.count, 3, "Should receive multiple classifications")
        
        // Test stopping continuous classification
        visionService.stopContinuousClassification()
        
        // Verify it can be stopped without error
        XCTAssertNoThrow(visionService.stopContinuousClassification(), "Should be able to stop multiple times")
    }
    
    /// Test classification performance
    func testClassificationPerformance() async throws {
        // Load model first
        try await visionService.loadModel()
        
        let testImage = createTestImage()
        let iterations = 10
        
        // Measure classification time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await visionService.classifyVehicleAngle(from: testImage)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let averageTime = (endTime - startTime) / Double(iterations)
        
        // Verify performance (should be under 200ms per classification)
        XCTAssertLessThan(averageTime, 0.2, "Average classification time should be under 200ms")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        // Create a simple test image (implementation specific)
        // This would need to be implemented based on the actual test requirements
        let size = CGSize(width: 224, height: 224)
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
}

// MARK: - Test Helpers

import XCTest

extension XCTestCase {
    
    /// Create vision service contract tests
    /// - Parameter visionService: Vision service implementation to test
    /// - Returns: Configured contract tests
    func createVisionServiceContractTests(visionService: VisionServiceProtocol) -> VisionServiceContractTests {
        return VisionServiceContractTests(visionService: visionService)
    }
}
