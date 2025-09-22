import SwiftUI
import AVFoundation

/// Automated session view for static camera setup - no user guidance needed
struct AutomatedSessionView: View {
    
    // MARK: - Properties
    @StateObject private var automatedDetector = AutomatedVehicleDetector()
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var sessionViewModel: AutomatedSessionViewModel
    
    // MARK: - State Properties
    @State private var isSessionActive = false
    @State private var capturedPhotos: [UIImage] = []
    @State private var sessionStartTime: Date?
    @State private var showSessionComplete = false
    @State private var sessionStatistics: AutomatedVehicleDetector.SessionStatistics?
    
    // MARK: - Constants
    private let totalPositions = 8
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentContainer, fileSystemManager: FileSystemManagerProtocol) {
        self._sessionViewModel = StateObject(wrappedValue: AutomatedSessionViewModel(persistentContainer: persistentContainer, fileSystemManager: fileSystemManager))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(cameraViewModel: cameraViewModel)
                .ignoresSafeArea()
            
            // Session Status Overlay
            VStack {
                // Top status bar
                sessionStatusView
                
                Spacer()
                
                // Bottom session info
                sessionInfoView
            }
            .padding()
        }
        .onAppear {
            startAutomatedSession()
        }
        .onDisappear {
            stopAutomatedSession()
        }
        .onChange(of: automatedDetector.captureReady) { isReady in
            if isReady {
                capturePhoto()
            }
        }
        .onChange(of: automatedDetector.isSessionComplete()) { isComplete in
            if isComplete {
                completeSession()
            }
        }
        .sheet(isPresented: $showSessionComplete) {
            SessionCompleteView(
                statistics: sessionStatistics,
                capturedPhotos: capturedPhotos
            )
        }
    }
    
    // MARK: - Session Status View
    private var sessionStatusView: some View {
        VStack(spacing: 12) {
            // Session progress
            HStack {
                Text("Vehicle Detection")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(automatedDetector.getCapturedPositions().count)/\(totalPositions)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Progress bar
            ProgressView(value: automatedDetector.getSessionProgress())
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Current status
            HStack {
                // Detection status
                HStack(spacing: 8) {
                    Circle()
                        .fill(automatedDetector.isVehicleInFrame ? .green : .gray)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut, value: automatedDetector.isVehicleInFrame)
                    
                    Text(automatedDetector.isVehicleInFrame ? "Vehicle Detected" : "No Vehicle")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Current position
                if let position = automatedDetector.currentVehiclePosition {
                    Text(position.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Confidence level
                Text("\(Int(automatedDetector.vehicleConfidence * 100))%")
                    .font(.caption)
                    .foregroundColor(confidenceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Session Info View
    private var sessionInfoView: some View {
        VStack(spacing: 16) {
            // Captured positions
            if !automatedDetector.getCapturedPositions().isEmpty {
                capturedPositionsView
            }
            
            // Session controls
            HStack(spacing: 20) {
                // Session status
                VStack(alignment: .leading) {
                    Text("Session Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(sessionStatusText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 16) {
                    if isSessionActive {
                        Button(action: pauseSession) {
                            Image(systemName: "pause.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    } else {
                        Button(action: resumeSession) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
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
        }
    }
    
    // MARK: - Captured Positions View
    private var capturedPositionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured Positions")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(AutomatedVehicleDetector.VehiclePosition.allCases, id: \.self) { position in
                    let isCaptured = automatedDetector.getCapturedPositions().contains(position)
                    
                    VStack(spacing: 4) {
                        Image(systemName: isCaptured ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCaptured ? .green : .gray)
                            .font(.title3)
                        
                        Text(position.displayName)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(8)
                    .background(isCaptured ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var confidenceColor: Color {
        if automatedDetector.vehicleConfidence > 0.8 {
            return .green
        } else if automatedDetector.vehicleConfidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sessionStatusText: String {
        if automatedDetector.isSessionComplete() {
            return "Session Complete"
        } else if automatedDetector.captureReady {
            return "Ready to Capture"
        } else if automatedDetector.isVehicleInFrame {
            return "Vehicle Detected"
        } else {
            return "Waiting for Vehicle"
        }
    }
    
    // MARK: - Session Management
    private func startAutomatedSession() {
        print("🚀 AutomatedSessionView: Starting automated session")
        sessionStartTime = Date()
        isSessionActive = true
        
        Task {
            await sessionViewModel.startSession()
        }
    }
    
    private func stopAutomatedSession() {
        print("🛑 AutomatedSessionView: Stopping automated session")
        isSessionActive = false
        sessionViewModel.endSession()
    }
    
    private func pauseSession() {
        print("⏸️ AutomatedSessionView: Pausing session")
        isSessionActive = false
        sessionViewModel.pauseSession()
    }
    
    private func resumeSession() {
        print("▶️ AutomatedSessionView: Resuming session")
        isSessionActive = true
        sessionViewModel.resumeSession()
    }
    
    private func endSession() {
        print("🛑 AutomatedSessionView: Ending session")
        stopAutomatedSession()
    }
    
    // MARK: - Photo Capture
    private func capturePhoto() {
        print("📸 AutomatedSessionView: Capturing photo")
        
        Task {
            await sessionViewModel.capturePhoto()
        }
    }
    
    private func completeSession() {
        print("🎉 AutomatedSessionView: Session completed")
        sessionStatistics = sessionViewModel.getSessionStatistics()
        showSessionComplete = true
        isSessionActive = false
    }
}

// MARK: - Session Complete View
struct SessionCompleteView: View {
    let statistics: AutomatedVehicleDetector.SessionStatistics?
    let capturedPhotos: [UIImage]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Success message
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Session Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Successfully captured \(capturedPhotos.count) vehicle positions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Statistics
                if let stats = statistics {
                    VStack(spacing: 16) {
                        StatisticRow(title: "Duration", value: formatDuration(stats.duration))
                        StatisticRow(title: "Completion Rate", value: "\(Int(stats.completionRate * 100))%")
                        StatisticRow(title: "Average Confidence", value: "\(Int(stats.averageConfidence * 100))%")
                        StatisticRow(title: "Positions Captured", value: "\(stats.capturedPositions.count)/\(stats.totalPositions)")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Captured positions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Captured Positions")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(statistics?.capturedPositions ?? [], id: \.self) { position in
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                Text(position.displayName)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Start New Session") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Session Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Statistic Row
struct StatisticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview
struct AutomatedSessionView_Previews: PreviewProvider {
    static var previews: some View {
        // Note: This preview won't work without proper initialization
        // In a real app, you would pass the required dependencies
        Text("AutomatedSessionView Preview")
            .preferredColorScheme(.dark)
    }
}
