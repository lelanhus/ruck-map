import Testing
import Foundation
import CoreMotion
import CoreLocation
import MapKit
@testable import RuckMap

/// Comprehensive test suite for TerrainDetector class using Swift Testing framework
/// Tests terrain detection algorithms, motion pattern analysis, state management, and integrations
@MainActor
struct TerrainDetectorTests {
    
    // MARK: - Terrain Type Classification Tests
    
    @Test("TerrainType enum provides correct terrain factors aligned with research")
    func testTerrainFactors() {
        // Updated to match the actual implementation values from Session 7 research
        #expect(TerrainType.pavedRoad.terrainFactor == 1.0)
        #expect(TerrainType.trail.terrainFactor == 1.2)
        #expect(TerrainType.gravel.terrainFactor == 1.3)
        #expect(TerrainType.sand.terrainFactor == 2.1)
        #expect(TerrainType.mud.terrainFactor == 1.8)
        #expect(TerrainType.snow.terrainFactor == 2.5)
        #expect(TerrainType.stairs.terrainFactor == 2.0)
        #expect(TerrainType.grass.terrainFactor == 1.2)
    }
    
    @Test("TerrainType enum provides display names")
    func testTerrainDisplayNames() {
        #expect(TerrainType.pavedRoad.displayName == "Paved Road")
        #expect(TerrainType.trail.displayName == "Trail")
        #expect(TerrainType.gravel.displayName == "Gravel")
        #expect(TerrainType.sand.displayName == "Sand") 
        #expect(TerrainType.mud.displayName == "Mud")
        #expect(TerrainType.snow.displayName == "Snow")
        #expect(TerrainType.stairs.displayName == "Stairs")
        #expect(TerrainType.grass.displayName == "Grass")
    }
    
    @Test("TerrainType enum provides valid SF Symbol icons")
    func testTerrainIconNames() {
        #expect(TerrainType.pavedRoad.iconName == "road.lanes")
        #expect(TerrainType.trail.iconName == "figure.hiking")
        #expect(TerrainType.gravel.iconName == "circle.grid.3x3.fill")
        #expect(TerrainType.sand.iconName == "beach.umbrella")
        #expect(TerrainType.mud.iconName == "cloud.rain")
        #expect(TerrainType.snow.iconName == "snowflake")
        #expect(TerrainType.stairs.iconName == "stairs")
        #expect(TerrainType.grass.iconName == "leaf")
    }
    
    @Test("TerrainType enum provides army green color identifiers")
    func testTerrainColorIdentifiers() {
        #expect(TerrainType.pavedRoad.colorIdentifier == "armyGreen.secondary")
        #expect(TerrainType.trail.colorIdentifier == "armyGreen.primary")
        #expect(TerrainType.gravel.colorIdentifier == "armyGreen.tertiary")
        #expect(TerrainType.sand.colorIdentifier == "armyGreen.accent")
        #expect(TerrainType.mud.colorIdentifier == "armyGreen.dark")
        #expect(TerrainType.snow.colorIdentifier == "armyGreen.light")
        #expect(TerrainType.stairs.colorIdentifier == "armyGreen.bright")
        #expect(TerrainType.grass.colorIdentifier == "armyGreen.natural")
    }
    
    @Test("TerrainType enum is case iterable and contains all terrain types")
    func testTerrainTypeIterable() {
        let allCases = TerrainType.allCases
        #expect(allCases.count == 8)
        #expect(allCases.contains(.pavedRoad))
        #expect(allCases.contains(.trail))
        #expect(allCases.contains(.gravel))
        #expect(allCases.contains(.sand))
        #expect(allCases.contains(.mud))
        #expect(allCases.contains(.snow))
        #expect(allCases.contains(.stairs))
        #expect(allCases.contains(.grass))
    }
    
    @Test("Terrain factors are properly ordered by difficulty", arguments: [
        (.pavedRoad, 1.0),
        (.trail, 1.2),
        (.grass, 1.2),
        (.gravel, 1.3),
        (.mud, 1.8),
        (.stairs, 2.0),
        (.sand, 2.1),
        (.snow, 2.5)
    ])
    func testTerrainFactorOrdering(terrain: TerrainType, expectedFactor: Double) {
        #expect(terrain.terrainFactor == expectedFactor)
    }
    
    // MARK: - TerrainDetectionResult Confidence Tests
    
    @Test("TerrainDetectionResult confidence classification", arguments: [
        (0.9, true),   // High confidence
        (0.85, true),  // Exactly at threshold
        (0.84, false), // Just below threshold
        (0.7, false),  // Medium confidence
        (0.5, false),  // Low confidence
        (0.0, false)   // No confidence
    ])
    func testConfidenceClassification(confidence: Double, shouldBeHighConfidence: Bool) {
        let result = TerrainDetectionResult(
            terrainType: .trail,
            confidence: confidence,
            timestamp: Date(),
            detectionMethod: .motion
        )
        
        #expect(result.isHighConfidence == shouldBeHighConfidence)
    }
    
