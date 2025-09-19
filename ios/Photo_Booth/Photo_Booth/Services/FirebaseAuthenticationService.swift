import Foundation
import FirebaseAuth
import FirebaseCore

/// Firebase-based authentication service implementation
class FirebaseAuthenticationService: AuthenticationServiceProtocol {
    
    // MARK: - Properties
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    init() {
        // Configure Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Set up auth state listener
        setupAuthStateListener()
    }
    
    deinit {
        // Remove auth state listener
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
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
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let firebaseUser = authResult.user
            
            // Get ID token
            let idToken = try await firebaseUser.getIDToken()
            
            // Create our User model
            let user = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? email,
                idToken: idToken,
                refreshToken: firebaseUser.refreshToken ?? "",
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                lastSignIn: firebaseUser.metadata.lastSignInDate
            )
            
            return user
        } catch {
            // Log the actual Firebase error for debugging
            print("❌ Firebase signup error: \(error.localizedDescription)")
            if let authError = error as? AuthErrorCode {
                print("❌ Auth error code: \(authError.code.rawValue)")
            }
            // Map Firebase errors to our custom errors
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - User Sign In
    
    func signIn(email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AuthenticationServiceError.invalidEmail
        }
        
        guard !password.isEmpty else {
            throw AuthenticationServiceError.invalidCredentials
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let firebaseUser = authResult.user
            
            // Get ID token
            let idToken = try await firebaseUser.getIDToken()
            
            // Create our User model
            let user = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? email,
                idToken: idToken,
                refreshToken: firebaseUser.refreshToken ?? "",
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                lastSignIn: firebaseUser.metadata.lastSignInDate
            )
            
            return user
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - User Sign Out
    
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthenticationServiceError.signOutFailed
        }
    }
    
    // MARK: - User State
    
    func getCurrentUser() -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            return nil
        }
        
        // Note: This is synchronous, so we can't get fresh tokens here
        // The user will need to sign in again if tokens are expired
        return User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            idToken: "", // Will be empty - need to call refreshToken() for fresh token
            refreshToken: firebaseUser.refreshToken ?? "",
            createdAt: firebaseUser.metadata.creationDate ?? Date(),
            lastSignIn: firebaseUser.metadata.lastSignInDate
        )
    }
    
    func isUserSignedIn() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        guard isValidEmail(email) else {
            throw AuthenticationServiceError.invalidEmail
        }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func resetPassword(email: String) async throws {
        try await sendPasswordReset(email: email)
    }
    
    func isAuthenticated() async -> Bool {
        return isUserSignedIn()
    }
    
    // MARK: - Token Management
    
    func refreshToken() async throws -> String {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationServiceError.notSignedIn
        }
        
        do {
            let idToken = try await firebaseUser.getIDToken(forcingRefresh: true)
            return idToken
        } catch {
            throw AuthenticationServiceError.tokenRefreshFailed
        }
    }
    
    // MARK: - Account Management
    
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationServiceError.notSignedIn
        }
        
        do {
            try await firebaseUser.delete()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { auth, user in
            // This will be called whenever the auth state changes
            // You can use this to update your UI or perform other actions
            if user != nil {
                print("User signed in: \(user?.email ?? "unknown")")
            } else {
                print("User signed out")
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        // Password must be at least 8 characters long
        return password.count >= 8
    }
    
    private func mapFirebaseError(_ error: Error) -> AuthenticationServiceError {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidEmail:
                return .invalidEmail
            case .weakPassword:
                return .weakPassword
            case .emailAlreadyInUse:
                return .emailAlreadyExists
            case .userNotFound:
                return .userNotFound
            case .wrongPassword:
                return .invalidCredentials
            case .userDisabled:
                return .invalidCredentials
            case .tooManyRequests:
                return .serverError
            case .networkError:
                return .networkError
            case .operationNotAllowed:
                return .serverError
            default:
                return .serverError
            }
        }
        return .serverError
    }
}
