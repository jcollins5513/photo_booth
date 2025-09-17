import Foundation
import UIKit

/// File system manager implementation
@MainActor
class FileSystemManager: FileSystemManagerProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let documentsDirectory: URL
    private let imagesDirectory: URL
    private let sessionsDirectory: URL
    private let exportsDirectory: URL
    private let backupsDirectory: URL
    
    // MARK: - Initialization
    
    nonisolated init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create organized directory structure
        imagesDirectory = documentsDirectory.appendingPathComponent("Images")
        sessionsDirectory = documentsDirectory.appendingPathComponent("Sessions")
        exportsDirectory = documentsDirectory.appendingPathComponent("Exports")
        backupsDirectory = documentsDirectory.appendingPathComponent("Backups")
        
        // Create directories if they don't exist
        createDirectoryStructure()
    }
    
    nonisolated private func createDirectoryStructure() {
        let directories = [imagesDirectory, sessionsDirectory, exportsDirectory, backupsDirectory]
        
        for directory in directories {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - File System Operations
    
    func saveImage(data: Data, fileName: String) async throws -> String {
        // Validate data
        guard !data.isEmpty else {
            throw StorageServiceError.fileSystemError("Cannot save empty data")
        }
        
        let fileURL = getFileURL(fileName: fileName)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try data.write(to: fileURL)
                    continuation.resume(returning: fileURL.path)
                } catch {
                    continuation.resume(throwing: StorageServiceError.fileSystemError(error.localizedDescription))
                }
            }
        }
    }
    
    func loadImage(filePath: String) async throws -> Data {
        let fileURL = URL(fileURLWithPath: filePath)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: fileURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: StorageServiceError.fileSystemError(error.localizedDescription))
                }
            }
        }
    }
    
    func deleteImage(filePath: String) async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageServiceError.fileSystemError(error.localizedDescription))
                }
            }
        }
    }
    
    func getFileURL(fileName: String) -> URL {
        return imagesDirectory.appendingPathComponent(fileName)
    }
    
    nonisolated func fileExists(filePath: String) -> Bool {
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    // MARK: - Enhanced Photo Organization
    
    func saveImageWithOrganization(data: Data, sessionId: UUID, angle: String, quality: PhotoQuality = .high) async throws -> String {
        // Validate data
        guard !data.isEmpty else {
            throw StorageServiceError.fileSystemError("Cannot save empty data")
        }
        
        // Create session-specific directory
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        
        // Create angle-specific subdirectory
        let angleDir = sessionDir.appendingPathComponent(angle)
        try FileManager.default.createDirectory(at: angleDir, withIntermediateDirectories: true)
        
        // Generate filename with timestamp and quality
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(angle)_\(timestamp)_\(quality.rawValue).jpg"
        let fileURL = angleDir.appendingPathComponent(fileName)
        
        // Compress image based on quality
        let compressedData = try await compressImage(data: data, quality: quality)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try compressedData.write(to: fileURL)
                    continuation.resume(returning: fileURL.path)
                } catch {
                    continuation.resume(throwing: StorageServiceError.fileSystemError(error.localizedDescription))
                }
            }
        }
    }
    
    private func compressImage(data: Data, quality: PhotoQuality) async throws -> Data {
        guard let image = UIImage(data: data) else {
            throw StorageServiceError.fileSystemError("Invalid image data")
        }
        
        let compressionQuality: CGFloat
        switch quality {
        case .high:
            compressionQuality = 0.9
        case .medium:
            compressionQuality = 0.7
        case .low:
            compressionQuality = 0.5
        }
        
        guard let compressedData = image.jpegData(compressionQuality: compressionQuality) else {
            throw StorageServiceError.fileSystemError("Failed to compress image")
        }
        
        return compressedData
    }
    
    nonisolated func getSessionDirectory(sessionId: UUID) -> URL {
        return sessionsDirectory.appendingPathComponent(sessionId.uuidString)
    }
    
    nonisolated func getExportDirectory() -> URL {
        return exportsDirectory
    }
    
    nonisolated func getBackupDirectory() -> URL {
        return backupsDirectory
    }
    
    // MARK: - Storage Management
    
    func getStorageInfo() async -> StorageInfo {
        let imagesSize = await calculateDirectorySize(imagesDirectory)
        let sessionsSize = await calculateDirectorySize(sessionsDirectory)
        let exportsSize = await calculateDirectorySize(exportsDirectory)
        let backupsSize = await calculateDirectorySize(backupsDirectory)
        let totalSize = imagesSize + sessionsSize + exportsSize + backupsSize
        
        let availableSpace = await getAvailableSpace()
        
        return StorageInfo(
            totalUsed: totalSize,
            availableSpace: availableSpace,
            imagesCount: await countFiles(in: imagesDirectory),
            sessionsCount: await countFiles(in: sessionsDirectory)
        )
    }
    
    private func calculateDirectorySize(_ directory: URL) async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var totalSize: Int64 = 0
                
                if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                            totalSize += Int64(resourceValues.fileSize ?? 0)
                        } catch {
                            // Skip files that can't be read
                        }
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    private func getAvailableSpace() async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let resourceValues = try self.documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    let availableSpace = Int64(resourceValues.volumeAvailableCapacityForImportantUsage ?? 0)
                    continuation.resume(returning: availableSpace)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    private func countFiles(in directory: URL) async -> Int {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    continuation.resume(returning: files.count)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupOldExports(olderThan days: Int) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: self.exportsDirectory, includingPropertiesForKeys: [.creationDateKey])
                    
                    for file in files {
                        let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                        if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                            try FileManager.default.removeItem(at: file)
                        }
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct StorageInfo {
    let totalUsed: Int64
    let availableSpace: Int64
    let imagesCount: Int
    let sessionsCount: Int
    
    var totalSpace: Int64 {
        return totalUsed + availableSpace
    }
    
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(totalUsed) / Double(totalSpace) * 100
    }
}
