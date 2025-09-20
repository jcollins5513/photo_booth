//
//  Photo_BoothApp.swift
//  Photo_Booth
//
//  Created by Justin Collins on 9/15/25.
//

import SwiftUI
import Firebase

@main
struct Photo_BoothApp: App {
    // MARK: - Services
    private let authenticationService = FirebaseAuthenticationService()
    private let cameraService = CameraService()
    private let visionService = VisionService()
    private let storageService: StorageService
    private let sessionManager: SessionManager
    private let modelManager = ModelManager()
    
    // MARK: - ViewModels
    @StateObject private var authenticationViewModel: AuthenticationViewModel
    @StateObject private var cameraViewModel: CameraViewModel
    @StateObject private var sessionViewModel: SessionViewModel
    @StateObject private var galleryViewModel: GalleryViewModel
    
    init() {
        // Configure Firebase using the configuration manager
        FirebaseConfigurationManager.shared.configure()
        
        // Initialize services with proper dependencies
        let coreDataStack = CoreDataStack.shared
        self.storageService = StorageService(
            persistentContainer: coreDataStack.container,
            fileSystemManager: FileSystemManager()
        )
        self.sessionManager = SessionManager(storageService: storageService)
        
        // Initialize additional services
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
        
        // Initialize ViewModels with services
        let authVM = AuthenticationViewModel(authenticationService: authenticationService)
        let cameraVM = CameraViewModel(cameraService: cameraService, visionService: visionService, modelManager: modelManager)
        let sessionVM = SessionViewModel(
            sessionManager: sessionManager, 
            storageService: storageService, 
            cameraViewModel: cameraVM,
            photoSessionManager: photoSessionManager,
            autoCaptureManager: autoCaptureManager
        )
        let galleryVM = GalleryViewModel(storageService: storageService, sessionManager: sessionManager)
        
        _authenticationViewModel = StateObject(wrappedValue: authVM)
        _cameraViewModel = StateObject(wrappedValue: cameraVM)
        _sessionViewModel = StateObject(wrappedValue: sessionVM)
        _galleryViewModel = StateObject(wrappedValue: galleryVM)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authenticationViewModel)
                .environmentObject(cameraViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(galleryViewModel)
        }
    }
}
