import Foundation
import UIKit

/// File system manager implementation
class FileSystemManager: FileSystemManagerProtocol {
    
    // MARK: - Properties
    
    private let documentsDirectory: URL
    private let imagesDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create images directory if it doesn't exist
        imagesDirectory = documentsDirectory.appendingPathComponent("Images")
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File System Operations
    
    func saveImage(data: Data, fileName: String) async throws -> String {
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
    
    func fileExists(filePath: String) -> Bool {
        return FileManager.default.fileExists(atPath: filePath)
    }
}
