import Foundation
import UIKit
import Combine
import CoreData

/// Manages complete photo session lifecycle and workflow
@MainActor
class PhotoSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentSession: PhotoSession?
    @Published var sessionState: SessionState = .idle
    @Published var sessionProgress: Float = 0.0
    @Published var currentAngle: ModelManager.VehicleAngle?
    @Published var capturedPhotos: [ModelManager.VehicleAngle: UIImage] = [:]
    @Published var sessionStatistics: SessionStatistics = SessionStatistics()
    @Published var isSessionActive = false
    @Published var sessionStartTime: Date?
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var qualityIssues: [ModelManager.VehicleAngle: [String]] = [:]
    
    // MARK: - Private Properties
    private let autoCaptureManager: AutoCaptureManager
    private let storageService: StorageServiceProtocol
    private let configurationService: ConfigurationService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Session Configuration
    private let requiredAngles: [ModelManager.VehicleAngle] = ModelManager.VehicleAngle.allCases
        .sorted { $0.captureOrder < $1.captureOrder }
    
    // MARK: - Initialization
    init(
        autoCaptureManager: AutoCaptureManager,
        storageService: StorageServiceProtocol,
        configurationService: ConfigurationService
    ) {
        self.autoCaptureManager = autoCaptureManager
        self.storageService = storageService
        self.configurationService = configurationService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to auto-capture manager updates
        autoCaptureManager.$currentSession
            .assign(to: &$currentSession)
        
        autoCaptureManager.$sessionProgress
            .assign(to: &$sessionProgress)
        
        autoCaptureManager.$currentAngle
            .assign(to: &$currentAngle)
        
        autoCaptureManager.$isCapturing
            .sink { [weak self] (isCapturing: Bool) in
                self?.updateSessionState()
            }
            .store(in: &cancellables)
        
        autoCaptureManager.$captureStatus
            .sink { [weak self] (status: AutoCaptureManager.CaptureStatus) in
                self?.updateSessionState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Lifecycle
    
    /// Creates and starts a new photo session
    /// - Parameters:
    ///   - vehicleMake: Vehicle make
    ///   - vehicleModel: Vehicle model
    ///   - vehicleYear: Vehicle year
    ///   - sessionType: Type of photo session
    func startNewSession(
        vehicleMake: String,
        vehicleModel: String,
        vehicleYear: Int? = nil,
        sessionType: SessionType = .standard
    ) async {
        do {
            // Create new session using storage service
            let sessionId = UUID()
            let session = try await storageService.savePhotoSession(
                id: sessionId,
                vehicleIdentifier: "\(vehicleMake) \(vehicleModel)",
                startDate: Date(),
                status: "active",
                totalAngles: 8,
                completedAngles: 0
            )
        
            // Start auto-capture session
            await autoCaptureManager.startAutoCaptureSession(session)
            
            // Update local state
            currentSession = session
            sessionState = .active
            isSessionActive = true
            sessionStartTime = Date()
            capturedPhotos.removeAll()
            qualityIssues.removeAll()
            
            // Initialize statistics
            sessionStatistics = SessionStatistics()
            sessionStatistics.sessionId = UUID(uuidString: session.id ?? "")
            sessionStatistics.startTime = Date()
            
            print("🚀 PhotoSessionManager: Started new session for \(vehicleMake) \(vehicleModel)")
        } catch {
            print("❌ PhotoSessionManager: Failed to create session - \(error.localizedDescription)")
            sessionState = .idle
        }
    }
    
    /// Pauses the current session
    func pauseSession() {
        guard isSessionActive else { return }
        
        autoCaptureManager.pauseAutoCaptureSession()
        sessionState = .paused
        
        print("⏸️ PhotoSessionManager: Paused session")
    }
    
    /// Resumes the paused session
    func resumeSession() {
        guard isSessionActive, sessionState == .paused else { return }
        
        autoCaptureManager.resumeAutoCaptureSession()
        sessionState = .active
        
        print("▶️ PhotoSessionManager: Resumed session")
    }
    
    /// Stops the current session
    func stopSession() {
        guard isSessionActive else { return }
        
        autoCaptureManager.stopAutoCaptureSession()
        sessionState = .idle
        isSessionActive = false
        
        // Update session statistics
        if let startTime = sessionStatistics.startTime {
            sessionStatistics.duration = Date().timeIntervalSince(startTime)
        }
        
        print("🛑 PhotoSessionManager: Stopped session")
    }
    
    /// Completes the current session
    func completeSession() async {
        guard isSessionActive else { return }
        
        // Update session completion
        if let session = currentSession {
            session.isCompleted = true
            session.completionDate = Date()
            session.totalPhotos = Int16(capturedPhotos.count)
            
            // Save session to storage
            do {
                try await storageService.saveSession(session)
                print("💾 PhotoSessionManager: Session saved to storage")
            } catch {
                print("❌ PhotoSessionManager: Failed to save session - \(error.localizedDescription)")
            }
        }
        
        // Update statistics
        sessionStatistics.completionTime = Date()
        sessionStatistics.totalPhotos = capturedPhotos.count
        sessionStatistics.successRate = calculateSuccessRate()
        
        // Stop session
        stopSession()
        
        print("✅ PhotoSessionManager: Session completed with \(capturedPhotos.count) photos")
    }
    
    // MARK: - Photo Management
    
    /// Adds a captured photo to the session
    /// - Parameters:
    ///   - photo: The captured image
    ///   - angle: The angle the photo was captured at
    func addCapturedPhoto(_ photo: UIImage, for angle: ModelManager.VehicleAngle) {
        capturedPhotos[angle] = photo
        updateSessionProgress()
        
        print("📸 PhotoSessionManager: Added \(angle.displayName) photo")
    }
    
    /// Removes a photo from the session
    /// - Parameter angle: The angle to remove
    func removePhoto(for angle: ModelManager.VehicleAngle) {
        capturedPhotos.removeValue(forKey: angle)
        qualityIssues.removeValue(forKey: angle)
        updateSessionProgress()
        
        print("🗑️ PhotoSessionManager: Removed \(angle.displayName) photo")
    }
    
    /// Retakes a photo for a specific angle
    /// - Parameter angle: The angle to retake
    func retakePhoto(for angle: ModelManager.VehicleAngle) async {
        // This would trigger a manual capture for the specific angle
        // For now, we'll just log the action
        print("🔄 PhotoSessionManager: Retaking \(angle.displayName) photo")
    }
    
    // MARK: - Progress and Validation
    
    private func updateSessionProgress() {
        let capturedCount = capturedPhotos.count
        let totalCount = requiredAngles.count
        sessionProgress = Float(capturedCount) / Float(totalCount)
        
        // Estimate time remaining
        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let averageTimePerPhoto = elapsed / Double(capturedCount + 1)
            let remainingPhotos = totalCount - capturedCount
            estimatedTimeRemaining = averageTimePerPhoto * Double(remainingPhotos)
        }
    }
    
    private func updateSessionState() {
        if autoCaptureManager.isCapturing {
            sessionState = .capturing
        } else if autoCaptureManager.captureStatus == AutoCaptureManager.CaptureStatus.positioning {
            sessionState = .positioning
        } else if autoCaptureManager.captureStatus == AutoCaptureManager.CaptureStatus.ready {
            sessionState = .ready
        } else if autoCaptureManager.captureStatus == AutoCaptureManager.CaptureStatus.completed {
            sessionState = .completed
        } else if autoCaptureManager.captureStatus == AutoCaptureManager.CaptureStatus.paused {
            sessionState = .paused
        }
    }
    
    // MARK: - Quality Management
    
    /// Adds quality issues for a specific angle
    /// - Parameters:
    ///   - issues: Array of quality issue descriptions
    ///   - angle: The angle with quality issues
    func addQualityIssues(_ issues: [String], for angle: ModelManager.VehicleAngle) {
        qualityIssues[angle] = issues
    }
    
    /// Gets quality issues for a specific angle
    /// - Parameter angle: The angle to check
    /// - Returns: Array of quality issues
    func getQualityIssues(for angle: ModelManager.VehicleAngle) -> [String] {
        return qualityIssues[angle] ?? []
    }
    
    /// Validates session completeness
    /// - Returns: True if all required angles are captured
    func isSessionComplete() -> Bool {
        return capturedPhotos.count >= requiredAngles.count
    }
    
    /// Gets missing angles
    /// - Returns: Array of angles that still need to be captured
    func getMissingAngles() -> [ModelManager.VehicleAngle] {
        return requiredAngles.filter { !capturedPhotos.keys.contains($0) }
    }
    
    /// Gets captured angles
    /// - Returns: Array of angles that have been captured
    func getCapturedAngles() -> [ModelManager.VehicleAngle] {
        return Array(capturedPhotos.keys).sorted { $0.captureOrder < $1.captureOrder }
    }
    
    // MARK: - Statistics and Analytics
    
    private func calculateSuccessRate() -> Float {
        let totalAttempts = sessionStatistics.totalAttempts
        let successfulCaptures = sessionStatistics.totalPhotos
        return totalAttempts > 0 ? Float(successfulCaptures) / Float(totalAttempts) * 100 : 0
    }
    
    /// Gets comprehensive session statistics
    /// - Returns: SessionStatistics object
    func getSessionStatistics() -> SessionStatistics {
        var stats = sessionStatistics
        stats.totalPhotos = capturedPhotos.count
        stats.successRate = calculateSuccessRate()
        stats.qualityIssues = qualityIssues
        stats.capturedAngles = getCapturedAngles()
        stats.missingAngles = getMissingAngles()
        return stats
    }
    
    /// Exports session data
    /// - Returns: Dictionary containing session data for export
    func exportSessionData() -> [String: Any] {
        var exportData: [String: Any] = [:]
        
        if let session = currentSession {
            exportData["sessionId"] = session.id
            exportData["vehicleMake"] = session.vehicleMake
            exportData["vehicleModel"] = session.vehicleModel
            exportData["vehicleYear"] = session.vehicleYear
            exportData["createdDate"] = session.createdDate?.timeIntervalSince1970
            exportData["completionDate"] = session.completionDate?.timeIntervalSince1970
            exportData["isCompleted"] = session.isCompleted
        }
        
        exportData["totalPhotos"] = capturedPhotos.count
        exportData["sessionProgress"] = sessionProgress
        exportData["sessionState"] = sessionState.rawValue
        exportData["statistics"] = getSessionStatistics().toDictionary()
        
        return exportData
    }
    
    // MARK: - Helper Methods
    
    /// Resets the session manager state
    func reset() {
        currentSession = nil
        sessionState = .idle
        sessionProgress = 0.0
        currentAngle = nil
        capturedPhotos.removeAll()
        qualityIssues.removeAll()
        isSessionActive = false
        sessionStartTime = nil
        estimatedTimeRemaining = 0
        sessionStatistics = SessionStatistics()
    }
}

