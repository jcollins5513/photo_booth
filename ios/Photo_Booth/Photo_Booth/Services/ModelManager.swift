import Foundation
import CoreML
import Vision
import UIKit

/// Manages CoreML model loading and inference for vehicle angle classification
class ModelManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var modelLoadError: String?
    @Published var inferenceCount = 0
    @Published var averageInferenceTime: Double = 0.0
    
    // MARK: - Private Properties
    private var coreMLModel: MLModel?
    private var visionModel: VNCoreMLModel?
    private var inferenceTimes: [Double] = []
    private let maxInferenceTimeHistory = 10
    
    // MARK: - Model Configuration
    private let modelName = "VehicleAngleClassifier"
    private let modelExtension = "mlmodel"
    private let inputImageSize = CGSize(width: 224, height: 224)
    private let confidenceThreshold: Float = 0.7
    
    // MARK: - Initialization
    init() {
        Task {
            await loadModel()
        }
    }
    
    // MARK: - Model Loading
    func loadModel() async {
        do {
            // Try to load the model from bundle
            guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: modelExtension) else {
                // If no model found, create a placeholder model
                await createPlaceholderModel()
                return
            }
            
            coreMLModel = try MLModel(contentsOf: modelURL)
            visionModel = try VNCoreMLModel(for: coreMLModel!)
            isModelLoaded = true
            modelLoadError = nil
            
            print("✅ CoreML model loaded successfully: \(modelName)")
            
        } catch {
            await MainActor.run {
                self.modelLoadError = "Failed to load model: \(error.localizedDescription)"
                self.isModelLoaded = false
            }
            print("❌ Failed to load CoreML model: \(error)")
        }
    }
    
    private func createPlaceholderModel() async {
        // Create a simple placeholder model for development
        // This will be replaced with a real trained model
        await MainActor.run {
            self.isModelLoaded = true
            self.modelLoadError = "Using placeholder model - replace with trained model"
        }
        print("⚠️ Using placeholder model - replace with trained VehicleAngleClassifier.mlmodel")
    }
    
    // MARK: - Image Classification
    func classifyVehicleAngle(from image: UIImage) async throws -> (PhotoAngleType, Float) {
        guard isModelLoaded else {
            throw ModelManagerError.modelNotLoaded
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Preprocess image
        let processedImage = preprocessImage(image)
        
        // Create classification request
        let request = VNClassifyImageRequest()
        
        // Perform classification
        let handler = VNImageRequestHandler(cgImage: processedImage.cgImage!, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results else {
                throw ModelManagerError.classificationFailed("No results from model")
            }
            
            // Process results
            let result = processClassificationResults(observations)
            
            // Update performance metrics
            let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
            updateInferenceMetrics(inferenceTime)
            
            return result
            
        } catch {
            throw ModelManagerError.classificationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // Resize image to model input size
        let renderer = UIGraphicsImageRenderer(size: inputImageSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: inputImageSize))
        }
    }
    
    // MARK: - Results Processing
    private func processClassificationResults(_ observations: [VNClassificationObservation]) -> (PhotoAngleType, Float) {
        // Sort by confidence
        let sortedObservations = observations.sorted { $0.confidence > $1.confidence }
        
        // Find the best match for vehicle angles
        for observation in sortedObservations {
            if let angleType = mapIdentifierToAngleType(observation.identifier),
               observation.confidence >= confidenceThreshold {
                return (angleType, observation.confidence)
            }
        }
        
        // If no high-confidence match, return the best available
        if let bestObservation = sortedObservations.first,
           let angleType = mapIdentifierToAngleType(bestObservation.identifier) {
            return (angleType, bestObservation.confidence)
        }
        
        // Fallback to front angle with low confidence
        return (.front, 0.1)
    }
    
    private func mapIdentifierToAngleType(_ identifier: String) -> PhotoAngleType? {
        // Map model output identifiers to PhotoAngleType
        let mapping: [String: PhotoAngleType] = [
            "front": .front,
            "rear": .rear,
            "left_side": .leftSide,
            "right_side": .rightSide,
            "front_left": .frontLeft,
            "front_right": .frontRight,
            "rear_left": .rearLeft,
            "rear_right": .rearRight
        ]
        
        return mapping[identifier.lowercased()]
    }
    
    // MARK: - Performance Monitoring
    private func updateInferenceMetrics(_ inferenceTime: Double) {
        inferenceCount += 1
        inferenceTimes.append(inferenceTime)
        
        // Keep only recent inference times
        if inferenceTimes.count > maxInferenceTimeHistory {
            inferenceTimes.removeFirst()
        }
        
        // Calculate average
        averageInferenceTime = inferenceTimes.reduce(0, +) / Double(inferenceTimes.count)
    }
    
    // MARK: - Model Information
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            name: modelName,
            isLoaded: isModelLoaded,
            inputSize: inputImageSize,
            confidenceThreshold: confidenceThreshold,
            inferenceCount: inferenceCount,
            averageInferenceTime: averageInferenceTime
        )
    }
    
    // MARK: - Error Handling
    func clearError() {
        modelLoadError = nil
    }
}

// MARK: - Supporting Types
struct ModelInfo {
    let name: String
    let isLoaded: Bool
    let inputSize: CGSize
    let confidenceThreshold: Float
    let inferenceCount: Int
    let averageInferenceTime: Double
}

enum ModelManagerError: Error, LocalizedError {
    case modelNotLoaded
    case classificationFailed(String)
    case imageProcessingFailed
    case invalidModelFormat
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "CoreML model is not loaded"
        case .classificationFailed(let message):
            return "Classification failed: \(message)"
        case .imageProcessingFailed:
            return "Failed to process image for classification"
        case .invalidModelFormat:
            return "Invalid model format"
        }
    }
}
