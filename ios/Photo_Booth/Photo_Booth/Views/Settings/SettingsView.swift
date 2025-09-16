import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // User Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User Account")
                                .font(.headline)
                            
                            if let userEmail = authenticationViewModel.userEmail {
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // App Information
                Section("App Information") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.green)
                        Text("Total Photos")
                        Spacer()
                        Text("\(galleryViewModel.photos.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.orange)
                        Text("Total Sessions")
                        Spacer()
                        Text("\(galleryViewModel.sessions.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data Management
                Section("Data Management") {
                    Button(action: {
                        Task {
                            await galleryViewModel.refreshData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Refresh Data")
                        }
                    }
                    
                    Button(action: {
                        // TODO: Implement data export
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.green)
                            Text("Export All Data")
                        }
                    }
                    
                    Button(action: {
                        // TODO: Implement data clear
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Data")
                        }
                    }
                }
                
                // Session Management
                if sessionViewModel.isSessionActive {
                    Section("Active Session") {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Current Session")
                                    .font(.headline)
                                Text(sessionViewModel.vehicleIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(sessionViewModel.sessionProgress * 100))%")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            Task {
                                await sessionViewModel.cancelSession()
                            }
                        }) {
                            HStack {
                                Image(systemName: "stop.circle")
                                    .foregroundColor(.red)
                                Text("Cancel Session")
                            }
                        }
                    }
                }
                
                // Account Actions
                Section("Account") {
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authenticationViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationViewModel(authenticationService: AuthenticationService()))
        .environmentObject(SessionViewModel(sessionManager: SessionManager(), storageService: StorageService(), cameraViewModel: CameraViewModel(cameraService: CameraService(), visionService: VisionService())))
        .environmentObject(GalleryViewModel(storageService: StorageService(), sessionManager: SessionManager()))
}
