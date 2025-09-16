import Foundation
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userEmail: String?
    
    // MARK: - Private Properties
    private let authenticationService: AuthenticationServiceProtocol
    
    // MARK: - Initialization
    init(authenticationService: AuthenticationServiceProtocol) {
        self.authenticationService = authenticationService
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await authenticationService.signIn(email: email, password: password)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.userEmail = user.email
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func signUp(email: String, password: String, confirmPassword: String) {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await authenticationService.signUp(email: email, password: password)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.userEmail = user.email
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await authenticationService.signOut()
                await MainActor.run {
                    self.isAuthenticated = false
                    self.userEmail = nil
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func resetPassword(email: String) {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authenticationService.resetPassword(email: email)
                await MainActor.run {
                    self.errorMessage = "Password reset email sent"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func checkAuthenticationStatus() {
        Task {
            let isAuth = await authenticationService.isAuthenticated()
            await MainActor.run {
                self.isAuthenticated = isAuth
                if isAuth {
                    // Get current user info if authenticated
                    Task {
                        if let user = try? await authenticationService.getCurrentUser() {
                            await MainActor.run {
                                self.userEmail = user.email
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    func clearError() {
        errorMessage = nil
    }
}
