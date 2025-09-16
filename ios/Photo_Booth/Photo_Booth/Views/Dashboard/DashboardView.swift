import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    @State private var showingSessionSetup = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Welcome to Vehicle Photo Booth")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if let userEmail = authenticationViewModel.userEmail {
                            Text("Hello, \(userEmail)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Quick Stats
                    if !galleryViewModel.photos.isEmpty {
                        StatsCardView()
                    }
                    
                    // Main Actions
                    VStack(spacing: 20) {
                        Button(action: {
                            showingSessionSetup = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("Start New Session")
                                        .font(.headline)
                                    Text("Capture vehicle photos")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
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
                        
                        Button(action: {
                            // Switch to gallery tab
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("View Gallery")
                                        .font(.headline)
                                    Text("Browse captured photos")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    
                    // Recent Sessions
                    if !galleryViewModel.sessions.isEmpty {
                        RecentSessionsView()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await galleryViewModel.refreshData()
            }
        }
        .sheet(isPresented: $showingSessionSetup) {
            SessionSetupSheet()
        }
    }
}

struct StatsCardView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Stats")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                StatItemView(
                    title: "Total Photos",
                    value: "\(galleryViewModel.photos.count)",
                    icon: "photo.fill",
                    color: .blue
                )
                
                StatItemView(
                    title: "Sessions",
                    value: "\(galleryViewModel.sessions.count)",
                    icon: "camera.fill",
                    color: .green
                )
                
                StatItemView(
                    title: "This Week",
                    value: "\(recentPhotosCount)",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentPhotosCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return galleryViewModel.photos.filter { $0.timestamp > weekAgo }.count
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentSessionsView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(galleryViewModel.sessions.prefix(3), id: \.id) { session in
                SessionRowView(session: session)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SessionRowView: View {
    let session: PhotoSession
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.vehicleIdentifier ?? "Unknown Vehicle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(galleryViewModel.getPhotosForSession(session).count) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(SessionStatus(rawValue: session.status ?? "unknown")?.displayName ?? "Unknown")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch SessionStatus(rawValue: session.status ?? "unknown") {
        case .active: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .paused: return .orange
        case .none: return .gray
        }
    }
}


#Preview {
    DashboardView()
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
        .environmentObject(GalleryViewModel(
            storageService: StorageService(
                persistentContainer: CoreDataStack.shared.container,
                fileSystemManager: FileSystemManager()
            ),
            sessionManager: SessionManager(storageService: StorageService(
                persistentContainer: CoreDataStack.shared.container,
                fileSystemManager: FileSystemManager()
            ))
        ))
        .environmentObject(AuthenticationViewModel(authenticationService: AuthenticationService()))
}
