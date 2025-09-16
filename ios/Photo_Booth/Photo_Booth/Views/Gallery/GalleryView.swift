import SwiftUI

struct GalleryView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @State private var selectedViewMode: ViewMode = .grid
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedPhoto: VehiclePhoto?
    @State private var isSelectionMode = false
    
    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        case sessions = "Sessions"
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            case .sessions: return "camera.viewfinder"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 10) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search photos...", text: $galleryViewModel.searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        Button(action: { showingFilters.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Filter and Sort Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(
                                title: galleryViewModel.filterOption.displayName,
                                isSelected: galleryViewModel.filterOption != .all,
                                action: { showingFilters.toggle() }
                            )
                            
                            FilterChip(
                                title: galleryViewModel.sortOption.displayName,
                                isSelected: galleryViewModel.sortOption != .dateDescending,
                                action: { showingSortOptions.toggle() }
                            )
                            
                            if galleryViewModel.selectedSession != nil {
                                FilterChip(
                                    title: "Session Filter",
                                    isSelected: true,
                                    action: { galleryViewModel.setSelectedSession(nil) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Content
                if galleryViewModel.isLoading {
                    Spacer()
                    ProgressView("Loading photos...")
                    Spacer()
                } else if galleryViewModel.filteredPhotos.isEmpty {
                    EmptyGalleryView()
                } else {
                    switch selectedViewMode {
                    case .grid:
                        PhotoGridView(
                            photos: galleryViewModel.filteredPhotos,
                            selectedPhotos: $galleryViewModel.selectedPhotos,
                            isSelectionMode: $isSelectionMode,
                            onPhotoSelected: { selectedPhoto = $0 }
                        )
                    case .list:
                        PhotoListView(
                            photos: galleryViewModel.filteredPhotos,
                            selectedPhotos: $galleryViewModel.selectedPhotos,
                            isSelectionMode: $isSelectionMode,
                            onPhotoSelected: { selectedPhoto = $0 }
                        )
                    case .sessions:
                        SessionsView(
                            sessions: galleryViewModel.sessions,
                            onSessionSelected: { session in
                                galleryViewModel.setSelectedSession(session)
                                selectedViewMode = .grid
                            }
                        )
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // View Mode Picker
                    Picker("View Mode", selection: $selectedViewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Selection Mode Toggle
                    if !galleryViewModel.filteredPhotos.isEmpty {
                        Button(isSelectionMode ? "Done" : "Select") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                galleryViewModel.deselectAllPhotos()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet()
            }
            .sheet(isPresented: $showingSortOptions) {
                SortSheet()
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
            .confirmationDialog("Selected Photos", isPresented: $isSelectionMode) {
                Button("Delete Selected") {
                    Task {
                        await galleryViewModel.deleteSelectedPhotos()
                        isSelectionMode = false
                    }
                }
                Button("Export Selected") {
                    Task {
                        let _ = await galleryViewModel.exportSelectedPhotos()
                        isSelectionMode = false
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .task {
            await galleryViewModel.loadPhotos()
        }
        .refreshable {
            await galleryViewModel.refreshData()
        }
    }
}

struct PhotoGridView: View {
    let photos: [VehiclePhoto]
    @Binding var selectedPhotos: Set<UUID>
    @Binding var isSelectionMode: Bool
    let onPhotoSelected: (VehiclePhoto) -> Void
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos, id: \.id) { photo in
                    PhotoGridItem(
                        photo: photo,
                        isSelected: selectedPhotos.contains(photo.id ?? UUID()),
                        isSelectionMode: isSelectionMode,
                        onTap: {
                            if isSelectionMode {
                                galleryViewModel.togglePhotoSelection(photo)
                            } else {
                                onPhotoSelected(photo)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PhotoListView: View {
    let photos: [VehiclePhoto]
    @Binding var selectedPhotos: Set<UUID>
    @Binding var isSelectionMode: Bool
    let onPhotoSelected: (VehiclePhoto) -> Void
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    var body: some View {
        List {
            ForEach(photos, id: \.id) { photo in
                PhotoListItem(
                    photo: photo,
                    isSelected: selectedPhotos.contains(photo.id ?? UUID()),
                    isSelectionMode: isSelectionMode,
                    onTap: {
                        if isSelectionMode {
                            galleryViewModel.togglePhotoSelection(photo)
                        } else {
                            onPhotoSelected(photo)
                        }
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct PhotoGridItem: View {
    let photo: VehiclePhoto
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .blue : .white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(8)
    }
}

struct PhotoListItem: View {
    let photo: VehiclePhoto
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.angle.capitalized)
                        .font(.headline)
                    
                    Text(photo.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let session = photo.session {
                        Text(session.vehicleIdentifier ?? "Unknown Vehicle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyGalleryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a photo session to capture vehicle photos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct FilterSheet: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Filter by Angle") {
                    ForEach(GalleryViewModel.FilterOption.allCases, id: \.self) { option in
                        Button(action: {
                            galleryViewModel.setFilterOption(option)
                            dismiss()
                        }) {
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if galleryViewModel.filterOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Photos")
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

struct SortSheet: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Sort by") {
                    ForEach(GalleryViewModel.SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            galleryViewModel.setSortOption(option)
                            dismiss()
                        }) {
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if galleryViewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort Photos")
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

struct PhotoDetailView: View {
    let photo: VehiclePhoto
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Photo placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(4/3, contentMode: .fit)
                    .cornerRadius(12)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Photo Details")
                        .font(.headline)
                    
                    DetailRow(title: "Angle", value: photo.angle.capitalized)
                    DetailRow(title: "Date", value: photo.timestamp.formatted())
                    
                    if let session = photo.session {
                        DetailRow(title: "Vehicle", value: session.vehicleIdentifier ?? "Unknown Vehicle")
                        DetailRow(title: "Session", value: (session.id?.uuidString.prefix(8) ?? "Unknown") + "...")
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Photo Detail")
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

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

struct SessionsView: View {
    let sessions: [PhotoSession]
    let onSessionSelected: (PhotoSession) -> Void
    
    var body: some View {
        List {
            ForEach(sessions, id: \.id) { session in
                Button(action: { onSessionSelected(session) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.vehicleIdentifier ?? "Unknown Vehicle")
                                .font(.headline)
                            
                            Text(session.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(SessionStatus(rawValue: session.status ?? "unknown")?.displayName ?? "Unknown")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(statusColor(SessionStatus(rawValue: session.status ?? "unknown") ?? .cancelled).opacity(0.2))
                                .foregroundColor(statusColor(SessionStatus(rawValue: session.status ?? "unknown") ?? .cancelled))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .active: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .paused: return .orange
        }
    }
}

#Preview {
    GalleryView()
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
}
