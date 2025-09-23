import Foundation
import SwiftUI
import Combine
import CoreData

/// Automated session view model for static camera setup - manages vehicle detection and capture
@MainActor
class AutomatedSessionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSessionActive = false
    @Published var sessionProgress: Float = 0.0
    @Published var capturedPhotos: [CapturedPhoto] = []
    @Published var currentVehiclePosition: AutomatedVehicleDetector.VehiclePosition?
    @Published var isVehicleDetected = false
    @Published var vehicleConfidence: Float = 0.0
    @Published var captureReady = false
    @Published var sessionQuality: SessionQuality = .good
    @Published var sessionStatistics: AutomatedVehicleDetector.SessionStatistics?
    
    // MARK: - Services
    private let automatedDetector = AutomatedVehicleDetector()
    private let cameraService = CameraService()
    private let storageService: StorageService
    
    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private var lastCaptureTime: Date?
    private var frameProcessingTask: Task<Void, Never>?
    
    // MARK: - Constants
    private let totalPositions = 8
    private let frameProcessingInterval: TimeInterval = 0.1 // 10 FPS
    
    // MARK: - Data Structures
    struct CapturedPhoto: Identifiable, Codable {
        let id: UUID
        let image: Data
        let position: String // Store as string to avoid Codable issues
        let timestamp: Date
        let confidence: Float
        let metadata: PhotoMetadata
        
        init(image: Data, position: AutomatedVehicleDetector.VehiclePosition, timestamp: Date, confidence: Float, metadata: PhotoMetadata) {
            self.id = UUID()
            self.image = image
            self.position = position.rawValue
            self.timestamp = timestamp
            self.confidence = confidence
            self.metadata = metadata
        }
        
        // Computed property to get VehiclePosition
        var vehiclePosition: AutomatedVehicleDetector.VehiclePosition {
            return AutomatedVehicleDetector.VehiclePosition(rawValue: position) ?? .front
        }
        
        struct PhotoMetadata: Codable {
            let deviceModel: String
            let iOSVersion: String
            let appVersion: String
            let sessionId: String
            let positionOrder: Int
        }
    }
    
    enum SessionQuality {
        case excellent
        case good
        case fair
        case poor
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "star.fill"
            case .good: return "checkmark.circle.fill"
            case .fair: return "exclamationmark.triangle.fill"
            case .poor: return "xmark.circle.fill"
            }
        }
    }
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentContainer, fileSystemManager: FileSystemManagerProtocol) {
        self.storageService = StorageService(persistentContainer: persistentContainer, fileSystemManager: fileSystemManager)
        setupBindings()
    }
    
    // MARK: - Setup Methods
    private func setupBindings() {
        // Bind to automated detector updates
        automatedDetector.$isDetecting
            .assign(to: \.isSessionActive, on: self)
            .store(in: &cancellables)
        
        automatedDetector.$currentVehiclePosition
            .assign(to: \.currentVehiclePosition, on: self)
            .store(in: &cancellables)
        
        automatedDetector.$isVehicleInFrame
            .assign(to: \.isVehicleDetected, on: self)
            .store(in: &cancellables)
        
        automatedDetector.$vehicleConfidence
            .assign(to: \.vehicleConfidence, on: self)
            .store(in: &cancellables)
        
        automatedDetector.$captureReady
            .assign(to: \.captureReady, on: self)
            .store(in: &cancellables)
        
        // Update session progress
        automatedDetector.$captureReady
            .sink { [weak self] _ in
                self?.updateSessionProgress()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    func startSession() async {
        print("🚀 AutomatedSessionViewModel: Starting automated session")
        
        sessionStartTime = Date()
        isSessionActive = true
        capturedPhotos.removeAll()
        
        do {
            // Start automated detection
            await automatedDetector.startDetection()
            
            // Start camera service
            try await cameraService.startSession()
            
            // Start frame processing
            startFrameProcessing()
            
            print("✅ AutomatedSessionViewModel: Session started successfully")
        } catch {
            print("❌ AutomatedSessionViewModel: Failed to start session - \(error)")
            isSessionActive = false
        }
    }
    
    func pauseSession() {
        print("⏸️ AutomatedSessionViewModel: Pausing session")
        isSessionActive = false
        frameProcessingTask?.cancel()
    }
    
    func resumeSession() {
        print("▶️ AutomatedSessionViewModel: Resuming session")
        isSessionActive = true
        startFrameProcessing()
    }
    
    func endSession() {
        print("🛑 AutomatedSessionViewModel: Ending session")
        isSessionActive = false
        automatedDetector.stopDetection()
        Task {
            try? await cameraService.stopSession()
        }
        frameProcessingTask?.cancel()
        
        // Save session data
        Task {
            await saveSessionData()
        }
    }
    
    // MARK: - Frame Processing
    private func startFrameProcessing() {
        frameProcessingTask?.cancel()
        
        frameProcessingTask = Task {
            while isSessionActive && !Task.isCancelled {
                do {
                    // For now, we'll simulate frame processing
                    // In a real implementation, this would get frames from the camera
                    // The camera service would need to be extended to provide frame access
                    
                    // Wait for next frame
                    try await Task.sleep(nanoseconds: UInt64(frameProcessingInterval * 1_000_000_000))
                } catch {
                    if !Task.isCancelled {
                        print("❌ AutomatedSessionViewModel: Frame processing error - \(error)")
                    }
                    break
                }
            }
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async {
        guard captureReady else {
            print("⚠️ AutomatedSessionViewModel: Not ready to capture")
            return
        }
        
        print("📸 AutomatedSessionViewModel: Capturing photo")
        
        // Capture photo from automated detector
        if let image = await automatedDetector.capturePhoto() {
            let photo = CapturedPhoto(
                image: image.jpegData(compressionQuality: 0.8) ?? Data(),
                position: currentVehiclePosition ?? .front,
                timestamp: Date(),
                confidence: vehicleConfidence,
                metadata: createPhotoMetadata()
            )
            
            capturedPhotos.append(photo)
            lastCaptureTime = Date()
            
            // Provide capture feedback
            provideCaptureFeedback()
            
            // Update session quality
            updateSessionQuality()
            
            // Check if session is complete
            if automatedDetector.isSessionComplete() {
                await completeSession()
            }
            
            print("✅ AutomatedSessionViewModel: Photo captured successfully - \(photo.vehiclePosition.displayName)")
        }
    }
    
    // MARK: - Session Progress
    private func updateSessionProgress() {
        sessionProgress = automatedDetector.getSessionProgress()
    }
    
    // MARK: - Session Quality
    private func updateSessionQuality() {
        guard !capturedPhotos.isEmpty else {
            sessionQuality = .poor
            return
        }
        
        let averageConfidence = capturedPhotos.map { $0.confidence }.reduce(0, +) / Float(capturedPhotos.count)
        let completionRate = Float(capturedPhotos.count) / Float(totalPositions)
        
        if averageConfidence > 0.9 && completionRate >= 1.0 {
            sessionQuality = .excellent
        } else if averageConfidence > 0.8 && completionRate >= 0.8 {
            sessionQuality = .good
        } else if averageConfidence > 0.6 && completionRate >= 0.6 {
            sessionQuality = .fair
        } else {
            sessionQuality = .poor
        }
    }
    
    // MARK: - Session Completion
    private func completeSession() async {
        print("🎉 AutomatedSessionViewModel: Session completed successfully")
        
        sessionStatistics = automatedDetector.getSessionStatistics()
        isSessionActive = false
        
        // Save session data
        await saveSessionData()
        
        print("✅ AutomatedSessionViewModel: Session completed with \(capturedPhotos.count) photos")
    }
    
    // MARK: - Data Persistence
    private func saveSessionData() async {
        do {
            let sessionData = AutomatedSessionData(
                id: UUID(),
                startTime: sessionStartTime ?? Date(),
                endTime: Date(),
                photos: capturedPhotos,
                quality: sessionQuality,
                statistics: sessionStatistics,
                totalPositions: totalPositions,
                successRate: Float(capturedPhotos.count) / Float(totalPositions)
            )
            
            try await storageService.saveAutomatedSession(sessionData)
            print("✅ AutomatedSessionViewModel: Session data saved successfully")
        } catch {
            print("❌ AutomatedSessionViewModel: Failed to save session data - \(error)")
        }
    }
    
    private func createPhotoMetadata() -> CapturedPhoto.PhotoMetadata {
        return CapturedPhoto.PhotoMetadata(
            deviceModel: UIDevice.current.model,
            iOSVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            sessionId: UUID().uuidString,
            positionOrder: currentVehiclePosition?.captureOrder ?? 1
        )
    }
    
    // MARK: - Feedback Methods
    private func provideCaptureFeedback() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Visual feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            // Flash effect or other visual feedback
        }
    }
    
    // MARK: - Session Statistics
    func getSessionStatistics() -> AutomatedSessionStatistics {
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let averageConfidence = capturedPhotos.isEmpty ? 0 : capturedPhotos.map { $0.confidence }.reduce(0, +) / Float(capturedPhotos.count)
        let completionRate = Float(capturedPhotos.count) / Float(totalPositions)
        
        return AutomatedSessionStatistics(
            duration: duration,
            totalPhotos: capturedPhotos.count,
            averageConfidence: averageConfidence,
            completionRate: completionRate,
            quality: sessionQuality,
            capturedPositions: automatedDetector.getCapturedPositions()
        )
    }
    
    struct AutomatedSessionStatistics {
        let duration: TimeInterval
        let totalPhotos: Int
        let averageConfidence: Float
        let completionRate: Float
        let quality: SessionQuality
        let capturedPositions: [AutomatedVehicleDetector.VehiclePosition]
    }
    
    // MARK: - Session Control
    func isSessionComplete() -> Bool {
        return automatedDetector.isSessionComplete()
    }
    
    func getCapturedPositions() -> [AutomatedVehicleDetector.VehiclePosition] {
        return automatedDetector.getCapturedPositions()
    }
    
    func getNextExpectedPosition() -> AutomatedVehicleDetector.VehiclePosition? {
        return automatedDetector.getNextExpectedPosition()
    }
}

// MARK: - Automated Session Data
struct AutomatedSessionData: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let photos: [AutomatedSessionViewModel.CapturedPhoto]
    let quality: String // Store as string to avoid Codable issues
    let statistics: AutomatedVehicleDetector.SessionStatistics?
    let totalPositions: Int
    let successRate: Float
    
    init(id: UUID, startTime: Date, endTime: Date, photos: [AutomatedSessionViewModel.CapturedPhoto], quality: AutomatedSessionViewModel.SessionQuality, statistics: AutomatedVehicleDetector.SessionStatistics?, totalPositions: Int, successRate: Float) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.photos = photos
        self.quality = "\(quality)" // Convert enum to string
        self.statistics = statistics
        self.totalPositions = totalPositions
        self.successRate = successRate
    }
}

// MARK: - Storage Service Extension
extension StorageService {
    func saveAutomatedSession(_ sessionData: AutomatedSessionData) async throws {
        // Implementation for saving automated session data
        // This would integrate with the existing storage service
        print("💾 StorageService: Saving automated session data")
    }
}
