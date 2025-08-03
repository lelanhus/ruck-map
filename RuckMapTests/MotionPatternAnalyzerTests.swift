import Testing
import Foundation
import CoreMotion
import Accelerate
@testable import RuckMap

/// Comprehensive test suite for MotionPatternAnalyzer
/// Tests motion pattern analysis, frequency analysis, and terrain detection algorithms
@MainActor
struct MotionPatternAnalyzerTests {
    
    // MARK: - Initialization Tests
    
    @Test("MotionPatternAnalyzer initializes correctly")
    func testInitialization() async {
        let analyzer = MotionPatternAnalyzer()
        
        let sampleCount = await analyzer.sampleCount
        let confidence = await analyzer.getAnalysisConfidence()
        let timeSinceAnalysis = await analyzer.timeSinceLastAnalysis
        
        #expect(sampleCount == 0)
        #expect(confidence == 0.0)
        #expect(timeSinceAnalysis == nil)
    }
    
    // MARK: - Sample Addition Tests
    
    @Test("Adding motion samples increases sample count")
    func testSampleAddition() async {
        let analyzer = MotionPatternAnalyzer()
        
        let accelData = createMockAccelerometerData(x: 0.1, y: 0.2, z: 0.9)
        let gyroData = createMockGyroscopeData(x: 0.01, y: 0.02, z: 0.03)
        
        await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        
        let sampleCount = await analyzer.sampleCount
        #expect(sampleCount == 1)
    }
    
