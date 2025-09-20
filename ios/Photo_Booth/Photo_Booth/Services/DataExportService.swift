import Foundation
import UIKit

/// Service for handling data export and sharing functionality
class DataExportService {
    
    // MARK: - Properties
    
    private let fileSystemManager: FileSystemManagerProtocol
    private let storageService: StorageServiceProtocol
    private let metadataService: PhotoMetadataService
    
    // MARK: - Initialization
    
    init(fileSystemManager: FileSystemManagerProtocol, storageService: StorageServiceProtocol, metadataService: PhotoMetadataService) {
        self.fileSystemManager = fileSystemManager
        self.storageService = storageService
        self.metadataService = metadataService
    }
    
    // MARK: - Session Export
    
    func exportSession(sessionId: UUID, format: ExportFormat) async throws -> URL {
        let session = try await storageService.getPhotoSession(id: sessionId)
        guard let session = session else {
            throw DataExportError.sessionNotFound
        }
        
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        switch format {
        case .zip:
            return try await exportSessionAsZIP(session: session, photos: photos)
        case .json:
            return try await exportSessionAsJSON(session: session, photos: photos)
        case .csv:
            return try await exportSessionAsCSV(session: session, photos: photos)
        }
    }
    
    private func exportSessionAsZIP(session: PhotoSession, photos: [VehiclePhoto]) async throws -> URL {
        let exportDir = fileSystemManager.getExportDirectory()
        let sessionDir = exportDir.appendingPathComponent("\(session.id ?? "unknown")_\(Date().timeIntervalSince1970)")
        
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        
        // Create session info file
        let sessionInfo = SessionExportInfo(
            id: session.id ?? "",
            vehicleIdentifier: session.vehicleIdentifier ?? "",
            startDate: session.startDate ?? Date(),
            status: session.status ?? "",
            totalAngles: Int(session.totalAngles),
            completedAngles: Int(session.completedAngles)
        )
        
        let sessionInfoData = try JSONEncoder().encode(sessionInfo)
        let sessionInfoURL = sessionDir.appendingPathComponent("session_info.json")
        try sessionInfoData.write(to: sessionInfoURL)
        
        // Copy photos to export directory
        for photo in photos {
            guard let photoId = photo.id,
                  let angle = photo.angleType else { continue }
            
            let photoData = try await storageService.getPhotoData(id: UUID(uuidString: photoId) ?? UUID())
            let photoURL = sessionDir.appendingPathComponent("\(angle)_\(photoId).jpg")
            try photoData.write(to: photoURL)
        }
        
        // Create a simple archive by copying all files to a single directory
        // For now, we'll return the session directory as the "export"
        // Note: In a production app, you would implement proper ZIP compression here
        return sessionDir
    }
    
    private func exportSessionAsJSON(session: PhotoSession, photos: [VehiclePhoto]) async throws -> URL {
        let exportDir = fileSystemManager.getExportDirectory()
        let fileName = "\(session.vehicleIdentifier ?? "session")_\(Date().timeIntervalSince1970).json"
        let fileURL = exportDir.appendingPathComponent(fileName)
        
        var exportData: [String: Any] = [:]
        
        // Session data
        exportData["session"] = [
            "id": session.id ?? "",
            "vehicleIdentifier": session.vehicleIdentifier ?? "",
            "startDate": ISO8601DateFormatter().string(from: session.startDate ?? Date()),
            "status": session.status ?? "",
            "totalAngles": session.totalAngles,
            "completedAngles": session.completedAngles
        ]
        
        // Photos data
        var photosData: [[String: Any]] = []
        for photo in photos {
            guard let photoId = photo.id else { continue }
            
            let photoData = try await storageService.getPhotoData(id: UUID(uuidString: photoId) ?? UUID())
            let base64String = photoData.base64EncodedString()
            
            var photoInfo: [String: Any] = [
                "id": photoId,
                "angle": photo.angleType ?? "",
                "timestamp": ISO8601DateFormatter().string(from: photo.captureDate ?? Date()),
                "imageData": base64String
            ]
            
            // Add metadata if available
            do {
                let exifData = try await metadataService.extractEXIFData(from: photoData)
                var exifDict: [String: Any] = [:]
                exifDict["width"] = exifData.width ?? 0
                exifDict["height"] = exifData.height ?? 0
                exifDict["cameraMake"] = exifData.cameraMake ?? ""
                exifDict["cameraModel"] = exifData.cameraModel ?? ""
                exifDict["exposureTime"] = exifData.exposureTime ?? 0
                exifDict["fNumber"] = exifData.fNumber ?? 0
                exifDict["iso"] = exifData.iso ?? 0
                photoInfo["exif"] = exifDict
            } catch {
                // Continue without metadata if extraction fails
            }
            
            photosData.append(photoInfo)
        }
        
        exportData["photos"] = photosData
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: fileURL)
        
