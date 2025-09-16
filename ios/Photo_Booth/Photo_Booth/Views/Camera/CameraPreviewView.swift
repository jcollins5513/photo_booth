import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    @Binding var isActive: Bool
    @Binding var isDetecting: Bool
    @Binding var detectionConfidence: Float
    let onFrameCaptured: (UIImage) -> Void
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.onFrameCaptured = onFrameCaptured
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if isActive {
            uiView.startCamera()
        } else {
            uiView.stopCamera()
        }
    }
}

class CameraPreviewUIView: UIView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var isSessionRunning = false
    
    var onFrameCaptured: ((UIImage) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        // Request camera permission
        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.configureCameraSession()
                } else {
                    print("Camera permission denied")
                }
            }
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func configureCameraSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera")
            return
        }
        
        do {
            // Add camera input
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }
            
            // Add video output for frame processing
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }
            
            // Add photo output for high-quality capture
            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }
            
            // Configure camera settings
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()
            
            // Setup preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
            
            self.captureSession = session
            
        } catch {
            print("Failed to configure camera: \(error)")
        }
    }
    
    // MARK: - Camera Control
    func startCamera() {
        guard let session = captureSession, !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopCamera() {
        guard let session = captureSession, isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        // Use maxPhotoDimensions instead of deprecated isHighResolutionPhotoEnabled
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func setFocusPoint(_ point: CGPoint) {
        guard let session = captureSession,
              let input = session.inputs.first as? AVCaptureDeviceInput else { return }
        let device = input.device
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to set focus point: \(error)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraPreviewUIView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.onFrameCaptured?(image)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraPreviewUIView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from photo data")
            return
        }
        
        DispatchQueue.main.async {
            self.onFrameCaptured?(image)
        }
    }
}

// MARK: - Camera Overlay View
struct CameraOverlayView: View {
    let currentAngle: PhotoAngleType
    let isDetecting: Bool
    let detectionConfidence: Float
    let onTap: (CGPoint) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Focus indicator
                if isDetecting {
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.0 + CGFloat(detectionConfidence * 0.5))
                        .animation(.easeInOut(duration: 0.3), value: isDetecting)
                }
                
                // Angle guidance overlay
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Current angle indicator
                        Text(currentAngle.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        
                        // Detection status
                        HStack {
                            Circle()
                                .fill(isDetecting ? Color.green : Color.gray)
                                .frame(width: 12, height: 12)
                            
                            Text(isDetecting ? "Angle Detected" : "Positioning...")
                                .foregroundColor(.white)
                                .font(.caption)
                            
                            if detectionConfidence > 0 {
                                Text("\(Int(detectionConfidence * 100))%")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                    .padding(.bottom, 100)
                }
                
                // Tap to focus areas
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let normalizedPoint = CGPoint(
                            x: location.x / geometry.size.width,
                            y: location.y / geometry.size.height
                        )
                        onTap(normalizedPoint)
                    }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        CameraPreviewView(
            isActive: .constant(true),
            isDetecting: .constant(true),
            detectionConfidence: .constant(0.85),
            onFrameCaptured: { _ in }
        )
        
        CameraOverlayView(
            currentAngle: .front,
            isDetecting: true,
            detectionConfidence: 0.85,
            onTap: { _ in }
        )
    }
    .ignoresSafeArea()
}
