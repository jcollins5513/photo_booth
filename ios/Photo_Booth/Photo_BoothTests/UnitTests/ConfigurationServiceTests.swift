import XCTest
import Combine
@testable import Photo_Booth

/// Unit tests for ConfigurationService
@MainActor
class ConfigurationServiceTests: XCTestCase {
    
    var configurationService: ConfigurationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        configurationService = ConfigurationService()
        cancellables = Set<AnyCancellable>()
        
        // Clear UserDefaults for clean tests
        UserDefaults.standard.removeObject(forKey: "confidenceThreshold")
        UserDefaults.standard.removeObject(forKey: "processingFPS")
        UserDefaults.standard.removeObject(forKey: "imageQualityThreshold")
        UserDefaults.standard.removeObject(forKey: "autoCaptureEnabled")
        UserDefaults.standard.removeObject(forKey: "soundEnabled")
        UserDefaults.standard.removeObject(forKey: "hapticFeedbackEnabled")
    }
    
    override func tearDown() {
        configurationService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(configurationService)
        XCTAssertEqual(configurationService.confidenceThreshold, 0.8)
        XCTAssertEqual(configurationService.processingFPS, 10)
        XCTAssertEqual(configurationService.imageQualityThreshold, 0.7)
        XCTAssertTrue(configurationService.autoCaptureEnabled)
        XCTAssertTrue(configurationService.soundEnabled)
        XCTAssertTrue(configurationService.hapticFeedbackEnabled)
    }
    
    // MARK: - Configuration Updates Tests
    
    func testUpdateConfidenceThreshold() {
        // Given
        let newThreshold: Float = 0.9
        
        // When
        configurationService.updateConfidenceThreshold(newThreshold)
        
        // Then
        XCTAssertEqual(configurationService.confidenceThreshold, newThreshold)
    }
    
    func testUpdateConfidenceThresholdWithClamping() {
        // Given
        let tooHighThreshold: Float = 1.5
        let tooLowThreshold: Float = -0.5
        
        // When
        configurationService.updateConfidenceThreshold(tooHighThreshold)
        XCTAssertEqual(configurationService.confidenceThreshold, 1.0)
        
        configurationService.updateConfidenceThreshold(tooLowThreshold)
        XCTAssertEqual(configurationService.confidenceThreshold, 0.0)
    }
    
    func testUpdateProcessingFPS() {
        // Given
        let newFPS = 15
        
        // When
        configurationService.updateProcessingFPS(newFPS)
        
        // Then
        XCTAssertEqual(configurationService.processingFPS, newFPS)
    }
    
    func testUpdateProcessingFPSWithClamping() {
        // Given
        let tooHighFPS = 50
        let tooLowFPS = 0
        
        // When
        configurationService.updateProcessingFPS(tooHighFPS)
        XCTAssertEqual(configurationService.processingFPS, 30)
        
        configurationService.updateProcessingFPS(tooLowFPS)
        XCTAssertEqual(configurationService.processingFPS, 1)
    }
    
    func testUpdateImageQualityThreshold() {
        // Given
        let newThreshold: Float = 0.8
        
        // When
        configurationService.updateImageQualityThreshold(newThreshold)
        
        // Then
        XCTAssertEqual(configurationService.imageQualityThreshold, newThreshold)
    }
    
    func testUpdateImageQualityThresholdWithClamping() {
        // Given
        let tooHighThreshold: Float = 1.5
        let tooLowThreshold: Float = -0.5
        
        // When
        configurationService.updateImageQualityThreshold(tooHighThreshold)
        XCTAssertEqual(configurationService.imageQualityThreshold, 1.0)
        
        configurationService.updateImageQualityThreshold(tooLowThreshold)
        XCTAssertEqual(configurationService.imageQualityThreshold, 0.0)
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() {
        // Given
        configurationService.confidenceThreshold = 0.9
        configurationService.processingFPS = 15
        configurationService.imageQualityThreshold = 0.8
        configurationService.autoCaptureEnabled = false
        configurationService.soundEnabled = false
        configurationService.hapticFeedbackEnabled = false
        
        // When
        configurationService.resetToDefaults()
        
        // Then
        XCTAssertEqual(configurationService.confidenceThreshold, 0.8)
        XCTAssertEqual(configurationService.processingFPS, 10)
        XCTAssertEqual(configurationService.imageQualityThreshold, 0.7)
        XCTAssertTrue(configurationService.autoCaptureEnabled)
        XCTAssertTrue(configurationService.soundEnabled)
        XCTAssertTrue(configurationService.hapticFeedbackEnabled)
    }
    
    // MARK: - Configuration Getters Tests
    
    func testGetModelConfiguration() {
        // Given
        configurationService.confidenceThreshold = 0.9
        configurationService.processingFPS = 15
        configurationService.imageQualityThreshold = 0.8
        configurationService.autoCaptureEnabled = true
        
        // When
        let config = configurationService.getModelConfiguration()
        
        // Then
        XCTAssertEqual(config["confidenceThreshold"] as? Float, 0.9)
        XCTAssertEqual(config["processingFPS"] as? Int, 15)
        XCTAssertEqual(config["imageQualityThreshold"] as? Float, 0.8)
        XCTAssertEqual(config["autoCaptureEnabled"] as? Bool, true)
    }
    
    func testGetCameraConfiguration() {
        // Given
        configurationService.processingFPS = 12
        configurationService.imageQualityThreshold = 0.75
        configurationService.autoCaptureEnabled = false
        
        // When
        let config = configurationService.getCameraConfiguration()
        
        // Then
        XCTAssertEqual(config["processingFPS"] as? Int, 12)
        XCTAssertEqual(config["imageQualityThreshold"] as? Float, 0.75)
        XCTAssertEqual(config["autoCaptureEnabled"] as? Bool, false)
    }
    
    func testGetPerformanceConfiguration() {
        // Given
        configurationService.processingFPS = 8
        configurationService.confidenceThreshold = 0.85
        configurationService.imageQualityThreshold = 0.65
        
        // When
        let config = configurationService.getPerformanceConfiguration()
        
        // Then
        XCTAssertEqual(config["processingFPS"] as? Int, 8)
        XCTAssertEqual(config["confidenceThreshold"] as? Float, 0.85)
        XCTAssertEqual(config["imageQualityThreshold"] as? Float, 0.65)
    }
    
    // MARK: - Optimization Tests
    
    func testIsConfigurationOptimal() {
        // Given - Optimal configuration
        configurationService.processingFPS = 10
        configurationService.confidenceThreshold = 0.8
        configurationService.imageQualityThreshold = 0.7
        
        // When
        let isOptimal = configurationService.isConfigurationOptimal()
        
        // Then
        XCTAssertTrue(isOptimal)
    }
    
    func testIsConfigurationNotOptimal() {
        // Given - Non-optimal configuration
        configurationService.processingFPS = 3 // Too low
        configurationService.confidenceThreshold = 0.5 // Too low
        configurationService.imageQualityThreshold = 0.4 // Too low
        
        // When
        let isOptimal = configurationService.isConfigurationOptimal()
        
        // Then
        XCTAssertFalse(isOptimal)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportConfiguration() {
        // Given
        configurationService.confidenceThreshold = 0.9
        configurationService.processingFPS = 15
        configurationService.imageQualityThreshold = 0.8
        configurationService.autoCaptureEnabled = false
        configurationService.soundEnabled = false
        configurationService.hapticFeedbackEnabled = false
        
        // When
        let exportData = configurationService.exportConfiguration()
        
        // Then
        XCTAssertNotNil(exportData)
        
        if let data = exportData,
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            XCTAssertEqual(json["confidenceThreshold"] as? Float, 0.9)
            XCTAssertEqual(json["processingFPS"] as? Int, 15)
            XCTAssertEqual(json["imageQualityThreshold"] as? Float, 0.8)
            XCTAssertEqual(json["autoCaptureEnabled"] as? Bool, false)
            XCTAssertEqual(json["soundEnabled"] as? Bool, false)
            XCTAssertEqual(json["hapticFeedbackEnabled"] as? Bool, false)
        }
    }
    
    func testImportConfiguration() {
        // Given
        let configData: [String: Any] = [
            "confidenceThreshold": 0.9,
            "processingFPS": 15,
            "imageQualityThreshold": 0.8,
            "autoCaptureEnabled": false,
            "soundEnabled": false,
            "hapticFeedbackEnabled": false
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: configData, options: [])
        
        // When
        let success = configurationService.importConfiguration(from: data)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(configurationService.confidenceThreshold, 0.9)
        XCTAssertEqual(configurationService.processingFPS, 15)
        XCTAssertEqual(configurationService.imageQualityThreshold, 0.8)
        XCTAssertFalse(configurationService.autoCaptureEnabled)
        XCTAssertFalse(configurationService.soundEnabled)
        XCTAssertFalse(configurationService.hapticFeedbackEnabled)
    }
    
    func testImportConfigurationWithInvalidData() {
        // Given
        let invalidData = "invalid json".data(using: .utf8)!
        
        // When
        let success = configurationService.importConfiguration(from: invalidData)
        
        // Then
        XCTAssertFalse(success)
    }
    
    // MARK: - Validation Tests
    
    func testValidateConfiguration() {
        // Given - Valid configuration
        configurationService.confidenceThreshold = 0.8
        configurationService.processingFPS = 10
        configurationService.imageQualityThreshold = 0.7
        
        // When
        let issues = configurationService.validateConfiguration()
        
        // Then
        XCTAssertTrue(issues.isEmpty)
    }
    
    func testValidateConfigurationWithIssues() {
        // Given - Invalid configuration
        configurationService.confidenceThreshold = 0.3 // Too low
        configurationService.processingFPS = 2 // Too low
        configurationService.imageQualityThreshold = 0.3 // Too low
        
        // When
        let issues = configurationService.validateConfiguration()
        
        // Then
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains(.confidenceTooLow))
        XCTAssertTrue(issues.contains(.fpsTooLow))
        XCTAssertTrue(issues.contains(.qualityThresholdTooLow))
    }
    
    // MARK: - Configuration Issue Tests
    
    func testConfigurationIssueDisplayNames() {
        // Test all configuration issue display names
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.confidenceTooLow.displayName, "Confidence threshold is too low")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.confidenceTooHigh.displayName, "Confidence threshold is too high")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.fpsTooLow.displayName, "Processing FPS is too low")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.fpsTooHigh.displayName, "Processing FPS is too high")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.qualityThresholdTooLow.displayName, "Image quality threshold is too low")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.qualityThresholdTooHigh.displayName, "Image quality threshold is too high")
    }
    
    func testConfigurationIssueSuggestions() {
        // Test configuration issue suggestions
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.confidenceTooLow.suggestion, "Increase confidence threshold to reduce false positives")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.confidenceTooHigh.suggestion, "Decrease confidence threshold to allow more captures")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.fpsTooLow.suggestion, "Increase FPS for better real-time performance")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.fpsTooHigh.suggestion, "Decrease FPS to reduce battery usage")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.qualityThresholdTooLow.suggestion, "Increase quality threshold for better image quality")
        XCTAssertEqual(ConfigurationService.ConfigurationIssue.qualityThresholdTooHigh.suggestion, "Decrease quality threshold to allow more captures")
    }
    
    // MARK: - Publisher Tests
    
    func testConfigurationPublishers() {
        // Given
        let expectation = XCTestExpectation(description: "Configuration updates")
        expectation.expectedFulfillmentCount = 3
        
        // When
        configurationService.$confidenceThreshold
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        configurationService.$processingFPS
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        configurationService.$imageQualityThreshold
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger updates
        configurationService.confidenceThreshold = 0.9
        configurationService.processingFPS = 15
        configurationService.imageQualityThreshold = 0.8
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
}