// MARK: - Session State
extension PhotoSessionManager {
    enum SessionState: String, CaseIterable {
        case idle = "idle"
        case active = "active"
        case positioning = "positioning"
        case ready = "ready"
        case capturing = "capturing"
        case paused = "paused"
        case completed = "completed"
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .active: return "Active"
            case .positioning: return "Positioning Vehicle"
            case .ready: return "Ready to Capture"
            case .capturing: return "Capturing Photo"
            case .paused: return "Paused"
            case .completed: return "Completed"
            }
        }
        
        var isActive: Bool {
            return self != .idle && self != .completed
        }
    }
}

// MARK: - Session Type
extension PhotoSessionManager {
    enum SessionType: String, CaseIterable {
        case standard = "standard"
        case premium = "premium"
        case quick = "quick"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .premium: return "Premium"
            case .quick: return "Quick"
            case .custom: return "Custom"
            }
        }
        
        var requiredAngles: [ModelManager.VehicleAngle] {
            switch self {
            case .standard: return ModelManager.VehicleAngle.allCases
            case .premium: return ModelManager.VehicleAngle.allCases
            case .quick: return [.front, .left, .right, .rear]
            case .custom: return ModelManager.VehicleAngle.allCases
            }
        }
    }
}

// MARK: - Session Statistics
extension PhotoSessionManager {
    struct SessionStatistics {
        var sessionId: UUID?
        var startTime: Date?
        var completionTime: Date?
        var duration: TimeInterval = 0
        var totalPhotos: Int = 0
        var totalAttempts: Int = 0
        var successRate: Float = 0
        var qualityIssues: [ModelManager.VehicleAngle: [String]] = [:]
        var capturedAngles: [ModelManager.VehicleAngle] = []
        var missingAngles: [ModelManager.VehicleAngle] = []
        
        func toDictionary() -> [String: Any] {
            return [
                "sessionId": sessionId?.uuidString ?? "",
                "startTime": startTime?.timeIntervalSince1970 ?? 0,
                "completionTime": completionTime?.timeIntervalSince1970 ?? 0,
                "duration": duration,
                "totalPhotos": totalPhotos,
                "totalAttempts": totalAttempts,
                "successRate": successRate,
                "capturedAngles": capturedAngles.map { $0.rawValue },
                "missingAngles": missingAngles.map { $0.rawValue }
            ]
        }
    }
}
