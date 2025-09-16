import Foundation
import SwiftUI
import AVFoundation
import UIKit

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
    
    // MARK: - Private Properties
    private let cameraService: CameraServiceProtocol
    private let visionService: VisionServiceProtocol
    private let modelManager: ModelManager
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var frameProcessingTimer: Timer?
    private var lastFrameTime: Date = Date()
    private var frameCount = 0
    
    // MARK: - Initialization
    init(cameraService: CameraServiceProtocol, visionService: VisionServiceProtocol, modelManager: ModelManager = ModelManager()) {
        self.cameraService = cameraService
        self.visionService = visionService
        self.modelManager = modelManager
        setupCameraPermission()
    }
    
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
        guard isCameraActive && !isCapturing else { return }
        
        isCapturing = true
        
        do {
            let imageData = try await cameraService.capturePhoto(settings: .default)
            if let image = UIImage(data: imageData) {
                lastCapturedPhoto = image
            }
        } catch {
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
        
        Task {
            do {
                // Use ModelManager for real-time classification
                let (angle, confidence) = try await modelManager.classifyVehicleAngle(from: image)
                
                await MainActor.run {
                    self.currentAngle = angle
                    self.detectionConfidence = confidence
                    self.isDetecting = confidence > 0.7
                    self.isProcessingFrame = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
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
}