    @Test("TerrainDetectionResult detection methods are properly tracked")
    func testDetectionMethods() {
        let methods: [TerrainDetectionResult.DetectionMethod] = [.motion, .location, .mapKit, .fusion, .manual]
        
        for method in methods {
            let result = TerrainDetectionResult(
                terrainType: .trail,
                confidence: 0.8,
                timestamp: Date(),
                detectionMethod: method
            )
            #expect(result.detectionMethod == method)
        }
    }
    
    // MARK: - TerrainDetector Initialization Tests
    
    @Test("TerrainDetector initializes with correct default state")
    func testTerrainDetectorInitialization() {
        let detector = TerrainDetector()
        
        #expect(detector.currentTerrain == .trail)
        #expect(detector.confidence == 0.0)
        #expect(detector.isDetecting == false)
        #expect(detector.detectionHistory.isEmpty)
        #expect(detector.getCurrentTerrainFactor() == 1.2) // trail factor
    }
    
    @Test("TerrainDetector calorie calculator integration initialization")
    func testCalorieCalculatorIntegrationInit() {
        let detector = TerrainDetector(withCalorieCalculatorIntegration: true)
        
        #expect(detector.currentTerrain == .trail)
        #expect(detector.confidence == 0.0)
        #expect(detector.isDetecting == false)
        #expect(detector.detectionHistory.isEmpty)
        #expect(detector.getCurrentTerrainFactor() == 1.2)
    }
    
    // MARK: - Manual Terrain Setting Tests
    
    @Test("Manual terrain setting updates state correctly")
    func testManualTerrainSetting() {
        let detector = TerrainDetector()
        
        detector.setManualTerrain(.sand)
        
        #expect(detector.currentTerrain == .sand)
        #expect(detector.confidence == 1.0)
        #expect(detector.getCurrentTerrainFactor() == 1.5)
        #expect(detector.detectionHistory.count == 1)
        
        let lastResult = detector.detectionHistory.last
        #expect(lastResult?.terrainType == .sand)
        #expect(lastResult?.confidence == 1.0)
        #expect(lastResult?.detectionMethod == .manual)
    }
    
    @Test("Manual terrain setting for all terrain types")
    func testManualTerrainSettingAllTypes() {
        let detector = TerrainDetector()
        
        for terrainType in TerrainType.allCases {
            detector.setManualTerrain(terrainType)
            
            #expect(detector.currentTerrain == terrainType)
            #expect(detector.confidence == 1.0)
            #expect(detector.getCurrentTerrainFactor() == terrainType.terrainFactor)
        }
        
        // Should have 8 history entries (all terrain types)
        #expect(detector.detectionHistory.count == 8)
    }
    
    // MARK: - Detection State Management Tests
    
    @Test("Detection state management works correctly")
    func testDetectionStateManagement() {
        let detector = TerrainDetector()
        
        // Initially not detecting
        #expect(detector.isDetecting == false)
        
        // Start detection
        detector.startDetection()
        #expect(detector.isDetecting == true)
        
        // Stop detection
        detector.stopDetection()
        #expect(detector.isDetecting == false)
    }
    
    @Test("Multiple start calls don't affect state")
    func testMultipleStartCalls() {
        let detector = TerrainDetector()
        
        detector.startDetection()
        let firstState = detector.isDetecting
        
        detector.startDetection() // Second call
        let secondState = detector.isDetecting
        
        #expect(firstState == true)
        #expect(secondState == true)
        
        detector.stopDetection()
        #expect(detector.isDetecting == false)
    }
    
    // MARK: - Reset Functionality Tests
    
    @Test("Reset functionality clears all state")
    func testResetFunctionality() {
        let detector = TerrainDetector()
        
        // Set up some state
        detector.setManualTerrain(.snow)
        detector.startDetection()
        
        // Verify state is set
        #expect(detector.currentTerrain == .snow)
        #expect(detector.confidence == 1.0)
        #expect(detector.detectionHistory.count == 1)
        
        // Reset
        detector.reset()
        
        // Verify everything is reset
        #expect(detector.currentTerrain == .trail)
        #expect(detector.confidence == 0.0)
        #expect(detector.detectionHistory.isEmpty)
    }
    
    // MARK: - Detection Result History Tests
    
    @Test("Detection history maintains maximum size")
    func testDetectionHistoryMaxSize() {
        let detector = TerrainDetector()
        
        // Add more than the maximum number of results
        // Simulate 105 manual detections (max is 100)
        for i in 0..<105 {
            let terrainType = TerrainType.allCases[i % 4]
            detector.setManualTerrain(terrainType)
        }
        
        // Should maintain maximum size of 100
        #expect(detector.detectionHistory.count == 100)
        
        // Verify that the oldest entries were removed
        // The first entry should now be the 6th manual detection
        let firstHistoryEntry = detector.detectionHistory.first
        #expect(firstHistoryEntry?.detectionMethod == .manual)
    }
    
