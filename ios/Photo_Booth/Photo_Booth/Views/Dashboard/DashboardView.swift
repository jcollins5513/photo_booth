import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Welcome to Vehicle Photo Booth")
                    .font(.title)
                    .multilineTextAlignment(.center)
                
                NavigationLink(destination: SessionView()) {
                    Label("Start New Session", systemImage: "camera")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: GalleryView()) {
                    Label("View Gallery", systemImage: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    DashboardView()
}
