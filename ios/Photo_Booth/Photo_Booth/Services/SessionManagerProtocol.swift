import Foundation

/// Protocol defining the session manager interface
protocol SessionManagerProtocol {
    /// Start a new photo session
    func startSession(
        vehicleIdentifier: String,
        totalAngles: Int16
    ) async throws -> PhotoSession
    
    /// Get a session by ID
    func getSession(id: UUID) async throws -> PhotoSession?
    
    /// Complete a photo session
    func completeSession(id: UUID) async throws -> PhotoSession
    
    /// Cancel a photo session
    func cancelSession(id: UUID) async throws -> PhotoSession
    
    /// Get all sessions
    func getAllSessions() async throws -> [PhotoSession]
    
    /// Manual photo capture
    func manualCapture(
        sessionId: UUID,
        angle: String,
        imageData: Data
    ) async throws -> VehiclePhoto
    
    /// Get current active session
    func getCurrentSession() -> PhotoSession?
    
    /// Set current active session
    func setCurrentSession(_ session: PhotoSession?)
}

/// Session manager errors
enum SessionManagerError: Error, LocalizedError {
    case sessionNotFound
    case sessionAlreadyActive
    case noActiveSession
    case invalidSessionState
    case captureFailed(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Photo session not found"
        case .sessionAlreadyActive:
            return "A session is already active"
        case .noActiveSession:
            return "No active session"
        case .invalidSessionState:
            return "Invalid session state"
        case .captureFailed(let message):
            return "Photo capture failed: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}