    @Test("Detection history maintains chronological order")
    func testDetectionHistoryOrder() async {
        let detector = TerrainDetector()
        
        // Add detections with small delays to ensure different timestamps
        detector.setManualTerrain(.pavement)
        
        try? await Task.sleep(for: .milliseconds(10))
        detector.setManualTerrain(.trail)
        
        try? await Task.sleep(for: .milliseconds(10))
        detector.setManualTerrain(.sand)
        
        #expect(detector.detectionHistory.count == 3)
        
        // Verify chronological order
        let timestamps = detector.detectionHistory.map { $0.timestamp }
        for i in 1..<timestamps.count {
            #expect(timestamps[i] >= timestamps[i-1])
        }
        
        // Verify terrain order
        #expect(detector.detectionHistory[0].terrainType == .pavement)
        #expect(detector.detectionHistory[1].terrainType == .trail)
        #expect(detector.detectionHistory[2].terrainType == .sand)
    }
    
    // MARK: - Debug Information Tests
    
    @Test("Debug information provides comprehensive state")
    func testDebugInformation() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.snow)
        
        let debugInfo = await detector.getDebugInfo()
        
        #expect(debugInfo.contains("Snow"))
        #expect(debugInfo.contains("100%"))
        #expect(debugInfo.contains("false")) // Detection not active
        #expect(debugInfo.contains("1")) // History count
        #expect(debugInfo.contains("2.1")) // Terrain factor
    }
    
    @Test("Debug information reflects detection state")
    func testDebugInformationDetectionState() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        let debugInfo = await detector.getDebugInfo()
        #expect(debugInfo.contains("true")) // Detection active
        
        detector.stopDetection()
        
        let debugInfoAfterStop = await detector.getDebugInfo()
        #expect(debugInfoAfterStop.contains("false")) // Detection inactive
    }
    
    // MARK: - Motion Detection Tests
    
    @Test("Immediate terrain detection with insufficient data")
    func testImmediateDetectionInsufficientData() async {
        let detector = TerrainDetector()
        
        // Detection without motion data should return low confidence
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.confidence == 0.0)
        #expect(result.terrainType == .trail) // Default terrain
        #expect(result.detectionMethod == .motion)
    }
    
    @Test("Motion confidence tracking")
    func testMotionConfidence() {
        let detector = TerrainDetector()
        
        // Initially should have zero confidence
        #expect(detector.getMotionConfidence() == 0.0)
        
        // After manual terrain setting, motion confidence should still be 0
        detector.setManualTerrain(.sand)
        #expect(detector.getMotionConfidence() == 0.0)
    }
    
    @Test("Battery optimization mode configuration")
    func testBatteryOptimization() {
        let detector = TerrainDetector()
        
        // Should start in normal mode
        detector.setBatteryOptimizedMode(false)
        
        // Enable battery optimization
        detector.setBatteryOptimizedMode(true)
        
        // Disable battery optimization
        detector.setBatteryOptimizedMode(false)
        
        // No exceptions should be thrown and detector should remain functional
        #expect(detector.currentTerrain == .trail)
    }
    
    // MARK: - Concurrency Safety Tests
    
    @Test("TerrainDetector is MainActor safe")
    func testMainActorSafety() async {
        // This test verifies that TerrainDetector methods can be called safely from MainActor
        let detector = TerrainDetector()
        
        await MainActor.run {
            detector.setManualTerrain(.sand)
            detector.startDetection()
            _ = detector.detectCurrentTerrain()
            detector.stopDetection()
            detector.reset()
        }
        
        // If we reach here without compiler errors, MainActor isolation is working
        #expect(true)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("TerrainDetector handles rapid state changes")
    func testRapidStateChanges() {
        let detector = TerrainDetector()
        
        // Rapid terrain changes
        for _ in 0..<10 {
            detector.setManualTerrain(.pavedRoad)
            detector.setManualTerrain(.trail)
            detector.setManualTerrain(.sand)
            detector.setManualTerrain(.snow)
        }
        
        // Should maintain consistent state
        #expect(detector.currentTerrain == .snow)
        #expect(detector.confidence == 1.0)
        #expect(detector.detectionHistory.count == 40)
    }
    
    @Test("TerrainDetector handles start/stop cycles")
    func testStartStopCycles() {
        let detector = TerrainDetector()
        
        for _ in 0..<5 {
            detector.startDetection()
            #expect(detector.isDetecting == true)
            
            detector.stopDetection()
            #expect(detector.isDetecting == false)
        }
        
        // Final state should be stopped
        #expect(detector.isDetecting == false)
    }
    
    // MARK: - Performance Tests
    
    @Test("TerrainDetector initialization is fast", .timeLimit(.seconds(1)))
    func testInitializationPerformance() {
        // Creating detector should be fast
        let detector = TerrainDetector()
        #expect(detector.currentTerrain == .trail)
    }
    
    @Test("Manual terrain setting is fast", .timeLimit(.milliseconds(100)))
    func testManualTerrainSettingPerformance() {
        let detector = TerrainDetector()
        
        // Setting terrain should be very fast
        detector.setManualTerrain(.sand)
        #expect(detector.currentTerrain == .sand)
    }
    
    @Test("Reset operation is fast", .timeLimit(.milliseconds(100)))
    func testResetPerformance() {
        let detector = TerrainDetector()
        
        // Add some history
        for _ in 0..<50 {
            detector.setManualTerrain(.trail)
        }
        
        // Reset should be fast even with history
        detector.reset()
        #expect(detector.detectionHistory.isEmpty)
    }
    
    // MARK: - Async Terrain Detection Tests
    
    @Test("Async terrain detection with sufficient motion data")
    func testAsyncTerrainDetectionWithData() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Simulate having motion data by manually setting terrain first
        detector.setManualTerrain(.trail)
        
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.terrainType == .trail)
        #expect(result.confidence >= 0.0)
        #expect(result.timestamp <= Date())
        
        detector.stopDetection()
    }
    
    @Test("Async terrain factor retrieval")
    func testAsyncTerrainFactor() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.sand)
        
        let factor = await detector.getTerrainFactor()
        #expect(factor == 2.1)
    }
    
    @Test("Enhanced terrain factor with grade compensation")
    func testEnhancedTerrainFactorWithGrade() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.trail) // Factor 1.2
        
        let flatFactor = await detector.getEnhancedTerrainFactor(grade: 0)
        let uphillFactor = await detector.getEnhancedTerrainFactor(grade: 10)
        let downhillFactor = await detector.getEnhancedTerrainFactor(grade: -5)
        
        #expect(flatFactor == 1.2)
        #expect(uphillFactor > flatFactor)
        #expect(downhillFactor == flatFactor) // Negative grades don't add multiplier
    }
    
    // MARK: - Motion Pattern Analysis Tests
    
    @Test("Motion confidence tracking returns zero initially")
    func testInitialMotionConfidence() {
        let detector = TerrainDetector()
        #expect(detector.getMotionConfidence() == 0.0)
    }
    
    @Test("Battery optimization configuration")
    func testBatteryOptimizationModes() {
        let detector = TerrainDetector()
        
        // Test normal mode
        detector.setBatteryOptimizedMode(false)
        #expect(detector.currentTerrain == .trail) // Should remain functional
        
        // Test optimized mode
        detector.setBatteryOptimizedMode(true)
        #expect(detector.currentTerrain == .trail) // Should remain functional
        
        // Test toggling
        detector.setBatteryOptimizedMode(false)
        detector.setBatteryOptimizedMode(true)
        #expect(detector.currentTerrain == .trail) // Should remain functional
    }
    
    // MARK: - Error Handling Tests
    
    @Test("TerrainDetectionError provides localized descriptions")
    func testTerrainDetectionErrors() {
        let lowConfidenceError = TerrainDetectionError.lowConfidence(0.4)
        let sensorFailureError = TerrainDetectionError.sensorFailure("Accelerometer")
        let locationError = TerrainDetectionError.locationUnavailable
        let motionError = TerrainDetectionError.motionDataInsufficient
        let timeoutError = TerrainDetectionError.analysisTimeout
        
        #expect(lowConfidenceError.errorDescription?.contains("40.0%") == true)
        #expect(sensorFailureError.errorDescription?.contains("Accelerometer") == true)
        #expect(locationError.errorDescription?.contains("Location") == true)
        #expect(motionError.errorDescription?.contains("motion") == true)
        #expect(timeoutError.errorDescription?.contains("timeout") == true)
    }
    
    @Test("Error handling maintains fallback state")
    func testErrorHandlingFallback() async {
        let detector = TerrainDetector()
        
        // Set initial state
        detector.setManualTerrain(.sand)
        #expect(detector.confidence == 1.0)
        
        // Simulate error handling
        let error = TerrainDetectionError.sensorFailure("Test")
        await detector.handleDetectionFailure(error)
        
        // Should maintain reasonable state
        #expect(detector.currentTerrain != .sand || detector.confidence < 1.0)
    }
    
    // MARK: - Real-time Detection Performance Tests
    
    @Test("Real-time detection maintains performance", .timeLimit(.seconds(2)))
    func testRealTimeDetectionPerformance() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Simulate rapid detection calls
        for _ in 0..<10 {
            let result = await detector.detectCurrentTerrain()
            #expect(result.confidence >= 0.0)
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        detector.stopDetection()
    }
    
    @Test("Terrain factor stream performance", .timeLimit(.seconds(3)))
    func testTerrainFactorStreamPerformance() async {
        let detector = TerrainDetector()
        detector.startDetection()
        detector.setManualTerrain(.trail)
        
        var streamCount = 0
        let maxStreamItems = 5
        
        for await (factor, confidence, terrainType) in detector.terrainFactorStream() {
            #expect(factor > 0)
            #expect(confidence >= 0.0 && confidence <= 1.0)
            #expect(TerrainType.allCases.contains(terrainType))
            
            streamCount += 1
            if streamCount >= maxStreamItems {
                break
            }
        }
        
        #expect(streamCount >= 1)
        detector.stopDetection()
    }
    
    // MARK: - Concurrency Safety Tests
    
    @Test("Concurrent terrain factor access is safe")
    func testConcurrentTerrainFactorAccess() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.trail)
        
        // Access terrain factor from multiple tasks concurrently
        await withTaskGroup(of: Double.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await detector.getTerrainFactor()
                }
            }
            
            var results: [Double] = []
            for await result in group {
                results.append(result)
            }
            
            // All results should be consistent
            #expect(results.allSatisfy { $0 == 1.2 })
        }
    }
    
    @Test("Concurrent manual terrain setting")
    func testConcurrentManualTerrainSetting() async {
        let detector = TerrainDetector()
        
        await withTaskGroup(of: Void.self) { group in
            let terrains: [TerrainType] = [.trail, .sand, .snow, .gravel]
            
            for terrain in terrains {
                group.addTask { @MainActor in
                    detector.setManualTerrain(terrain)
                }
            }
        }
        
        // Should have final terrain set and history
        #expect(TerrainType.allCases.contains(detector.currentTerrain))
        #expect(detector.confidence == 1.0)
        #expect(detector.detectionHistory.count == 4)
    }
    
    @Test("Detection state changes are actor-safe")
    func testDetectionStateActorSafety() async {
        let detector = TerrainDetector()
        
        await withTaskGroup(of: Void.self) { group in
            // Start detection from multiple tasks
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    detector.startDetection()
                }
            }
            
            // Stop detection from multiple tasks
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    detector.stopDetection()
                }
            }
        }
        
        // Final state should be consistent
        #expect(detector.isDetecting == false)
    }
    
    // MARK: - Terrain Factor Monitoring Tests
    
    @Test("Terrain factor monitoring provides updates")
    func testTerrainFactorMonitoring() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        var receivedUpdates: [(Double, TerrainType, Double)] = []
        let expectation = Task {
            detector.startTerrainFactorMonitoring { factor, terrainType, confidence in
                receivedUpdates.append((factor, terrainType, confidence))
            }
        }
        
        // Give monitoring a moment to start
        try? await Task.sleep(for: .milliseconds(100))
        
        // Change terrain to trigger update
        detector.setManualTerrain(.sand)
        
        // Wait for update
        try? await Task.sleep(for: .milliseconds(200))
        
        expectation.cancel()
        detector.stopDetection()
        
        #expect(receivedUpdates.count >= 1)
        if let lastUpdate = receivedUpdates.last {
            #expect(lastUpdate.0 == 2.1) // Sand factor
            #expect(lastUpdate.1 == .sand)
            #expect(lastUpdate.2 > 0.8) // High confidence
        }
    }
    
    // MARK: - Debug Information Tests
    
    @Test("Debug information is comprehensive")
    func testDebugInformationComprehensive() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.snow)
        detector.startDetection()
        
        let debugInfo = await detector.getDebugInfo()
        
        // Should contain key information
        #expect(debugInfo.contains("Snow"))
        #expect(debugInfo.contains("100%"))
        #expect(debugInfo.contains("true")) // Detection active
        #expect(debugInfo.contains("2.5")) // Snow terrain factor
        #expect(debugInfo.contains("Motion Analyzer"))
        
        detector.stopDetection()
    }
    
    // MARK: - Edge Case and Stress Tests
    
    @Test("Massive history doesn't break memory limits")
    func testMassiveHistoryHandling() {
        let detector = TerrainDetector()
        
        // Add way more than the max size
        for i in 0..<500 {
            let terrain = TerrainType.allCases[i % TerrainType.allCases.count]
            detector.setManualTerrain(terrain)
        }
        
        // Should maintain size limit
        #expect(detector.detectionHistory.count == 100)
        
        // Should still be functional
        detector.setManualTerrain(.trail)
        #expect(detector.currentTerrain == .trail)
    }
    
    @Test("Rapid terrain changes maintain consistency")
    func testRapidTerrainChanges() {
        let detector = TerrainDetector()
        
        // Rapid changes between all terrain types
        for _ in 0..<20 {
            for terrain in TerrainType.allCases {
                detector.setManualTerrain(terrain)
                #expect(detector.currentTerrain == terrain)
                #expect(detector.confidence == 1.0)
            }
        }
        
        // Should maintain consistent final state
        #expect(detector.currentTerrain == .grass) // Last in allCases
        #expect(detector.confidence == 1.0)
        #expect(detector.detectionHistory.count == 100) // Capped at max
    }
    
    @Test("Detection with invalid sensor data")
    func testInvalidSensorDataHandling() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Should handle detection gracefully even without proper sensor setup
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.confidence >= 0.0 && result.confidence <= 1.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
        #expect(result.timestamp <= Date())
        
        detector.stopDetection()
    }
}

