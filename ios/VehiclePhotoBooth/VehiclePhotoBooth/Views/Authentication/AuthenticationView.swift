import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Vehicle Photo Booth")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Sign In") {
                authenticationViewModel.signIn(email: email, password: password)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authenticationViewModel.isLoading)
            
            if authenticationViewModel.isLoading {
                ProgressView()
            }
            
            if let errorMessage = authenticationViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationViewModel())
}
