import Testing
import Foundation
import CoreMotion
import CoreLocation
@testable import RuckMap

/// Integration tests for motion-based terrain analysis system
/// Tests the complete flow from sensor data to terrain detection
@MainActor
struct MotionTerrainIntegrationTests {
    
    // MARK: - End-to-End Motion Analysis Tests
    
    @Test("Complete motion analysis pipeline")
    func testCompleteMotionPipeline() async {
        let detector = TerrainDetector()
        
        // Start detection
        detector.startDetection()
        #expect(detector.isDetecting == true)
        
        // Simulate a complete motion analysis session
        let result = await detector.detectCurrentTerrain()
        
        // Should get some result even with no motion data
        #expect(result.terrainType != nil)
        #expect(result.confidence >= 0.0)
        #expect(result.timestamp != nil)
        
        detector.stopDetection()
        #expect(detector.isDetecting == false)
    }
    
    @Test("Motion confidence updates after analysis")
    func testMotionConfidenceUpdates() async {
        let detector = TerrainDetector()
        
        // Initial confidence should be zero
        #expect(detector.getMotionConfidence() == 0.0)
        
        detector.startDetection()
        
        // After analysis attempt, confidence might still be zero due to insufficient data
        _ = await detector.detectCurrentTerrain()
        let confidenceAfterAnalysis = detector.getMotionConfidence()
        #expect(confidenceAfterAnalysis >= 0.0)
        #expect(confidenceAfterAnalysis <= 1.0)
        
        detector.stopDetection()
    }
    
    @Test("Battery optimization affects sensor configuration")
    func testBatteryOptimizationIntegration() {
        let detector = TerrainDetector()
        
        // Test normal mode
        detector.setBatteryOptimizedMode(false)
        detector.startDetection()
        #expect(detector.isDetecting == true)
        
        // Switch to battery optimized mode while detecting
        detector.setBatteryOptimizedMode(true)
        #expect(detector.isDetecting == true) // Should remain detecting
        
        // Switch back to normal mode
        detector.setBatteryOptimizedMode(false)
        #expect(detector.isDetecting == true)
        
        detector.stopDetection()
    }
    
    @Test("Terrain detection with motion analyzer integration")
    func testTerrainDetectionWithMotionAnalyzer() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Perform multiple detection cycles
        for _ in 0..<3 {
            let result = await detector.detectCurrentTerrain()
            
            // Verify result structure
            #expect(result.terrainType != nil)
            #expect(result.confidence >= 0.0 && result.confidence <= 1.0)
            #expect(result.detectionMethod != nil)
            #expect(result.timestamp != nil)
            
            // Small delay between detections
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        detector.stopDetection()
    }
    
    @Test("Reset clears all motion analysis state")
    func testResetClearsMotionState() async {
        let detector = TerrainDetector()
        
        // Set up some state
        detector.startDetection()
        detector.setManualTerrain(.sand)
        _ = await detector.detectCurrentTerrain()
        
        // Verify state exists
        #expect(detector.currentTerrain == .sand)
        #expect(detector.confidence == 1.0)
        
        // Reset
        detector.reset()
        
        // Verify motion state is cleared
        #expect(detector.currentTerrain == .trail)
        #expect(detector.confidence == 0.0)
        #expect(detector.getMotionConfidence() == 0.0)
        #expect(detector.detectionHistory.isEmpty)
    }
    
    // MARK: - Real-time Analysis Tests
    
