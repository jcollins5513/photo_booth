import Foundation
import CryptoKit
import Security
import UIKit

/// Service for handling data security, encryption, and privacy controls
class DataSecurityService {
    
    // MARK: - Properties
    
    private let keychain = KeychainManager()
    private let encryptionKey: SymmetricKey
    
    // MARK: - Initialization
    
    init() {
        // Generate or retrieve encryption key
        self.encryptionKey = Self.getOrCreateEncryptionKey()
    }
    
    // MARK: - Data Encryption
    
    func encryptData(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined ?? Data()
    }
    
    func decryptData(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw DataSecurityError.invalidStringData
        }
        return try encryptData(data)
    }
    
    func decryptString(_ encryptedData: Data) throws -> String {
        let decryptedData = try decryptData(encryptedData)
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw DataSecurityError.decryptionFailed
        }
        return string
    }
    
    // MARK: - Photo Encryption
    
    func encryptPhoto(_ photoData: Data) throws -> Data {
        return try encryptData(photoData)
    }
    
    func decryptPhoto(_ encryptedPhotoData: Data) throws -> Data {
        return try decryptData(encryptedPhotoData)
    }
    
    // MARK: - Secure Data Storage
    
    func storeSecureData(_ data: Data, forKey key: String) throws {
        let encryptedData = try encryptData(data)
        try keychain.store(data: encryptedData, forKey: key)
    }
    
    func retrieveSecureData(forKey key: String) throws -> Data {
        let encryptedData = try keychain.retrieveData(forKey: key)
        return try decryptData(encryptedData)
    }
    
    func deleteSecureData(forKey key: String) throws {
        try keychain.deleteData(forKey: key)
    }
    
    // MARK: - Privacy Controls
    
    func anonymizePhotoMetadata(_ metadata: PhotoEXIFData) -> PhotoEXIFData {
        var anonymized = metadata
        
        // Remove location data
        anonymized.gpsData = nil
        
        // Remove camera identification
        anonymized.cameraMake = nil
        anonymized.cameraModel = nil
        
        // Remove timestamps
        anonymized.dateTimeOriginal = nil
        
        return anonymized
    }
    
    func redactSensitiveData(_ data: [String: Any]) -> [String: Any] {
        var redacted = data
        
        // Remove sensitive keys
        let sensitiveKeys = ["gps", "location", "timestamp", "camera_make", "camera_model", "device_id"]
        for key in sensitiveKeys {
            redacted.removeValue(forKey: key)
        }
        
        return redacted
    }
    
    // MARK: - Data Retention Management
    
    func applyDataRetentionPolicy(olderThan days: Int) async throws -> DataRetentionReport {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // This would need to be implemented with actual data deletion
        // For now, we'll return a placeholder report
        let report = DataRetentionReport(
            cutoffDate: cutoffDate,
            sessionsDeleted: 0,
            photosDeleted: 0,
            storageFreed: 0,
            errors: []
        )
        
        return report
    }
    
    func scheduleDataCleanup(olderThan days: Int) {
        // Schedule background cleanup task
        Task {
            do {
                let _ = try await applyDataRetentionPolicy(olderThan: days)
            } catch {
                print("Data cleanup failed: \(error)")
            }
        }
    }
    
    // MARK: - Access Logging
    
    func logDataAccess(operation: DataAccessOperation, resourceId: String, userId: String? = nil) {
        let logEntry = DataAccessLog(
            timestamp: Date(),
            operation: operation,
            resourceId: resourceId,
            userId: userId ?? "anonymous",
            deviceId: getDeviceIdentifier()
        )
        
        // Store log entry securely
        do {
            let logData = try JSONEncoder().encode(logEntry)
            try storeSecureData(logData, forKey: "access_log_\(Date().timeIntervalSince1970)")
        } catch {
            print("Failed to log data access: \(error)")
        }
    }
    
    private func getDeviceIdentifier() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    // MARK: - Compliance Features
    
    func generateDataExportForUser(userId: String) async throws -> DataExportPackage {
        // This would generate a complete data export for GDPR compliance
        let exportPackage = DataExportPackage(
            userId: userId,
            exportDate: Date(),
            sessions: [], // Would contain all user sessions
            photos: [], // Would contain all user photos
            metadata: [:], // Would contain all metadata
            logs: [] // Would contain all access logs
        )
        
        return exportPackage
    }
    
    func deleteAllUserData(userId: String) async throws -> DataDeletionReport {
        // This would delete all user data for GDPR compliance
        let report = DataDeletionReport(
            userId: userId,
            deletionDate: Date(),
            sessionsDeleted: 0,
            photosDeleted: 0,
            metadataDeleted: 0,
            logsDeleted: 0,
            success: true
        )
        
        return report
    }
    
    // MARK: - Security Monitoring
    
    func detectSuspiciousActivity() async -> [SecurityAlert] {
        // This would analyze access patterns and detect anomalies
        return []
    }
    
    func generateSecurityReport() async -> SecurityReport {
        let report = SecurityReport(
            reportDate: Date(),
            totalAccessAttempts: 0,
            failedAccessAttempts: 0,
            suspiciousActivities: 0,
            dataBreaches: 0,
            recommendations: []
        )
        
        return report
    }
    
    // MARK: - Key Management
    
    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keychain = KeychainManager()
        let keyIdentifier = "photo_booth_encryption_key"
        
        do {
            if let existingKeyData = try? keychain.retrieveData(forKey: keyIdentifier) {
                return SymmetricKey(data: existingKeyData)
            } else {
                let newKey = SymmetricKey(size: .bits256)
                let keyData = Data(newKey.withUnsafeBytes { Data($0) })
                try keychain.store(data: keyData, forKey: keyIdentifier)
                return newKey
            }
        } catch {
            // Fallback to generating a new key
            return SymmetricKey(size: .bits256)
        }
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    
    func store(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DataSecurityError.keychainError("Failed to store data in keychain")
        }
    }
    
    func retrieveData(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw DataSecurityError.keychainError("Failed to retrieve data from keychain")
        }
        
        return data
    }
    
    func deleteData(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DataSecurityError.keychainError("Failed to delete data from keychain")
        }
    }
}

