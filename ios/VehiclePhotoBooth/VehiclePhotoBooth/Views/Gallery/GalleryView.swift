import SwiftUI

struct GalleryView: View {
    var body: some View {
        VStack {
            Text("Photo Gallery")
                .font(.title)
            
            Text("Gallery functionality will be implemented in upcoming tasks")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        GalleryView()
    }
}
