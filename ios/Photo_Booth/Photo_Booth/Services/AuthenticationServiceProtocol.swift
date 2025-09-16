import Foundation

/// Protocol defining the authentication service interface
protocol AuthenticationServiceProtocol {
    /// Register a new user with email and password
    func registerUser(email: String, password: String) async throws -> User
    
    /// Sign up a new user with email and password (alias for registerUser)
    func signUp(email: String, password: String) async throws -> User
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User
    
    /// Sign out the current user
    func signOut() async throws
    
    /// Get the current signed-in user
    func getCurrentUser() -> User?
    
    /// Check if a user is currently signed in
    func isUserSignedIn() -> Bool
    
    /// Check if authenticated (alias for isUserSignedIn)
    func isAuthenticated() async -> Bool
    
    /// Send password reset email
    func sendPasswordReset(email: String) async throws
    
    /// Reset password (alias for sendPasswordReset)
    func resetPassword(email: String) async throws
    
    /// Refresh the authentication token
    func refreshToken() async throws -> String
    
    /// Delete the current user account
    func deleteAccount() async throws
}

/// User data model
struct User: Codable, Equatable {
    let id: String
    let email: String
    let idToken: String
    let refreshToken: String
    let createdAt: Date
    let lastSignIn: Date?
    
    init(id: String, email: String, idToken: String, refreshToken: String, createdAt: Date = Date(), lastSignIn: Date? = nil) {
        self.id = id
        self.email = email
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.createdAt = createdAt
        self.lastSignIn = lastSignIn
    }
}

/// Authentication service errors
enum AuthenticationServiceError: Error, LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyExists
    case invalidCredentials
    case userNotFound
    case notSignedIn
    case networkError
    case serverError
    case tokenExpired
    case accountDeletionFailed
    case passwordResetFailed
    case registrationFailed
    case signInFailed
    case signOutFailed
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The email address is invalid"
        case .weakPassword:
            return "The password is too weak. Please choose a stronger password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .notSignedIn:
            return "No user is currently signed in"
        case .networkError:
            return "Network connection error. Please check your internet connection"
        case .serverError:
            return "Server error. Please try again later"
        case .tokenExpired:
            return "Authentication token has expired"
        case .accountDeletionFailed:
            return "Failed to delete account. Please try again"
        case .passwordResetFailed:
            return "Failed to send password reset email"
        case .registrationFailed:
            return "Failed to register user. Please try again"
        case .signInFailed:
            return "Failed to sign in. Please try again"
        case .signOutFailed:
            return "Failed to sign out. Please try again"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        }
    }
}
