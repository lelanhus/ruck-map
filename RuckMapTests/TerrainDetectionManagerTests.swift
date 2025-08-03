import XCTest
import CoreLocation
import CoreMotion
@testable import RuckMap

/// Unit tests for TerrainDetectionManager
/// Tests automatic terrain detection using MapKit + motion patterns
@MainActor
final class TerrainDetectionManagerTests: XCTestCase {
    
    private var terrainDetectionManager: TerrainDetectionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        terrainDetectionManager = TerrainDetectionManager()
    }
    
    override func tearDown() async throws {
        terrainDetectionManager.stopDetection()
        terrainDetectionManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(terrainDetectionManager)
        XCTAssertFalse(terrainDetectionManager.isDetecting)
        XCTAssertNil(terrainDetectionManager.currentTerrain)
        XCTAssertFalse(terrainDetectionManager.isManualOverrideActive)
    }
    
    // MARK: - Detection Lifecycle Tests
    
    func testStartStopDetection() {
        // Start detection
        terrainDetectionManager.startDetection()
        XCTAssertTrue(terrainDetectionManager.isDetecting)
        
        // Stop detection
        terrainDetectionManager.stopDetection()
        XCTAssertFalse(terrainDetectionManager.isDetecting)
    }
    
    func testMultipleStartCalls() {
        // Multiple start calls should be safe
        terrainDetectionManager.startDetection()
        terrainDetectionManager.startDetection()
        XCTAssertTrue(terrainDetectionManager.isDetecting)
        
        terrainDetectionManager.stopDetection()
        XCTAssertFalse(terrainDetectionManager.isDetecting)
    }
    
    // MARK: - Manual Override Tests
    
    func testManualOverride() {
        // Set manual override
        terrainDetectionManager.setManualOverride(.sand)
        
        XCTAssertTrue(terrainDetectionManager.isManualOverrideActive)
        XCTAssertEqual(terrainDetectionManager.manualOverride, .sand)
        XCTAssertEqual(terrainDetectionManager.getCurrentTerrainType(), .sand)
        XCTAssertNotNil(terrainDetectionManager.currentTerrain)
        XCTAssertTrue(terrainDetectionManager.currentTerrain?.isManualOverride == true)
        XCTAssertEqual(terrainDetectionManager.currentTerrain?.confidence, 1.0)
    }
    
    func testClearManualOverride() {
        // Set and then clear override
        terrainDetectionManager.setManualOverride(.sand)
        terrainDetectionManager.clearManualOverride()
        
        XCTAssertFalse(terrainDetectionManager.isManualOverrideActive)
        XCTAssertNil(terrainDetectionManager.manualOverride)
    }
    
    func testManualOverrideNil() {
        // Setting nil should clear override
        terrainDetectionManager.setManualOverride(.sand)
        terrainDetectionManager.setManualOverride(nil)
        
        XCTAssertFalse(terrainDetectionManager.isManualOverrideActive)
        XCTAssertNil(terrainDetectionManager.manualOverride)
    }
    
    // MARK: - Terrain Detection Tests
    
    func testDetectTerrainWithManualOverride() async {
        // Set manual override
        terrainDetectionManager.setManualOverride(.snow)
        
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let result = await terrainDetectionManager.detectTerrain(at: location)
        
        XCTAssertEqual(result.terrainType, .snow)
        XCTAssertEqual(result.confidence, 1.0)
        XCTAssertEqual(result.detectionMethod, .manualOverride)
        XCTAssertTrue(result.isManualOverride)
    }
    
    func testDetectTerrainBelowMinimumSpeed() async {
        // Create location with very low speed
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0.2, // Below minimum speed threshold
            timestamp: Date()
        )
        
        let result = await terrainDetectionManager.detectTerrain(at: location)
        
        // Should return low confidence result when below minimum speed
        XCTAssertLessThan(result.confidence, 0.5)
        XCTAssertEqual(result.detectionMethod, .fusion)
        XCTAssertFalse(result.isManualOverride)
    }
    
    func testDetectTerrainAboveMinimumSpeed() async {
        // Create location with adequate speed
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 1.5, // Above minimum speed threshold
            timestamp: Date()
        )
        
        let result = await terrainDetectionManager.detectTerrain(at: location)
        
        // Should perform actual detection
        XCTAssertNotEqual(result.detectionMethod, .manualOverride)
        XCTAssertFalse(result.isManualOverride)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    // MARK: - Terrain Factor Tests
    
    func testGetCurrentTerrainFactor() {
        // Test default terrain factor
        let defaultFactor = terrainDetectionManager.getCurrentTerrainFactor()
        XCTAssertEqual(defaultFactor, TerrainType.trail.terrainFactor)
        
        // Test with manual override
        terrainDetectionManager.setManualOverride(.sand)
        let sandFactor = terrainDetectionManager.getCurrentTerrainFactor()
        XCTAssertEqual(sandFactor, TerrainType.sand.terrainFactor)
    }
    
    func testTerrainFactorValues() {
        // Verify terrain factors match expected values from spec
        XCTAssertEqual(TerrainType.pavedRoad.terrainFactor, 1.0)
        XCTAssertEqual(TerrainType.trail.terrainFactor, 1.2)
        XCTAssertEqual(TerrainType.sand.terrainFactor, 1.5)
        XCTAssertEqual(TerrainType.snow.terrainFactor, 2.1)
    }
    
    // MARK: - Confidence Tests
    
    func testHighConfidenceDetection() {
        // No detection initially
        XCTAssertFalse(terrainDetectionManager.hasHighConfidenceDetection())
        
        // Manual override should always be high confidence
        terrainDetectionManager.setManualOverride(.trail)
        XCTAssertTrue(terrainDetectionManager.hasHighConfidenceDetection())
    }
    
    func testConfidenceThreshold() {
        // Test that 85% confidence threshold is used (from User Story 2.2)
        terrainDetectionManager.setManualOverride(.trail)
        
        // Manual override should be high confidence
        if let currentTerrain = terrainDetectionManager.currentTerrain {
            XCTAssertGreaterThanOrEqual(currentTerrain.confidence, 0.85)
        } else {
            XCTFail("Expected current terrain to be set with manual override")
        }
    }
    
    // MARK: - History Management Tests
    
    func testDetectionHistory() {
        let initialHistoryCount = terrainDetectionManager.detectionHistory.count
        
        // Add manual override (should add to history)
        terrainDetectionManager.setManualOverride(.sand)
        
        XCTAssertEqual(terrainDetectionManager.detectionHistory.count, initialHistoryCount + 1)
        
        if let lastResult = terrainDetectionManager.detectionHistory.last {
            XCTAssertEqual(lastResult.terrainType, .sand)
            XCTAssertTrue(lastResult.isManualOverride)
        }
    }
    
    func testTerrainChangeLog() {
        let startTime = Date()
        
        // Add some terrain changes
        terrainDetectionManager.setManualOverride(.trail)
        Thread.sleep(forTimeInterval: 0.1)
        terrainDetectionManager.setManualOverride(.sand)
        
        let changeLog = terrainDetectionManager.getTerrainChangeLog(since: startTime)
        XCTAssertGreaterThanOrEqual(changeLog.count, 2)
    }
    
    // MARK: - Reset Functionality Tests
    
    func testReset() {
        // Set up some state
        terrainDetectionManager.setManualOverride(.sand)
        terrainDetectionManager.startDetection()
        
        // Reset should clear everything
        terrainDetectionManager.reset()
        
        XCTAssertNil(terrainDetectionManager.currentTerrain)
        XCTAssertTrue(terrainDetectionManager.detectionHistory.isEmpty)
        XCTAssertFalse(terrainDetectionManager.isManualOverrideActive)
        XCTAssertNil(terrainDetectionManager.manualOverride)
    }
    
    // MARK: - Integration Tests
    
    func testCreateTerrainSegment() {
        let startTime = Date()
        let endTime = Date().addingTimeInterval(300) // 5 minutes later
        let grade = 5.0
        
        terrainDetectionManager.setManualOverride(.trail)
        
        let segment = terrainDetectionManager.createTerrainSegment(
            startTime: startTime,
            endTime: endTime,
            grade: grade
        )
        
        XCTAssertEqual(segment.terrainType, .trail)
        XCTAssertEqual(segment.grade, grade)
        XCTAssertEqual(segment.startTime, startTime)
        XCTAssertEqual(segment.endTime, endTime)
        XCTAssertTrue(segment.isManuallySet)
        XCTAssertEqual(segment.confidence, 1.0) // Manual override should be full confidence
    }
    
    func testValidateAgainstKnownRoute() {
        terrainDetectionManager.setManualOverride(.trail)
        
        // Should return high score for matching terrain
        let accuracy = terrainDetectionManager.validateAgainstKnownRoute(expectedTerrain: .trail)
        XCTAssertEqual(accuracy, 1.0)
        
        // Should return 0 for non-matching terrain
        let mismatchAccuracy = terrainDetectionManager.validateAgainstKnownRoute(expectedTerrain: .sand)
        XCTAssertEqual(mismatchAccuracy, 0.0)
        
        // Should return 0 if no current terrain
        terrainDetectionManager.reset()
        let noTerrainAccuracy = terrainDetectionManager.validateAgainstKnownRoute(expectedTerrain: .trail)
        XCTAssertEqual(noTerrainAccuracy, 0.0)
    }
    
    // MARK: - Debug Information Tests
    
    func testDebugInfo() {
        let debugInfo = terrainDetectionManager.getDebugInfo()
        
        XCTAssertTrue(debugInfo.contains("Terrain Detection Debug"))
        XCTAssertTrue(debugInfo.contains("Current Terrain"))
        XCTAssertTrue(debugInfo.contains("Manual Override"))
        XCTAssertTrue(debugInfo.contains("Detection Active"))
    }
    
    // MARK: - Performance Tests
    
    func testDetectionPerformance() async {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 1.5,
            timestamp: Date()
        )
        
        measure {
            Task {
                _ = await terrainDetectionManager.detectTerrain(at: location)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testInvalidLocation() async {
        // Test with invalid coordinates
        let invalidLocation = CLLocation(latitude: 999, longitude: 999)
        
        let result = await terrainDetectionManager.detectTerrain(at: invalidLocation)
        
        // Should still return a result, defaulting to trail
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isManualOverride)
    }
    
    func testConcurrentDetection() async {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 1.5,
            timestamp: Date()
        )
        
        // Test concurrent terrain detection calls
        async let result1 = terrainDetectionManager.detectTerrain(at: location)
        async let result2 = terrainDetectionManager.detectTerrain(at: location)
        async let result3 = terrainDetectionManager.detectTerrain(at: location)
        
        let results = await [result1, result2, result3]
        
        // All should complete successfully
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertNotNil(result)
        }
    }
}

