//
//  Photo_BoothApp.swift
//  Photo_Booth
//
//  Created by Justin Collins on 9/15/25.
//

import SwiftUI

@main
struct Photo_BoothApp: App {
    // MARK: - Services
    private let authenticationService = AuthenticationService()
    private let cameraService = CameraService()
    private let visionService = VisionService()
    private let storageService = StorageService()
    private let sessionManager = SessionManager()
    
    // MARK: - ViewModels
    @StateObject private var authenticationViewModel: AuthenticationViewModel
    @StateObject private var cameraViewModel: CameraViewModel
    @StateObject private var sessionViewModel: SessionViewModel
    @StateObject private var galleryViewModel: GalleryViewModel
    
    init() {
        // Initialize ViewModels with services
        let authVM = AuthenticationViewModel(authenticationService: authenticationService)
        let cameraVM = CameraViewModel(cameraService: cameraService, visionService: visionService)
        let sessionVM = SessionViewModel(sessionManager: sessionManager, storageService: storageService, cameraViewModel: cameraVM)
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
