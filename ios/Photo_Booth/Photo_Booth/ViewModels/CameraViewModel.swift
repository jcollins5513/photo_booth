import Foundation
import SwiftUI
import AVFoundation
import UIKit
import Combine

@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isCameraActive = false
    @Published var isCapturing = false
    @Published var lastCapturedPhoto: UIImage?
    @Published var currentAngle: PhotoAngleType = .front
    @Published var detectionConfidence: Float = 0.0
    @Published var isDetecting = false
    @Published var errorMessage: String?
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var isProcessingFrame = false
    @Published var frameProcessingRate: Double = 0.0
    
    // MARK: - Enhanced Vision Properties
    @Published var imageQuality: Float = 0.0
    @Published var qualityIssues: [ImageProcessor.QualityIssue] = []
    @Published var isPositionValid = false
    @Published var isReadyForCapture = false
    @Published var qualityFeedback: [String] = []
    
    // MARK: - Private Properties
    private let cameraService: CameraServiceProtocol
    private let visionService: VisionServiceProtocol
    private var modelManager: ModelManager
    private let configurationService: ConfigurationService
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var frameProcessingTimer: Timer?
    private var lastFrameTime: Date = Date()
    private var frameCount = 0
    
    // MARK: - Initialization
    init(cameraService: CameraServiceProtocol, visionService: VisionServiceProtocol, modelManager: ModelManager? = nil, configurationService: ConfigurationService = ConfigurationService()) {
        self.cameraService = cameraService
        self.visionService = visionService
        self.configurationService = configurationService
        
        // Initialize modelManager
        if let modelManager = modelManager {
            self.modelManager = modelManager
        } else {
            self.modelManager = ModelManager()
        }
        
        setupCameraPermission()
        setupVisionBindings()
    }
    
    private func setupVisionBindings() {
        // Bind to VisionService published properties if it's ObservableObject
        if let visionService = visionService as? VisionService {
            visionService.$imageQuality
                .assign(to: &$imageQuality)
            
            visionService.$qualityIssues
                .assign(to: &$qualityIssues)
            
            visionService.$isPositionValid
                .assign(to: &$isPositionValid)
            
            visionService.$currentAngle
                .sink { [weak self] angleName in
                    if let angle = PhotoAngleType.allCases.first(where: { $0.rawValue == angleName.lowercased() }) {
                        self?.currentAngle = angle
                    }
                }
                .store(in: &cancellables)
            
            visionService.$confidence
                .assign(to: &$detectionConfidence)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Camera Management
    func startCamera() async {
        do {
            guard cameraPermissionStatus == .authorized else {
                await requestCameraPermission()
                return
            }
            
            try await cameraService.configureSession(
                position: .back,
                quality: .photo,
                flashMode: .auto
            )
            
            try await cameraService.startSession()
            previewLayer = cameraService.getPreviewLayer()
            isCameraActive = true
            errorMessage = nil
            
            // Start continuous angle detection
            await startAngleDetection()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stopCamera() async {
        do {
            try await cameraService.stopSession()
            isCameraActive = false
            isDetecting = false
            previewLayer = nil
            stopFrameProcessingTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async {
        guard isCameraActive && !isCapturing else { 
            print("⚠️ CameraViewModel: Cannot capture - camera not active or already capturing")
            return 
        }
        
        print("📸 CameraViewModel: Starting photo capture")
        isCapturing = true
        
        do {
            let imageData = try await cameraService.capturePhoto(settings: .default)
            if let image = UIImage(data: imageData) {
                lastCapturedPhoto = image
                print("✅ CameraViewModel: Photo captured successfully")
            } else {
                print("❌ CameraViewModel: Failed to create image from data")
                errorMessage = "Failed to create image from captured data"
            }
        } catch {
            print("❌ CameraViewModel: Photo capture failed - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isCapturing = false
    }
    
    // MARK: - Angle Detection
    private func startAngleDetection() async {
        guard isCameraActive else { return }
        
        do {
            try await visionService.loadModel()
            
            // Start frame processing timer
            startFrameProcessingTimer()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func startFrameProcessingTimer() {
        frameProcessingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrameProcessingRate()
            }
        }
    }
    
    private func stopFrameProcessingTimer() {
        frameProcessingTimer?.invalidate()
        frameProcessingTimer = nil
    }
    
    private func updateFrameProcessingRate() {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastFrameTime)
        
        if timeInterval >= 1.0 {
            frameProcessingRate = Double(frameCount) / timeInterval
            frameCount = 0
            lastFrameTime = now
        }
    }
    
    // MARK: - Frame Processing
    func processFrame(_ image: UIImage) {
        guard !isProcessingFrame else { return }
        
        isProcessingFrame = true
        frameCount += 1
        
        // Use enhanced VisionService for real-time analysis
        if let visionService = visionService as? VisionService {
            visionService.processCameraFrame(image)
            
            // Update derived properties
            isReadyForCapture = visionService.isReadyForCapture()
            qualityFeedback = visionService.getQualityFeedback()
            isDetecting = detectionConfidence > configurationService.confidenceThreshold
        } else {
            // Fallback to original ModelManager approach
            Task {
                let (angle, confidence) = await modelManager.classifyVehicleAngle(from: image)
                
                await MainActor.run {
                    self.currentAngle = self.convertToPhotoAngleType(angle)
                    self.detectionConfidence = confidence
                    self.isDetecting = confidence > self.configurationService.confidenceThreshold
                    self.isProcessingFrame = false
                }
            }
        }
    }
    
    func setTargetAngle(_ angle: PhotoAngleType) {
        visionService.setTargetAngle(angle)
    }
    
    // MARK: - Camera Controls
    func setFocusPoint(_ point: CGPoint) async {
        do {
            try await cameraService.setFocusPoint(point)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func setExposurePoint(_ point: CGPoint) async {
        do {
            try await cameraService.setExposurePoint(point)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Permission Management
    private func setupCameraPermission() {
        cameraPermissionStatus = cameraService.checkCameraPermission()
    }
    
    private func requestCameraPermission() async {
        let granted = await cameraService.requestCameraPermission()
        cameraPermissionStatus = granted ? .authorized : .denied
        
        if granted {
            await startCamera()
        } else {
            errorMessage = "Camera permission is required to use this feature"
        }
    }
    
    // MARK: - Helper Methods
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    func updatePreviewFrame(_ frame: CGRect) {
        cameraService.updatePreviewFrame(frame)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Enhanced Vision Methods
    
    /// Gets all angles in the capture sequence
    /// - Returns: Array of angle display names in capture order
    func getAllAnglesInSequence() -> [String] {
        if let visionService = visionService as? VisionService {
            return visionService.getAllAnglesInSequence()
        }
        return PhotoAngleType.allCases.map { $0.rawValue.capitalized }
    }
    
    /// Gets the next angle in the sequence
    /// - Parameter currentAngle: Current angle name
    /// - Returns: Next angle name or nil if sequence complete
    func getNextAngle(currentAngle: String) -> String? {
        if let visionService = visionService as? VisionService {
            return visionService.getNextAngle(currentAngle: PhotoAngleType(rawValue: currentAngle) ?? .front).rawValue
        }
        return nil
    }
    
    /// Updates confidence threshold
    /// - Parameter threshold: New confidence threshold
    func updateConfidenceThreshold(_ threshold: Float) {
        configurationService.updateConfidenceThreshold(threshold)
        if let visionService = visionService as? VisionService {
            visionService.updateConfidenceThreshold(threshold)
        }
    }
    
    /// Gets current confidence threshold
    /// - Returns: Current confidence threshold
    func getConfidenceThreshold() -> Float {
        return configurationService.confidenceThreshold
    }
    
    /// Gets performance metrics
    /// - Returns: Performance metrics tuple
    func getPerformanceMetrics() -> (averageInferenceTime: TimeInterval, modelAccuracy: Float) {
        if let visionService = visionService as? VisionService {
            return visionService.getPerformanceMetrics()
        }
        return (0.0, 0.0)
    }
    
    /// Checks if performance is acceptable
    /// - Returns: True if performance meets requirements
    func isPerformanceAcceptable() -> Bool {
        if let visionService = visionService as? VisionService {
            return visionService.isPerformanceAcceptable()
        }
        return false
    }
    
    /// Resets vision service state
    func resetVision() {
        if let visionService = visionService as? VisionService {
            visionService.reset()
        }
        imageQuality = 0.0
        qualityIssues = []
        isPositionValid = false
        isReadyForCapture = false
        qualityFeedback = []
    }
    
    // MARK: - Helper Methods
    
    private func convertToPhotoAngleType(_ angle: ModelManager.VehicleAngle?) -> PhotoAngleType {
        guard let angle = angle else { return .front }
        
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
}

// MARK: - Frame Provider
private class CameraFrameProvider: FrameProvider {
    private let cameraService: CameraServiceProtocol
    private var isProviderActive = false
    
    init(cameraService: CameraServiceProtocol) {
        self.cameraService = cameraService
    }
    
    var isActive: Bool {
        return isProviderActive
    }
    
    func getCurrentFrame() -> UIImage? {
        // This would need to be implemented based on how we get frames from the camera
        // For now, return nil as this is a placeholder
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func convertToPhotoAngleType(_ angle: ModelManager.VehicleAngle?) -> PhotoAngleType {
        guard let angle = angle else { return .front }
        
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
}