    @Test("Motion samples maintain sliding window")
    func testSlidingWindow() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add more samples than the window size (150 + some extra)
        for i in 0..<200 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.033) // 30Hz
            let accelData = createMockAccelerometerData(x: 0.1, y: 0.2, z: 0.9, timestamp: timestamp)
            let gyroData = createMockGyroscopeData(x: 0.01, y: 0.02, z: 0.03, timestamp: timestamp)
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        let sampleCount = await analyzer.sampleCount
        // Should maintain window size with some overlap
        #expect(sampleCount <= 150)
        #expect(sampleCount > 100) // Should have removed some but not all
    }
    
    // MARK: - Motion Pattern Analysis Tests
    
    @Test("Motion analysis with insufficient samples returns nil")
    func testInsufficientSamples() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add only a few samples (less than 30 required)
        for i in 0..<10 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.033)
            let accelData = createMockAccelerometerData(x: 0.1, y: 0.2, z: 0.9, timestamp: timestamp)
            let gyroData = createMockGyroscopeData(x: 0.01, y: 0.02, z: 0.03, timestamp: timestamp)
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result == nil)
    }
    
    @Test("Motion analysis with sufficient samples returns result")
    func testSufficientSamples() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add enough samples for analysis
        await addPavedRoadSamples(to: analyzer, count: 50)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        #expect(result?.terrainType != nil)
        #expect(result?.confidence != nil)
        #expect(result?.analysisDetails != nil)
    }
    
    // MARK: - Terrain Detection Tests
    
    @Test("Paved road pattern detection")
    func testPavedRoadDetection() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Generate paved road motion pattern: regular, low variance
        await addPavedRoadSamples(to: analyzer, count: 100)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Should detect paved road with reasonable confidence
            #expect(result.terrainType == .pavedRoad || result.confidence > 0.5)
            #expect(result.analysisDetails.stepRegularity > 0.7) // Should be regular
            #expect(result.analysisDetails.accelerationVariance < 0.2) // Should be low variance
        }
    }
    
    @Test("Trail pattern detection")
    func testTrailDetection() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Generate trail motion pattern: moderate variance, less regular
        await addTrailSamples(to: analyzer, count: 100)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Trail should have moderate characteristics
            #expect(result.analysisDetails.accelerationVariance > 0.05)
            #expect(result.analysisDetails.stepRegularity < 0.9)
            #expect(result.analysisDetails.verticalComponent > 0.2)
        }
    }
    
    @Test("Sand pattern detection")
    func testSandDetection() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Generate sand motion pattern: high variance, irregular, damped
        await addSandSamples(to: analyzer, count: 100)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Sand should have high variance and low regularity
            #expect(result.analysisDetails.accelerationVariance > 0.15)
            #expect(result.analysisDetails.stepRegularity < 0.6)
            #expect(result.analysisDetails.impactIntensity < 0.5) // Damped by sand
        }
    }
    
    @Test("Snow pattern detection")
    func testSnowDetection() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Generate snow motion pattern: moderate variance, sliding movements
        await addSnowSamples(to: analyzer, count: 100)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Snow should have specific characteristics
            #expect(result.analysisDetails.stepFrequency < 2.0) // Slower movement
            #expect(result.analysisDetails.impactIntensity < 0.3) // Muffled by snow
        }
    }
    
    // MARK: - Frequency Analysis Tests
    
    @Test("Frequency profile analysis")
    func testFrequencyProfile() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples with known frequency characteristics
        await addHighFrequencyVibrationSamples(to: analyzer, count: 100)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            let profile = result.analysisDetails.frequencyProfile
            #expect(profile.count == 4) // Should have 4 frequency bands
            
            // High frequency samples should show power in higher bands
            let highFreqPower = profile.suffix(2).reduce(0, +)
            let lowFreqPower = profile.prefix(2).reduce(0, +)
            #expect(highFreqPower > 0.1) // Some power in high frequencies
        }
    }
    
    // MARK: - Confidence Scoring Tests
    
    @Test("Confidence scoring reflects data quality")
    func testConfidenceScoring() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add very regular paved road samples
        await addPavedRoadSamples(to: analyzer, count: 150)
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Should have high confidence for clear pattern
            #expect(result.confidence > 0.3)
        }
        
        // Test confidence decay over time
        let immediateConfidence = await analyzer.getAnalysisConfidence()
        
        // Wait a bit (simulated time passage)
        try? await Task.sleep(for: .milliseconds(100))
        
        let laterConfidence = await analyzer.getAnalysisConfidence()
        #expect(laterConfidence <= immediateConfidence) // Should decay or stay same
    }
    
    // MARK: - Reset Functionality Tests
    
    @Test("Reset clears all data")
    func testReset() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add some samples
        await addPavedRoadSamples(to: analyzer, count: 50)
        
        let sampleCountBefore = await analyzer.sampleCount
        #expect(sampleCountBefore > 0)
        
        // Reset
        await analyzer.reset()
        
        let sampleCountAfter = await analyzer.sampleCount
        let confidenceAfter = await analyzer.getAnalysisConfidence()
        let timeAfter = await analyzer.timeSinceLastAnalysis
        
        #expect(sampleCountAfter == 0)
        #expect(confidenceAfter == 0.0)
        #expect(timeAfter == nil)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent sample addition is safe")
    func testConcurrentAccess() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    for j in 0..<10 {
                        let timestamp = Date().addingTimeInterval(Double(i * 10 + j) * 0.033)
                        let accelData = createMockAccelerometerData(x: 0.1, y: 0.2, z: 0.9, timestamp: timestamp)
                        let gyroData = createMockGyroscopeData(x: 0.01, y: 0.02, z: 0.03, timestamp: timestamp)
                        
                        await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
                    }
                }
            }
        }
        
        let finalCount = await analyzer.sampleCount
        #expect(finalCount > 0)
        #expect(finalCount <= 150) // Shouldn't exceed window size
    }
    
    // MARK: - Performance Tests
    
    @Test("Analysis performance is acceptable", .timeLimit(.seconds(2)))
    func testAnalysisPerformance() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add maximum samples
        await addPavedRoadSamples(to: analyzer, count: 150)
        
        // Analysis should complete quickly
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
    }
    
    @Test("Sample addition performance is acceptable", .timeLimit(.seconds(1)))
    func testSampleAdditionPerformance() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Adding many samples should be fast
        for i in 0..<200 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.033)
            let accelData = createMockAccelerometerData(x: 0.1, y: 0.2, z: 0.9, timestamp: timestamp)
            let gyroData = createMockGyroscopeData(x: 0.01, y: 0.02, z: 0.03, timestamp: timestamp)
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        let sampleCount = await analyzer.sampleCount
        #expect(sampleCount > 0)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Handles extreme motion values")
    func testExtremeValues() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples with extreme values
        for i in 0..<50 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.033)
            let accelData = createMockAccelerometerData(x: 10.0, y: -10.0, z: 15.0, timestamp: timestamp)
            let gyroData = createMockGyroscopeData(x: 5.0, y: -5.0, z: 8.0, timestamp: timestamp)
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        // Should handle extreme values without crashing
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Should still produce reasonable analysis
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
        }
    }
    
    @Test("Handles zero motion values")
    func testZeroMotion() async {
        let analyzer = MotionPatternAnalyzer()
        
        // Add samples with zero motion
        for i in 0..<50 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.033)
            let accelData = createMockAccelerometerData(x: 0.0, y: 0.0, z: 0.0, timestamp: timestamp)
            let gyroData = createMockGyroscopeData(x: 0.0, y: 0.0, z: 0.0, timestamp: timestamp)
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
        
        let result = await analyzer.analyzeMotionPattern()
        #expect(result != nil)
        
        if let result = result {
            // Should handle zero motion gracefully
            #expect(result.analysisDetails.stepFrequency >= 0.0)
            #expect(result.analysisDetails.accelerationVariance >= 0.0)
        }
    }
    
    // MARK: - Debug Information Tests
    
    @Test("Debug information is comprehensive")
    func testDebugInformation() async {
        let analyzer = MotionPatternAnalyzer()
        
        await addPavedRoadSamples(to: analyzer, count: 50)
        _ = await analyzer.analyzeMotionPattern()
        
        let debugInfo = await analyzer.getDebugInfo()
        
        // Should contain key information
        #expect(debugInfo.contains("Sample Count"))
        #expect(debugInfo.contains("Analysis Confidence"))
        #expect(debugInfo.contains("Window Size"))
        #expect(debugInfo.contains("Sample Rate"))
    }
}

