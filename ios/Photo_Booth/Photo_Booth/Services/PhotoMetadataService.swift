@preconcurrency import Foundation
import UIKit
import ImageIO
import CoreLocation

/// Service for managing photo metadata and quality assessment
@MainActor
class PhotoMetadataService: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let fileSystemManager: FileSystemManagerProtocol
    
    // MARK: - Initialization
    
    nonisolated init(fileSystemManager: FileSystemManagerProtocol) {
        self.fileSystemManager = fileSystemManager
    }
    
    // MARK: - EXIF Data Extraction
    
    func extractEXIFData(from imageData: Data) async throws -> PhotoEXIFData {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw PhotoMetadataError.invalidImageData
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw PhotoMetadataError.noMetadataFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let exifData = try self.parseEXIFProperties(properties)
                    continuation.resume(returning: exifData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseEXIFProperties(_ properties: [CFString: Any]) throws -> PhotoEXIFData {
        var exifData = PhotoEXIFData()
        
        // Basic image properties
        if let width = properties[kCGImagePropertyPixelWidth] as? Int {
            exifData.width = width
        }
        
        if let height = properties[kCGImagePropertyPixelHeight] as? Int {
            exifData.height = height
        }
        
        if let dpiWidth = properties[kCGImagePropertyDPIWidth] as? Double {
            exifData.dpiWidth = dpiWidth
        }
        
        if let dpiHeight = properties[kCGImagePropertyDPIHeight] as? Double {
            exifData.dpiHeight = dpiHeight
        }
        
        // EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                exifData.dateTimeOriginal = self.parseEXIFDate(dateTimeOriginal)
            }
            
            if let exposureTime = exif[kCGImagePropertyExifExposureTime] as? Double {
                exifData.exposureTime = exposureTime
            }
            
            if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                exifData.fNumber = fNumber
            }
            
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int] {
                exifData.iso = iso.first
            }
            
            if let focalLength = exif[kCGImagePropertyExifFocalLength] as? Double {
                exifData.focalLength = focalLength
            }
            
            if let flash = exif[kCGImagePropertyExifFlash] as? Int {
                exifData.flash = flash
            }
            
            if let whiteBalance = exif[kCGImagePropertyExifWhiteBalance] as? Int {
                exifData.whiteBalance = whiteBalance
            }
        }
        
        // GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            exifData.gpsData = try self.parseGPSData(gps)
        }
        
        // Camera make and model
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                exifData.cameraMake = make
            }
            
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                exifData.cameraModel = model
            }
        }
        
        return exifData
    }
    
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
    
    private func parseGPSData(_ gps: [CFString: Any]) throws -> GPSData? {
        guard let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
              let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String else {
            return nil
        }
        
        let lat = latitudeRef == "N" ? latitude : -latitude
        let lon = longitudeRef == "E" ? longitude : -longitude
        
        return GPSData(
            latitude: lat,
            longitude: lon,
            altitude: gps[kCGImagePropertyGPSAltitude] as? Double,
            timestamp: gps[kCGImagePropertyGPSTimeStamp] as? String
        )
    }
    
    // MARK: - Photo Quality Assessment
    
    func assessPhotoQuality(imageData: Data) async throws -> PhotoQualityAssessment {
        guard let image = UIImage(data: imageData) else {
            throw PhotoMetadataError.invalidImageData
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let assessment = try self.performQualityAssessment(image: image, imageData: imageData)
                    continuation.resume(returning: assessment)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performQualityAssessment(image: UIImage, imageData: Data) throws -> PhotoQualityAssessment {
        var assessment = PhotoQualityAssessment()
        
        // Basic metrics
        assessment.resolution = CGSize(width: image.size.width, height: image.size.height)
        assessment.fileSize = imageData.count
        assessment.aspectRatio = image.size.width / image.size.height
        
        // Blur detection
        assessment.blurScore = try self.detectBlur(image: image)
        
        // Brightness assessment
        assessment.brightnessScore = try self.assessBrightness(image: image)
        
        // Contrast assessment
        assessment.contrastScore = try self.assessContrast(image: image)
        
        // Overall quality score
        assessment.overallScore = self.calculateOverallScore(assessment)
        
        // Quality level
        assessment.qualityLevel = self.determineQualityLevel(assessment.overallScore)
        
        return assessment
    }
    
    private func detectBlur(image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else {
            throw PhotoMetadataError.invalidImageData
        }
        
        // Convert to grayscale for blur detection
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let cgContext = context else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = cgContext.data else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        // Calculate Laplacian variance for blur detection
        var laplacianSum: Double = 0
        var laplacianCount = 0
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Int(y * width + x)
                let top = Int((y - 1) * width + x)
                let bottom = Int((y + 1) * width + x)
                let left = Int(y * width + (x - 1))
                let right = Int(y * width + (x + 1))
                
                let laplacian = abs(Int(buffer[center]) * 4 - Int(buffer[top]) - Int(buffer[bottom]) - Int(buffer[left]) - Int(buffer[right]))
                laplacianSum += Double(laplacian * laplacian)
                laplacianCount += 1
            }
        }
        
        let variance = laplacianSum / Double(laplacianCount)
        return variance
    }
    
    private func assessBrightness(image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else {
            throw PhotoMetadataError.invalidImageData
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let cgContext = context else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = cgContext.data else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var totalBrightness: Double = 0
        var pixelCount = 0
        
        for i in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let r = Double(buffer[i])
            let g = Double(buffer[i + 1])
            let b = Double(buffer[i + 2])
            
            // Calculate perceived brightness
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            totalBrightness += brightness
            pixelCount += 1
        }
        
        return totalBrightness / Double(pixelCount) / 255.0
    }
    
    private func assessContrast(image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else {
            throw PhotoMetadataError.invalidImageData
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let cgContext = context else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = cgContext.data else {
            throw PhotoMetadataError.imageProcessingError
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var totalBrightness: Double = 0
        var pixelCount = 0
        
        // Calculate mean brightness
        for i in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let r = Double(buffer[i])
            let g = Double(buffer[i + 1])
            let b = Double(buffer[i + 2])
            
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            totalBrightness += brightness
            pixelCount += 1
        }
        
        let meanBrightness = totalBrightness / Double(pixelCount)
        
        // Calculate standard deviation for contrast
        var variance: Double = 0
        for i in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let r = Double(buffer[i])
            let g = Double(buffer[i + 1])
            let b = Double(buffer[i + 2])
            
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            let diff = brightness - meanBrightness
            variance += diff * diff
        }
        
        let standardDeviation = sqrt(variance / Double(pixelCount))
        return standardDeviation / 255.0
    }
    
    private func calculateOverallScore(_ assessment: PhotoQualityAssessment) -> Double {
        let blurWeight = 0.4
        let brightnessWeight = 0.3
        let contrastWeight = 0.3
        
        // Normalize scores (0-1 range)
        let blurScore = min(assessment.blurScore / 1000.0, 1.0) // Normalize blur score
        let brightnessScore = 1.0 - abs(assessment.brightnessScore - 0.5) * 2 // Optimal brightness is 0.5
        let contrastScore = min(assessment.contrastScore * 10, 1.0) // Normalize contrast score
        
        return (blurScore * blurWeight + brightnessScore * brightnessWeight + contrastScore * contrastWeight) * 100
    }
    
    private func determineQualityLevel(_ score: Double) -> PhotoQualityLevel {
        switch score {
        case 90...100:
            return .excellent
        case 80..<90:
            return .good
        case 70..<80:
            return .fair
        case 60..<70:
            return .poor
        default:
            return .veryPoor
        }
    }
    
    // MARK: - Photo Tagging and Categorization
    
    func generatePhotoTags(for photo: VehiclePhoto, exifData: PhotoEXIFData, qualityAssessment: PhotoQualityAssessment) -> [String] {
        var tags: [String] = []
        
        // Angle-based tags
        if let angle = photo.angleType {
            tags.append("angle-\(angle)")
        }
        
        // Quality-based tags
        tags.append("quality-\(qualityAssessment.qualityLevel.rawValue)")
        
        // Camera-based tags
        if let make = exifData.cameraMake {
            tags.append("camera-\(make.lowercased())")
        }
        
        // Time-based tags
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: photo.captureDate ?? Date())
        if hour >= 6 && hour < 12 {
            tags.append("morning")
        } else if hour >= 12 && hour < 18 {
            tags.append("afternoon")
        } else {
            tags.append("evening")
        }
        
        // Weather-based tags (if GPS data available)
        if exifData.gpsData != nil {
            tags.append("location-available")
        }
        
        // Technical tags
        if qualityAssessment.blurScore > 500 {
            tags.append("sharp")
        } else if qualityAssessment.blurScore < 100 {
            tags.append("blurry")
        }
        
        if qualityAssessment.brightnessScore > 0.7 {
            tags.append("bright")
        } else if qualityAssessment.brightnessScore < 0.3 {
            tags.append("dark")
        }
        
        return tags
    }
}

