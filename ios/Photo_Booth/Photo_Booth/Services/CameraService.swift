import Foundation
@preconcurrency import AVFoundation
import UIKit

/// Camera service implementation
class CameraService: CameraServiceProtocol {
    
    // MARK: - Properties
    
    private var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var isSessionConfigured = false
    private var isSessionRunning = false
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default values
    }
    
    // MARK: - Session Configuration
    
    func configureSession(
        position: AVCaptureDevice.Position,
        quality: AVCaptureSession.Preset,
        flashMode: AVCaptureDevice.FlashMode
    ) async throws {
        
        // Check camera permission first
        let permissionStatus = checkCameraPermission()
        guard permissionStatus == .authorized else {
            throw CameraServiceError.permissionDenied
        }
        
        // Create capture session
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Set session preset
        if session.canSetSessionPreset(quality) {
            session.sessionPreset = quality
        }
        
        // Get camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            session.commitConfiguration()
            throw CameraServiceError.deviceNotAvailable
        }
        
        // Create device input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            } else {
                session.commitConfiguration()
                throw CameraServiceError.configurationFailed
            }
        } catch {
            session.commitConfiguration()
            throw CameraServiceError.configurationFailed
        }
        
        // Create photo output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        } else {
            session.commitConfiguration()
            throw CameraServiceError.configurationFailed
        }
        
        // Note: Flash mode will be configured per photo capture
        
        session.commitConfiguration()
        
        // Store session and update state
        captureSession = session
        isSessionConfigured = true
        
        // Create preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        previewLayer = preview
    }
    
    func startSession() async throws {
        guard let session = captureSession, isSessionConfigured else {
            throw CameraServiceError.sessionNotConfigured
        }
        
        guard !isSessionRunning else {
            return // Already running
        }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.startRunning()
                self?.isSessionRunning = session.isRunning
                continuation.resume()
            }
        }
        
        guard isSessionRunning else {
            throw CameraServiceError.configurationFailed
        }
    }
    
    func stopSession() async throws {
        guard let session = captureSession else {
            return // No session to stop
        }
        
        guard isSessionRunning else {
            return // Already stopped
        }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.stopRunning()
                self?.isSessionRunning = false
                continuation.resume()
            }
        }
    }
    
    // MARK: - Preview Layer
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if let existingLayer = previewLayer {
            return existingLayer
        }
        
        // Create a default preview layer if none exists
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }
    
    func updatePreviewFrame(_ frame: CGRect) {
        previewLayer?.frame = frame
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(settings: PhotoCaptureSettings) async throws -> Data {
        guard let session = captureSession, isSessionRunning else {
            throw CameraServiceError.sessionNotRunning
        }
        
        guard let photoOutput = photoOutput else {
            throw CameraServiceError.captureFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let photoSettings = AVCapturePhotoSettings()
            
            // Configure format
            for (key, value) in settings.format {
                photoSettings.setValue(value, forKey: key)
            }
            
            // Configure flash
            photoSettings.flashMode = settings.flashMode
            
            // Configure focus and exposure
            if let device = videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    device.focusMode = settings.focusMode
                    device.exposureMode = settings.exposureMode
                    device.whiteBalanceMode = settings.whiteBalanceMode
                    device.unlockForConfiguration()
                } catch {
                    // Configuration failed, but continue with capture
                }
            }
            
            // Set up photo capture delegate
            let delegate = PhotoCaptureDelegate { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(photoOutput, "photoDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Capture photo
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    // MARK: - Focus and Exposure
    
    func setFocusPoint(_ point: CGPoint) async throws {
        // Validate point coordinates (should be 0-1)
        guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
            throw CameraServiceError.invalidFocusPoint
        }
        
        guard let device = videoDeviceInput?.device, device.isFocusPointOfInterestSupported else {
            return // Focus point not supported
        }
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            device.unlockForConfiguration()
        } catch {
            throw CameraServiceError.configurationFailed
        }
    }
    
    func setExposurePoint(_ point: CGPoint) async throws {
        // Validate point coordinates (should be 0-1)
        guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
            throw CameraServiceError.invalidExposurePoint
        }
        
        guard let device = videoDeviceInput?.device, device.isExposurePointOfInterestSupported else {
            return // Exposure point not supported
        }
        
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch {
            throw CameraServiceError.configurationFailed
        }
    }
    
    // MARK: - Permissions
    
    func checkCameraPermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestCameraPermission() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        return status
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let completion: (Result<Data, Error>) -> Void
    
    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion(.failure(CameraServiceError.captureFailed))
            return
        }
        
        completion(.success(imageData))
    }
}