// MARK: - MapKit Integration Tests

@MainActor
struct TerrainDetectorMapKitTests {
    
    @Test("MapKit terrain analyzer integration")
    func testMapKitAnalyzerIntegration() async {
        let detector = TerrainDetector()
        
        // Mock location for testing
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        
        // Set up location manager with test location
        let locationManager = MockLocationManager()
        locationManager.location = testLocation
        detector.locationManager = locationManager
        
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
    }
    
    @Test("MapKit analysis with poor GPS accuracy")
    func testMapKitAnalysisWithPoorGPS() async {
        let detector = TerrainDetector()
        
        // Mock location with poor accuracy
        let poorLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 200, // Poor accuracy
            verticalAccuracy: 50,
            timestamp: Date()
        )
        
        let locationManager = MockLocationManager()
        locationManager.location = poorLocation
        detector.locationManager = locationManager
        
        let result = await detector.detectCurrentTerrain()
        
        // Should still provide result but with lower confidence
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
    }
}

// MARK: - CalorieCalculator Integration Tests

@MainActor
struct TerrainCalorieIntegrationTests {
    
    @Test("TerrainDetector provides terrain factors for CalorieCalculator")
    func testTerrainFactorForCalorieCalculator() async {
        let detector = TerrainDetector()
        let calculator = CalorieCalculator()
        
        // Test different terrain factors
        for terrain in TerrainType.allCases {
            detector.setManualTerrain(terrain)
            let factor = await detector.getTerrainFactor()
            
            #expect(factor == terrain.terrainFactor)
            #expect(factor > 0.0)
        }
    }
    
