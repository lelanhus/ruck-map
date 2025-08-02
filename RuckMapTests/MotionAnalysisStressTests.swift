import Testing
import Foundation
import CoreMotion
@testable import RuckMap

/// Stress tests for motion analysis system to ensure robustness and performance
/// Tests system behavior under extreme conditions and high load
struct MotionAnalysisStressTests {
    
    // MARK: - High Load Tests
    
    @Test("High frequency sample addition stress test")
    func testHighFrequencySampleAddition() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples at very high frequency
        await withTaskGroup(of: Void.self) { group in
            for batchIndex in 0..<10 {
                group.addTask {
                    for i in 0..<100 {
                        let timestamp = Date().addingTimeInterval(Double(batchIndex * 100 + i) * 0.001) // 1000Hz
                        let accelData = createStressTestAccelerometerData(
                            x: Double.random(in: -2...2),
                            y: Double.random(in: -2...2),
                            z: Double.random(in: -2...2),
                            timestamp: timestamp
                        )
                        let gyroData = createStressTestGyroscopeData(
                            x: Double.random(in: -5...5),
                            y: Double.random(in: -5...5),
                            z: Double.random(in: -5...5),
                            timestamp: timestamp
                        )
                        
                        await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
                    }
                }
            }
        }
        
        // System should remain stable
        let sampleCount = await analyzer.sampleCount
        #expect(sampleCount > 0)
        
