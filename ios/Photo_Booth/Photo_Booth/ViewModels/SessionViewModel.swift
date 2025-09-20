import Foundation
import SwiftUI
import Combine

enum SessionError: Error, LocalizedError {
    case invalidSession
    case sessionNotFound
    case captureFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Invalid session"
        case .sessionNotFound:
            return "Session not found"
        case .captureFailed:
            return "Failed to capture photo"
        case .saveFailed:
            return "Failed to save photo"
        }
    }
}

@MainActor
class SessionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentSession: PhotoSession?
    @Published var isSessionActive = false
    @Published var currentAngle: PhotoAngleType = .front
    @Published var sessionProgress: Double = 0.0
    @Published var capturedPhotos: [VehiclePhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var vehicleIdentifier = ""
    @Published var totalAngles: Int = 8
    
    // MARK: - Enhanced Auto-Capture Properties
    @Published var isAutoCaptureEnabled = false
    @Published var sessionState: PhotoSessionManager.SessionState = .idle
    @Published var captureStatus: AutoCaptureManager.CaptureStatus = .idle
    @Published var qualityScore: Float = 0.0
    @Published var retryCount = 0
    @Published var sessionStatistics: PhotoSessionManager.SessionStatistics = PhotoSessionManager.SessionStatistics()
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var qualityIssues: [String] = []
    @Published var isReadyForCapture = false
    
    // MARK: - Private Properties
    private let sessionManager: SessionManagerProtocol
    private let storageService: StorageServiceProtocol
    private let cameraViewModel: CameraViewModel
    private let photoSessionManager: PhotoSessionManager
    private let autoCaptureManager: AutoCaptureManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var remainingAngles: [PhotoAngleType] {
        let allAngles = PhotoAngleType.allCases
        let capturedAngleStrings = Set(capturedPhotos.compactMap { $0.angleType })
        return allAngles.filter { !capturedAngleStrings.contains($0.rawValue) }
    }
    
    var isSessionComplete: Bool {
        return capturedPhotos.count >= totalAngles
    }
    
    var progressPercentage: Double {
        guard totalAngles > 0 else { return 0.0 }
        return Double(capturedPhotos.count) / Double(totalAngles)
    }
    
    // MARK: - Initialization
    init(
        sessionManager: SessionManagerProtocol, 
        storageService: StorageServiceProtocol, 
        cameraViewModel: CameraViewModel,
        photoSessionManager: PhotoSessionManager,
        autoCaptureManager: AutoCaptureManager
    ) {
        self.sessionManager = sessionManager
        self.storageService = storageService
        self.cameraViewModel = cameraViewModel
        self.photoSessionManager = photoSessionManager
        self.autoCaptureManager = autoCaptureManager
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to PhotoSessionManager updates
        photoSessionManager.$currentSession
            .assign(to: &$currentSession)
        
        photoSessionManager.$sessionState
            .assign(to: &$sessionState)
        
        photoSessionManager.$sessionProgress
            .sink { [weak self] progress in
                self?.sessionProgress = Double(progress)
            }
            .store(in: &cancellables)
        
        photoSessionManager.$sessionStatistics
            .assign(to: &$sessionStatistics)
        
        photoSessionManager.$estimatedTimeRemaining
            .assign(to: &$estimatedTimeRemaining)
        
        // Bind to AutoCaptureManager updates
        autoCaptureManager.$isAutoCaptureEnabled
            .assign(to: &$isAutoCaptureEnabled)
        
        autoCaptureManager.$captureStatus
            .assign(to: &$captureStatus)
        
        autoCaptureManager.$qualityScore
            .assign(to: &$qualityScore)
        
        autoCaptureManager.$retryCount
            .assign(to: &$retryCount)
        
        // Bind to CameraViewModel updates
        cameraViewModel.$isReadyForCapture
            .assign(to: &$isReadyForCapture)
        
        cameraViewModel.$qualityIssues
            .sink { [weak self] issues in
                self?.qualityIssues = issues.map { $0.displayName }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    func startNewSession(vehicleIdentifier: String, totalAngles: Int = 8) async {
        guard !isSessionActive else {
            errorMessage = "A session is already active"
            return
        }
        
        guard !vehicleIdentifier.isEmpty else {
            errorMessage = "Please enter a vehicle identifier"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Start enhanced photo session
        await photoSessionManager.startNewSession(
            vehicleMake: vehicleIdentifier,
            vehicleModel: "Vehicle",
            sessionType: .standard
        )
        
        isSessionActive = true
        self.vehicleIdentifier = vehicleIdentifier
        self.totalAngles = totalAngles
        capturedPhotos = []
        currentAngle = .front
        sessionProgress = 0.0
        
        // Set the first angle as target for camera
        cameraViewModel.setTargetAngle(currentAngle)
        
        isLoading = false
    }
    
    /// Starts a new auto-capture session
    /// - Parameters:
    ///   - vehicleMake: Vehicle make
    ///   - vehicleModel: Vehicle model
    ///   - vehicleYear: Vehicle year (optional)
    func startAutoCaptureSession(vehicleMake: String, vehicleModel: String, vehicleYear: Int? = nil) async {
        guard !isSessionActive else {
            errorMessage = "A session is already active"
            return
        }
        
        guard !vehicleMake.isEmpty && !vehicleModel.isEmpty else {
            errorMessage = "Please enter vehicle make and model"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        await photoSessionManager.startNewSession(
            vehicleMake: vehicleMake,
            vehicleModel: vehicleModel,
            vehicleYear: vehicleYear,
            sessionType: .standard
        )
        
        isSessionActive = true
        isAutoCaptureEnabled = true
        vehicleIdentifier = "\(vehicleMake) \(vehicleModel)"
        
        isLoading = false
    }
    
    /// Toggles auto-capture mode
    func toggleAutoCapture() {
        if isAutoCaptureEnabled {
            pauseAutoCapture()
        } else {
            resumeAutoCapture()
        }
    }
    
    /// Pauses auto-capture
    func pauseAutoCapture() {
        photoSessionManager.pauseSession()
        isAutoCaptureEnabled = false
    }
    
    /// Resumes auto-capture
    func resumeAutoCapture() {
        photoSessionManager.resumeSession()
        isAutoCaptureEnabled = true
    }
    
    func completeSession() async {
        guard currentSession != nil else {
            errorMessage = "No active session to complete"
            return
        }
        
        isLoading = true
        
        // Complete the enhanced photo session
        await photoSessionManager.completeSession()
        
        isSessionActive = false
        isAutoCaptureEnabled = false
        sessionProgress = 1.0
        
        isLoading = false
    }
    
    func cancelSession() async {
        guard currentSession != nil else {
            errorMessage = "No active session to cancel"
            return
        }
        
        isLoading = true
        
        // Stop the enhanced photo session
        photoSessionManager.stopSession()
        
        isSessionActive = false
        isAutoCaptureEnabled = false
        sessionProgress = 0.0
        capturedPhotos = []
        
        isLoading = false
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async {
        guard isSessionActive else {
            errorMessage = "No active session"
            return
        }
        
        do {
            // Capture photo using camera
            await cameraViewModel.capturePhoto()
            
            guard let image = cameraViewModel.lastCapturedPhoto,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Failed to capture photo"
                return
            }
            
            // Save photo to session
            let vehiclePhoto = try await sessionManager.manualCapture(
                sessionId: UUID(uuidString: currentSession?.id ?? UUID().uuidString)!,
                angle: currentAngle.rawValue,
                imageData: imageData
            )
            
            capturedPhotos.append(vehiclePhoto)
            updateProgress()
            
            // Move to next angle
            moveToNextAngle()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func retakePhoto() async {
        // This would allow retaking the current angle
        // For now, we'll just clear the last captured photo
        cameraViewModel.lastCapturedPhoto = nil
    }
    
    // MARK: - Angle Management
    func moveToNextAngle() {
        guard let nextAngle = currentAngle.nextAngle else {
            // Session complete
            return
        }
        
        currentAngle = nextAngle
        cameraViewModel.setTargetAngle(currentAngle)
    }
    
    func setCurrentAngle(_ angle: PhotoAngleType) {
        currentAngle = angle
        cameraViewModel.setTargetAngle(angle)
    }
    
    // MARK: - Progress Management
    private func updateProgress() {
        sessionProgress = progressPercentage
    }
    
    // MARK: - Session History
    func loadSessionHistory() async {
        do {
            let _ = try await sessionManager.getAllSessions()
            // This would be used to display session history
            // For now, we'll just handle the current session
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    func clearError() {
        errorMessage = nil
    }
    
    func resetSession() {
        currentSession = nil
        isSessionActive = false
        currentAngle = .front
        sessionProgress = 0.0
        capturedPhotos = []
        vehicleIdentifier = ""
        totalAngles = 8
        errorMessage = nil
        
        // Reset enhanced properties
        isAutoCaptureEnabled = false
        sessionState = .idle
        captureStatus = .idle
        qualityScore = 0.0
        retryCount = 0
        estimatedTimeRemaining = 0
        qualityIssues = []
        isReadyForCapture = false
        
        // Reset managers
        photoSessionManager.reset()
    }
    
    // MARK: - Enhanced Session Methods
    
    /// Gets session statistics
    /// - Returns: Current session statistics
    func getSessionStatistics() -> PhotoSessionManager.SessionStatistics {
        return photoSessionManager.getSessionStatistics()
    }
    
    /// Gets remaining angles to capture
    /// - Returns: Array of remaining angles
    func getRemainingAngles() -> [ModelManager.VehicleAngle] {
        return photoSessionManager.getMissingAngles()
    }
    
    /// Gets captured angles
    /// - Returns: Array of captured angles
    func getCapturedAngles() -> [ModelManager.VehicleAngle] {
        return photoSessionManager.getCapturedAngles()
    }
    
    
    /// Gets quality issues for a specific angle
    /// - Parameter angle: The angle to check
    /// - Returns: Array of quality issues
    func getQualityIssues(for angle: ModelManager.VehicleAngle) -> [String] {
        return photoSessionManager.getQualityIssues(for: angle)
    }
    
    /// Exports session data
    /// - Returns: Dictionary containing session data
    func exportSessionData() -> [String: Any] {
        return photoSessionManager.exportSessionData()
    }
    
    /// Gets performance metrics
    /// - Returns: Performance metrics tuple
    func getPerformanceMetrics() -> (averageInferenceTime: TimeInterval, modelAccuracy: Float) {
        return cameraViewModel.getPerformanceMetrics()
    }
    
    /// Checks if performance is acceptable
    /// - Returns: True if performance meets requirements
    func isPerformanceAcceptable() -> Bool {
        return cameraViewModel.isPerformanceAcceptable()
    }
}
