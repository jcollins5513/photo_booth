import Foundation

/// Authentication service implementation
class AuthenticationService: AuthenticationServiceProtocol {
    
    // MARK: - Properties
    
    private var currentUser: User?
    private var isSignedIn: Bool = false
    
    // MARK: - User Registration
    
    func registerUser(email: String, password: String) async throws -> User {
        return try await signUp(email: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws -> User {
        // Validate email format
        guard isValidEmail(email) else {
            throw AuthenticationServiceError.invalidEmail
        }
        
        // Validate password strength
        guard isStrongPassword(password) else {
            throw AuthenticationServiceError.weakPassword
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check if email already exists (mock check)
        if email == "existing@example.com" {
            throw AuthenticationServiceError.emailAlreadyExists
        }
        
        // Simulate registration success
        let user = User(
            id: UUID().uuidString,
            email: email,
            idToken: generateMockToken(),
            refreshToken: generateMockRefreshToken()
        )
        
        // Set as current user
        currentUser = user
        isSignedIn = true
        
        return user
    }
    
    // MARK: - User Sign In
    
    func signIn(email: String, password: String) async throws -> User {
        // Validate email format
        guard isValidEmail(email) else {
            throw AuthenticationServiceError.invalidEmail
        }
        
        // Validate password is not empty
        guard !password.isEmpty else {
            throw AuthenticationServiceError.invalidCredentials
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        
        // Mock authentication logic
        if email == "test@example.com" && password == "password123" {
            let user = User(
                id: UUID().uuidString,
                email: email,
                idToken: generateMockToken(),
                refreshToken: generateMockRefreshToken(),
                lastSignIn: Date()
            )
            
            currentUser = user
            isSignedIn = true
            
            return user
        } else if email == "nonexistent@example.com" {
            throw AuthenticationServiceError.userNotFound
        } else {
            throw AuthenticationServiceError.invalidCredentials
        }
    }
    
    // MARK: - User Sign Out
    
    func signOut() async throws {
        guard isSignedIn else {
            throw AuthenticationServiceError.notSignedIn
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        
        // Clear current user
        currentUser = nil
        isSignedIn = false
    }
    
    // MARK: - User State
    
    func getCurrentUser() -> User? {
        return currentUser
    }
    
    func isUserSignedIn() -> Bool {
        return isSignedIn && currentUser != nil
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        // Validate email format
        guard isValidEmail(email) else {
            throw AuthenticationServiceError.invalidEmail
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Simulate password reset email sent
        print("Password reset email sent to: \(email)")
    }
    
    func resetPassword(email: String) async throws {
        try await sendPasswordReset(email: email)
    }
    
    func isAuthenticated() async -> Bool {
        return isUserSignedIn()
    }
    
    // MARK: - Token Management
    
    func refreshToken() async throws -> String {
        guard let user = currentUser, isSignedIn else {
            throw AuthenticationServiceError.notSignedIn
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 250_000_000) // 0.25 second delay
        
        // Generate new token
        let newToken = generateMockToken()
        
        // Update current user with new token
        let updatedUser = User(
            id: user.id,
            email: user.email,
            idToken: newToken,
            refreshToken: user.refreshToken,
            createdAt: user.createdAt,
            lastSignIn: user.lastSignIn
        )
        
        currentUser = updatedUser
        
        return newToken
    }
    
    // MARK: - Account Management
    
    func deleteAccount() async throws {
        guard currentUser != nil, isSignedIn else {
            throw AuthenticationServiceError.notSignedIn
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 second delay
        
        // Clear current user
        currentUser = nil
        isSignedIn = false
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        // Password must be at least 8 characters long
        return password.count >= 8
    }
    
    private func generateMockToken() -> String {
        // Generate a mock JWT-like token
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
        let signature = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        return "\(header).\(payload).\(signature)"
    }
    
    private func generateMockRefreshToken() -> String {
        return UUID().uuidString + "-refresh"
    }
}
