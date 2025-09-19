import XCTest
@testable import Photo_Booth

final class VehiclePhotoBoothTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(1 + 1, 2)
    }
    
    @MainActor
    func testCoreMLModelLoading() async throws {
        // Test that the CoreML model loads successfully
        let modelManager = ModelManager()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        XCTAssertTrue(modelManager.isModelLoaded, "CoreML model should be loaded")
        XCTAssertNotNil(modelManager.visionModel, "Vision model should be available")
    }
    
    @MainActor
    func testCoreMLClassification() async throws {
        // Test CoreML classification with a sample image
        let modelManager = ModelManager()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Create a simple test image (1x1 pixel)
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        // Test classification
        let result = await modelManager.classifyVehicleAngle(from: testImage)
        
        // Verify we get a result (even if not accurate due to test image)
        XCTAssertNotNil(result.angle, "Classification should return an angle")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0, "Confidence should be non-negative")
        XCTAssertLessThanOrEqual(result.confidence, 1.0, "Confidence should be at most 1.0")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
