import SwiftUI
import AVFoundation
import CoreData

/// Enhanced session view with improved user guidance and feedback
struct EnhancedSessionView: View {
    
    // MARK: - Properties
    @StateObject private var sessionViewModel: EnhancedSessionViewModel
    @StateObject private var enhancedVisionService = EnhancedVisionService()
    @StateObject private var cameraService = CameraService()
    @StateObject private var cameraViewModel: CameraViewModel
    
    // MARK: - State Properties
    @State private var isSessionActive = false
    @State private var currentPhotoIndex = 0
    @State private var capturedPhotos: [UIImage] = []
    @State private var showPhotoReview = false
    @State private var currentPhoto: UIImage?
    @State private var showGuidanceOverlay = true
    @State private var guidanceOpacity: Double = 1.0
    
    // MARK: - Constants
    private let totalPhotos = 8
    private let guidanceAnimationDuration: Double = 0.3
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentContainer, fileSystemManager: FileSystemManagerProtocol) {
        self._sessionViewModel = StateObject(wrappedValue: EnhancedSessionViewModel(persistentContainer: persistentContainer, fileSystemManager: fileSystemManager))
        
        // Initialize camera view model with the services
        self._cameraViewModel = StateObject(wrappedValue: CameraViewModel(cameraService: cameraService, visionService: enhancedVisionService))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(
                isActive: $isSessionActive,
                isDetecting: $sessionViewModel.isProcessing,
                detectionConfidence: $sessionViewModel.sessionProgress,
                onFrameCaptured: { image in
                    // Handle frame capture
                    cameraViewModel.processFrame(image)
                }
            )
            .ignoresSafeArea()
            
            // Enhanced Guidance Overlay
            if showGuidanceOverlay {
                guidanceOverlayView
                    .opacity(guidanceOpacity)
                    .animation(.easeInOut(duration: guidanceAnimationDuration), value: guidanceOpacity)
            }
            
            // Session Controls
            VStack {
                Spacer()
                sessionControlsView
            }
            .padding()
        }
        .onAppear {
            setupSession()
        }
        .onDisappear {
            cleanupSession()
        }
        .onChange(of: enhancedVisionService.isPositionValid) { _, isValid in
            handlePositionValidation(isValid)
        }
        .onChange(of: enhancedVisionService.guidanceType) { _, guidanceType in
            updateGuidanceDisplay(guidanceType)
        }
    }
    
    // MARK: - Guidance Overlay View
    private var guidanceOverlayView: some View {
        VStack {
            // Top guidance area
            VStack(spacing: 16) {
                // Current angle and confidence
                HStack {
                    VStack(alignment: .leading) {
                        Text(enhancedVisionService.currentAngle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Confidence: \(Int(enhancedVisionService.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Quality indicator
                    qualityIndicatorView
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                
                // Guidance message
                if !enhancedVisionService.guidanceMessage.isEmpty {
                    Text(enhancedVisionService.guidanceMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(guidanceBackgroundColor)
                        .cornerRadius(12)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)
            
            Spacer()
            
            // Positioning guides
            positioningGuidesView
        }
    }
    
    // MARK: - Quality Indicator View
    private var qualityIndicatorView: some View {
        HStack(spacing: 8) {
            Image(systemName: qualityIcon)
                .foregroundColor(qualityColor)
                .font(.title2)
            
            Text("\(Int(enhancedVisionService.imageQuality * 100))%")
                .font(.caption)
                .foregroundColor(qualityColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(qualityColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Positioning Guides View
    private var positioningGuidesView: some View {
        VStack(spacing: 20) {
            // Current photo progress
            HStack {
                ForEach(0..<totalPhotos, id: \.self) { index in
                    Circle()
                        .fill(index < currentPhotoIndex ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(index == currentPhotoIndex ? 1.2 : 1.0)
                        .animation(.easeInOut, value: currentPhotoIndex)
                }
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            
            // Angle-specific positioning guide
            if let currentAngle = getCurrentTargetAngle() {
                anglePositioningGuide(for: currentAngle)
            }
        }
        .padding(.bottom, 100)
    }
    
    // MARK: - Angle Positioning Guide
    private func anglePositioningGuide(for angle: PhotoAngleType) -> some View {
        VStack(spacing: 12) {
            Text("Position for \(angle.displayName)")
                .font(.headline)
                .foregroundColor(.white)
            
            // Visual guide based on angle
            Group {
                switch angle {
                case .front:
                    frontPositioningGuide
                case .frontRight:
                    frontRightPositioningGuide
                case .rightSide:
                    rightSidePositioningGuide
                case .rearLeft:
                    rearLeftPositioningGuide
                case .rear:
                    rearPositioningGuide
                case .rearRight:
                    rearRightPositioningGuide
                case .leftSide:
                    leftSidePositioningGuide
                case .frontLeft:
                    frontLeftPositioningGuide
                }
            }
            .frame(width: 200, height: 120)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Positioning Guide Views
    private var frontPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
            Text("Front View")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var frontRightPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(45))
            Text("Front Right")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var rightSidePositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(90))
            Text("Right Side")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var rearLeftPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(135))
            Text("Rear Left")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var rearPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(180))
            Text("Rear View")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var rearRightPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(225))
            Text("Rear Right")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var leftSidePositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(270))
            Text("Left Side")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var frontLeftPositioningGuide: some View {
        VStack {
            Text("🚗")
                .font(.system(size: 40))
                .rotationEffect(.degrees(315))
            Text("Front Left")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Session Controls View
    private var sessionControlsView: some View {
        VStack(spacing: 20) {
            // Session status
            HStack {
                VStack(alignment: .leading) {
                    Text("Session Progress")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(currentPhotoIndex)/\(totalPhotos) photos")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Session control buttons
                HStack(spacing: 16) {
                    Button(action: pauseSession) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: endSession) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            
            // Capture button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(enhancedVisionService.isPositionValid ? Color.green : Color.gray)
                        .frame(width: 80, height: 80)
                    
                    if enhancedVisionService.isPositionValid {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "camera")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .disabled(!enhancedVisionService.isPositionValid)
            .scaleEffect(enhancedVisionService.isPositionValid ? 1.1 : 1.0)
            .animation(.easeInOut, value: enhancedVisionService.isPositionValid)
        }
    }
    
    // MARK: - Computed Properties
    private var qualityIcon: String {
        if enhancedVisionService.imageQuality > 0.7 {
            return "checkmark.circle.fill"
        } else if enhancedVisionService.imageQuality > 0.4 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var qualityColor: Color {
        if enhancedVisionService.imageQuality > 0.7 {
            return .green
        } else if enhancedVisionService.imageQuality > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var guidanceBackgroundColor: Color {
        switch enhancedVisionService.guidanceType {
        case .success:
            return .green.opacity(0.8)
        case .quality:
            return .orange.opacity(0.8)
        case .angle:
            return .blue.opacity(0.8)
        case .positioning:
            return .purple.opacity(0.8)
        case .error:
            return .red.opacity(0.8)
        case .none:
            return .black.opacity(0.6)
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentTargetAngle() -> PhotoAngleType? {
        let angles: [PhotoAngleType] = [.front, .frontRight, .rightSide, .rearLeft, .rear, .rearRight, .leftSide, .frontLeft]
        return currentPhotoIndex < angles.count ? angles[currentPhotoIndex] : nil
    }
    
    private func setupSession() {
        Task {
            do {
                try await enhancedVisionService.loadModel()
                await cameraViewModel.startCamera()
                isSessionActive = true
                print("✅ EnhancedSessionView: Session started successfully")
            } catch {
                print("❌ EnhancedSessionView: Failed to start session - \(error)")
            }
        }
    }
    
    private func cleanupSession() {
        isSessionActive = false
        Task {
            await cameraViewModel.stopCamera()
        }
        enhancedVisionService.stopContinuousClassification()
    }
    
    private func handlePositionValidation(_ isValid: Bool) {
        if isValid {
            // Provide success feedback
            provideSuccessFeedback()
        }
    }
    
    private func updateGuidanceDisplay(_ guidanceType: EnhancedVisionService.GuidanceType) {
        withAnimation(.easeInOut(duration: guidanceAnimationDuration)) {
            switch guidanceType {
            case .success:
                guidanceOpacity = 1.0
            case .quality, .angle, .positioning:
                guidanceOpacity = 0.9
            case .error:
                guidanceOpacity = 0.8
            case .none:
                guidanceOpacity = 0.0
            }
        }
    }
    
    private func capturePhoto() {
        guard enhancedVisionService.isPositionValid else { return }
        
        Task {
            await cameraViewModel.capturePhoto()
            if let photo = cameraViewModel.lastCapturedPhoto {
                capturedPhotos.append(photo)
            }
            currentPhotoIndex += 1
            
            // Provide capture feedback
            provideCaptureFeedback()
            
            // Check if session is complete
            if currentPhotoIndex >= totalPhotos {
                completeSession()
            }
        }
    }
    
    private func pauseSession() {
        isSessionActive = false
        // Camera pause not implemented in CameraViewModel
        enhancedVisionService.stopContinuousClassification()
    }
    
    private func endSession() {
        isSessionActive = false
        Task {
            await cameraViewModel.stopCamera()
        }
        enhancedVisionService.stopContinuousClassification()
        // Navigate back or show results
    }
    
    private func completeSession() {
        print("✅ EnhancedSessionView: Session completed with \(capturedPhotos.count) photos")
        // Handle session completion
    }
    
    private func provideSuccessFeedback() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func provideCaptureFeedback() {
        // Haptic feedback for capture
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Visual feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            // Flash effect or other visual feedback
        }
    }
}

// MARK: - Preview
struct EnhancedSessionView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview requires Core Data setup - commented out for now
        Text("EnhancedSessionView Preview")
            .preferredColorScheme(.dark)
    }
}