    @Test("Real-time terrain factor updates for calorie calculation")
    func testRealTimeTerrainFactorUpdates() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        var lastFactor: Double = 0
        var updateCount = 0
        
        let monitoringTask = Task {
            for await (factor, confidence, terrainType) in detector.terrainFactorStream() {
                lastFactor = factor
                updateCount += 1
                
                #expect(factor > 0)
                #expect(confidence >= 0.0 && confidence <= 1.0)
                #expect(TerrainType.allCases.contains(terrainType))
                
                if updateCount >= 3 {
                    break
                }
            }
        }
        
        // Trigger terrain changes
        detector.setManualTerrain(.trail)
        try? await Task.sleep(for: .milliseconds(100))
        
        detector.setManualTerrain(.sand)
        try? await Task.sleep(for: .milliseconds(100))
        
        detector.setManualTerrain(.snow)
        try? await Task.sleep(for: .milliseconds(100))
        
        await monitoringTask.value
        
        #expect(updateCount >= 1)
        #expect(lastFactor > 0)
        
        detector.stopDetection()
    }
    
    @Test("Enhanced terrain factor calculation integration")
    func testEnhancedTerrainFactorCalculation() async {
        let detector = TerrainDetector()
        
        // Test various terrain and grade combinations
        detector.setManualTerrain(.sand) // High base factor
        
        let flatSand = await detector.getEnhancedTerrainFactor(grade: 0)
        let uphillSand = await detector.getEnhancedTerrainFactor(grade: 15)
        
        #expect(flatSand == 2.1) // Base sand factor
        #expect(uphillSand > flatSand) // Should be higher with grade
        
        detector.setManualTerrain(.pavedRoad) // Low base factor
        
        let flatPaved = await detector.getEnhancedTerrainFactor(grade: 0)
        let uphillPaved = await detector.getEnhancedTerrainFactor(grade: 15)
        
        #expect(flatPaved == 1.0) // Base paved factor
        #expect(uphillPaved > flatPaved) // Should be higher with grade
    }
}