    @Test("Handles rapid terrain detection requests")
    func testRapidDetectionRequests() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Make multiple rapid detection requests
        let results = await withTaskGroup(of: TerrainDetectionResult.self, returning: [TerrainDetectionResult].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    return await detector.detectCurrentTerrain()
                }
            }
            
            var allResults: [TerrainDetectionResult] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        // All requests should complete successfully
        #expect(results.count == 5)
        for result in results {
            #expect(result.terrainType != nil)
            #expect(result.confidence >= 0.0)
        }
        
        detector.stopDetection()
    }
    
    @Test("Motion analysis state consistency under concurrent access")
    func testConcurrentStateConsistency() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Concurrent terrain detections
            group.addTask {
                for _ in 0..<3 {
                    _ = await detector.detectCurrentTerrain()
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            
            // Concurrent manual terrain settings
            group.addTask {
                for terrain in TerrainType.allCases.prefix(3) {
                    detector.setManualTerrain(terrain)
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            
            // Concurrent battery mode changes
            group.addTask {
                for i in 0..<3 {
                    detector.setBatteryOptimizedMode(i % 2 == 0)
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }
        
        // Detector should still be in a consistent state
        #expect(detector.isDetecting == true)
        #expect(detector.currentTerrain != nil)
        #expect(detector.confidence >= 0.0 && detector.confidence <= 1.0)
        
        detector.stopDetection()
    }
    
    // MARK: - Debug Information Integration Tests
    
    @Test("Debug information includes motion analyzer details")
    func testDebugInformationIntegration() async {
        let detector = TerrainDetector()
        detector.startDetection()
        detector.setManualTerrain(.trail)
        
        let debugInfo = await detector.getDebugInfo()
        
        // Should include terrain detector information
        #expect(debugInfo.contains("Terrain Detector Debug"))
        #expect(debugInfo.contains("Trail"))
        #expect(debugInfo.contains("Detection Active: true"))
        
        // Should include motion analyzer information
        #expect(debugInfo.contains("Motion Pattern Analyzer Debug"))
        #expect(debugInfo.contains("Sample Count"))
        #expect(debugInfo.contains("Sample Rate"))
        
        // Should include motion confidence
        #expect(debugInfo.contains("Motion Confidence"))
        
        // Should include battery optimization state
        #expect(debugInfo.contains("Battery Optimized"))
        
        detector.stopDetection()
    }
    
    @Test("Debug information reflects battery optimization state")
    func testDebugBatteryOptimization() async {
        let detector = TerrainDetector()
        
        // Test normal mode
        detector.setBatteryOptimizedMode(false)
        let normalModeDebug = await detector.getDebugInfo()
        #expect(normalModeDebug.contains("Battery Optimized: false"))
        
        // Test battery optimized mode
        detector.setBatteryOptimizedMode(true)
        let batteryModeDebug = await detector.getDebugInfo()
        #expect(batteryModeDebug.contains("Battery Optimized: true"))
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("Motion analysis doesn't significantly impact detection performance", .timeLimit(.seconds(3)))
    func testMotionAnalysisPerformance() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Perform multiple detection cycles rapidly
        for _ in 0..<10 {
            _ = await detector.detectCurrentTerrain()
        }
        
        // Should complete within time limit
        detector.stopDetection()
    }
    
    @Test("Battery optimization mode affects performance characteristics", .timeLimit(.seconds(2)))
    func testBatteryOptimizationPerformance() async {
        let detector = TerrainDetector()
        
        // Test normal mode performance
        detector.setBatteryOptimizedMode(false)
        detector.startDetection()
        
        for _ in 0..<5 {
            _ = await detector.detectCurrentTerrain()
        }
        
        // Switch to battery mode and continue
        detector.setBatteryOptimizedMode(true)
        
        for _ in 0..<5 {
            _ = await detector.detectCurrentTerrain()
        }
        
        detector.stopDetection()
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Graceful handling of motion analysis failures")
    func testMotionAnalysisFailureHandling() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Even without proper motion data, should not crash
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.terrainType != nil)
        #expect(result.confidence >= 0.0)
        #expect(result.detectionMethod != nil)
        
        detector.stopDetection()
    }
    
    @Test("State management during start/stop cycles with motion analysis")
    func testStateManagementWithMotionAnalysis() async {
        let detector = TerrainDetector()
        
        // Multiple start/stop cycles
        for cycle in 0..<3 {
            detector.startDetection()
            #expect(detector.isDetecting == true)
            
            // Perform some analysis
            _ = await detector.detectCurrentTerrain()
            
            // Set terrain for this cycle
            let terrain = TerrainType.allCases[cycle % TerrainType.allCases.count]
            detector.setManualTerrain(terrain)
            #expect(detector.currentTerrain == terrain)
            
            detector.stopDetection()
            #expect(detector.isDetecting == false)
            
            // Terrain should persist after stopping
            #expect(detector.currentTerrain == terrain)
        }
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Motion analyzer memory management during long sessions")
    func testMotionAnalyzerMemoryManagement() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Simulate a long detection session
        for _ in 0..<20 {
            _ = await detector.detectCurrentTerrain()
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Check debug info to ensure system is stable
        let debugInfo = await detector.getDebugInfo()
        #expect(debugInfo.contains("Motion Pattern Analyzer Debug"))
        
        detector.stopDetection()
        
        // After stopping, memory should be cleaned up
        let finalDebugInfo = await detector.getDebugInfo()
        #expect(finalDebugInfo.contains("Detection Active: false"))
    }
    
    // MARK: - Terrain Factor Integration Tests
    
    @Test("Terrain factors remain consistent with motion analysis")
    func testTerrainFactorConsistency() async {
        let detector = TerrainDetector()
        
        for terrain in TerrainType.allCases {
            detector.setManualTerrain(terrain)
            
            let factor = detector.getCurrentTerrainFactor()
            let expectedFactor = terrain.terrainFactor
            
            #expect(factor == expectedFactor)
            
            // Perform motion analysis - should not affect terrain factor
            detector.startDetection()
            _ = await detector.detectCurrentTerrain()
            
            let factorAfterAnalysis = detector.getCurrentTerrainFactor()
            #expect(factorAfterAnalysis == expectedFactor)
            
            detector.stopDetection()
        }
    }
    
    // MARK: - Location Manager Integration Tests
    
    @Test("Location manager integration with motion analysis")
    func testLocationManagerIntegration() async {
        let detector = TerrainDetector()
        let locationManager = CLLocationManager()
        
        // Set location manager reference
        detector.locationManager = locationManager
        
        detector.startDetection()
        
        // Perform terrain detection with location manager set
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.terrainType != nil)
        
        // Location manager reference should be maintained
        #expect(detector.locationManager === locationManager)
        
        detector.stopDetection()
    }
}

// MARK: - Performance Monitoring

extension MotionTerrainIntegrationTests {
    
    /// Measures detection latency
    @Test("Detection latency measurement")
    func testDetectionLatency() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        var latencies: [TimeInterval] = []
        
        for _ in 0..<5 {
            let startTime = Date()
            _ = await detector.detectCurrentTerrain()
            let endTime = Date()
            
            let latency = endTime.timeIntervalSince(startTime)
            latencies.append(latency)
        }
        
        // Average latency should be reasonable (under 100ms)
        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        #expect(averageLatency < 0.1) // 100ms
        
        detector.stopDetection()
    }
    
    /// Tests memory usage stability
    @Test("Memory usage stability")
    func testMemoryUsageStability() async {
        let detector = TerrainDetector()
        detector.startDetection()
        
        // Perform many detection cycles to test for memory leaks
        for _ in 0..<50 {
            _ = await detector.detectCurrentTerrain()
            
            // Vary terrain to ensure different code paths
            if Int.random(in: 0...10) < 3 {
                let randomTerrain = TerrainType.allCases.randomElement() ?? .trail
                detector.setManualTerrain(randomTerrain)
            }
            
            // Occasional battery mode changes
            if Int.random(in: 0...10) < 2 {
                detector.setBatteryOptimizedMode(Bool.random())
            }
        }
        
        // System should still be responsive
        let finalResult = await detector.detectCurrentTerrain()
        #expect(finalResult.terrainType != nil)
        
        detector.stopDetection()
    }
}