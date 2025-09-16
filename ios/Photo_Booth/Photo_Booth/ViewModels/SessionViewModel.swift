import Foundation
import SwiftUI

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
    
    // MARK: - Private Properties
    private let sessionManager: SessionManagerProtocol
    private let storageService: StorageServiceProtocol
    private let cameraViewModel: CameraViewModel
    
    // MARK: - Computed Properties
    var remainingAngles: [PhotoAngleType] {
        let allAngles = PhotoAngleType.allCases
        let capturedAngleStrings = Set(capturedPhotos.map { $0.angle })
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
    init(sessionManager: SessionManagerProtocol, storageService: StorageServiceProtocol, cameraViewModel: CameraViewModel) {
        self.sessionManager = sessionManager
        self.storageService = storageService
        self.cameraViewModel = cameraViewModel
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
        
        do {
            let session = try await sessionManager.startSession(
                vehicleIdentifier: vehicleIdentifier,
                totalAngles: Int16(totalAngles)
            )
            
            currentSession = session
            isSessionActive = true
            self.vehicleIdentifier = vehicleIdentifier
            self.totalAngles = totalAngles
            capturedPhotos = []
            currentAngle = .front
            sessionProgress = 0.0
            
            // Set the first angle as target for camera
            cameraViewModel.setTargetAngle(currentAngle)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func completeSession() async {
        guard let session = currentSession else {
            errorMessage = "No active session to complete"
            return
        }
        
        isLoading = true
        
        do {
            let completedSession = try await sessionManager.completeSession(id: session.id)
            currentSession = completedSession
            isSessionActive = false
            sessionProgress = 1.0
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func cancelSession() async {
        guard let session = currentSession else {
            errorMessage = "No active session to cancel"
            return
        }
        
        isLoading = true
        
        do {
            let cancelledSession = try await sessionManager.cancelSession(id: session.id)
            currentSession = cancelledSession
            isSessionActive = false
            sessionProgress = 0.0
            capturedPhotos = []
        } catch {
            errorMessage = error.localizedDescription
        }
        
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
                sessionId: currentSession!.id,
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
            let sessions = try await sessionManager.getAllSessions()
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
    }
}
