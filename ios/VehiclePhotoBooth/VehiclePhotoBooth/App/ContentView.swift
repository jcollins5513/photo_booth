import SwiftUI

struct ContentView: View {
    @StateObject private var authenticationViewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if authenticationViewModel.isAuthenticated {
                DashboardView()
            } else {
                AuthenticationView()
            }
        }
        .environmentObject(authenticationViewModel)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