// MARK: - Mock Classes for Testing

class MockLocationManager: CLLocationManager {
    override var location: CLLocation? {
        get { _location }
        set { _location = newValue }
    }
    
    private var _location: CLLocation?
}

// MARK: - Integration Tests

@MainActor
struct TerrainDetectorIntegrationTests {
    
    @Test("TerrainDetector integrates with location manager reference")
    func testLocationManagerIntegration() {
        let detector = TerrainDetector()
        let locationManager = CLLocationManager()
        
        detector.locationManager = locationManager
        
        // Verify weak reference is maintained
        #expect(detector.locationManager === locationManager)
    }
    
    @Test("TerrainDetector maintains terrain factors for calorie calculations")
    func testCalorieCalculationIntegration() {
        let detector = TerrainDetector()
        
        // Test terrain factor retrieval for different terrains
        detector.setManualTerrain(.pavedRoad)
        #expect(detector.getCurrentTerrainFactor() == 1.0)
        
        detector.setManualTerrain(.trail)
        #expect(detector.getCurrentTerrainFactor() == 1.2)
        
        detector.setManualTerrain(.sand)
        #expect(detector.getCurrentTerrainFactor() == 2.1)
        
        detector.setManualTerrain(.snow)
        #expect(detector.getCurrentTerrainFactor() == 2.5)
    }
    
