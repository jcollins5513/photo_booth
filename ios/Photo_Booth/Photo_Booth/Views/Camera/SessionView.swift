import SwiftUI

struct SessionView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var cameraViewModel: CameraViewModel
    @State private var showingPhotoReview = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Session Header
            VStack(spacing: 10) {
                Text("Photo Session")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(sessionViewModel.vehicleIdentifier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Progress Bar
                ProgressView(value: sessionViewModel.sessionProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                Text("\(Int(sessionViewModel.sessionProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Current Angle Display
            VStack(spacing: 15) {
                Text("Current Angle")
                    .font(.headline)
                
                Text(sessionViewModel.currentAngle.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                // Angle guidance
                AngleGuidanceView(angle: sessionViewModel.currentAngle)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Real Camera Preview
            ZStack {
                CameraPreviewView(
                    isActive: $cameraViewModel.isCameraActive,
                    isDetecting: $cameraViewModel.isDetecting,
                    detectionConfidence: $cameraViewModel.detectionConfidence,
                    onFrameCaptured: { image in
                        cameraViewModel.processFrame(image)
                    }
                )
                .frame(height: 300)
                .cornerRadius(12)
                .padding(.horizontal)
                
                CameraOverlayView(
                    currentAngle: sessionViewModel.currentAngle,
                    isDetecting: cameraViewModel.isDetecting,
                    detectionConfidence: cameraViewModel.detectionConfidence,
                    onTap: { point in
                        // Handle tap to focus
                        Task {
                            await cameraViewModel.setFocusPoint(point)
                        }
                    }
                )
                .frame(height: 300)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Detection Status
            DetectionStatusView()
            
            // Action Buttons
            VStack(spacing: 15) {
                Button(action: {
                    Task {
                        await sessionViewModel.capturePhoto()
                        // Only show photo review for manual capture, not auto-capture
                        if !sessionViewModel.isAutoCaptureEnabled {
                            showingPhotoReview = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Capture Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(sessionViewModel.isLoading || cameraViewModel.isCapturing)
                
                if sessionViewModel.isLoading || cameraViewModel.isCapturing {
                    ProgressView("Processing...")
                }
                
                // Session Actions
                HStack(spacing: 15) {
                    Button("Skip Angle") {
                        sessionViewModel.moveToNextAngle()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Complete Session") {
                        Task {
                            await sessionViewModel.completeSession()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!sessionViewModel.isSessionComplete)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    Task {
                        await sessionViewModel.cancelSession()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingPhotoReview) {
            PhotoReviewSheet()
        }
        .onAppear {
            // Start camera when session view appears
            Task {
                await cameraViewModel.startCamera()
            }
        }
        .onDisappear {
            // Stop camera when session view disappears
            Task {
                await cameraViewModel.stopCamera()
            }
        }
    }
}

struct CameraPreviewPlaceholder: View {
    var body: some View {
        VStack {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("Camera Preview")
                .foregroundColor(.white)
                .font(.headline)
            
            Text("Camera integration coming soon")
                .foregroundColor(.white.opacity(0.7))
                .font(.caption)
        }
    }
}

struct AngleGuidanceView: View {
    let angle: PhotoAngleType
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: angleIcon)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text(guidanceText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    private var angleIcon: String {
        switch angle {
        case .front: return "arrow.up"
        case .rear: return "arrow.down"
        case .leftSide: return "arrow.left"
        case .rightSide: return "arrow.right"
        case .frontLeft: return "arrow.up.left"
        case .frontRight: return "arrow.up.right"
        case .rearLeft: return "arrow.down.left"
        case .rearRight: return "arrow.down.right"
        }
    }
    
    private var guidanceText: String {
        switch angle {
        case .front: return "Position camera to capture the front of the vehicle"
        case .rear: return "Position camera to capture the rear of the vehicle"
        case .leftSide: return "Position camera to capture the left side of the vehicle"
        case .rightSide: return "Position camera to capture the right side of the vehicle"
        case .frontLeft: return "Position camera to capture the front-left angle"
        case .frontRight: return "Position camera to capture the front-right angle"
        case .rearLeft: return "Position camera to capture the rear-left angle"
        case .rearRight: return "Position camera to capture the rear-right angle"
        }
    }
}

struct DetectionStatusView: View {
    @EnvironmentObject var cameraViewModel: CameraViewModel
    
    var body: some View {
        HStack {
            Circle()
                .fill(cameraViewModel.isDetecting ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            Text(cameraViewModel.isDetecting ? "Angle Detected" : "Positioning...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if cameraViewModel.detectionConfidence > 0 {
                Text("\(Int(cameraViewModel.detectionConfidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct PhotoReviewSheet: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var cameraViewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let photo = cameraViewModel.lastCapturedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .padding()
                    
                    VStack(spacing: 15) {
                        Text("Photo Captured")
                            .font(.headline)
                        
                        Text("Angle: \(sessionViewModel.currentAngle.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Button("Retake") {
                                Task {
                                    await sessionViewModel.retakePhoto()
                                    dismiss()
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Keep Photo") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Photo Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SessionSetupView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @State private var vehicleIdentifier = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Start New Photo Session")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Vehicle Identifier")
                    .font(.headline)
                
                TextField("Enter vehicle VIN, license plate, or ID", text: $vehicleIdentifier)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)
            }
            
            Button("Start Session") {
                Task {
                    await sessionViewModel.startNewSession(vehicleIdentifier: vehicleIdentifier)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vehicleIdentifier.isEmpty || sessionViewModel.isLoading)
            
            if sessionViewModel.isLoading {
                ProgressView("Starting session...")
            }
            
            if let errorMessage = sessionViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    let storageService = StorageService(
        persistentContainer: CoreDataStack.shared.persistentContainer,
        fileSystemManager: FileSystemManager()
    )
    let sessionManager = SessionManager(storageService: storageService)
    let cameraService = CameraService()
    let visionService = VisionService()
    let modelManager = ModelManager()
    let cameraViewModel = CameraViewModel(
        cameraService: cameraService,
        visionService: visionService,
        modelManager: modelManager
    )
    let configurationService = ConfigurationService()
    let autoCaptureManager = AutoCaptureManager(
        modelManager: modelManager,
        visionService: visionService,
        cameraService: cameraService,
        storageService: storageService,
        configurationService: configurationService
    )
    let photoSessionManager = PhotoSessionManager(
        autoCaptureManager: autoCaptureManager,
        storageService: storageService,
        configurationService: configurationService
    )
    
    return NavigationView {
        SessionView()
            .environmentObject(SessionViewModel(
                sessionManager: sessionManager,
                storageService: storageService,
                cameraViewModel: cameraViewModel,
                photoSessionManager: photoSessionManager,
                autoCaptureManager: autoCaptureManager
            ))
            .environmentObject(cameraViewModel)
    }
}
