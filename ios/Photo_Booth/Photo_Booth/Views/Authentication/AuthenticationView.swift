import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authenticationViewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUpMode = false
    @State private var showPasswordReset = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Vehicle Photo Booth")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Automated vehicle photography made simple")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if isSignUpMode {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        Button(isSignUpMode ? "Sign Up" : "Sign In") {
                            if isSignUpMode {
                                authenticationViewModel.signUp(
                                    email: email,
                                    password: password,
                                    confirmPassword: confirmPassword
                                )
                            } else {
                                authenticationViewModel.signIn(
                                    email: email,
                                    password: password
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(authenticationViewModel.isLoading || !isFormValid)
                        .frame(maxWidth: .infinity)
                        
                        if !isSignUpMode {
                            Button("Forgot Password?") {
                                showPasswordReset = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                            withAnimation {
                                isSignUpMode.toggle()
                                clearForm()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Loading and Error States
                    if authenticationViewModel.isLoading {
                        ProgressView("Please wait...")
                            .padding()
                    }
                    
                    if let errorMessage = authenticationViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .alert("Reset Password", isPresented: $showPasswordReset) {
            TextField("Email", text: $email)
            Button("Send Reset Email") {
                authenticationViewModel.resetPassword(email: email)
                showPasswordReset = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your email address to receive password reset instructions.")
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        if isSignUpMode {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   password == confirmPassword &&
                   password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    // MARK: - Helper Methods
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        authenticationViewModel.clearError()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationViewModel(authenticationService: AuthenticationService()))
}