// MARK: - Supporting Types

struct PhotoEXIFData {
    var width: Int?
    var height: Int?
    var dpiWidth: Double?
    var dpiHeight: Double?
    var dateTimeOriginal: Date?
    var exposureTime: Double?
    var fNumber: Double?
    var iso: Int?
    var focalLength: Double?
    var flash: Int?
    var whiteBalance: Int?
    var cameraMake: String?
    var cameraModel: String?
    var gpsData: GPSData?
}

struct GPSData {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: String?
}

struct PhotoQualityAssessment {
    var resolution: CGSize = .zero
    var fileSize: Int = 0
    var aspectRatio: CGFloat = 0
    var blurScore: Double = 0
    var brightnessScore: Double = 0
    var contrastScore: Double = 0
    var overallScore: Double = 0
    var qualityLevel: PhotoQualityLevel = .fair
}

enum PhotoQualityLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case veryPoor = "very-poor"
}

enum PhotoMetadataError: Error, LocalizedError {
    case invalidImageData
    case noMetadataFound
    case imageProcessingError
    case exifParsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided"
        case .noMetadataFound:
            return "No metadata found in image"
        case .imageProcessingError:
            return "Error processing image for analysis"
        case .exifParsingError:
            return "Error parsing EXIF data"
        }
    }
}
