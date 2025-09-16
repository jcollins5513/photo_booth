import SwiftUI

struct SessionSetupSheet: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var vehicleIdentifier = ""
    @State private var totalAngles = 8
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Start New Photo Session")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Capture comprehensive vehicle photos from multiple angles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 20) {
                    // Vehicle Identifier
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vehicle Identifier")
                            .font(.headline)
                        
                        TextField("Enter VIN, license plate, or ID", text: $vehicleIdentifier)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        Text("This helps identify and organize your photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Photo Count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Photos")
                            .font(.headline)
                        
                        HStack {
                            Stepper(value: $totalAngles, in: 4...12) {
                                Text("\(totalAngles) photos")
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                        }
                        
                        Text("Standard: 8 photos (all angles)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Advanced Options
                    Button(action: {
                        showingAdvancedOptions.toggle()
                    }) {
                        HStack {
                            Text("Advanced Options")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if showingAdvancedOptions {
                        VStack(spacing: 15) {
                            // Auto-capture toggle
                            Toggle("Enable Auto-Capture", isOn: .constant(true))
                                .disabled(true) // Always enabled for now
                            
                            // Quality setting
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Photo Quality")
                                    .font(.subheadline)
                                
                                Picker("Quality", selection: .constant(PhotoQuality.high)) {
                                    Text("High").tag(PhotoQuality.high)
                                    Text("Medium").tag(PhotoQuality.medium)
                                    Text("Low").tag(PhotoQuality.low)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: {
                        Task {
                            await sessionViewModel.startNewSession(
                                vehicleIdentifier: vehicleIdentifier,
                                totalAngles: totalAngles
                            )
                            if sessionViewModel.isSessionActive {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Session")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(vehicleIdentifier.isEmpty || sessionViewModel.isLoading)
                    
                    if sessionViewModel.isLoading {
                        ProgressView("Starting session...")
                    }
                    
                    if let errorMessage = sessionViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Quality Enum
enum PhotoQuality: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Preview
#Preview {
    SessionSetupSheet()
        .environmentObject(SessionViewModel(
            sessionManager: SessionManager(storageService: StorageService(
                persistentContainer: CoreDataStack.shared.container,
                fileSystemManager: FileSystemManager()
            )),
            storageService: StorageService(
                persistentContainer: CoreDataStack.shared.container,
                fileSystemManager: FileSystemManager()
            ),
            cameraViewModel: CameraViewModel(
                cameraService: CameraService(),
                visionService: VisionService()
            )
        ))
}
