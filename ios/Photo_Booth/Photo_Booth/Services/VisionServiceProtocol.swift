import Foundation
import Vision
import CoreML
import UIKit

/// Protocol defining the vision service interface for vehicle angle detection
protocol VisionServiceProtocol {
    /// Load the CoreML model for vehicle angle classification
    func loadModel() async throws
    
    /// Check if the model is currently loaded
    var isModelLoaded: Bool { get }
    
    /// Classify vehicle angle from UIImage
    func classifyVehicleAngle(from image: UIImage) async throws -> PhotoAngleType
    
    /// Classify vehicle angle from image data
    func classifyVehicleAngle(from imageData: Data) async throws -> PhotoAngleType
    
    /// Start continuous classification with frame provider
    func startContinuousClassification(
        frameProvider: FrameProvider,
        onClassification: @escaping (PhotoAngleType, Float) -> Void
    ) async throws
    
    /// Stop continuous classification
    func stopContinuousClassification()
    
    /// Get current confidence threshold
    func getConfidenceThreshold() -> Float
    
    /// Set confidence threshold (0.0 to 1.0)
    func setConfidenceThreshold(_ threshold: Float)
    
    /// Get current target angle
    func getTargetAngle() -> PhotoAngleType
    
    /// Set target angle for classification
    func setTargetAngle(_ angle: PhotoAngleType)
}

/// Protocol for providing camera frames to vision service
protocol FrameProvider: AnyObject {
    /// Get the latest camera frame
    func getCurrentFrame() -> UIImage?
    
    /// Check if frame provider is active
    var isActive: Bool { get }
}

/// Vehicle photo angle types
enum PhotoAngleType: String, CaseIterable, Codable {
    case front = "front"
    case rear = "rear"
    case leftSide = "left_side"
    case rightSide = "right_side"
    case frontLeft = "front_left"
    case frontRight = "front_right"
    case rearLeft = "rear_left"
    case rearRight = "rear_right"
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .front: return "Front"
        case .rear: return "Rear"
        case .leftSide: return "Left Side"
        case .rightSide: return "Right Side"
        case .frontLeft: return "Front Left"
        case .frontRight: return "Front Right"
        case .rearLeft: return "Rear Left"
        case .rearRight: return "Rear Right"
        }
    }
    
    /// Get the next angle in sequence
    var nextAngle: PhotoAngleType? {
        let allCases = PhotoAngleType.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return nil }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

/// Vision service errors
enum VisionServiceError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case classificationFailed(String)
    case invalidImage
    case invalidImageData
    case frameProviderNotAvailable
    case continuousClassificationNotStarted
    case invalidConfidenceThreshold
    case invalidTargetAngle
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded. Call loadModel() first."
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .classificationFailed(let message):
            return "Classification failed: \(message)"
        case .invalidImage:
            return "Invalid image provided for classification"
        case .invalidImageData:
            return "Invalid image data provided for classification"
        case .frameProviderNotAvailable:
            return "Frame provider is not available"
        case .continuousClassificationNotStarted:
            return "Continuous classification has not been started"
        case .invalidConfidenceThreshold:
            return "Confidence threshold must be between 0.0 and 1.0"
        case .invalidTargetAngle:
            return "Invalid target angle provided"
        }
    }
}
