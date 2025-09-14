import Foundation
import AVFoundation
import UIKit

// MARK: - Camera Service Contract

/// Protocol defining the camera service interface for vehicle photo capture
protocol CameraServiceProtocol {
    
    // MARK: - Configuration
    
    /// Configure camera session with specified settings
    /// - Parameters:
    ///   - position: Camera position (front/rear)
    ///   - quality: Photo quality preset
    ///   - flashMode: Flash mode setting
    func configureSession(position: AVCaptureDevice.Position, 
                         quality: AVCaptureSession.Preset, 
                         flashMode: AVCaptureDevice.FlashMode) async throws
    
    /// Start camera session and begin preview
    func startSession() async throws
    
    /// Stop camera session and end preview
    func stopSession() async throws
    
    // MARK: - Preview
    
    /// Get camera preview layer for UI display
    /// - Returns: Configured AVCaptureVideoPreviewLayer
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer
    
    /// Update preview layer frame for UI changes
    /// - Parameter frame: New frame for preview layer
    func updatePreviewFrame(_ frame: CGRect)
    
    // MARK: - Capture
    
    /// Capture high-quality photo
    /// - Parameter settings: Photo capture settings
    /// - Returns: Captured image data
    func capturePhoto(settings: PhotoCaptureSettings) async throws -> Data
    
    /// Set focus point for camera
    /// - Parameter point: Focus point in normalized coordinates (0,0 to 1,1)
    func setFocusPoint(_ point: CGPoint) async throws
    
    /// Set exposure point for camera
    /// - Parameter point: Exposure point in normalized coordinates (0,0 to 1,1)
    func setExposurePoint(_ point: CGPoint) async throws
    
    // MARK: - Permissions
    
    /// Check camera permission status
    /// - Returns: Current permission status
    func checkCameraPermission() -> AVAuthorizationStatus
    
    /// Request camera permission from user
    /// - Returns: Permission granted status
    func requestCameraPermission() async -> Bool
}

// MARK: - Supporting Types

/// Photo capture settings configuration
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
enum CameraServiceError: LocalizedError {
    case sessionNotConfigured
    case sessionNotRunning
    case captureFailed
    case permissionDenied
    case deviceNotAvailable
    case configurationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotConfigured:
            return "Camera session not configured"
        case .sessionNotRunning:
            return "Camera session not running"
        case .captureFailed:
            return "Photo capture failed"
        case .permissionDenied:
            return "Camera permission denied"
        case .deviceNotAvailable:
            return "Camera device not available"
        case .configurationFailed(let message):
            return "Camera configuration failed: \(message)"
        }
    }
}

// MARK: - Contract Tests

/// Contract tests for camera service implementation
class CameraServiceContractTests {
    
    private let cameraService: CameraServiceProtocol
    
    init(cameraService: CameraServiceProtocol) {
        self.cameraService = cameraService
    }
    
    /// Test camera session configuration
    func testSessionConfiguration() async throws {
        // Test default configuration
        try await cameraService.configureSession(
            position: .back,
            quality: .photo,
            flashMode: .auto
        )
        
        // Test custom configuration
        try await cameraService.configureSession(
            position: .front,
            quality: .high,
            flashMode: .off
        )
    }
    
    /// Test camera session lifecycle
    func testSessionLifecycle() async throws {
        // Start session
        try await cameraService.startSession()
        
        // Verify session is running (implementation specific)
        // This would need to be implemented by the concrete class
        
        // Stop session
        try await cameraService.stopSession()
    }
    
    /// Test photo capture
    func testPhotoCapture() async throws {
        // Configure and start session
        try await cameraService.configureSession(
            position: .back,
            quality: .photo,
            flashMode: .auto
        )
        try await cameraService.startSession()
        
        // Capture photo
        let imageData = try await cameraService.capturePhoto(
            settings: .default
        )
        
        // Verify image data
        XCTAssertFalse(imageData.isEmpty, "Captured image data should not be empty")
        
        // Verify image can be created from data
        let image = UIImage(data: imageData)
        XCTAssertNotNil(image, "Captured data should create valid UIImage")
    }
    
    /// Test permission handling
    func testPermissionHandling() async {
        // Check initial permission status
        let initialStatus = cameraService.checkCameraPermission()
        XCTAssertNotEqual(initialStatus, .notDetermined, "Permission should be determined")
        
        // Request permission if needed
        if initialStatus == .notDetermined {
            let granted = await cameraService.requestCameraPermission()
            XCTAssertTrue(granted, "Camera permission should be granted for testing")
        }
    }
    
    /// Test preview layer configuration
    func testPreviewLayerConfiguration() {
        let previewLayer = cameraService.getPreviewLayer()
        
        // Verify preview layer properties
        XCTAssertNotNil(previewLayer.session, "Preview layer should have session")
        XCTAssertEqual(previewLayer.videoGravity, .resizeAspectFill, "Default video gravity should be resizeAspectFill")
        
        // Test frame update
        let testFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        cameraService.updatePreviewFrame(testFrame)
        XCTAssertEqual(previewLayer.frame, testFrame, "Preview frame should be updated")
    }
    
    /// Test focus and exposure point setting
    func testFocusAndExposurePoints() async throws {
        try await cameraService.configureSession(
            position: .back,
            quality: .photo,
            flashMode: .auto
        )
        try await cameraService.startSession()
        
        // Test focus point
        let focusPoint = CGPoint(x: 0.5, y: 0.5)
        try await cameraService.setFocusPoint(focusPoint)
        
        // Test exposure point
        let exposurePoint = CGPoint(x: 0.3, y: 0.7)
        try await cameraService.setExposurePoint(exposurePoint)
    }
}

// MARK: - Test Helpers

import XCTest

extension XCTestCase {
    
    /// Create camera service contract tests
    /// - Parameter cameraService: Camera service implementation to test
    /// - Returns: Configured contract tests
    func createCameraServiceContractTests(cameraService: CameraServiceProtocol) -> CameraServiceContractTests {
        return CameraServiceContractTests(cameraService: cameraService)
    }
}
