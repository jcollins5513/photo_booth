import Foundation
import AVFoundation
import UIKit

/// Protocol defining the camera service interface
protocol CameraServiceProtocol {
    /// Configure the camera session with specified settings
    func configureSession(
        position: AVCaptureDevice.Position,
        quality: AVCaptureSession.Preset,
        flashMode: AVCaptureDevice.FlashMode
    ) async throws
    
    /// Start the camera session
    func startSession() async throws
    
    /// Stop the camera session
    func stopSession() async throws
    
    /// Get the preview layer for displaying camera feed
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer
    
    /// Update the preview layer frame
    func updatePreviewFrame(_ frame: CGRect)
    
    /// Capture a photo with specified settings
    func capturePhoto(settings: PhotoCaptureSettings) async throws -> Data
    
    /// Set focus point (normalized coordinates 0-1)
    func setFocusPoint(_ point: CGPoint) async throws
    
    /// Set exposure point (normalized coordinates 0-1)
    func setExposurePoint(_ point: CGPoint) async throws
    
    /// Check current camera permission status
    func checkCameraPermission() -> AVAuthorizationStatus
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool
}

/// Photo capture settings
struct PhotoCaptureSettings {
    let format: [String: Any]
    let flashMode: AVCaptureDevice.FlashMode
    let focusMode: AVCaptureDevice.FocusMode
    let exposureMode: AVCaptureDevice.ExposureMode
    let whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode
    
    static let `default` = PhotoCaptureSettings(
        format: [AVVideoCodecKey: AVVideoCodecType.jpeg],
        flashMode: .auto,
        focusMode: .continuousAutoFocus,
        exposureMode: .continuousAutoExposure,
        whiteBalanceMode: .continuousAutoWhiteBalance
    )
}

/// Camera service errors
enum CameraServiceError: Error, LocalizedError {
    case configurationFailed
    case sessionNotConfigured
    case sessionNotRunning
    case permissionDenied
    case deviceNotAvailable
    case captureFailed
    case invalidFocusPoint
    case invalidExposurePoint
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure camera session"
        case .sessionNotConfigured:
            return "Camera session not configured"
        case .sessionNotRunning:
            return "Camera session not running"
        case .permissionDenied:
            return "Camera permission denied"
        case .deviceNotAvailable:
            return "Camera device not available"
        case .captureFailed:
            return "Photo capture failed"
        case .invalidFocusPoint:
            return "Invalid focus point coordinates"
        case .invalidExposurePoint:
            return "Invalid exposure point coordinates"
        }
    }
}
