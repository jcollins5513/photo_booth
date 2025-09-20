import Foundation
import UIKit
import CoreImage
import Vision

/// Handles image preprocessing for CoreML model inference
class ImageProcessor {
    
    // MARK: - Configuration
    private let targetSize = CGSize(width: 224, height: 224) // Standard input size for many CoreML models
    private let jpegCompressionQuality: CGFloat = 0.8
    
    // MARK: - Image Preprocessing
    
    /// Preprocesses an image for CoreML model inference
    /// - Parameter image: Input image from camera
    /// - Returns: Preprocessed image ready for classification
    func preprocessForClassification(_ image: UIImage) -> UIImage? {
        // Resize image to target size
        guard let resizedImage = resizeImage(image, to: targetSize) else {
            print("❌ ImageProcessor: Failed to resize image")
            return nil
        }
        
        // Normalize image orientation
        guard let normalizedImage = normalizeOrientation(resizedImage) else {
            print("❌ ImageProcessor: Failed to normalize image orientation")
            return nil
        }
        
        // Apply any additional preprocessing (brightness, contrast, etc.)
        guard let processedImage = applyEnhancements(normalizedImage) else {
            print("❌ ImageProcessor: Failed to apply image enhancements")
            return nil
        }
        
        return processedImage
    }
    
    /// Resizes image to target size while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    /// Normalizes image orientation to ensure consistent processing
    private func normalizeOrientation(_ image: UIImage) -> UIImage? {
        // If image orientation is already up, return as-is
        guard image.imageOrientation != .up else { return image }
        
        // Create a new image with normalized orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    /// Applies image enhancements for better classification
    private func applyEnhancements(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply slight contrast and brightness adjustments
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.1, forKey: kCIInputContrastKey) // Slight contrast boost
        filter?.setValue(0.05, forKey: kCIInputBrightnessKey) // Slight brightness boost
        filter?.setValue(1.0, forKey: kCIInputSaturationKey) // Keep saturation
        
        guard let outputImage = filter?.outputImage,
              let enhancedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: enhancedCGImage)
    }
    
    // MARK: - Image Quality Assessment
    
    /// Assesses image quality for vehicle photography
    /// - Parameter image: Image to assess
    /// - Returns: Quality score (0.0 to 1.0) and quality issues
    func assessImageQuality(_ image: UIImage) -> (score: Float, issues: [QualityIssue]) {
        var issues: [QualityIssue] = []
        var score: Float = 1.0
        
        // Check image sharpness
        let sharpness = calculateSharpness(image)
        if sharpness < 0.3 {
            issues.append(.blurry)
            score -= 0.3
        }
        
        // Check image brightness
        let brightness = calculateBrightness(image)
        if brightness < 0.2 {
            issues.append(.tooDark)
            score -= 0.2
        } else if brightness > 0.8 {
            issues.append(.tooBright)
            score -= 0.2
        }
        
        // Check image contrast
        let contrast = calculateContrast(image)
        if contrast < 0.2 {
            issues.append(.lowContrast)
            score -= 0.2
        }
        
        // Check for motion blur (simplified)
        if sharpness < 0.2 {
            issues.append(.motionBlur)
            score -= 0.3
        }
        
        return (max(0.0, score), issues)
    }
    
    private func calculateSharpness(_ image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // Simplified sharpness calculation using edge detection
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let outputImage = filter?.outputImage,
              let edgeCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return 0.0
        }
        
        // Calculate average pixel intensity as sharpness indicator
        let data = edgeCGImage.dataProvider?.data
        let bytes = CFDataGetBytePtr(data)
        let length = CFDataGetLength(data)
        
        var totalIntensity: Float = 0.0
        let pixelCount = length / 4 // Assuming RGBA
        
        for i in 0..<pixelCount {
            if let bytes = bytes {
                let pixelIndex = i * 4
                let r = Float(bytes[pixelIndex])
                let g = Float(bytes[pixelIndex + 1])
                let b = Float(bytes[pixelIndex + 2])
                totalIntensity += (r + g + b) / 3.0
            }
        }
        
        return totalIntensity / Float(pixelCount) / 255.0
    }
    
    private func calculateBrightness(_ image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter?.outputImage,
              let averageCGImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            return 0.0
        }
        
        let data = averageCGImage.dataProvider?.data
        let bytes = CFDataGetBytePtr(data)
        
        guard let bytes = bytes else { return 0.0 }
        
        let r = Float(bytes[0])
        let g = Float(bytes[1])
        let b = Float(bytes[2])
        
        return (r + g + b) / 3.0 / 255.0
    }
    
    private func calculateContrast(_ image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // Simplified contrast calculation
        let _ = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Calculate standard deviation of pixel intensities as contrast measure
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(2.0, forKey: kCIInputContrastKey)
        
        guard filter?.outputImage != nil else { return 0.0 }
        
        // This is a simplified implementation
        // In production, you'd calculate actual standard deviation
        return 0.5 // Placeholder value
    }
    
    // MARK: - Image Compression
    
    /// Compresses image for storage while maintaining quality
    /// - Parameters:
    ///   - image: Image to compress
    ///   - maxFileSize: Maximum file size in bytes
    /// - Returns: Compressed image data
    func compressImage(_ image: UIImage, maxFileSize: Int = 500_000) -> Data? {
        var compressionQuality: CGFloat = jpegCompressionQuality
        var imageData = image.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality until file size is acceptable
        while let data = imageData, data.count > maxFileSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
}

// MARK: - Quality Issues
extension ImageProcessor {
    enum QualityIssue: String, CaseIterable {
        case blurry = "Image is blurry"
        case tooDark = "Image is too dark"
        case tooBright = "Image is too bright"
        case lowContrast = "Image has low contrast"
        case motionBlur = "Image has motion blur"
        case outOfFocus = "Image is out of focus"
        
        var displayName: String {
            return self.rawValue
        }
        
        var suggestion: String {
            switch self {
            case .blurry, .motionBlur, .outOfFocus:
                return "Hold device steady and ensure good lighting"
            case .tooDark:
                return "Move to a brighter area or adjust lighting"
            case .tooBright:
                return "Move to a shaded area or reduce lighting"
            case .lowContrast:
                return "Ensure good lighting and clear vehicle visibility"
            }
        }
    }
}
