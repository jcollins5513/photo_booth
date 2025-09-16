//
//  ContentView.swift
//  Photo_Booth
//
//  Created by Justin Collins on 9/15/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    
    var body: some View {
        Group {
            if authenticationViewModel.isAuthenticated {
                DashboardView()
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authenticationViewModel.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationViewModel())
}