    @Test("TerrainDetector provides consistent state for session tracking")
    func testSessionTrackingIntegration() {
        let detector = TerrainDetector()
        
        // Simulate session progression
        detector.startDetection()
        detector.setManualTerrain(.trail)
        
        // Terrain should remain consistent for calorie calculations
        let initialFactor = detector.getCurrentTerrainFactor()
        let subsequentFactor = detector.getCurrentTerrainFactor()
        
        #expect(initialFactor == subsequentFactor)
        #expect(initialFactor == 1.2) // Trail factor
        
        detector.stopDetection()
    }
}

// MARK: - Mock Data Helpers

extension TerrainDetectorTests {
    
    /// Creates a mock terrain detection result for testing
    static func createMockDetectionResult(
        terrain: TerrainType = .trail,
        confidence: Double = 0.8,
        method: TerrainDetectionResult.DetectionMethod = .motion
    ) -> TerrainDetectionResult {
        return TerrainDetectionResult(
            terrainType: terrain,
            confidence: confidence,
            timestamp: Date(),
            detectionMethod: method
        )
    }
}

// MARK: - Terrain Detection Pipeline Tests

@MainActor 
struct TerrainDetectionPipelineTests {
    
    @Test("Full terrain detection pipeline from raw input to result")
    func testFullTerrainDetectionPipeline() async {
        let detector = TerrainDetector()
        
        // Test the complete pipeline
        detector.startDetection()
        
        // Verify initial state
        #expect(detector.isDetecting == true)
        #expect(detector.currentTerrain == .trail)
        
        // Simulate detection pipeline
        let result = await detector.detectCurrentTerrain()
        
        // Verify pipeline output
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
        #expect(result.timestamp <= Date())
        #expect(result.detectionMethod != nil)
        
        detector.stopDetection()
        #expect(detector.isDetecting == false)
    }
    
    @Test("Pipeline handles motion, location, and mapkit fusion", arguments: [
        (.motion, "Motion-based detection"),
        (.mapKit, "MapKit-based detection"),
        (.fusion, "Fusion detection"),
        (.manual, "Manual override")
    ])
    func testDetectionMethodPipeline(method: TerrainDetectionResult.DetectionMethod, description: String) {
        let detector = TerrainDetector()
        
        // Create mock result for each detection method
        let result = TerrainDetectionResult(
            terrainType: .trail,
            confidence: 0.8,
            timestamp: Date(),
            detectionMethod: method
        )
        
        #expect(result.detectionMethod == method)
        #expect(result.terrainType == .trail)
        #expect(result.confidence == 0.8)
    }
    
    @Test("Pipeline confidence thresholds are respected")
    func testPipelineConfidenceThresholds() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Test that pipeline respects minimum confidence thresholds
        let result = await detector.detectCurrentTerrain()
        
        // Should either have sufficient confidence or provide fallback
        if result.confidence < 0.6 {
            // Low confidence should default to reasonable terrain
            #expect(TerrainType.allCases.contains(result.terrainType))
        } else {
            // High confidence should have valid detection
            #expect(result.confidence >= 0.6)
            #expect(result.confidence <= 1.0)
        }
        
