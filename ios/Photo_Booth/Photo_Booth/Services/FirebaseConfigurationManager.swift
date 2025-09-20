import Foundation
import Firebase

/// Manages Firebase configuration to ensure it's only initialized once
class FirebaseConfigurationManager {
    static let shared = FirebaseConfigurationManager()
    private var isConfigured = false
    private let configurationLock = NSLock()
    
    private init() {}
    
    /// Configures Firebase if not already configured
    func configure() {
        configurationLock.lock()
        defer { configurationLock.unlock() }
        
        guard !isConfigured else {
            print("🔥 FirebaseConfig: Already configured, skipping")
            return
        }
        
        print("🔥 FirebaseConfig: Configuring Firebase app")
        FirebaseApp.configure()
        isConfigured = true
        print("🔥 FirebaseConfig: Firebase configured successfully")
    }
}
