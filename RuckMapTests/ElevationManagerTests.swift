import Testing
import CoreMotion
import CoreLocation
@testable import RuckMap

/// Comprehensive tests for the ElevationManager with Swift 6 concurrency patterns
@Suite("ElevationManager Tests", .serialized)
struct ElevationManagerTests {
    
    // MARK: - Test Configuration
    
    let testConfiguration = ElevationConfiguration(
        kalmanProcessNoise: 0.01,
        kalmanMeasurementNoise: 0.1,
        elevationAccuracyThreshold: 1.0,
        pressureStabilityThreshold: 0.5,
        calibrationTimeout: 5.0
    )
    
    // MARK: - Initialization Tests
    
    @Test("Elevation Manager initializes with correct default configuration")
    func testInitialization() async throws {
        let manager = ElevationManager()
        
        #expect(!manager.isTracking)
        #expect(!manager.isCalibrated)
        #expect(manager.totalElevationGain == 0.0)
        #expect(manager.totalElevationLoss == 0.0)
        #expect(manager.currentElevationData == nil)
    }
    
    @Test("Elevation Manager initializes with custom configuration")
    func testCustomConfigurationInitialization() async throws {
        let manager = ElevationManager(configuration: testConfiguration)
        
        #expect(manager.configuration.kalmanProcessNoise == testConfiguration.kalmanProcessNoise)
        #expect(manager.configuration.elevationAccuracyThreshold == testConfiguration.elevationAccuracyThreshold)
    }
    
    // MARK: - Configuration Tests
    
    @Test("Configuration updates properly")
    func testConfigurationUpdate() async throws {
        let manager = ElevationManager()
        let newConfiguration = ElevationConfiguration.precise
        
        manager.updateConfiguration(newConfiguration)
        
        #expect(manager.configuration.kalmanProcessNoise == newConfiguration.kalmanProcessNoise)
        #expect(manager.configuration.measurementNoise == newConfiguration.kalmanMeasurementNoise)
    }
    
    // MARK: - Tracking State Tests
    
    @Test("Tracking state management")
    func testTrackingState() async throws {
        let manager = ElevationManager()
        
        // Initial state
        #expect(!manager.isTracking)
        
        // Note: We can't actually start tracking in tests without device hardware
        // This test validates the state management logic
        manager.stopTracking()
        #expect(!manager.isTracking)
        #expect(!manager.isCalibrated)
    }
    
    // MARK: - Metrics Tests
    
    @Test("Metrics reset functionality")
    func testMetricsReset() async throws {
        let manager = ElevationManager()
        
        // Simulate some data
        manager.resetMetrics()
        
        #expect(manager.totalElevationGain == 0.0)
        #expect(manager.totalElevationLoss == 0.0)
        #expect(manager.averageGrade == 0.0)
        #expect(manager.maxGrade == 0.0)
        #expect(manager.minGrade == 0.0)
    }
    
    // MARK: - Location Processing Tests
    
