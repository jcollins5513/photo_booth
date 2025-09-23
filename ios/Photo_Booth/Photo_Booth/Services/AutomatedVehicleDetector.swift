import Foundation
import Vision
import CoreML
import UIKit
import Combine

/// Automated vehicle detector for static camera setup - detects vehicle positions as they drive past
@MainActor
class AutomatedVehicleDetector: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isDetecting = false
    @Published var currentVehiclePosition: VehiclePosition?
    @Published var isVehicleInFrame = false
    @Published var vehicleConfidence: Float = 0.0
    @Published var captureReady = false
    @Published var lastCaptureTime: Date?
    
    // MARK: - Private Properties
    private var modelManager: ModelManager?
    private var imageProcessor: ImageProcessor?
    private var processingQueue = DispatchQueue(label: "automated.detection", qos: .userInitiated)
    
    // MARK: - Vehicle Tracking Properties
    private var vehicleTrackingHistory: [VehicleDetection] = []
    private var currentSession: VehicleSession?
    private var lastDetectionTime: Date?
    private var vehicleMovementDirection: MovementDirection?
    private var expectedNextPosition: VehiclePosition?
    
    // MARK: - Configuration
    private let detectionThreshold: Float = 0.8
    private let movementThreshold: Float = 0.3
    private let captureCooldown: TimeInterval = 2.0 // Minimum time between captures
    private let maxTrackingHistory = 10
    
    // MARK: - Data Structures
    enum VehiclePosition: String, CaseIterable {
        case front = "front"
        case frontRight = "front_right"
        case rightSide = "right_side"
        case rearLeft = "rear_left"
        case rear = "rear"
        case rearRight = "rear_right"
        case leftSide = "left_side"
        case frontLeft = "front_left"
        
        var displayName: String {
            switch self {
            case .front: return "Front"
            case .frontRight: return "Front Right"
            case .rightSide: return "Right Side"
            case .rearLeft: return "Rear Left"
            case .rear: return "Rear"
            case .rearRight: return "Rear Right"
            case .leftSide: return "Left Side"
            case .frontLeft: return "Front Left"
            }
        }
        
        var captureOrder: Int {
            switch self {
            case .front: return 1
            case .frontRight: return 2
            case .rightSide: return 3
            case .rearLeft: return 4
            case .rear: return 5
            case .rearRight: return 6
            case .leftSide: return 7
            case .frontLeft: return 8
            }
        }
        
        var nextPosition: VehiclePosition? {
            let allPositions = VehiclePosition.allCases.sorted { $0.captureOrder < $1.captureOrder }
            guard let currentIndex = allPositions.firstIndex(of: self) else { return nil }
            let nextIndex = currentIndex + 1
            return nextIndex < allPositions.count ? allPositions[nextIndex] : nil
        }
    }
    
    enum MovementDirection {
        case forward
        case backward
        case stationary
    }
    
    struct VehicleDetection {
        let position: VehiclePosition
        let confidence: Float
        let timestamp: Date
        let image: UIImage
        let boundingBox: CGRect
        let movementVector: CGVector?
    }
    
    struct VehicleSession {
        let id: UUID
        let startTime: Date
        var capturedPositions: [VehiclePosition]
        var lastPosition: VehiclePosition?
        var movementDirection: MovementDirection?
        var isComplete: Bool
        
        init() {
            self.id = UUID()
            self.startTime = Date()
            self.capturedPositions = []
            self.lastPosition = nil
            self.movementDirection = nil
            self.isComplete = false
        }
    }
    
    // MARK: - Initialization
    init() {
        Task { @MainActor in
            setupServices()
        }
    }
    
    @MainActor
    private func setupServices() {
        modelManager = ModelManager()
        imageProcessor = ImageProcessor()
    }
    
    // MARK: - Detection Methods
    func startDetection() async {
        print("🚗 AutomatedVehicleDetector: Starting automated vehicle detection")
        isDetecting = true
        
        // Initialize new session
        currentSession = VehicleSession()
        
        // Load model
        if let modelManager = modelManager {
            await modelManager.loadModel()
        }
    }
    
    func stopDetection() {
        print("🛑 AutomatedVehicleDetector: Stopping automated vehicle detection")
        isDetecting = false
        currentSession = nil
        vehicleTrackingHistory.removeAll()
    }
    
    func processFrame(_ image: UIImage) async {
        guard isDetecting else { return }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                await self.analyzeVehiclePosition(image)
            }
        }
    }
    
    private func analyzeVehiclePosition(_ image: UIImage) async {
        guard let modelManager = modelManager,
              let imageProcessor = imageProcessor else {
            print("❌ AutomatedVehicleDetector: Services not initialized")
            return
        }
        
        // Assess image quality
        let qualityAssessment = imageProcessor.assessImageQuality(image)
        guard qualityAssessment.score > 0.3 else {
            print("⚠️ AutomatedVehicleDetector: Image quality too low: \(qualityAssessment.score)")
            return
        }
        
        // Preprocess image
        guard let processedImage = imageProcessor.preprocessForClassification(image) else {
            print("❌ AutomatedVehicleDetector: Failed to preprocess image")
            return
        }
        
        // Classify vehicle position
        let result = await modelManager.classifyVehicleAngle(from: processedImage)
        
        guard let detectedAngle = result.angle,
              result.confidence >= detectionThreshold else {
            print("⚠️ AutomatedVehicleDetector: No vehicle detected or confidence too low: \(result.confidence)")
            isVehicleInFrame = false
            vehicleConfidence = result.confidence
            return
        }
        
        // Convert to VehiclePosition
        let vehiclePosition = convertToVehiclePosition(detectedAngle)
        
        // Update tracking
        let detection = VehicleDetection(
            position: vehiclePosition,
            confidence: result.confidence,
            timestamp: Date(),
            image: image,
            boundingBox: CGRect.zero, // Would be populated with actual bounding box
            movementVector: calculateMovementVector()
        )
        
        updateVehicleTracking(detection)
        
        // Check if ready for capture
        checkCaptureReadiness(detection)
    }
    
    private func convertToVehiclePosition(_ angle: ModelManager.VehicleAngle) -> VehiclePosition {
        switch angle {
        case .front: return .front
        case .frontLeft: return .frontLeft
        case .frontRight: return .frontRight
        case .left: return .leftSide
        case .right: return .rightSide
        case .rear: return .rear
        case .rearLeft: return .rearLeft
        case .rearRight: return .rearRight
        }
    }
    
    private func updateVehicleTracking(_ detection: VehicleDetection) {
        // Add to tracking history
        vehicleTrackingHistory.append(detection)
        
        // Keep only recent detections
        if vehicleTrackingHistory.count > maxTrackingHistory {
            vehicleTrackingHistory.removeFirst()
        }
        
        // Update current state
        currentVehiclePosition = detection.position
        isVehicleInFrame = true
        vehicleConfidence = detection.confidence
        lastDetectionTime = detection.timestamp
        
        // Update session
        if var session = currentSession {
            session.lastPosition = detection.position
            session.movementDirection = determineMovementDirection()
            currentSession = session
        }
        
        print("🚗 AutomatedVehicleDetector: Vehicle detected at \(detection.position.displayName) with confidence \(detection.confidence)")
    }
    
    private func checkCaptureReadiness(_ detection: VehicleDetection) {
        guard let session = currentSession else { return }
        
        // Check if this position has already been captured
        if session.capturedPositions.contains(detection.position) {
            print("📸 AutomatedVehicleDetector: Position \(detection.position.displayName) already captured")
            return
        }
        
        // Check capture cooldown
        if let lastCapture = lastCaptureTime,
           Date().timeIntervalSince(lastCapture) < captureCooldown {
            print("⏱️ AutomatedVehicleDetector: Capture cooldown active")
            return
        }
        
        // Check if vehicle is in stable position
        if isVehicleStable(at: detection.position) {
            captureReady = true
            print("✅ AutomatedVehicleDetector: Ready to capture \(detection.position.displayName)")
        } else {
            captureReady = false
            print("⚠️ AutomatedVehicleDetector: Vehicle not stable at \(detection.position.displayName)")
        }
    }
    
    private func isVehicleStable(at position: VehiclePosition) -> Bool {
        // Check if we have enough recent detections at this position
        let recentDetections = vehicleTrackingHistory.suffix(3)
        let positionDetections = recentDetections.filter { $0.position == position }
        
        // Vehicle is stable if we have at least 2 recent detections at the same position
        return positionDetections.count >= 2
    }
    
    private func calculateMovementVector() -> CGVector? {
        guard vehicleTrackingHistory.count >= 2 else { return nil }
        
        let recent = vehicleTrackingHistory.suffix(2)
        let positions = recent.map { $0.position }
        
        // Simple movement detection based on position changes
        // In a real implementation, this would use bounding box centroids
        if positions.count == 2 {
            let current = positions[1]
            let previous = positions[0]
            
            // Calculate movement direction based on position order
            if current.captureOrder > previous.captureOrder {
                return CGVector(dx: 1, dy: 0) // Moving forward
            } else if current.captureOrder < previous.captureOrder {
                return CGVector(dx: -1, dy: 0) // Moving backward
            }
        }
        
        return nil
    }
    
    private func determineMovementDirection() -> MovementDirection {
        guard vehicleTrackingHistory.count >= 2 else { return .stationary }
        
        let recent = vehicleTrackingHistory.suffix(2)
        let positions = recent.map { $0.position }
        
        if positions.count == 2 {
            let current = positions[1]
            let previous = positions[0]
            
            if current.captureOrder > previous.captureOrder {
                return .forward
            } else if current.captureOrder < previous.captureOrder {
                return .backward
            }
        }
        
        return .stationary
    }
    
    // MARK: - Capture Methods
    func capturePhoto() async -> UIImage? {
        guard captureReady,
              let position = currentVehiclePosition,
              let _ = currentSession else {
            print("❌ AutomatedVehicleDetector: Not ready to capture")
            return nil
        }
        
        // Get the most recent detection image
        guard let recentDetection = vehicleTrackingHistory.last else {
            print("❌ AutomatedVehicleDetector: No recent detection image")
            return nil
        }
        
        // Update session
        if var session = currentSession {
            session.capturedPositions.append(position)
            currentSession = session
        }
        
        // Update capture state
        lastCaptureTime = Date()
        captureReady = false
        
        print("📸 AutomatedVehicleDetector: Captured \(position.displayName)")
        
        return recentDetection.image
    }
    
    func getNextExpectedPosition() -> VehiclePosition? {
        guard let session = currentSession,
              let lastPosition = session.lastPosition else {
            return .front // Start with front position
        }
        
        // Determine next expected position based on movement direction
        switch session.movementDirection {
        case .forward:
            return lastPosition.nextPosition
        case .backward:
            return lastPosition.previousPosition
        case .stationary, .none:
            return lastPosition.nextPosition // Default to forward
        }
    }
    
    // MARK: - Session Management
    func getSessionProgress() -> Float {
        guard let session = currentSession else { return 0.0 }
        return Float(session.capturedPositions.count) / Float(VehiclePosition.allCases.count)
    }
    
    func isSessionComplete() -> Bool {
        guard let session = currentSession else { return false }
        return session.capturedPositions.count >= VehiclePosition.allCases.count
    }
    
    func getCapturedPositions() -> [VehiclePosition] {
        return currentSession?.capturedPositions ?? []
    }
    
    func getSessionStatistics() -> SessionStatistics {
        guard let session = currentSession else {
            return SessionStatistics(
                duration: 0,
                capturedPositions: [],
                totalPositions: VehiclePosition.allCases.count,
                completionRate: 0.0,
                averageConfidence: 0.0
            )
        }
        
        let duration = Date().timeIntervalSince(session.startTime)
        let averageConfidence = vehicleTrackingHistory.isEmpty ? 0.0 : 
            vehicleTrackingHistory.map { $0.confidence }.reduce(0, +) / Float(vehicleTrackingHistory.count)
        
        return SessionStatistics(
            duration: duration,
            capturedPositions: session.capturedPositions,
            totalPositions: VehiclePosition.allCases.count,
            completionRate: Float(session.capturedPositions.count) / Float(VehiclePosition.allCases.count),
            averageConfidence: averageConfidence
        )
    }
    
    struct SessionStatistics: Codable {
        let duration: TimeInterval
        let capturedPositions: [String] // Store as strings to avoid Codable issues
        let totalPositions: Int
        let completionRate: Float
        let averageConfidence: Float
        
        init(duration: TimeInterval, capturedPositions: [VehiclePosition], totalPositions: Int, completionRate: Float, averageConfidence: Float) {
            self.duration = duration
            self.capturedPositions = capturedPositions.map { $0.rawValue }
            self.totalPositions = totalPositions
            self.completionRate = completionRate
            self.averageConfidence = averageConfidence
        }
        
        // Computed property to get VehiclePosition array
        var vehiclePositions: [VehiclePosition] {
            return capturedPositions.compactMap { VehiclePosition(rawValue: $0) }
        }
    }
}

// MARK: - VehiclePosition Extensions
extension AutomatedVehicleDetector.VehiclePosition {
    var previousPosition: AutomatedVehicleDetector.VehiclePosition? {
        let allPositions = AutomatedVehicleDetector.VehiclePosition.allCases.sorted { $0.captureOrder < $1.captureOrder }
        guard let currentIndex = allPositions.firstIndex(of: self) else { return nil }
        let previousIndex = currentIndex - 1
        return previousIndex >= 0 ? allPositions[previousIndex] : nil
    }
}