// MARK: - Supporting Types

enum DataAccessOperation: String, CaseIterable, Codable {
    case create = "create"
    case read = "read"
    case update = "update"
    case delete = "delete"
    case export = "export"
    case share = "share"
}

struct DataAccessLog: Codable {
    let timestamp: Date
    let operation: DataAccessOperation
    let resourceId: String
    let userId: String
    let deviceId: String
}

struct DataRetentionReport {
    let cutoffDate: Date
    let sessionsDeleted: Int
    let photosDeleted: Int
    let storageFreed: Int64
    let errors: [String]
}

struct DataExportPackage: Codable {
    let userId: String
    let exportDate: Date
    let sessions: [String] // Session IDs
    let photos: [String] // Photo IDs
    let metadata: [String: String] // Metadata as String values
    let logs: [DataAccessLog] // Access logs
}

struct DataDeletionReport {
    let userId: String
    let deletionDate: Date
    let sessionsDeleted: Int
    let photosDeleted: Int
    let metadataDeleted: Int
    let logsDeleted: Int
    let success: Bool
}

struct SecurityAlert {
    let timestamp: Date
    let severity: SecuritySeverity
    let description: String
    let resourceId: String
}

enum SecuritySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct SecurityReport {
    let reportDate: Date
    let totalAccessAttempts: Int
    let failedAccessAttempts: Int
    let suspiciousActivities: Int
    let dataBreaches: Int
    let recommendations: [String]
}

enum DataSecurityError: Error, LocalizedError {
    case invalidStringData
    case decryptionFailed
    case keychainError(String)
    case encryptionFailed
    case dataRetentionError
    
    var errorDescription: String? {
        switch self {
        case .invalidStringData:
            return "Invalid string data for encryption"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .dataRetentionError:
            return "Data retention policy application failed"
        }
    }
}