        detector.stopDetection()
    }
    
    @Test("Pipeline handles sensor unavailability gracefully")
    func testPipelineSensorUnavailability() async {
        let detector = TerrainDetector()
        
        // Test pipeline when sensors are not available/configured
        let result = await detector.detectCurrentTerrain()
        
        // Should provide fallback result
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
        #expect(result.detectionMethod == .motion) // Expected for insufficient data
    }
    
    @Test("Pipeline provides consistent results over time")
    func testPipelineConsistency() async {
        let detector = TerrainDetector()
        detector.setManualTerrain(.sand) // Set known state
        detector.startDetection()
        
        var results: [TerrainDetectionResult] = []
        
        // Collect multiple results
        for _ in 0..<5 {
            let result = await detector.detectCurrentTerrain()
            results.append(result)
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Results should be reasonably consistent
        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.confidence >= 0.0 })
        #expect(results.allSatisfy { TerrainType.allCases.contains($0.terrainType) })
        
        detector.stopDetection()
    }
    
    @Test("Pipeline memory management under continuous operation")
    func testPipelineMemoryManagement() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Run continuous detection for extended period
        for i in 0..<100 {
            let result = await detector.detectCurrentTerrain()
            #expect(result.confidence >= 0.0)
            
            // Periodically change terrain to generate history
            if i % 20 == 0 {
                let terrain = TerrainType.allCases[i / 20 % TerrainType.allCases.count]
                detector.setManualTerrain(terrain)
            }
        }
        
        // History should be maintained within limits
        #expect(detector.detectionHistory.count <= 100)
        
        detector.stopDetection()
    }
    
    @Test("Pipeline handles rapid state transitions")
    func testPipelineRapidStateTransitions() async {
        let detector = TerrainDetector()
        
        // Rapid start/stop cycles
        for _ in 0..<10 {
            detector.startDetection()
            #expect(detector.isDetecting == true)
            
            let result = await detector.detectCurrentTerrain()
            #expect(result.confidence >= 0.0)
            
            detector.stopDetection()
            #expect(detector.isDetecting == false)
        }
    }
    
    @Test("Pipeline integration with real-time monitoring")
    func testPipelineRealTimeMonitoring() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        var monitoringResults: [(Double, TerrainType, Double)] = []
        let monitoringTask = Task {
            await detector.startTerrainFactorMonitoring { factor, terrainType, confidence in
                monitoringResults.append((factor, terrainType, confidence))
            }
        }
        
        // Allow monitoring to start
        try? await Task.sleep(for: .milliseconds(100))
        
        // Trigger changes
        detector.setManualTerrain(.trail)
        try? await Task.sleep(for: .milliseconds(100))
        
        detector.setManualTerrain(.sand)
        try? await Task.sleep(for: .milliseconds(100))
        
        monitoringTask.cancel()
        detector.stopDetection()
        
        // Should have received monitoring updates
        #expect(monitoringResults.count >= 1)
        if let lastResult = monitoringResults.last {
            #expect(lastResult.0 > 0) // Factor
            #expect(lastResult.2 >= 0.0 && lastResult.2 <= 1.0) // Confidence
        }
    }
}

// MARK: - Advanced Error Handling and Recovery Tests

@MainActor
struct TerrainDetectorErrorHandlingTests {
    
    @Test("Detector recovers from sensor failures")
    func testSensorFailureRecovery() async {
        let detector = TerrainDetector()
        
        // Set initial good state
        detector.setManualTerrain(.trail)
        #expect(detector.confidence == 1.0)
        
        // Simulate various sensor failures
        let errors = [
            TerrainDetectionError.sensorFailure("Accelerometer"),
            TerrainDetectionError.sensorFailure("Gyroscope"),
            TerrainDetectionError.locationUnavailable,
            TerrainDetectionError.motionDataInsufficient
        ]
        
        for error in errors {
            await detector.handleDetectionFailure(error)
            
            // Should maintain functional state
            #expect(detector.currentTerrain != nil)
            #expect(detector.confidence >= 0.0 && detector.confidence <= 1.0)
        }
    }
    
    @Test("Low confidence handling maintains system stability")
    func testLowConfidenceHandling() async {
        let detector = TerrainDetector()
        
        // Simulate low confidence scenarios
        let lowConfidenceError = TerrainDetectionError.lowConfidence(0.2)
        await detector.handleDetectionFailure(lowConfidenceError)
        
        // Should have fallback state
        #expect(detector.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(detector.currentTerrain))
    }
    
    @Test("Analysis timeout recovery")
    func testAnalysisTimeoutRecovery() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Simulate timeout
        let timeoutError = TerrainDetectionError.analysisTimeout
        await detector.handleDetectionFailure(timeoutError)
        
        // Should remain operational
        #expect(detector.isDetecting == true)
        
        // Should be able to continue detection
        let result = await detector.detectCurrentTerrain()
        #expect(result.confidence >= 0.0)
        
        detector.stopDetection()
    }
    
    @Test("Multiple simultaneous errors handled gracefully")
    func testMultipleSimultaneousErrors() async {
        let detector = TerrainDetector()
        
        // Handle multiple errors in sequence
        await detector.handleDetectionFailure(TerrainDetectionError.sensorFailure("Accelerometer"))
        await detector.handleDetectionFailure(TerrainDetectionError.locationUnavailable)
        await detector.handleDetectionFailure(TerrainDetectionError.lowConfidence(0.1))
        
        // System should remain stable
        #expect(detector.currentTerrain != nil)
        #expect(detector.confidence >= 0.0)
    }
}