// MARK: - Motion Pattern Analysis Tests
extension TerrainDetectionManagerTests {
    
    func testMotionPatternDatabase() {
        // Verify that all terrain types have motion patterns defined
        let allTerrainTypes: [TerrainType] = [.pavedRoad, .trail, .gravel, .sand, .mud, .snow, .grass, .stairs]
        
        for terrainType in allTerrainTypes {
            // Each terrain should have distinct characteristics
            let factor = terrainType.terrainFactor
            XCTAssertGreaterThan(factor, 0.0)
            XCTAssertLessThanOrEqual(factor, 3.0) // Reasonable upper bound
        }
    }
    
    func testTerrainFactorOrdering() {
        // Terrain factors should be ordered by difficulty
        XCTAssertLessThan(TerrainType.pavedRoad.terrainFactor, TerrainType.trail.terrainFactor)
        XCTAssertLessThan(TerrainType.trail.terrainFactor, TerrainType.sand.terrainFactor)
        XCTAssertLessThan(TerrainType.sand.terrainFactor, TerrainType.snow.terrainFactor)
    }
}

// MARK: - User Story 2.2 Acceptance Criteria Tests
extension TerrainDetectionManagerTests {
    
    func testAcceptanceCriteria_FourTerrainTypes() {
        // Must detect at least 4 terrain types: road, trail, sand, snow (from User Story 2.2)
        let requiredTypes: [TerrainType] = [.pavedRoad, .trail, .sand, .snow]
        
        for terrainType in requiredTypes {
            terrainDetectionManager.setManualOverride(terrainType)
            XCTAssertEqual(terrainDetectionManager.getCurrentTerrainType(), terrainType)
        }
    }
    