// MARK: - Mock Data Helpers

extension MotionPatternAnalyzerTests {
    
    /// Creates mock accelerometer data for testing
    private func createMockAccelerometerData(
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
    
    /// Creates mock gyroscope data for testing
    private func createMockGyroscopeData(
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
    
    /// Adds mock paved road motion samples
    private func addPavedRoadSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033 // 30Hz sampling
            let timestamp = Date().addingTimeInterval(t)
            
            // Regular walking pattern on smooth surface
            let stepPhase = sin(t * 2.0 * .pi * 1.8) // 1.8 Hz step frequency
            let baseAccel = 0.1 + 0.05 * stepPhase
            let noise = Double.random(in: -0.02...0.02) // Low noise for smooth surface
            
            let accelData = createMockAccelerometerData(
                x: baseAccel + noise,
                y: 0.1 + noise,
                z: 0.9 + 0.1 * stepPhase + noise,
                timestamp: timestamp
            )
            
            let gyroData = createMockGyroscopeData(
                x: 0.05 * stepPhase + Double.random(in: -0.01...0.01),
                y: 0.02 + Double.random(in: -0.01...0.01),
                z: 0.01 + Double.random(in: -0.005...0.005),
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
    
    /// Adds mock trail motion samples
    private func addTrailSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033
            let timestamp = Date().addingTimeInterval(t)
            
            // Irregular walking pattern on uneven surface
            let stepPhase = sin(t * 2.0 * .pi * 1.6) // Slightly slower on trail
            let irregularity = sin(t * 0.5) * 0.1 // Terrain irregularity
            let noise = Double.random(in: -0.08...0.08) // Higher noise for uneven surface
            
            let accelData = createMockAccelerometerData(
                x: 0.15 + 0.1 * stepPhase + irregularity + noise,
                y: 0.1 + noise,
                z: 0.9 + 0.2 * stepPhase + irregularity + noise,
                timestamp: timestamp
            )
            
            let gyroData = createMockGyroscopeData(
                x: 0.1 * stepPhase + Double.random(in: -0.05...0.05),
                y: 0.05 + Double.random(in: -0.03...0.03),
                z: 0.02 + Double.random(in: -0.02...0.02),
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
    
    /// Adds mock sand motion samples
    private func addSandSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033
            let timestamp = Date().addingTimeInterval(t)
            
            // Slow, irregular walking pattern on sand
            let stepPhase = sin(t * 2.0 * .pi * 1.2) // Slower on sand
            let sinking = sin(t * 0.3) * 0.3 // Foot sinking effect
            let noise = Double.random(in: -0.15...0.15) // High variance for sand
            
            let accelData = createMockAccelerometerData(
                x: 0.2 + 0.15 * stepPhase + sinking + noise,
                y: 0.15 + noise,
                z: 0.8 + 0.4 * stepPhase + sinking + noise, // Higher vertical component
                timestamp: timestamp
            )
            
            let gyroData = createMockGyroscopeData(
                x: 0.2 * stepPhase + Double.random(in: -0.1...0.1),
                y: 0.1 + Double.random(in: -0.08...0.08),
                z: 0.05 + Double.random(in: -0.04...0.04),
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
    
    /// Adds mock snow motion samples
    private func addSnowSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033
            let timestamp = Date().addingTimeInterval(t)
            
            // Cautious walking pattern on snow with sliding
            let stepPhase = sin(t * 2.0 * .pi * 1.4) // Careful steps
            let sliding = sin(t * 0.8) * 0.2 // Occasional sliding
            let noise = Double.random(in: -0.06...0.06) // Moderate noise for snow
            
            let accelData = createMockAccelerometerData(
                x: 0.12 + 0.08 * stepPhase + sliding + noise,
                y: 0.08 + sliding * 0.5 + noise, // Lateral sliding
                z: 0.85 + 0.25 * stepPhase + noise,
                timestamp: timestamp
            )
            
            let gyroData = createMockGyroscopeData(
                x: 0.08 * stepPhase + Double.random(in: -0.04...0.04),
                y: 0.06 + sliding * 0.3 + Double.random(in: -0.03...0.03),
                z: 0.03 + Double.random(in: -0.02...0.02),
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
    
    /// Adds mock high frequency vibration samples
    private func addHighFrequencyVibrationSamples(to analyzer: MotionPatternAnalyzer, count: Int) async {
        for i in 0..<count {
            let t = Double(i) * 0.033
            let timestamp = Date().addingTimeInterval(t)
            
            // High frequency vibrations (e.g., stairs or rough surface)
            let highFreq = sin(t * 2.0 * .pi * 10.0) * 0.1 // 10Hz vibration
            let stepPhase = sin(t * 2.0 * .pi * 0.8) * 0.3 // Slow stepping
            let noise = Double.random(in: -0.05...0.05)
            
            let accelData = createMockAccelerometerData(
                x: 0.2 + stepPhase + highFreq + noise,
                y: 0.15 + highFreq + noise,
                z: 0.9 + stepPhase + highFreq + noise,
                timestamp: timestamp
            )
            
            let gyroData = createMockGyroscopeData(
                x: 0.3 * stepPhase + highFreq + Double.random(in: -0.05...0.05),
                y: 0.2 + highFreq + Double.random(in: -0.04...0.04),
                z: 0.1 + Double.random(in: -0.03...0.03),
                timestamp: timestamp
            )
            
            await analyzer.addMotionSample(accelerometer: accelData, gyroscope: gyroData)
        }
    }
}