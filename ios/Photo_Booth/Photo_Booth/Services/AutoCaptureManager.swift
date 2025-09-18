import Foundation
import UIKit
import Combine

/// Manages automated photo capture with position detection and quality assurance
@MainActor
class AutoCaptureManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAutoCaptureEnabled = false
    @Published var currentSession: PhotoSession?
    @Published var currentAngle: ModelManager.VehicleAngle?
    @Published var sessionProgress: Float = 0.0
    @Published var isCapturing = false
    @Published var captureStatus: CaptureStatus = .idle
    @Published var qualityScore: Float = 0.0
    @Published var retryCount = 0
    @Published var totalCaptures = 0
    @Published var successfulCaptures = 0
    @Published var sessionStartTime: Date?
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    // MARK: - Private Properties
    private let modelManager: ModelManager
    private let visionService: VisionService
    private let cameraService: CameraServiceProtocol
    private let storageService: StorageServiceProtocol
    private let configurationService: ConfigurationService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let maxRetryAttempts = 3
    private let captureDelay: TimeInterval = 1.0
    private let qualityThreshold: Float = 0.7
    private let positionStabilityTime: TimeInterval = 2.0
    
    // MARK: - State Management
    private var positionStabilityTimer: Timer?
    private var captureTimer: Timer?
    private var sessionTimer: Timer?
    private var lastPositionChange: Date = Date()
    private var stablePositionStart: Date?
    private var angleSequence: [ModelManager.VehicleAngle] = []
    private var currentAngleIndex = 0
    private var capturedAngles: Set<ModelManager.VehicleAngle> = []
    
    // MARK: - Initialization
    init(
        modelManager: ModelManager,
        visionService: VisionService,
        cameraService: CameraServiceProtocol,
        storageService: StorageServiceProtocol,
        configurationService: ConfigurationService
    ) {
        self.modelManager = modelManager
        self.visionService = visionService
        self.cameraService = cameraService
        self.storageService = storageService
        self.configurationService = configurationService
        
        setupBindings()
        initializeAngleSequence()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind to vision service updates
        visionService.$isPositionValid
            .sink { [weak self] isValid in
                self?.handlePositionChange(isValid: isValid)
            }
            .store(in: &cancellables)
        
        visionService.$imageQuality
            .assign(to: &$qualityScore)
        
        // Bind to configuration changes
        configurationService.$confidenceThreshold
            .sink { [weak self] threshold in
                self?.updateCaptureThreshold(threshold)
            }
            .store(in: &cancellables)
    }
    
    private func initializeAngleSequence() {
        angleSequence = ModelManager.VehicleAngle.allCases
            .sorted { $0.captureOrder < $1.captureOrder }
    }
    
    // MARK: - Session Management
    
    /// Starts a new auto-capture session
    /// - Parameter session: The photo session to capture
    func startAutoCaptureSession(_ session: PhotoSession) async {
        guard !isCapturing else { return }
        
        currentSession = session
        isAutoCaptureEnabled = true
        sessionStartTime = Date()
        currentAngleIndex = 0
        capturedAngles.removeAll()
        retryCount = 0
        totalCaptures = 0
        successfulCaptures = 0
        
        // Set first angle
        if !angleSequence.isEmpty {
            currentAngle = angleSequence[0]
            visionService.setTargetAngle(convertToPhotoAngleType(angleSequence[0]))
        }
        
        captureStatus = .positioning
        updateSessionProgress()
        startSessionTimer()
        
        print("🚀 AutoCaptureManager: Started session for \(session.vehicleMake ?? "Unknown") \(session.vehicleModel ?? "Vehicle")")
    }
    
    /// Stops the current auto-capture session
    func stopAutoCaptureSession() {
        isAutoCaptureEnabled = false
        isCapturing = false
        captureStatus = .idle
        currentSession = nil
        currentAngle = nil
        
        stopAllTimers()
        resetSessionState()
        
        print("🛑 AutoCaptureManager: Stopped auto-capture session")
    }
    
    /// Pauses the current auto-capture session
    func pauseAutoCaptureSession() {
        isAutoCaptureEnabled = false
        captureStatus = .paused
        stopAllTimers()
        
        print("⏸️ AutoCaptureManager: Paused auto-capture session")
    }
    
    /// Resumes the paused auto-capture session
    func resumeAutoCaptureSession() {
        guard currentSession != nil else { return }
        
        isAutoCaptureEnabled = true
        captureStatus = .positioning
        startSessionTimer()
        
        print("▶️ AutoCaptureManager: Resumed auto-capture session")
    }
    
    // MARK: - Position Detection and Capture
    
    private func handlePositionChange(isValid: Bool) {
        guard isAutoCaptureEnabled, let currentAngle = currentAngle else { return }
        
        if isValid {
            // Position is valid, start stability timer
            if stablePositionStart == nil {
                stablePositionStart = Date()
                positionStabilityTimer?.invalidate()
                positionStabilityTimer = Timer.scheduledTimer(withTimeInterval: positionStabilityTime, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.triggerCapture()
                    }
                }
                captureStatus = .ready
            }
        } else {
            // Position is invalid, reset stability timer
            stablePositionStart = nil
            positionStabilityTimer?.invalidate()
            captureStatus = .positioning
        }
    }
    
    private func triggerCapture() async {
        guard isAutoCaptureEnabled, 
              let currentAngle = currentAngle,
              let session = currentSession,
              !isCapturing else { return }
        
        isCapturing = true
        captureStatus = .capturing
        totalCaptures += 1
        
        print("📸 AutoCaptureManager: Capturing \(currentAngle.displayName)")
        
        do {
            // Capture photo
            let imageData = try await cameraService.capturePhoto(settings: .default)
            
            // Validate captured image
            if let image = UIImage(data: imageData) {
                let qualityAssessment = await assessCaptureQuality(image)
                
                if qualityAssessment.isAcceptable {
                    // Save successful capture
                    try await saveSuccessfulCapture(image, for: currentAngle, in: session)
                    successfulCaptures += 1
                    capturedAngles.insert(currentAngle)
                    
                    // Move to next angle
                    await moveToNextAngle()
                } else {
                    // Quality not acceptable, retry if attempts remaining
                    await handleFailedCapture(qualityAssessment.issues)
                }
            } else {
                await handleFailedCapture(["Invalid image data"])
            }
            
        } catch {
            await handleFailedCapture([error.localizedDescription])
        }
        
        isCapturing = false
    }
    
    private func moveToNextAngle() async {
        currentAngleIndex += 1
        
        if currentAngleIndex < angleSequence.count {
            // Move to next angle
            currentAngle = angleSequence[currentAngleIndex]
            visionService.setTargetAngle(convertToPhotoAngleType(currentAngle!))
            captureStatus = .positioning
            updateSessionProgress()
            
            print("➡️ AutoCaptureManager: Moving to \(currentAngle!.displayName)")
        } else {
            // Session complete
            await completeSession()
        }
    }
    
    private func completeSession() async {
        captureStatus = .completed
        isAutoCaptureEnabled = false
        stopAllTimers()
        
        let sessionDuration = Date().timeIntervalSince(sessionStartTime ?? Date())
        let successRate = Float(successfulCaptures) / Float(totalCaptures) * 100
        
        print("✅ AutoCaptureManager: Session completed in \(String(format: "%.1f", sessionDuration))s with \(successRate)% success rate")
        
        // Update session with completion data
        if let session = currentSession {
            session.isCompleted = true
            session.completionDate = Date()
            session.totalPhotos = successfulCaptures
            session.sessionDuration = sessionDuration
        }
    }
    
    // MARK: - Quality Assessment
    
    private func assessCaptureQuality(_ image: UIImage) async -> (isAcceptable: Bool, issues: [String]) {
        var issues: [String] = []
        
        // Check image quality using ImageProcessor
        let imageProcessor = ImageProcessor()
        let qualityAssessment = imageProcessor.assessImageQuality(image)
        
        if qualityAssessment.score < qualityThreshold {
            issues.append("Image quality too low (\(String(format: "%.1f", qualityAssessment.score * 100))%)")
        }
        
        for issue in qualityAssessment.issues {
            issues.append(issue.displayName)
        }
        
        // Check if image is too dark or too bright
        let brightness = calculateBrightness(image)
        if brightness < 0.2 {
            issues.append("Image too dark")
        } else if brightness > 0.8 {
            issues.append("Image too bright")
        }
        
        return (issues.isEmpty, issues)
    }
    
    private func calculateBrightness(_ image: UIImage) -> Float {
        // Simplified brightness calculation
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter?.outputImage,
              let averageCGImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            return 0.0
        }
        
        let data = averageCGImage.dataProvider?.data
        let bytes = CFDataGetBytePtr(data)
        
        guard let bytes = bytes else { return 0.0 }
        
        let r = Float(bytes[0])
        let g = Float(bytes[1])
        let b = Float(bytes[2])
        
        return (r + g + b) / 3.0 / 255.0
    }
    
    // MARK: - Error Handling and Retry
    
    private func handleFailedCapture(_ issues: [String]) async {
        retryCount += 1
        
        print("❌ AutoCaptureManager: Capture failed - \(issues.joined(separator: ", "))")
        
        if retryCount < maxRetryAttempts {
            captureStatus = .retrying
            print("🔄 AutoCaptureManager: Retrying capture (\(retryCount)/\(maxRetryAttempts))")
            
            // Wait before retry
            try? await Task.sleep(nanoseconds: UInt64(captureDelay * 1_000_000_000))
            captureStatus = .positioning
        } else {
            print("⚠️ AutoCaptureManager: Max retry attempts reached, skipping angle")
            await moveToNextAngle()
        }
    }
    
    // MARK: - Data Management
    
    private func saveSuccessfulCapture(_ image: UIImage, for angle: ModelManager.VehicleAngle, in session: PhotoSession) async throws {
        // This would integrate with StorageService to save the photo
        // For now, we'll simulate the save operation
        print("💾 AutoCaptureManager: Saving \(angle.displayName) photo")
        
        // In a real implementation, this would:
        // 1. Save image to file system
        // 2. Create VehiclePhoto record in Core Data
        // 3. Associate with PhotoSession
        // 4. Update session metadata
    }
    
    // MARK: - Progress and Timing
    
    private func updateSessionProgress() {
        guard !angleSequence.isEmpty else { return }
        
        let completedAngles = capturedAngles.count
        let totalAngles = angleSequence.count
        sessionProgress = Float(completedAngles) / Float(totalAngles)
        
        // Estimate time remaining
        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let averageTimePerAngle = elapsed / Float(currentAngleIndex + 1)
            let remainingAngles = totalAngles - completedAngles
            estimatedTimeRemaining = averageTimePerAngle * Float(remainingAngles)
        }
    }
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionProgress()
            }
        }
    }
    
    private func stopAllTimers() {
        positionStabilityTimer?.invalidate()
        captureTimer?.invalidate()
        sessionTimer?.invalidate()
        
        positionStabilityTimer = nil
        captureTimer = nil
        sessionTimer = nil
    }
    
    private func resetSessionState() {
        currentAngleIndex = 0
        capturedAngles.removeAll()
        retryCount = 0
        totalCaptures = 0
        successfulCaptures = 0
        sessionProgress = 0.0
        estimatedTimeRemaining = 0
        stablePositionStart = nil
    }
    
    // MARK: - Helper Methods
    
    private func convertToPhotoAngleType(_ angle: ModelManager.VehicleAngle) -> PhotoAngleType {
        switch angle {
        case .front: return .front
        case .frontLeft: return .frontLeft
        case .frontRight: return .frontRight
        case .left: return .left
        case .right: return .right
        case .rear: return .rear
        case .rearLeft: return .rearLeft
        case .rearRight: return .rearRight
        }
    }
    
    private func updateCaptureThreshold(_ threshold: Float) {
        // Update vision service threshold
        visionService.updateConfidenceThreshold(threshold)
    }
    
    // MARK: - Public Interface
    
    /// Gets current session statistics
    /// - Returns: Dictionary of session statistics
    func getSessionStatistics() -> [String: Any] {
        return [
            "totalCaptures": totalCaptures,
            "successfulCaptures": successfulCaptures,
            "retryCount": retryCount,
            "successRate": totalCaptures > 0 ? Float(successfulCaptures) / Float(totalCaptures) * 100 : 0,
            "sessionProgress": sessionProgress * 100,
            "estimatedTimeRemaining": estimatedTimeRemaining
        ]
    }
    
    /// Checks if session is complete
    /// - Returns: True if all angles have been captured
    func isSessionComplete() -> Bool {
        return capturedAngles.count >= angleSequence.count
    }
    
    /// Gets remaining angles to capture
    /// - Returns: Array of remaining angles
    func getRemainingAngles() -> [ModelManager.VehicleAngle] {
        return angleSequence.filter { !capturedAngles.contains($0) }
    }
}

// MARK: - Capture Status
extension AutoCaptureManager {
    enum CaptureStatus: String, CaseIterable {
        case idle = "idle"
        case positioning = "positioning"
        case ready = "ready"
        case capturing = "capturing"
        case retrying = "retrying"
        case paused = "paused"
        case completed = "completed"
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .positioning: return "Positioning Vehicle"
            case .ready: return "Ready to Capture"
            case .capturing: return "Capturing Photo"
            case .retrying: return "Retrying Capture"
            case .paused: return "Paused"
            case .completed: return "Session Complete"
            }
        }
        
        var isActive: Bool {
            return self != .idle && self != .completed
        }
    }
}
