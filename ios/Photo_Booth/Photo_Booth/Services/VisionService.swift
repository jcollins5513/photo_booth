import Foundation
import Vision
import CoreML
import UIKit

/// Vision service implementation for vehicle angle detection
class VisionService: VisionServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    
    private var model: VNCoreMLModel?
    private var confidenceThreshold: Float = 0.8
    private var targetAngle: PhotoAngleType = .front
    private var isContinuousClassificationActive = false
    private var frameProvider: FrameProvider?
    private var classificationHandler: ((PhotoAngleType, Float) -> Void)?
    
    // MARK: - New Properties for Enhanced Vision
    private var modelManager: ModelManager?
    private var imageProcessor: ImageProcessor?
    private var processingQueue = DispatchQueue(label: "vision.processing", qos: .userInitiated)
    private let processingInterval: TimeInterval = 0.1 // Process every 100ms (10 FPS)
    private var lastProcessingTime: TimeInterval = 0
    
    // MARK: - Published Properties for UI
    @Published var isProcessing = false
    @Published var currentAngle: String = ""
    @Published var confidence: Float = 0.0
    @Published var isPositionValid = false
    @Published var imageQuality: Float = 0.0
    @Published var qualityIssues: [ImageProcessor.QualityIssue] = []
    
    // MARK: - Initialization
    init() {
        Task { @MainActor in
            setupEnhancedServices()
        }
    }
    
    @MainActor
    private func setupEnhancedServices() {
        modelManager = ModelManager()
        imageProcessor = ImageProcessor()
    }
    
    // MARK: - Model Management
    
    func loadModel() async throws {
        // Load the model through ModelManager
        guard let modelManager = modelManager else {
            throw VisionServiceError.modelLoadFailed("ModelManager not initialized")
        }
        
        await modelManager.loadModel()
        
        if await modelManager.isModelLoaded {
            // Get the Vision model from ModelManager
            self.model = await modelManager.visionModel
            print("✅ VisionService: Model loaded successfully through ModelManager")
        } else {
            throw VisionServiceError.modelLoadFailed("Failed to load model through ModelManager")
        }
    }
    
    var isModelLoaded: Bool {
        return model != nil
    }
    
    // MARK: - Classification
    
    func classifyVehicleAngle(from image: UIImage) async throws -> PhotoAngleType {
        guard isModelLoaded else {
            throw VisionServiceError.modelNotLoaded
        }
        
        guard image.size.width > 0 && image.size.height > 0 else {
            throw VisionServiceError.invalidImage
        }
        
        // Use enhanced classification with ModelManager
        if let modelManager = modelManager, let imageProcessor = imageProcessor {
            do {
                // Assess image quality
                let qualityAssessment = imageProcessor.assessImageQuality(image)
                
                // Preprocess image
                guard let processedImage = imageProcessor.preprocessForClassification(image) else {
                    print("❌ VisionService: Failed to preprocess image for classification")
                    throw VisionServiceError.invalidImage
                }
                
                // Classify using ModelManager
                let result = await modelManager.classifyVehicleAngle(from: processedImage)
                
                // Update published properties
                await MainActor.run {
                    if let angle = result.angle {
                        self.currentAngle = angle.displayName
                        self.confidence = result.confidence
                        // For sequential capture, we just need a stable vehicle view with good confidence
                        // Don't require specific angle matching - just ensure it's a valid vehicle detection
                        let isValidVehicleView = result.confidence > 0.5 && isValidVehicleAngle(angle, confidence: result.confidence)
                        self.isPositionValid = isValidVehicleView
                        print("✅ VisionService: Detected angle: \(angle.displayName) with confidence: \(result.confidence) - Position valid: \(self.isPositionValid)")
                    } else {
                        self.currentAngle = "Unknown"
                        self.confidence = result.confidence
                        // Even if we can't classify the angle, if confidence is high enough, allow capture
                        self.isPositionValid = result.confidence > 0.5
                        print("⚠️ VisionService: Failed to classify angle - result was nil, but confidence is \(result.confidence) - Position valid: \(self.isPositionValid)")
                    }
                    
                    self.imageQuality = qualityAssessment.score
                    self.qualityIssues = qualityAssessment.issues
                }
                
                // Convert ModelManager.VehicleAngle to PhotoAngleType
                if let detectedAngle = result.angle {
                    return convertToPhotoAngleType(detectedAngle)
                } else {
                    print("⚠️ VisionService: No valid angle detected, using default fallback")
                    return .front // Default fallback
                }
            } catch {
                print("❌ VisionService: Classification failed - \(error.localizedDescription)")
                // Update UI to show error state
                await MainActor.run {
                    self.currentAngle = "Error"
                    self.confidence = 0.0
                    self.isPositionValid = false
                }
                // Return default fallback
                return .front
            }
        } else {
            // Fallback to original mock implementation
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second delay
            
            let mockConfidence: Float = 0.85
            let mockAngle = PhotoAngleType.allCases.randomElement() ?? .front
            
            if mockConfidence >= confidenceThreshold {
                return targetAngle
            } else {
                return mockAngle
            }
        }
    }
    
    private func convertToPhotoAngleType(_ angle: ModelManager.VehicleAngle) -> PhotoAngleType {
        switch angle {
        case .front:
            return .front
        case .frontLeft:
            return .frontLeft
        case .frontRight:
            return .frontRight
        case .left:
            return .leftSide
        case .right:
            return .rightSide
        case .rear:
            return .rear
        case .rearLeft:
            return .rearLeft
        case .rearRight:
            return .rearRight
        }
    }
    
    func classifyVehicleAngle(from imageData: Data) async throws -> PhotoAngleType {
        guard let image = UIImage(data: imageData) else {
            throw VisionServiceError.invalidImageData
        }
        
        return try await classifyVehicleAngle(from: image)
    }
    
    // MARK: - Continuous Classification
    
    func startContinuousClassification(
        frameProvider: FrameProvider,
        onClassification: @escaping (PhotoAngleType, Float) -> Void
    ) async throws {
        guard isModelLoaded else {
            throw VisionServiceError.modelNotLoaded
        }
        
        guard frameProvider.isActive else {
            throw VisionServiceError.frameProviderNotAvailable
        }
        
        self.frameProvider = frameProvider
        self.classificationHandler = onClassification
        self.isContinuousClassificationActive = true
        
        // Start continuous classification loop
        Task {
            await continuousClassificationLoop()
        }
    }
    
    func stopContinuousClassification() {
        isContinuousClassificationActive = false
        frameProvider = nil
        classificationHandler = nil
    }
    
    private func continuousClassificationLoop() async {
        while isContinuousClassificationActive {
            guard let frameProvider = frameProvider,
                  let handler = classificationHandler else {
                break
            }
            
            if let frame = frameProvider.getCurrentFrame() {
                do {
                    let angle = try await classifyVehicleAngle(from: frame)
                    // Use the actual confidence from the model instead of mock value
                    let confidence = self.confidence
                    handler(angle, confidence)
                } catch {
                    // Handle classification error
                    print("Classification error: \(error)")
                }
            }
            
            // Small delay to prevent excessive CPU usage
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    // MARK: - Configuration
    
    func getConfidenceThreshold() -> Float {
        return confidenceThreshold
    }
    
    func setConfidenceThreshold(_ threshold: Float) {
        // Clamp threshold between 0.0 and 1.0
        self.confidenceThreshold = max(0.0, min(1.0, threshold))
    }
    
    func getTargetAngle() -> PhotoAngleType {
        return targetAngle
    }
    
    func setTargetAngle(_ angle: PhotoAngleType) {
        self.targetAngle = angle
    }
    
    // MARK: - Enhanced Vision Methods
    
    /// Processes camera frames continuously for real-time analysis
    /// - Parameter image: The camera frame to process
    func processCameraFrame(_ image: UIImage) {
        // Throttle processing to maintain target FPS
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastProcessingTime >= processingInterval else { return }
        lastProcessingTime = currentTime
        
        print("🔍 VisionService: Processing camera frame - size: \(image.size)")
        
        Task {
            await analyzeImage(image)
        }
    }
    
    /// Analyzes an image with enhanced quality assessment
    /// - Parameter image: The image to analyze
    func analyzeImage(_ image: UIImage) async {
        guard let modelManager = modelManager,
              let imageProcessor = imageProcessor else {
            print("❌ VisionService: Enhanced services not initialized")
            return
        }
        
        isProcessing = true
        
        // Assess image quality first
        let qualityAssessment = imageProcessor.assessImageQuality(image)
        
        // Preprocess image
        guard let processedImage = imageProcessor.preprocessForClassification(image) else {
            print("❌ VisionService: Failed to preprocess image")
            isProcessing = false
            return
        }
        
        // Classify vehicle angle
        let result = await modelManager.classifyVehicleAngle(from: processedImage)
        
        await MainActor.run {
            if let angle = result.angle {
                self.currentAngle = angle.displayName
                self.confidence = result.confidence
                
                // Use our enhanced validation logic with image quality check
                let isValidVehicleView = result.confidence > 0.7 && 
                                       isValidVehicleAngle(angle, confidence: result.confidence) &&
                                       qualityAssessment.score > 0.2 // Require minimum image quality
                
                self.isPositionValid = isValidVehicleView
                print("✅ VisionService: Detected angle: \(angle.displayName) with confidence: \(result.confidence), quality: \(qualityAssessment.score) - Position valid: \(self.isPositionValid)")
            } else {
                self.currentAngle = "Unknown"
                self.confidence = 0.0
                self.isPositionValid = false
                print("⚠️ VisionService: No angle detected - Position valid: false")
            }
            
            // Update quality metrics
            self.imageQuality = qualityAssessment.score
            self.qualityIssues = qualityAssessment.issues
            
            self.isProcessing = false
        }
    }
    
    /// Gets all angles in the capture sequence
    /// - Returns: Array of angle display names in capture order
    func getAllAnglesInSequence() -> [String] {
        return ModelManager.VehicleAngle.allCases
            .sorted { $0.captureOrder < $1.captureOrder }
            .map { $0.displayName }
    }
    
    /// Checks if the current position is suitable for capture
    /// - Returns: True if position is valid and quality is acceptable
    func isReadyForCapture() -> Bool {
        return isPositionValid && imageQuality > 0.7 && qualityIssues.isEmpty
    }
    
    /// Gets quality feedback for the user
    /// - Returns: Array of quality issue suggestions
    func getQualityFeedback() -> [String] {
        return qualityIssues.map { $0.suggestion }
    }
    
    /// Resets the vision service state
    func reset() {
        currentAngle = ""
        confidence = 0.0
        isPositionValid = false
        isProcessing = false
        imageQuality = 0.0
        qualityIssues = []
        lastProcessingTime = 0
    }
    
    // MARK: - Performance Monitoring
    
    /// Gets performance metrics
    /// - Returns: Tuple of average inference time and model accuracy
    @MainActor
    func getPerformanceMetrics() -> (averageInferenceTime: TimeInterval, modelAccuracy: Float) {
        return modelManager?.getPerformanceMetrics() ?? (0.0, 0.0)
    }
    
    /// Checks if performance is acceptable
    /// - Returns: True if performance meets requirements
    @MainActor
    func isPerformanceAcceptable() -> Bool {
        return modelManager?.isPerformanceAcceptable() ?? false
    }
    
    // MARK: - Additional Methods
    
    /// Gets the next angle in the sequence
    /// - Parameter currentAngle: The current angle
    /// - Returns: The next angle to capture
    func getNextAngle(currentAngle: PhotoAngleType) -> PhotoAngleType {
        let allAngles: [PhotoAngleType] = [.front, .frontRight, .rightSide, .rearLeft, .rear, .rearRight, .leftSide, .frontLeft]
        
        guard let currentIndex = allAngles.firstIndex(of: currentAngle) else {
            return .front
        }
        
        let nextIndex = (currentIndex + 1) % allAngles.count
        return allAngles[nextIndex]
    }
    
    /// Updates the confidence threshold
    /// - Parameter threshold: The new confidence threshold
    func updateConfidenceThreshold(_ threshold: Float) {
        confidenceThreshold = threshold
    }
    
    /// Validates that the detected angle represents a proper vehicle view
    /// - Parameters:
    ///   - angle: The detected vehicle angle
    ///   - confidence: The confidence score for the detection
    /// - Returns: True if the angle represents a valid vehicle view
    private func isValidVehicleAngle(_ angle: ModelManager.VehicleAngle, confidence: Float) -> Bool {
        // More strict validation to prevent false positives
        let minimumConfidence: Float = 0.8
        
        // Ensure confidence is above minimum threshold
        guard confidence >= minimumConfidence else {
            print("⚠️ VisionService: Confidence too low for \(angle.displayName): \(confidence)")
            return false
        }
        
        // Additional validation: Check if this looks like a real vehicle detection
        // Very high confidence (>0.9) on non-vehicle objects often indicates the model
        // is overconfident on wrong predictions
        
        // If confidence is extremely high (>0.95), be more suspicious
        // This often happens when the model is very confident about wrong predictions
        if confidence > 0.95 {
            print("⚠️ VisionService: Extremely high confidence (\(confidence)) - might be false positive")
            // For now, we'll still allow it, but in production you might want to add
            // additional validation like checking image quality or using a secondary model
        }
        
        return true
    }
}
