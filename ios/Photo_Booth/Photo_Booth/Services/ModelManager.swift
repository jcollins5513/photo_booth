import Foundation
import CoreML
import Vision
import UIKit

/// Manages CoreML model loading, configuration, and inference for vehicle angle classification
@MainActor
class ModelManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var modelAccuracy: Float = 0.0
    @Published var lastInferenceTime: TimeInterval = 0.0
    
    // MARK: - Private Properties
    private var coreMLModel: MLModel?
    private var _visionModel: VNCoreMLModel?
    private var classificationRequest: VNClassifyImageRequest?
    
    // MARK: - Public Properties
    var visionModel: VNCoreMLModel? {
        return _visionModel
    }
    
    // MARK: - Configuration
    private let confidenceThreshold: Float = 0.8
    private let maxInferenceTime: TimeInterval = 0.1 // 100ms target
    
    // MARK: - Vehicle Angle Types
    enum VehicleAngle: String, CaseIterable {
        case front = "front"
        case frontLeft = "front_left"
        case frontRight = "front_right"
        case left = "left"
        case right = "right"
        case rear = "rear"
        case rearLeft = "rear_left"
        case rearRight = "rear_right"
        
        var displayName: String {
            switch self {
            case .front: return "Front"
            case .frontLeft: return "Front Left"
            case .frontRight: return "Front Right"
            case .left: return "Left Side"
            case .right: return "Right Side"
            case .rear: return "Rear"
            case .rearLeft: return "Rear Left"
            case .rearRight: return "Rear Right"
            }
        }
        
        var captureOrder: Int {
            switch self {
            case .front: return 1
            case .frontRight: return 2
            case .right: return 3
            case .rearLeft: return 4
            case .rear: return 5
            case .rearRight: return 6
            case .left: return 7
            case .frontLeft: return 8
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        Task {
            await loadModel()
        }
    }
    
    // MARK: - Model Loading
    func loadModel() async {
        do {
            try await loadCoreMLModel()
            isModelLoaded = true
            print("✅ ModelManager: CoreML model loaded successfully")
        } catch {
            print("❌ ModelManager: Failed to load model - \(error.localizedDescription)")
            isModelLoaded = false
        }
    }
    
    private func loadCoreMLModel() async throws {
        // Load the actual CoreML model from the bundle
        // Try .mlmodelc first (compiled version), then .mlmodel
        guard let modelURL = Bundle.main.url(forResource: "VehicleAngleClassifier", withExtension: "mlmodelc") ??
                             Bundle.main.url(forResource: "VehicleAngleClassifier", withExtension: "mlmodel") else {
            throw ModelError.modelNotFound
        }
        
        do {
            // Load the CoreML model
            coreMLModel = try MLModel(contentsOf: modelURL)
            
            // Create Vision model wrapper
            _visionModel = try VNCoreMLModel(for: coreMLModel!)
            
            // Create classification request
            classificationRequest = VNClassifyImageRequest()
            
            // Set model accuracy based on training data
            modelAccuracy = 0.95 // This should be updated based on actual model performance
            
            print("✅ ModelManager: VehicleAngleClassifier model loaded with \(VehicleAngle.allCases.count) angle classes")
            
            // Log model information for debugging
            logModelInfo()
        } catch {
            throw ModelError.modelLoadFailed
        }
    }
    
    // MARK: - Image Classification
    func classifyVehicleAngle(from image: UIImage) async -> (angle: VehicleAngle?, confidence: Float) {
        guard isModelLoaded else {
            print("❌ ModelManager: Model not loaded")
            return (nil, 0.0)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // In production, this would use the actual Vision framework classification
        let result = await performClassification(image: image)
        
        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
        lastInferenceTime = inferenceTime
        
        return result
    }
    
    private func performClassification(image: UIImage) async -> (angle: VehicleAngle?, confidence: Float) {
        guard let visionModel = visionModel else {
            print("❌ ModelManager: Vision model not available")
            return (nil, 0.0)
        }
        
        return await withCheckedContinuation { continuation in
            // Create a custom Vision request using our CoreML model
            let classifyRequest = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    print("❌ ModelManager: Classification error - \(error.localizedDescription)")
                    continuation.resume(returning: (nil, 0.0))
                    return
                }
                
                // Handle VNCoreMLRequest results - they come as VNClassificationObservation
                guard let observations = request.results as? [VNClassificationObservation] else {
                    print("❌ ModelManager: No CoreML results")
                    print("🔍 ModelManager: Request results type: \(type(of: request.results))")
                    print("🔍 ModelManager: Request results: \(String(describing: request.results))")
                    continuation.resume(returning: (nil, 0.0))
                    return
                }
                
                print("🔍 ModelManager: Found \(observations.count) classification observations")
                for (index, obs) in observations.enumerated() {
                    print("   \(index): identifier=\(obs.identifier), confidence=\(obs.confidence)")
                }
                
                // Find the best classification result
                guard let bestObservation = observations.first else {
                    print("❌ ModelManager: No observations found")
                    continuation.resume(returning: (nil, 0.0))
                    return
                }
                
                // Extract the string value and confidence
                let stringValue = bestObservation.identifier
                let confidence = bestObservation.confidence
                
                // Map the CoreML output to our VehicleAngle enum
                let detectedAngle = self.mapCoreMLOutputToVehicleAngle(stringValue)
                
                // Debug: Print the result
                print("🔍 ModelManager: Model output - identifier: \(stringValue), confidence: \(confidence)")
                print("🔍 ModelManager: All probabilities:")
                for (index, obs) in observations.enumerated() {
                    print("   \(index): \(obs.identifier): \(obs.confidence)")
                }
                
                if let angle = detectedAngle {
                    print("✅ ModelManager: Detected angle: \(angle.displayName) with confidence: \(confidence)")
                } else {
                    print("⚠️ ModelManager: Unknown angle identifier: \(stringValue)")
                    print("🔍 ModelManager: Detected angle: Unknown with confidence: \(confidence)")
                }
                continuation.resume(returning: (detectedAngle, confidence))
            }
            
            // Perform the classification using the Vision model
            let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            do {
                try handler.perform([classifyRequest])
            } catch {
                print("❌ ModelManager: Failed to perform classification - \(error.localizedDescription)")
                continuation.resume(returning: (nil, 0.0))
            }
        }
    }
    
    private func mapCoreMLOutputToVehicleAngle(_ identifier: String) -> VehicleAngle? {
        // Map CoreML model output identifiers to our VehicleAngle enum
        // This mapping matches the actual class labels from the trained model
        switch identifier {
        case "front":
            return .front
        case "frontLeft":
            return .frontLeft
        case "frontRight":
            return .frontRight
        case "leftSide":
            return .left
        case "rightSide":
            return .right
        case "rear":
            return .rear
        case "rearLeft":
            return .rearLeft
        case "rearRight":
            return .rearRight
        // Handle legacy naming conventions
        case "front_left", "frontleft":
            return .frontLeft
        case "front_right", "frontright":
            return .frontRight
        case "left", "left_side", "leftside":
            return .left
        case "right", "right_side", "rightside":
            return .right
        case "rear_left", "rearleft":
            return .rearLeft
        case "rear_right", "rearright":
            return .rearRight
        // Handle unexpected identifiers that might be from the model
        case "material":
            print("⚠️ ModelManager: Received 'material' identifier - this might indicate a model issue")
            return nil
        default:
            print("⚠️ ModelManager: Unknown angle identifier: \(identifier)")
            return nil
        }
    }
    
    // MARK: - Position Detection
    func shouldTriggerCapture(for angle: VehicleAngle, confidence: Float) -> Bool {
        return confidence >= confidenceThreshold
    }
    
    // MARK: - Debug Methods
    func getAvailableClassLabels() -> [String] {
        // Return the known class labels from our mapping
        return ["front", "frontLeft", "frontRight", "leftSide", "rightSide", "rear", "rearLeft", "rearRight"]
    }
    
    func logModelInfo() {
        guard let model = coreMLModel else {
            print("❌ ModelManager: No model loaded")
            return
        }
        
        print("📊 ModelManager: Model Information")
        print("   - Model Description: \(model.modelDescription)")
        print("   - Available Classes: \(getAvailableClassLabels())")
    }
    
    func getNextAngleInSequence(currentAngle: VehicleAngle?) -> VehicleAngle? {
        guard let current = currentAngle else {
            return .front
        }
        
        let allAngles = VehicleAngle.allCases.sorted { $0.captureOrder < $1.captureOrder }
        guard let currentIndex = allAngles.firstIndex(of: current) else {
            return .front
        }
        
        let nextIndex = currentIndex + 1
        return nextIndex < allAngles.count ? allAngles[nextIndex] : nil
    }
    
    // MARK: - Model Configuration
    func updateConfidenceThreshold(_ threshold: Float) {
        // Update confidence threshold for auto-capture
        // This would be persisted in UserDefaults
        UserDefaults.standard.set(threshold, forKey: "confidenceThreshold")
    }
    
    func getConfidenceThreshold() -> Float {
        return UserDefaults.standard.float(forKey: "confidenceThreshold") != 0 ? 
               UserDefaults.standard.float(forKey: "confidenceThreshold") : confidenceThreshold
    }
    
    // MARK: - Performance Monitoring
    func getPerformanceMetrics() -> (averageInferenceTime: TimeInterval, modelAccuracy: Float) {
        return (lastInferenceTime, modelAccuracy)
    }
    
    func isPerformanceAcceptable() -> Bool {
        return lastInferenceTime <= maxInferenceTime && modelAccuracy >= 0.9
    }
}

// MARK: - Error Handling
extension ModelManager {
    enum ModelError: LocalizedError {
        case modelNotFound
        case modelLoadFailed
        case classificationFailed
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "CoreML model file not found"
            case .modelLoadFailed:
                return "Failed to load CoreML model"
            case .classificationFailed:
                return "Image classification failed"
            case .invalidImage:
                return "Invalid image provided for classification"
            }
        }
    }
}