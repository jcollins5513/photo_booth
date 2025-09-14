import SwiftUI

struct SessionView: View {
    var body: some View {
        VStack {
            Text("Photo Session")
                .font(.title)
            
            Text("Session functionality will be implemented in upcoming tasks")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SessionView()
    }
}
