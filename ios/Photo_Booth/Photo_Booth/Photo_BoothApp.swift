//
//  Photo_BoothApp.swift
//  Photo_Booth
//
//  Created by Justin Collins on 9/15/25.
//

import SwiftUI

@main
struct Photo_BoothApp: App {
    @StateObject private var authenticationViewModel = AuthenticationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authenticationViewModel)
        }
    }
}
