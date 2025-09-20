import Foundation
import SwiftUI

@MainActor
class GalleryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var photos: [VehiclePhoto] = []
    @Published var sessions: [PhotoSession] = []
    @Published var selectedPhotos: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedSession: PhotoSession?
    @Published var sortOption: SortOption = .dateDescending
    @Published var filterOption: FilterOption = .all
    
    // MARK: - Enums
    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case angle = "By Angle"
        case session = "By Session"
        
        var displayName: String {
            return rawValue
        }
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All Photos"
        case front = "Front"
        case rear = "Rear"
        case leftSide = "Left Side"
        case rightSide = "Right Side"
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"
        
        var displayName: String {
            return rawValue
        }
        
        var angleType: PhotoAngleType? {
            switch self {
            case .all: return nil
            case .front: return .front
            case .rear: return .rear
            case .leftSide: return .leftSide
            case .rightSide: return .rightSide
            case .frontLeft: return .frontLeft
            case .frontRight: return .frontRight
            case .rearLeft: return .rearLeft
            case .rearRight: return .rearRight
            }
        }
    }
    
    // MARK: - Private Properties
    private let storageService: StorageServiceProtocol
    private let sessionManager: SessionManagerProtocol
    
    // MARK: - Computed Properties
    var filteredPhotos: [VehiclePhoto] {
        var filtered = photos
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { photo in
                photo.angle.localizedCaseInsensitiveContains(searchText) ||
                photo.session?.vehicleIdentifier?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply angle filter
        if let angleType = filterOption.angleType {
            filtered = filtered.filter { $0.angle == angleType.rawValue }
        }
        
        // Apply session filter
        if let selectedSession = selectedSession {
            filtered = filtered.filter { $0.session?.id == selectedSession.id }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateDescending:
            filtered = filtered.sorted { $0.timestamp > $1.timestamp }
        case .dateAscending:
            filtered = filtered.sorted { $0.timestamp < $1.timestamp }
        case .angle:
            filtered = filtered.sorted { $0.angle < $1.angle }
        case .session:
            filtered = filtered.sorted { 
                ($0.session?.vehicleIdentifier ?? "") < ($1.session?.vehicleIdentifier ?? "")
            }
        }
        
        return filtered
    }
    
    var groupedPhotos: [String: [VehiclePhoto]] {
        Dictionary(grouping: filteredPhotos) { photo in
            photo.session?.vehicleIdentifier ?? "Unknown Session"
        }
    }
    
    var hasSelectedPhotos: Bool {
        return !selectedPhotos.isEmpty
    }
    
    // MARK: - Initialization
    init(storageService: StorageServiceProtocol, sessionManager: SessionManagerProtocol) {
        self.storageService = storageService
        self.sessionManager = sessionManager
    }
    
    // MARK: - Data Loading
    func loadPhotos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedPhotos = try await storageService.getAllPhotos()
            let loadedSessions = try await sessionManager.getAllSessions()
            
            await MainActor.run {
                self.photos = loadedPhotos
                self.sessions = loadedSessions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func refreshData() async {
        await loadPhotos()
    }
    
    // MARK: - Photo Management
    func deletePhoto(_ photo: VehiclePhoto) async {
        guard let photoId = photo.id else { return }
        
        do {
            try await storageService.deletePhoto(id: UUID(uuidString: photoId)!)
            await MainActor.run {
                self.photos.removeAll { $0.id == photoId }
                self.selectedPhotos.remove(photoId)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func deleteSelectedPhotos() async {
        let photosToDelete = photos.filter { photo in
            guard let photoId = photo.id else { return false }
            return selectedPhotos.contains(photoId)
        }
        
        for photo in photosToDelete {
            await deletePhoto(photo)
        }
        
        selectedPhotos.removeAll()
    }
    
    func exportPhoto(_ photo: VehiclePhoto) async -> Data? {
        guard let photoId = photo.id else { return nil }
        
        do {
            return try await storageService.getPhotoData(id: UUID(uuidString: photoId)!)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return nil
        }
    }
    
    func exportSelectedPhotos() async -> [Data] {
        var exportedData: [Data] = []
        
        for photoId in selectedPhotos {
            if let photo = photos.first(where: { $0.id == photoId }),
               let data = await exportPhoto(photo) {
                exportedData.append(data)
            }
        }
        
        return exportedData
    }
    
    // MARK: - Selection Management
    func selectPhoto(_ photo: VehiclePhoto) {
        guard let photoId = photo.id else { return }
        selectedPhotos.insert(photoId)
    }
    
    func deselectPhoto(_ photo: VehiclePhoto) {
        guard let photoId = photo.id else { return }
        selectedPhotos.remove(photoId)
    }
    
    func togglePhotoSelection(_ photo: VehiclePhoto) {
        guard let photoId = photo.id else { return }
        if selectedPhotos.contains(photoId) {
            deselectPhoto(photo)
        } else {
            selectPhoto(photo)
        }
    }
    
    func selectAllPhotos() {
        selectedPhotos = Set(filteredPhotos.compactMap { $0.id })
    }
    
    func deselectAllPhotos() {
        selectedPhotos.removeAll()
    }
    
    // MARK: - Filtering and Sorting
    func setSortOption(_ option: SortOption) {
        sortOption = option
    }
    
    func setFilterOption(_ option: FilterOption) {
        filterOption = option
    }
    
    func setSelectedSession(_ session: PhotoSession?) {
        selectedSession = session
    }
    
    func clearFilters() {
        searchText = ""
        filterOption = .all
        selectedSession = nil
        sortOption = .dateDescending
    }
    
    // MARK: - Session Management
    func deleteSession(_ session: PhotoSession) async {
        guard let sessionId = session.id else { return }
        
        do {
            // First delete all photos in the session
            let sessionPhotos = photos.filter { $0.session?.id == sessionId }
            for photo in sessionPhotos {
                guard let photoId = photo.id else { continue }
                try await storageService.deletePhoto(id: UUID(uuidString: photoId)!)
            }
            
            // Then delete the session
            _ = try await sessionManager.cancelSession(id: UUID(uuidString: sessionId)!)
            
            await MainActor.run {
                self.photos.removeAll { $0.session?.id == sessionId }
                self.sessions.removeAll { $0.id == sessionId }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Helper Methods
    func clearError() {
        errorMessage = nil
    }
    
    func getPhotosForSession(_ session: PhotoSession) -> [VehiclePhoto] {
        guard let sessionId = session.id else { return [] }
        return photos.filter { $0.session?.id == sessionId }
    }
    
    func getSessionForPhoto(_ photo: VehiclePhoto) -> PhotoSession? {
        guard let photoSessionId = photo.session?.id else { return nil }
        return sessions.first { $0.id == photoSessionId }
    }
}
