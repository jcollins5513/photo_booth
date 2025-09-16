//
//  ContentView.swift
//  Photo_Booth
//
//  Created by Justin Collins on 9/15/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    
    var body: some View {
        Group {
            if authenticationViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authenticationViewModel.isAuthenticated)
        .task {
            if authenticationViewModel.isAuthenticated {
                await galleryViewModel.loadPhotos()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            CameraTabView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Camera")
                }
                .tag(1)
            
            GalleryView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Gallery")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

struct CameraTabView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var cameraViewModel: CameraViewModel
    
    var body: some View {
        NavigationView {
            if sessionViewModel.isSessionActive {
                SessionView()
            } else {
                SessionSetupView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationViewModel(authenticationService: AuthenticationService()))
        .environmentObject(SessionViewModel(sessionManager: SessionManager(), storageService: StorageService(), cameraViewModel: CameraViewModel(cameraService: CameraService(), visionService: VisionService())))
        .environmentObject(GalleryViewModel(storageService: StorageService(), sessionManager: SessionManager()))
}
