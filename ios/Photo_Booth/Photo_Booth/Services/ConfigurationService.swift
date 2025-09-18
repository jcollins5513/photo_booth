import Foundation
import Combine

/// Service for managing app configuration and settings
class ConfigurationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var confidenceThreshold: Float = 0.8
    @Published var processingFPS: Int = 10
    @Published var imageQualityThreshold: Float = 0.7
    @Published var autoCaptureEnabled: Bool = true
    @Published var soundEnabled: Bool = true
    @Published var hapticFeedbackEnabled: Bool = true
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration Keys
    private enum Keys {
        static let confidenceThreshold = "confidenceThreshold"
        static let processingFPS = "processingFPS"
        static let imageQualityThreshold = "imageQualityThreshold"
        static let autoCaptureEnabled = "autoCaptureEnabled"
        static let soundEnabled = "soundEnabled"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
    }
    
    // MARK: - Initialization
    init() {
        loadConfiguration()
        setupBindings()
    }
    
    // MARK: - Configuration Loading
    private func loadConfiguration() {
        confidenceThreshold = userDefaults.float(forKey: Keys.confidenceThreshold) != 0 ? 
                             userDefaults.float(forKey: Keys.confidenceThreshold) : 0.8
        
        processingFPS = userDefaults.object(forKey: Keys.processingFPS) as? Int ?? 10
        
        imageQualityThreshold = userDefaults.float(forKey: Keys.imageQualityThreshold) != 0 ? 
                               userDefaults.float(forKey: Keys.imageQualityThreshold) : 0.7
        
        autoCaptureEnabled = userDefaults.object(forKey: Keys.autoCaptureEnabled) as? Bool ?? true
        soundEnabled = userDefaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        hapticFeedbackEnabled = userDefaults.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true
    }
    
    private func setupBindings() {
        // Save configuration changes to UserDefaults
        $confidenceThreshold
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.confidenceThreshold)
            }
            .store(in: &cancellables)
        
        $processingFPS
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.processingFPS)
            }
            .store(in: &cancellables)
        
        $imageQualityThreshold
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.imageQualityThreshold)
            }
            .store(in: &cancellables)
        
        $autoCaptureEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.autoCaptureEnabled)
            }
            .store(in: &cancellables)
        
        $soundEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.soundEnabled)
            }
            .store(in: &cancellables)
        
        $hapticFeedbackEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.hapticFeedbackEnabled)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration Methods
    
    /// Updates confidence threshold for auto-capture
    /// - Parameter threshold: New confidence threshold (0.0 to 1.0)
    func updateConfidenceThreshold(_ threshold: Float) {
        confidenceThreshold = max(0.0, min(1.0, threshold))
    }
    
    /// Updates processing FPS
    /// - Parameter fps: New FPS value (1 to 30)
    func updateProcessingFPS(_ fps: Int) {
        processingFPS = max(1, min(30, fps))
    }
    
    /// Updates image quality threshold
    /// - Parameter threshold: New quality threshold (0.0 to 1.0)
    func updateImageQualityThreshold(_ threshold: Float) {
        imageQualityThreshold = max(0.0, min(1.0, threshold))
    }
    
    /// Resets all configuration to default values
    func resetToDefaults() {
        confidenceThreshold = 0.8
        processingFPS = 10
        imageQualityThreshold = 0.7
        autoCaptureEnabled = true
        soundEnabled = true
        hapticFeedbackEnabled = true
    }
    
    // MARK: - Model Configuration
    
    /// Gets model configuration for CoreML inference
    /// - Returns: Dictionary of model configuration parameters
    func getModelConfiguration() -> [String: Any] {
        return [
            "confidenceThreshold": confidenceThreshold,
            "processingFPS": processingFPS,
            "imageQualityThreshold": imageQualityThreshold,
            "autoCaptureEnabled": autoCaptureEnabled
        ]
    }
    
    /// Gets camera configuration
    /// - Returns: Dictionary of camera configuration parameters
    func getCameraConfiguration() -> [String: Any] {
        return [
            "processingFPS": processingFPS,
            "imageQualityThreshold": imageQualityThreshold,
            "autoCaptureEnabled": autoCaptureEnabled
        ]
    }
    
    // MARK: - Performance Configuration
    
    /// Gets performance configuration
    /// - Returns: Dictionary of performance configuration parameters
    func getPerformanceConfiguration() -> [String: Any] {
        return [
            "processingFPS": processingFPS,
            "confidenceThreshold": confidenceThreshold,
            "imageQualityThreshold": imageQualityThreshold
        ]
    }
    
    /// Checks if current configuration is optimal for performance
    /// - Returns: True if configuration is optimized
    func isConfigurationOptimal() -> Bool {
        return processingFPS >= 5 && 
               processingFPS <= 15 && 
               confidenceThreshold >= 0.7 && 
               confidenceThreshold <= 0.9 &&
               imageQualityThreshold >= 0.6
    }
    
    // MARK: - Export/Import Configuration
    
    /// Exports current configuration as JSON
    /// - Returns: JSON data representation of configuration
    func exportConfiguration() -> Data? {
        let configuration = [
            "confidenceThreshold": confidenceThreshold,
            "processingFPS": processingFPS,
            "imageQualityThreshold": imageQualityThreshold,
            "autoCaptureEnabled": autoCaptureEnabled,
            "soundEnabled": soundEnabled,
            "hapticFeedbackEnabled": hapticFeedbackEnabled
        ]
        
        return try? JSONSerialization.data(withJSONObject: configuration, options: .prettyPrinted)
    }
    
    /// Imports configuration from JSON data
    /// - Parameter data: JSON data containing configuration
    /// - Returns: True if import was successful
    func importConfiguration(from data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }
        
        if let threshold = json["confidenceThreshold"] as? Float {
            confidenceThreshold = threshold
        }
        
        if let fps = json["processingFPS"] as? Int {
            processingFPS = fps
        }
        
        if let quality = json["imageQualityThreshold"] as? Float {
            imageQualityThreshold = quality
        }
        
        if let autoCapture = json["autoCaptureEnabled"] as? Bool {
            autoCaptureEnabled = autoCapture
        }
        
        if let sound = json["soundEnabled"] as? Bool {
            soundEnabled = sound
        }
        
        if let haptic = json["hapticFeedbackEnabled"] as? Bool {
            hapticFeedbackEnabled = haptic
        }
        
        return true
    }
}

