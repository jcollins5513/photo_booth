import Foundation
@preconcurrency import AVFoundation
import UIKit

/// Camera service implementation
class CameraService: @unchecked Sendable, CameraServiceProtocol {
    
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
        
        // Set session preset with error handling
        if session.canSetSessionPreset(quality) {
            session.sessionPreset = quality
        } else {
            print("⚠️ CameraService: Cannot set session preset \(quality), using default")
            session.sessionPreset = .photo
        }
        
        // Get camera device with better error handling
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            session.commitConfiguration()
            print("❌ CameraService: No camera device available for position \(position)")
            throw CameraServiceError.deviceNotAvailable
        }
        
        // Check if camera is available
        guard camera.isConnected && !camera.isSuspended else {
            session.commitConfiguration()
            print("❌ CameraService: Camera device is not connected or is suspended")
            throw CameraServiceError.deviceNotAvailable
        }
        
        // Create device input with better error handling
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
                print("✅ CameraService: Device input added successfully")
            } else {
                session.commitConfiguration()
                print("❌ CameraService: Cannot add device input to session")
                throw CameraServiceError.configurationFailed
            }
        } catch {
            session.commitConfiguration()
            print("❌ CameraService: Failed to create device input - \(error.localizedDescription)")
            throw CameraServiceError.configurationFailed
        }
        
        // Create photo output with better error handling
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
            print("✅ CameraService: Photo output added successfully")
        } else {
            session.commitConfiguration()
            print("❌ CameraService: Cannot add photo output to session")
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
                Task { @MainActor in
                    self?.isSessionRunning = session.isRunning
                }
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
                Task { @MainActor in
                    self?.isSessionRunning = false
                }
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
        guard isSessionRunning else {
            print("❌ CameraService: Session not running for photo capture")
            throw CameraServiceError.sessionNotRunning
        }
        
        guard let photoOutput = photoOutput else {
            print("❌ CameraService: Photo output not available")
            throw CameraServiceError.captureFailed
        }
        
        print("🔍 CameraService: Session running: \(isSessionRunning)")
        print("🔍 CameraService: Session configured: \(isSessionConfigured)")
        
        // Double-check that the session is actually running
        guard let session = captureSession else {
            print("❌ CameraService: No capture session available")
            throw CameraServiceError.sessionNotRunning
        }
        
        // Give the session a moment to start if it's not running yet
        if !session.isRunning {
            print("⚠️ CameraService: Session not running, attempting to start...")
            session.startRunning()
            // Wait a brief moment for the session to start
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        guard session.isRunning else {
            print("❌ CameraService: Session failed to start")
            throw CameraServiceError.sessionNotRunning
        }
        
        // Note: AVCapturePhotoOutput doesn't have a direct property to check if capturing
        // We'll rely on the delegate pattern to handle concurrent captures
        
        return try await withCheckedThrowingContinuation { continuation in
            let photoSettings = AVCapturePhotoSettings()
            
            // Configure flash
            photoSettings.flashMode = settings.flashMode
            
            // Configure focus and exposure with better error handling
            if let device = videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    device.focusMode = settings.focusMode
                    device.exposureMode = settings.exposureMode
                    device.whiteBalanceMode = settings.whiteBalanceMode
                    device.unlockForConfiguration()
                    print("✅ CameraService: Camera settings configured successfully")
                } catch {
                    print("⚠️ CameraService: Failed to configure camera settings - \(error.localizedDescription)")
                    // Continue with capture even if configuration fails
                }
            }
            
            // Set up photo capture delegate
            let delegate = PhotoCaptureDelegate { result in
                switch result {
                case .success(let data):
                    print("✅ CameraService: Photo captured successfully (\(data.count) bytes)")
                    continuation.resume(returning: data)
                case .failure(let error):
                    print("❌ CameraService: Photo capture failed - \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(photoOutput, "photoDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Capture photo
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
            print("📸 CameraService: Photo capture initiated")
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
            print("❌ PhotoCaptureDelegate: Photo processing error - \(error.localizedDescription)")
            print("❌ PhotoCaptureDelegate: Error details - \(error)")
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ PhotoCaptureDelegate: Failed to get image data from photo")
            completion(.failure(CameraServiceError.captureFailed))
            return
        }
        
        print("✅ PhotoCaptureDelegate: Photo processed successfully (\(imageData.count) bytes)")
        completion(.success(imageData))
    }
}
