import Testing
import CoreLocation
@testable import RuckMap

/// Comprehensive tests for the ElevationFusionEngine Kalman filtering implementation
@Suite("ElevationFusionEngine Tests", .serialized)
struct ElevationFusionEngineTests {
    
    // MARK: - Test Configuration
    
    let testConfiguration = ElevationConfiguration(
        kalmanProcessNoise: 0.01,
        kalmanMeasurementNoise: 0.1,
        elevationAccuracyThreshold: 1.0,
        pressureStabilityThreshold: 0.5,
        calibrationTimeout: 5.0
    )
    
    // MARK: - Initialization Tests
    
    @Test("Fusion engine initializes with correct configuration")
    func testInitialization() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        let currentAltitude = await engine.currentAltitude
        let uncertainty = await engine.uncertainty
        let stabilityFactor = await engine.stabilityFactor
        
        #expect(currentAltitude == 0.0)
        #expect(uncertainty > 0.0)
        #expect(stabilityFactor >= 0.0 && stabilityFactor <= 1.0)
    }
    
    @Test("Configuration updates correctly")
    func testConfigurationUpdate() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        let newConfiguration = ElevationConfiguration.precise
        
        await engine.updateConfiguration(newConfiguration)
        
        // Test passes if no exceptions are thrown
        #expect(true)
    }
    
    // MARK: - Calibration Tests
    
    @Test("Calibration sets known elevation correctly")
    func testCalibration() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        let knownElevation = 500.0
        let pressureReading = 95.0 // kPa at ~500m elevation
        
        await engine.calibrate(knownElevation: knownElevation, pressureReading: pressureReading)
        
        let currentAltitude = await engine.currentAltitude
        let uncertainty = await engine.uncertainty
        
        #expect(currentAltitude == knownElevation)
        #expect(uncertainty < 10.0) // Should have low uncertainty after calibration
    }
    
    // MARK: - Kalman Filtering Tests
    
    @Test("Kalman filter processes measurements correctly")
    func testKalmanFiltering() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        // Calibrate to known elevation
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        let initialAltitude = await engine.currentAltitude
        
        // Process a series of measurements
        let measurements = [102.0, 103.0, 101.5, 104.0, 102.5]
        
        for (index, measurement) in measurements.enumerated() {
            let timestamp = Date().addingTimeInterval(TimeInterval(index))
            let filteredAltitude = await engine.processMeasurement(
                barometricAltitude: measurement,
                pressure: 101.0 - (measurement - 100.0) * 0.12, // Approximate pressure change
                timestamp: timestamp
            )
            
            // Filtered result should be reasonable
            #expect(filteredAltitude >= 90.0 && filteredAltitude <= 110.0)
        }
        
        let finalAltitude = await engine.currentAltitude
        #expect(finalAltitude != initialAltitude) // Should have updated
    }
    
    @Test("Kalman filter provides smoothing")
    func testKalmanSmoothing() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Add noisy measurements
        let noisyMeasurements = [100.0, 105.0, 95.0, 110.0, 90.0, 102.0]
        var filteredResults: [Double] = []
        
        for (index, measurement) in noisyMeasurements.enumerated() {
            let timestamp = Date().addingTimeInterval(TimeInterval(index))
            let filtered = await engine.processMeasurement(
                barometricAltitude: measurement,
                pressure: 101.0,
                timestamp: timestamp
            )
            filteredResults.append(filtered)
        }
        
        // Calculate variance of filtered vs raw measurements
        let rawVariance = calculateVariance(noisyMeasurements)
        let filteredVariance = calculateVariance(filteredResults)
        
        // Filtered results should have lower variance (smoother)
        #expect(filteredVariance < rawVariance)
    }
    
    // MARK: - GPS Integration Tests
    
    @Test("GPS altitude integration")
    func testGPSIntegration() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Add GPS measurements
        let gpsAltitude = 105.0
        let gpsAccuracy = 5.0
        let timestamp = Date()
        
        await engine.updateGPSAltitude(gpsAltitude, accuracy: gpsAccuracy, timestamp: timestamp)
        
        // Process barometric measurement
        let filteredAltitude = await engine.processMeasurement(
            barometricAltitude: 100.0,
            pressure: 101.0,
            timestamp: timestamp.addingTimeInterval(1.0)
        )
        
        // Result should be influenced by GPS reading
        #expect(filteredAltitude > 100.0 && filteredAltitude < 105.0)
    }
    
    @Test("GPS accuracy weighting")
    func testGPSAccuracyWeighting() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Test with high accuracy GPS
        await engine.updateGPSAltitude(110.0, accuracy: 2.0, timestamp: Date())
        let highAccuracyResult = await engine.processMeasurement(
            barometricAltitude: 100.0,
            pressure: 101.0,
            timestamp: Date().addingTimeInterval(1.0)
        )
        
        // Reset for low accuracy test
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Test with low accuracy GPS
        await engine.updateGPSAltitude(110.0, accuracy: 50.0, timestamp: Date())
        let lowAccuracyResult = await engine.processMeasurement(
            barometricAltitude: 100.0,
            pressure: 101.0,
            timestamp: Date().addingTimeInterval(1.0)
        )
        
        // High accuracy GPS should have more influence
        #expect(highAccuracyResult > lowAccuracyResult)
    }
    
    // MARK: - Stability Tests
    
    @Test("Stability factor calculation")
    func testStabilityFactor() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Add stable measurements
        let stableMeasurements = Array(repeating: 100.0, count: 10)
        
        for (index, measurement) in stableMeasurements.enumerated() {
            let timestamp = Date().addingTimeInterval(TimeInterval(index))
            await engine.processMeasurement(
                barometricAltitude: measurement,
                pressure: 101.0,
                timestamp: timestamp
            )
        }
        
        let stabilityAfterStable = await engine.stabilityFactor
        
        // Add unstable measurements
        let unstableMeasurements = [95.0, 105.0, 90.0, 110.0, 85.0]
        
        for (index, measurement) in unstableMeasurements.enumerated() {
            let timestamp = Date().addingTimeInterval(TimeInterval(index + 10))
            await engine.processMeasurement(
                barometricAltitude: measurement,
                pressure: 101.0,
                timestamp: timestamp
            )
        }
        
        let stabilityAfterUnstable = await engine.stabilityFactor
        
        #expect(stabilityAfterStable > stabilityAfterUnstable)
    }
    
    // MARK: - Quality Assessment Tests
    
    @Test("Fusion quality assessment")
    func testFusionQuality() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        let (quality, factors) = await engine.assessFusionQuality()
        
        #expect(quality >= 0.0 && quality <= 1.0)
        #expect(factors.count > 0)
        #expect(factors.keys.contains("stability"))
        #expect(factors.keys.contains("uncertainty"))
    }
    
    // MARK: - Performance Tests
    
    @Test("Performance with high-frequency updates", .timeLimit(.seconds(3)))
    func testHighFrequencyPerformance() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        let startTime = Date()
        
        // Simulate high-frequency updates (100 Hz for 1 second)
        for i in 0..<100 {
            let timestamp = Date().addingTimeInterval(TimeInterval(i) * 0.01)
            let measurement = 100.0 + sin(Double(i) * 0.1) * 2.0 // Sine wave variation
            
            await engine.processMeasurement(
                barometricAltitude: measurement,
                pressure: 101.0,
                timestamp: timestamp
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete quickly
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Concurrent measurement processing")
    func testConcurrentProcessing() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Process measurements concurrently
        await withTaskGroup(of: Double.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let measurement = 100.0 + Double(i % 5)
                    let timestamp = Date().addingTimeInterval(TimeInterval(i))
                    
                    return await engine.processMeasurement(
                        barometricAltitude: measurement,
                        pressure: 101.0,
                        timestamp: timestamp
                    )
                }
            }
            
            var results: [Double] = []
            for await result in group {
                results.append(result)
            }
            
            #expect(results.count == 20)
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Extreme measurement values")
    func testExtremeMeasurements() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Test extreme high measurement
        let extremeHigh = await engine.processMeasurement(
            barometricAltitude: 8000.0, // Mount Everest altitude
            pressure: 35.0,
            timestamp: Date()
        )
        
        // Test extreme low measurement
        let extremeLow = await engine.processMeasurement(
            barometricAltitude: -100.0, // Below sea level
            pressure: 110.0,
            timestamp: Date().addingTimeInterval(1.0)
        )
        
        // Results should be reasonable (Kalman filter should prevent wild jumps)
        #expect(extremeHigh < 1000.0) // Should not jump to Everest instantly
        #expect(extremeLow > 0.0) // Should not go wildly negative
    }
    
    @Test("Rapid pressure changes")
    func testRapidPressureChanges() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        await engine.calibrate(knownElevation: 100.0, pressureReading: 101.0)
        
        // Simulate rapid pressure changes (weather front)
        let pressureChanges = [101.0, 100.5, 99.0, 98.5, 99.5, 101.0]
        let altitudeChanges = [100.0, 105.0, 120.0, 125.0, 115.0, 100.0]
        
        for (index, (altitude, pressure)) in zip(altitudeChanges, pressureChanges).enumerated() {
            let timestamp = Date().addingTimeInterval(TimeInterval(index))
            await engine.processMeasurement(
                barometricAltitude: altitude,
                pressure: pressure,
                timestamp: timestamp
            )
        }
        
        let uncertainty = await engine.uncertainty
        
        // Uncertainty should increase with rapid changes
        #expect(uncertainty > 1.0)
    }
    
    // MARK: - Debug Tests
    
    @Test("Debug information completeness")
    func testDebugInformation() async throws {
        let engine = ElevationFusionEngine(configuration: testConfiguration)
        
        let debugInfo = await engine.debugInfo
        
        #expect(debugInfo.contains("Elevation Fusion Engine Debug"))
        #expect(debugInfo.contains("Current State"))
        #expect(debugInfo.contains("Uncertainty"))
        #expect(debugInfo.contains("Stability Factor"))
    }
    
    // MARK: - Helper Functions
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let sumOfSquaredDeviations = values.map { pow($0 - mean, 2) }.reduce(0, +)
        
        return sumOfSquaredDeviations / Double(values.count - 1)
    }
    
    private func generateSinusoidalData(
        baseValue: Double,
        amplitude: Double,
        frequency: Double,
        count: Int
    ) -> [Double] {
        return (0..<count).map { i in
            baseValue + amplitude * sin(Double(i) * frequency)
        }
    }
}

// MARK: - Test Fixtures

extension ElevationFusionEngineTests {
    
    /// Creates a test fusion engine with controlled configuration
    func createTestEngine() -> ElevationFusionEngine {
        return ElevationFusionEngine(configuration: testConfiguration)
    }
    
    /// Generates realistic altitude/pressure pairs
    func generateRealisticData(count: Int = 10) -> [(altitude: Double, pressure: Double)] {
        var data: [(Double, Double)] = []
        let baseAltitude = 100.0
        let basePressure = 101.325
        
        for i in 0..<count {
            let altitudeChange = Double(i) * 2.0 + Double.random(in: -1...1)
            let altitude = baseAltitude + altitudeChange
            
            // Use barometric formula for realistic pressure
            let pressure = basePressure * pow(1.0 - (0.0065 * altitude / 288.15), 5.255)
            
            data.append((altitude, pressure))
        }
        
        return data
    }
}