// MARK: - Configuration Validation
extension ConfigurationService {
    
    /// Validates current configuration
    /// - Returns: Array of validation issues, empty if valid
    func validateConfiguration() -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        
        if confidenceThreshold < 0.5 {
            issues.append(.confidenceTooLow)
        }
        
        if confidenceThreshold > 0.95 {
            issues.append(.confidenceTooHigh)
        }
        
        if processingFPS < 5 {
            issues.append(.fpsTooLow)
        }
        
        if processingFPS > 30 {
            issues.append(.fpsTooHigh)
        }
        
        if imageQualityThreshold < 0.5 {
            issues.append(.qualityThresholdTooLow)
        }
        
        if imageQualityThreshold > 0.9 {
            issues.append(.qualityThresholdTooHigh)
        }
        
        return issues
    }
    
    enum ConfigurationIssue: String, CaseIterable {
        case confidenceTooLow = "Confidence threshold is too low"
        case confidenceTooHigh = "Confidence threshold is too high"
        case fpsTooLow = "Processing FPS is too low"
        case fpsTooHigh = "Processing FPS is too high"
        case qualityThresholdTooLow = "Image quality threshold is too low"
        case qualityThresholdTooHigh = "Image quality threshold is too high"
        
        var suggestion: String {
            switch self {
            case .confidenceTooLow:
                return "Increase confidence threshold to reduce false positives"
            case .confidenceTooHigh:
                return "Decrease confidence threshold to allow more captures"
            case .fpsTooLow:
                return "Increase FPS for better real-time performance"
            case .fpsTooHigh:
                return "Decrease FPS to reduce battery usage"
            case .qualityThresholdTooLow:
                return "Increase quality threshold for better image quality"
            case .qualityThresholdTooHigh:
                return "Decrease quality threshold to allow more captures"
            }
        }
    }
}