        // Should be able to perform analysis
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
    }
    
    @Test("Concurrent analysis requests stress test")
    func testConcurrentAnalysisRequests() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add sufficient data for analysis
        await addStressTestSamples(to: analyzer, count: 200)
        
        // Make many concurrent analysis requests
        let results = await withTaskGroup(of: MotionPatternAnalyzer.MotionAnalysisResult?.self, 
                                        returning: [MotionPatternAnalyzer.MotionAnalysisResult?].self) { group in
            for _ in 0..<20 {
                group.addTask {
                    return await analyzer.analyzeMotionPattern()
                }
            }
            
            var allResults: [MotionPatternAnalyzer.MotionAnalysisResult?] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        // All requests should complete
        #expect(results.count == 20)
        
        // Most should return valid results (some might be nil due to caching)
        let validResults = results.compactMap { $0 }
        #expect(validResults.count > 0)
    }
    
    @Test("Memory stress test with large data volumes")
    func testMemoryStressWithLargeVolumes() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add very large amounts of data
        for batchIndex in 0..<100 {
            for i in 0..<50 {
                let timestamp = Date().addingTimeInterval(Double(batchIndex * 50 + i) * 0.033)
                let accelData = createStressTestAccelerometerData(
                    x: sin(Double(i) * 0.1) + Double.random(in: -0.5...0.5),
                    y: cos(Double(i) * 0.1) + Double.random(in: -0.5...0.5),
                    z: 1.0 + sin(Double(i) * 0.05) + Double.random(in: -0.2...0.2),
                    timestamp: timestamp
                )
                let gyroData = createStressTestGyroscopeData(
                    x: Double.random(in: -1...1),
                    y: Double.random(in: -1...1),
                    z: Double.random(in: -1...1),
                    timestamp: timestamp
                )
                
                await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
            }
            
            // Perform analysis periodically
            if batchIndex % 10 == 0 {
                _ = await analyzer.analyzeMotionPattern()
            }
        }
        
        // System should still be responsive
        let finalResult = await analyzer.analyzeMotionPattern()
        #expect(finalResult != nil)
        
        // Sample count should be within expected bounds (sliding window)
        let sampleCount = await analyzer.sampleCount
        #expect(sampleCount <= 150) // Should respect sliding window
    }
    
    // MARK: - Extreme Data Tests
    
    @Test("Extreme acceleration values handling")
    func testExtremeAccelerationValues() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples with extreme acceleration values
        let extremeValues = [-100.0, -50.0, -10.0, 0.0, 10.0, 50.0, 100.0]
        
        for (index, value) in extremeValues.enumerated() {
            for i in 0..<20 {
                let timestamp = Date().addingTimeInterval(Double(index * 20 + i) * 0.033)
                let accelData = createStressTestAccelerometerData(
                    x: value,
                    y: value * 0.5,
                    z: value * 0.3,
                    timestamp: timestamp
                )
                let gyroData = createStressTestGyroscopeData(
                    x: value * 0.1,
                    y: value * 0.1,
                    z: value * 0.1,
                    timestamp: timestamp
                )
                
                await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
            }
        }
        
        // Should handle extreme values gracefully
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Results should be within reasonable bounds
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
            #expect(result.analysisDetails.stepFrequency >= 0.0)
            #expect(result.analysisDetails.accelerationVariance >= 0.0)
        }
    }
    
    @Test("NaN and infinite values handling")
    func testNaNAndInfiniteValues() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add some normal samples first
        await addStressTestSamples(to: analyzer, count: 50)
        
        // Add samples with problematic values
        let problematicValues = [Double.nan, Double.infinity, -Double.infinity, Double.greatestFiniteMagnitude]
        
        for value in problematicValues {
            let timestamp = Date()
            let accelData = createStressTestAccelerometerData(
                x: value,
                y: 0.1,
                z: 0.9,
                timestamp: timestamp
            )
            let gyroData = createStressTestGyroscopeData(
                x: value,
                y: 0.01,
                z: 0.01,
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        // Should handle problematic values without crashing
        let result = await analyzer.analyzeMotionPattern()
        
        // Should either return nil or valid results (no NaN/infinite values)
        if let result = result {
            #expect(!result.confidence.isNaN)
            #expect(!result.confidence.isInfinite)
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
        }
    }
    
    @Test("Rapid terrain pattern changes")
    func testRapidTerrainPatternChanges() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Simulate rapid changes between different terrain patterns
        let terrainPatterns = [
            (freq: 1.8, variance: 0.05, name: "pavement"),
            (freq: 1.2, variance: 0.3, name: "sand"),
            (freq: 1.6, variance: 0.15, name: "trail"),
            (freq: 0.8, variance: 0.6, name: "stairs")
        ]
        
        for patternIndex in 0..<terrainPatterns.count {
            let pattern = terrainPatterns[patternIndex]
            
            // Add samples for this terrain pattern
            for i in 0..<30 {
                let t = Double(i) * 0.033
                let timestamp = Date().addingTimeInterval(Double(patternIndex * 30) * 0.033 + t)
                
                let stepPhase = sin(t * 2.0 * .pi * pattern.freq)
                let noise = Double.random(in: -pattern.variance...pattern.variance)
                
                let accelData = createStressTestAccelerometerData(
                    x: 0.1 + 0.1 * stepPhase + noise,
                    y: 0.1 + noise,
                    z: 0.9 + 0.2 * stepPhase + noise,
                    timestamp: timestamp
                )
                
                let gyroData = createStressTestGyroscopeData(
                    x: 0.1 * stepPhase + noise * 0.1,
                    y: 0.05 + noise * 0.1,
                    z: 0.02 + noise * 0.1,
                    timestamp: timestamp
                )
                
                await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
            }
            
            // Analyze pattern after each terrain change
            let result = await analyzer.analyzeMotionPattern()
            #expect(result != nil)
        }
        
        // Final analysis should still work
        let finalResult = await analyzer.analyzeMotionPattern()
        #expect(finalResult != nil)
    }
    
    // MARK: - Timing and Synchronization Stress Tests
    
    @Test("Out-of-order timestamp handling")
    func testOutOfOrderTimestamps() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples with deliberately out-of-order timestamps
        let baseTime = Date()
        let timeOffsets = [0.0, 0.5, 0.1, 0.8, 0.3, 0.9, 0.2, 0.7, 0.4, 0.6]
        
        for offset in timeOffsets {
            let timestamp = baseTime.addingTimeInterval(offset)
            let accelData = createStressTestAccelerometerData(
                x: 0.1 + offset * 0.1,
                y: 0.1,
                z: 0.9 + offset * 0.1,
                timestamp: timestamp
            )
            let gyroData = createStressTestGyroscopeData(
                x: offset * 0.1,
                y: 0.01,
                z: 0.01,
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        // Add more normal samples
        await addStressTestSamples(to: analyzer, count: 50)
        
        // Should handle out-of-order timestamps gracefully
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
    }
    
    @Test("Very long analysis sessions")
    func testVeryLongAnalysisSessions() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Simulate a very long session with periodic analysis
        for sessionMinute in 0..<10 { // 10 "minutes" of data
            // Add data for this "minute"
            for i in 0..<100 {
                let timestamp = Date().addingTimeInterval(Double(sessionMinute * 100 + i) * 0.033)
                let t = Double(sessionMinute * 100 + i) * 0.033
                
                // Slowly evolving pattern
                let evolution = Double(sessionMinute) / 10.0
                let stepPhase = sin(t * 2.0 * .pi * (1.5 + evolution * 0.5))
                let noise = Double.random(in: -0.1...0.1)
                
                let accelData = createStressTestAccelerometerData(
                    x: 0.1 + 0.1 * stepPhase + noise,
                    y: 0.1 + noise,
                    z: 0.9 + 0.2 * stepPhase + noise,
                    timestamp: timestamp
                )
                
                let gyroData = createStressTestGyroscopeData(
                    x: 0.1 * stepPhase + noise * 0.5,
                    y: 0.05 + noise * 0.5,
                    z: 0.02 + noise * 0.5,
                    timestamp: timestamp
                )
                
                await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
            }
            
            // Perform analysis every "minute"
            let result = await analyzer.analyzeMotionPattern()
            #expect(result != nil)
            
            if let result = result {
                #expect(result.confidence >= 0.0)
                #expect(result.confidence <= 1.0)
            }
        }
        
        // Final check
        let confidence = await analyzer.getAnalysisConfidence()
        #expect(confidence >= 0.0)
        #expect(confidence <= 1.0)
    }
    
    // MARK: - Resource Management Stress Tests
    
    @Test("Repeated reset operations under load")
    func testRepeatedResetOperations() async {
        let analyzer = MotionPatternAnalyzer()
        
        for resetCycle in 0..<20 {
            // Add some data
            await addStressTestSamples(to: analyzer, count: 30)
            
            // Perform analysis
            _ = await analyzer.analyzeMotionPattern()
            
            // Reset
            await analyzer.reset()
            
            // Verify clean state
            let sampleCount = await analyzer.sampleCount
            #expect(sampleCount == 0)
            
            let confidence = await analyzer.getAnalysisConfidence()
            #expect(confidence == 0.0)
        }
    }
    
    @Test("Stress test with terrain detector integration")
    func testTerrainDetectorIntegrationStress() async {
        let detector = TerrainDetector()
        
        // Rapid start/stop cycles with battery optimization changes
        for cycle in 0..<10 {
            detector.setBatteryOptimizedMode(cycle % 2 == 0)
            detector.startDetection()
            
            // Rapid terrain changes
            for terrain in TerrainType.allCases.prefix(3) {
                detector.setManualTerrain(terrain)
                _ = await detector.detectCurrentTerrain()
            }
            
            detector.stopDetection()
            detector.reset()
        }
        
        // Final state should be clean
        #expect(detector.currentTerrain == .trail)
        #expect(detector.confidence == 0.0)
        #expect(!detector.isDetecting)
    }
}