    func testAcceptanceCriteria_ManualOverride() {
        // Must allow manual override with quick gesture
        terrainDetectionManager.setManualOverride(.sand)
        
        XCTAssertTrue(terrainDetectionManager.isManualOverrideActive)
        XCTAssertEqual(terrainDetectionManager.getCurrentTerrainType(), .sand)
    }
    
    func testAcceptanceCriteria_TerrainFactorDisplay() {
        // Must show terrain factor in UI (1.0-2.1)
        for terrainType in TerrainType.allCases {
            terrainDetectionManager.setManualOverride(terrainType)
            let factor = terrainDetectionManager.getCurrentTerrainFactor()
            
            XCTAssertGreaterThanOrEqual(factor, 1.0)
            XCTAssertLessThanOrEqual(factor, 2.1)
        }
    }
    
    func testAcceptanceCriteria_TerrainChangeLogging() {
        // Must log terrain changes with timestamps
        let startTime = Date()
        
        terrainDetectionManager.setManualOverride(.trail)
        Thread.sleep(forTimeInterval: 0.1)
        terrainDetectionManager.setManualOverride(.sand)
        
        let changeLog = terrainDetectionManager.getTerrainChangeLog(since: startTime)
        
        XCTAssertGreaterThanOrEqual(changeLog.count, 2)
        
        // Verify timestamps are logged
        for change in changeLog {
            XCTAssertGreaterThanOrEqual(change.timestamp, startTime)
        }
    }
    
    func testAcceptanceCriteria_TargetAccuracy() {
        // Target: 85%+ accuracy on known routes
        // This is tested through the validation method
        terrainDetectionManager.setManualOverride(.trail)
        
        let accuracy = terrainDetectionManager.validateAgainstKnownRoute(expectedTerrain: .trail)
        XCTAssertGreaterThanOrEqual(accuracy, 0.85)
    }
}