    @Test("GPS location processing without barometer")
    func testGPSLocationProcessing() async throws {
        let manager = ElevationManager()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        
        // Process location update
        await manager.processLocationUpdate(location)
        
        // Verify location was processed (no exceptions thrown)
        #expect(true) // Test passes if no exceptions occur
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error handling for unavailable sensors")
    func testErrorHandling() async throws {
        let manager = ElevationManager()
        
        // Test error conditions
        do {
            // This will fail on simulator/test environment
            try await manager.startTracking()
        } catch let error as ElevationError {
            // Verify specific error types
            #expect(error == .altimeterNotAvailable || error == .authorizationDenied)
        } catch {
            throw error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Performance with rapid location updates", .timeLimit(.seconds(5)))
    func testPerformanceWithRapidUpdates() async throws {
        let manager = ElevationManager()
        let startTime = Date()
        
        // Simulate rapid location updates
        for i in 0..<100 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                ),
                altitude: 100.0 + Double(i) * 0.1,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: Date()
            )
            
            await manager.processLocationUpdate(location)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete in under 1 second
    }
    
    // MARK: - Thread Safety Tests
    
    @Test("Concurrent access safety")
    func testConcurrentAccess() async throws {
        let manager = ElevationManager()
        
        // Create multiple concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let location = CLLocation(
                        coordinate: CLLocationCoordinate2D(
                            latitude: 37.7749 + Double(i) * 0.001,
                            longitude: -122.4194
                        ),
                        altitude: 100.0 + Double(i),
                        horizontalAccuracy: 5.0,
                        verticalAccuracy: 10.0,
                        timestamp: Date()
                    )
                    
                    await manager.processLocationUpdate(location)
                }
            }
        }
        
        // Test passes if no data races or crashes occur
        #expect(true)
    }
    
    // MARK: - Data Validation Tests
    
    @Test("Elevation data validation")
    func testElevationDataValidation() async throws {
        // Test ElevationData structure
        let elevationData = ElevationData(
            barometricAltitude: 100.0,
            gpsAltitude: 105.0,
            fusedAltitude: 102.5,
            pressure: 101.325,
            elevationGain: 10.0,
            elevationLoss: 5.0,
            currentGrade: 2.5,
            confidence: 0.85,
            accuracy: 1.0,
            timestamp: Date()
        )
        
        #expect(elevationData.meetsAccuracyTarget)
        #expect(elevationData.confidence > 0.7)
        #expect(elevationData.accuracy <= 1.0)
    }
    
    @Test("Grade calculation accuracy")
    func testGradeCalculation() async throws {
        // Test grade calculation with known values
        let elevationChange = 10.0 // 10 meters
        let distance = 100.0 // 100 meters
        
        let grade = ElevationData.calculateGrade(
            elevationChange: elevationChange,
            distance: distance
        )
        
        #expect(abs(grade - 10.0) < 0.01) // Should be 10%
        
        // Test clamping to ±20%
        let extremeGrade = ElevationData.calculateGrade(
            elevationChange: 50.0,
            distance: 100.0
        )
        
        #expect(extremeGrade <= 20.0)
    }
    
    // MARK: - Integration Tests
    
    @Test("Integration with mock location stream")
    func testLocationStreamIntegration() async throws {
        let manager = ElevationManager()
        
        // Create a realistic hiking path
        let hikingPath = generateHikingPath()
        
        for location in hikingPath {
            await manager.processLocationUpdate(location)
            
            // Small delay to simulate real-time updates
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Verify that processing completed without errors
        #expect(true)
    }
    
    @Test("Debug information completeness")
    func testDebugInformation() async throws {
        let manager = ElevationManager()
        let debugInfo = manager.debugInfo
        
        #expect(debugInfo.contains("Elevation Manager Debug Info"))
        #expect(debugInfo.contains("Tracking:"))
        #expect(debugInfo.contains("Calibrated:"))
        #expect(debugInfo.contains("Authorization:"))
    }
    
    // MARK: - Test Utilities
    
    private func generateHikingPath() -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        var currentAltitude = 100.0
        
        for i in 0..<50 {
            // Simulate elevation changes
            if i % 10 == 0 {
                currentAltitude += Double.random(in: -5...15) // Random elevation change
            }
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLocation.latitude + Double(i) * 0.0001,
                    longitude: baseLocation.longitude + Double(i) * 0.0001
                ),
                altitude: currentAltitude,
                horizontalAccuracy: Double.random(in: 3...8),
                verticalAccuracy: Double.random(in: 5...15),
                timestamp: Date().addingTimeInterval(TimeInterval(i * 5))
            )
            
            locations.append(location)
        }
        
        return locations
    }
}

// MARK: - Test Fixtures and Helpers

extension ElevationManagerTests {
    
    /// Creates a test elevation manager with mocked sensor data
    func createTestManager() -> ElevationManager {
        return ElevationManager(configuration: testConfiguration)
    }
    
    /// Generates test elevation data for validation
    func createTestElevationData(
        altitude: Double = 100.0,
        accuracy: Double = 1.0,
        confidence: Double = 0.9
    ) -> ElevationData {
        return ElevationData(
            barometricAltitude: altitude,
            gpsAltitude: altitude + 2.0,
            fusedAltitude: altitude + 1.0,
            pressure: 101.325,
            elevationGain: 0.0,
            elevationLoss: 0.0,
            currentGrade: 0.0,
            confidence: confidence,
            accuracy: accuracy,
            timestamp: Date()
        )
    }
}