// MARK: - Stress Test Helpers

extension MotionAnalysisStressTests {
    
    /// Creates mock accelerometer data for stress testing
    private func createStressTestAccelerometerData(
        x: Double,
        y: Double,
        z: Double,
        timestamp: Date = Date()
    ) -> CMAccelerometerData {
        let data = CMAccelerometerData()
        data.setValue(CMAcceleration(x: x, y: y, z: z), forKey: "acceleration")
        data.setValue(timestamp.timeIntervalSinceReferenceDate, forKey: "timestamp")
        return data
    }
    
    /// Creates mock gyroscope data for stress testing
    private func createStressTestGyroscopeData(
        x: Double,
        y: Double,
        z: Double,
        timestamp: Date = Date()
    ) -> CMGyroData {
        let data = CMGyroData()
        data.setValue(CMRotationRate(x: x, y: y, z: z), forKey: "rotationRate")
        data.setValue(timestamp.timeIntervalSinceReferenceDate, forKey: "timestamp")
        return data
    }
    
    /// Adds a batch of realistic motion samples for stress testing
    private func addStressTestSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033 // 30Hz
            let timestamp = Date().addingTimeInterval(t)
            
            // Realistic walking motion
            let stepPhase = sin(t * 2.0 * .pi * 1.6) // 1.6 Hz step frequency
            let noise = Double.random(in: -0.05...0.05)
            
            let accelData = createStressTestAccelerometerData(
                x: 0.1 + 0.08 * stepPhase + noise,
                y: 0.05 + noise,
                z: 0.9 + 0.15 * stepPhase + noise,
                timestamp: timestamp
            )
            
            let gyroData = createStressTestGyroscopeData(
                x: 0.06 * stepPhase + noise,
                y: 0.03 + noise * 0.5,
                z: 0.01 + noise * 0.5,
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
}