        return fileURL
    }
    
    private func exportSessionAsCSV(session: PhotoSession, photos: [VehiclePhoto]) async throws -> URL {
        let exportDir = fileSystemManager.getExportDirectory()
        let fileName = "\(session.vehicleIdentifier ?? "session")_\(Date().timeIntervalSince1970).csv"
        let fileURL = exportDir.appendingPathComponent(fileName)
        
        var csvContent = "Session ID,Vehicle ID,Start Date,Status,Total Angles,Completed Angles\n"
        csvContent += "\(session.id ?? ""),\(session.vehicleIdentifier ?? ""),\(ISO8601DateFormatter().string(from: session.startDate ?? Date())),\(session.status ?? ""),\(session.totalAngles),\(session.completedAngles)\n\n"
        
        csvContent += "Photo ID,Angle,Timestamp,File Size (bytes),Width,Height,Camera Make,Camera Model,Exposure Time,F Number,ISO\n"
        
        for photo in photos {
            guard let photoId = photo.id else { continue }
            
            let photoData = try await storageService.getPhotoData(id: UUID(uuidString: photoId) ?? UUID())
            let fileSize = photoData.count
            
            var photoRow = "\(photoId),\(photo.angleType ?? ""),\(ISO8601DateFormatter().string(from: photo.captureDate ?? Date())),\(fileSize)"
            
            // Add EXIF data if available
            do {
                let exifData = try await metadataService.extractEXIFData(from: photoData)
                photoRow += ",\(exifData.width ?? 0),\(exifData.height ?? 0),\(exifData.cameraMake ?? ""),\(exifData.cameraModel ?? ""),\(exifData.exposureTime ?? 0),\(exifData.fNumber ?? 0),\(exifData.iso ?? 0)"
            } catch {
                photoRow += ",0,0,,,,,"
            }
            
            csvContent += photoRow + "\n"
        }
        
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // MARK: - Individual Photo Export
    
    func exportPhoto(photoId: UUID, format: PhotoExportFormat) async throws -> URL {
        guard let photo = try await storageService.getVehiclePhoto(id: photoId) else {
            throw DataExportError.photoNotFound
        }
        
        let photoData = try await storageService.getPhotoData(id: photoId)
        let exportDir = fileSystemManager.getExportDirectory()
        
        let fileName: String
        switch format {
        case .original:
            fileName = "\(photo.angleType ?? "photo")_\(photoId.uuidString).jpg"
        case .highQuality:
            fileName = "\(photo.angleType ?? "photo")_\(photoId.uuidString)_hq.jpg"
        case .mediumQuality:
            fileName = "\(photo.angleType ?? "photo")_\(photoId.uuidString)_mq.jpg"
        case .lowQuality:
            fileName = "\(photo.angleType ?? "photo")_\(photoId.uuidString)_lq.jpg"
        }
        
        let fileURL = exportDir.appendingPathComponent(fileName)
        
        // Process image based on format
        let processedData: Data
        switch format {
        case .original:
            processedData = photoData
        case .highQuality:
            processedData = try await compressImage(photoData, quality: .high)
        case .mediumQuality:
            processedData = try await compressImage(photoData, quality: .medium)
        case .lowQuality:
            processedData = try await compressImage(photoData, quality: .low)
        }
        
        try processedData.write(to: fileURL)
        return fileURL
    }
    
    private func compressImage(_ data: Data, quality: PhotoQuality) async throws -> Data {
        guard let image = UIImage(data: data) else {
            throw DataExportError.invalidImageData
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
            throw DataExportError.imageProcessingError
        }
        
        return compressedData
    }
    
    // MARK: - Cloud Storage Integration
    
    func uploadToCloudStorage(fileURL: URL, service: CloudStorageService) async throws -> String {
        // This would integrate with cloud storage services
        // For now, we'll simulate the upload
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let fileName = fileURL.lastPathComponent
        let cloudURL = "https://cloud.example.com/\(fileName)"
        
        return cloudURL
    }
    
    // MARK: - Sharing Functionality
    
    func createShareableLink(for fileURL: URL) async throws -> String {
        // This would integrate with sharing services
        // For now, we'll return a placeholder
        return "https://share.example.com/\(fileURL.lastPathComponent)"
    }
    
    func generateQRCode(for fileURL: URL) async throws -> UIImage {
        let data = fileURL.absoluteString.data(using: .utf8) ?? Data()
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw DataExportError.qrCodeGenerationError
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else {
            throw DataExportError.qrCodeGenerationError
        }
        
        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw DataExportError.qrCodeGenerationError
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Supporting Types

enum ExportFormat {
    case zip
    case json
    case csv
}

enum PhotoExportFormat {
    case original
    case highQuality
    case mediumQuality
    case lowQuality
}

enum CloudStorageService {
    case iCloud
    case googleDrive
    case dropbox
    case oneDrive
}

struct SessionExportInfo: Codable {
    let id: String
    let vehicleIdentifier: String
    let startDate: Date
    let status: String
    let totalAngles: Int
    let completedAngles: Int
}

enum DataExportError: Error, LocalizedError {
    case sessionNotFound
    case photoNotFound
    case invalidImageData
    case imageProcessingError
    case qrCodeGenerationError
    case cloudUploadError
    case fileCreationError
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found for export"
        case .photoNotFound:
            return "Photo not found for export"
        case .invalidImageData:
            return "Invalid image data provided"
        case .imageProcessingError:
            return "Error processing image for export"
        case .qrCodeGenerationError:
            return "Error generating QR code"
        case .cloudUploadError:
            return "Error uploading to cloud storage"
        case .fileCreationError:
            return "Error creating export file"
        }
    }
}
