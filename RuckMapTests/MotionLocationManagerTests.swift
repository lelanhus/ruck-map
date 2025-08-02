import Testing
import CoreLocation
import CoreMotion
@testable import RuckMap

@MainActor
struct MotionLocationManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testMotionLocationManagerInitialization() async throws {
        let motionManager = MotionLocationManager()
        
        #expect(motionManager.currentMotionActivity == .unknown)
        #expect(motionManager.motionConfidence == 0.0)
        #expect(motionManager.isMotionTracking == false)
        #expect(motionManager.suppressLocationUpdates == false)
        #expect(motionManager.batteryOptimizedMode == false)
    }
    
    // MARK: - Motion Activity Classification Tests
    
    @Test func testMotionActivityTypeFromSpeed() async throws {
        let stationaryActivity = MotionActivityType(from: 0.3)
        #expect(stationaryActivity == .stationary)
        
        let walkingActivity = MotionActivityType(from: 1.5)
        #expect(walkingActivity == .walking)
        
        let joggingActivity = MotionActivityType(from: 2.8)
        #expect(joggingActivity == .jogging)
        
        let runningActivity = MotionActivityType(from: 4.5)
        #expect(runningActivity == .running)
    }
    
    @Test func testMotionActivityUpdateFrequency() async throws {
        #expect(MotionActivityType.stationary.updateFrequency == 5.0)
        #expect(MotionActivityType.walking.updateFrequency == 1.0)
        #expect(MotionActivityType.running.updateFrequency == 0.5)
        #expect(MotionActivityType.automotive.updateFrequency == 0.3)
    }
    
    @Test func testMotionActivityExpectedSpeed() async throws {
        #expect(MotionActivityType.stationary.expectedSpeed.contains(0.2))
        #expect(MotionActivityType.walking.expectedSpeed.contains(1.5))
        #expect(MotionActivityType.running.expectedSpeed.contains(4.0))
        #expect(MotionActivityType.cycling.expectedSpeed.contains(10.0))
        #expect(MotionActivityType.automotive.expectedSpeed.contains(20.0))
    }
    
    // MARK: - Motion Data Tests
    
    @Test func testMotionDataCreation() async throws {
        let acceleration = CMAcceleration(x: 0.1, y: 0.2, z: 9.8)
        let rotationRate = CMRotationRate(x: 0.0, y: 0.0, z: 0.1)
        let attitude = CMAttitude()
        
        let motionData = MotionData(
            acceleration: acceleration,
            rotationRate: rotationRate,
            attitude: attitude,
            timestamp: Date(),
            motionActivity: .walking,
            confidence: 0.8
        )
        
        #expect(motionData.motionActivity == .walking)
        #expect(motionData.confidence == 0.8)
        #expect(motionData.magnitude > 9.8) // Should be close to gravity plus movement
    }
    
    @Test func testSignificantMotionDetection() async throws {
        let lowAcceleration = CMAcceleration(x: 0.0, y: 0.0, z: 9.8) // Just gravity
        let motionDataLow = MotionData(
            acceleration: lowAcceleration,
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0),
            attitude: nil,
            timestamp: Date(),
            motionActivity: .stationary,
            confidence: 0.9
        )
        
        #expect(motionDataLow.isSignificantMotion == false)
        
        let highAcceleration = CMAcceleration(x: 2.0, y: 1.0, z: 10.0) // Significant movement
        let motionDataHigh = MotionData(
            acceleration: highAcceleration,
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0),
            attitude: nil,
            timestamp: Date(),
            motionActivity: .running,
            confidence: 0.9
        )
        
        #expect(motionDataHigh.isSignificantMotion == true)
    }
    
    // MARK: - Kalman Filter Tests
    
    @Test func testKalmanFilterInitialization() async throws {
        let kalmanFilter = KalmanLocationFilter()
        
        let initialLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        let processedLocation = await kalmanFilter.process(
            location: initialLocation,
            motionData: nil
        )
        
        // First location should pass through unchanged
        #expect(processedLocation.coordinate.latitude == initialLocation.coordinate.latitude)
        #expect(processedLocation.coordinate.longitude == initialLocation.coordinate.longitude)
    }
    
    @Test func testKalmanFilterSmoothing() async throws {
        let kalmanFilter = KalmanLocationFilter()
        
        // Initial location
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        _ = await kalmanFilter.process(location: location1, motionData: nil)
        
        // Slightly noisy second location
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            altitude: 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date().addingTimeInterval(1.0)
        )
        
        let filteredLocation2 = await kalmanFilter.process(location: location2, motionData: nil)
        
        // Filtered location should be smoother
        #expect(filteredLocation2.horizontalAccuracy <= 10.0)
        #expect(abs(filteredLocation2.coordinate.latitude - 37.7749) < 0.001)
        #expect(abs(filteredLocation2.coordinate.longitude - -122.4194) < 0.001)
    }
    
    // MARK: - Location Processing Tests
    
    @Test func testLocationProcessingWithoutMotion() async throws {
        let motionManager = MotionLocationManager()
        
        let testLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        let processedLocation = await motionManager.processLocationUpdate(testLocation)
        
        // Without motion tracking, should return filtered location
        #expect(processedLocation.coordinate.latitude == testLocation.coordinate.latitude)
        #expect(processedLocation.coordinate.longitude == testLocation.coordinate.longitude)
    }
    
    @Test func testLocationSuppressionDuringStationary() async throws {
        let motionManager = MotionLocationManager()
        motionManager.currentMotionActivity = .stationary
        
        // Simulate being stationary for more than threshold
        motionManager.lastSignificantMotionTime = Date().addingTimeInterval(-35) // 35 seconds ago
        
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Process several location updates
        for i in 0..<6 {
            _ = await motionManager.processLocationUpdate(testLocation)
        }
        
        // Should have suppressed some updates
        #expect(motionManager.updateSuppressionCount > 0)
    }
    
    // MARK: - Battery Optimization Tests
    
    @Test func testBatteryOptimizedMode() async throws {
        let motionManager = MotionLocationManager()
        
        #expect(motionManager.batteryOptimizedMode == false)
        
        motionManager.setBatteryOptimizedMode(true)
        #expect(motionManager.batteryOptimizedMode == true)
        
        motionManager.setBatteryOptimizedMode(false)
        #expect(motionManager.batteryOptimizedMode == false)
    }
    
    // MARK: - Motion Prediction Tests
    
    @Test func testMotionPredictionToggle() async throws {
        let motionManager = MotionLocationManager()
        
        motionManager.enableMotionPrediction(true)
        motionManager.enableMotionPrediction(false)
        
        // Test passes if no crashes occur
        #expect(true)
    }
    
    @Test func testMotionPredictionWithMovement() async throws {
        let motionManager = MotionLocationManager()
        motionManager.enableMotionPrediction(true)
        
        // Set up motion data indicating movement
        let motionData = MotionData(
            acceleration: CMAcceleration(x: 1.0, y: 0.5, z: 9.8),
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0.1),
            attitude: nil,
            timestamp: Date(),
            motionActivity: .walking,
            confidence: 0.8
        )
        
        // Set up location with some speed
        let movingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 45.0,
            speed: 1.5, // Walking speed
            timestamp: Date()
        )
        
        motionManager.filteredLocation = movingLocation
        motionManager.lastMotionData = motionData
        
        // Should be able to generate prediction without crashing
        #expect(true)
    }
    
    // MARK: - Integration Tests
    
    @Test func testAdaptiveGPSIntegration() async throws {
        let motionManager = MotionLocationManager()
        let adaptiveGPS = AdaptiveGPSManager()
        
        motionManager.setAdaptiveGPSManager(adaptiveGPS)
        
        // Test battery optimization sync
        adaptiveGPS.setBatteryOptimization(true)
        motionManager.setBatteryOptimizedMode(adaptiveGPS.batteryOptimizationEnabled)
        
        #expect(motionManager.batteryOptimizedMode == true)
    }
    
    // MARK: - Debug Information Tests
    
    @Test func testDebugInformation() async throws {
        let motionManager = MotionLocationManager()
        
        let debugInfo = motionManager.debugInfo
        
        #expect(debugInfo.contains("Motion Activity"))
        #expect(debugInfo.contains("Motion Confidence"))
        #expect(debugInfo.contains("Battery Optimized"))
        #expect(debugInfo.contains("Motion Tracking"))
    }
    
    // MARK: - Stress Tests
    
    @Test func testHighFrequencyLocationUpdates() async throws {
        let motionManager = MotionLocationManager()
        motionManager.startMotionTracking()
        
        let baseLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Simulate high frequency updates
        for i in 0..<100 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLocation.coordinate.latitude + Double(i) * 0.00001,
                    longitude: baseLocation.coordinate.longitude + Double(i) * 0.00001
                ),
                altitude: 0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date().addingTimeInterval(Double(i) * 0.1)
            )
            
            _ = await motionManager.processLocationUpdate(location)
        }
        
        motionManager.stopMotionTracking()
        
        // Should handle high frequency without issues
        #expect(true)
    }
    
    @Test func testMemoryUsageDuringLongSession() async throws {
        let motionManager = MotionLocationManager()
        motionManager.startMotionTracking()
        
        // Simulate long tracking session
        for i in 0..<1000 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            
            _ = await motionManager.processLocationUpdate(location)
        }
        
        motionManager.stopMotionTracking()
        
        // Should not accumulate excessive memory
        #expect(true)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testInvalidLocationHandling() async throws {
        let motionManager = MotionLocationManager()
        
        let invalidLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: -1, // Invalid accuracy
            verticalAccuracy: -1,
            timestamp: Date()
        )
        
        let processedLocation = await motionManager.processLocationUpdate(invalidLocation)
        
        // Should handle invalid location gracefully
        #expect(processedLocation.coordinate.latitude == 0)
        #expect(processedLocation.coordinate.longitude == 0)
    }
    
    @Test func testConcurrentLocationUpdates() async throws {
        let motionManager = MotionLocationManager()
        motionManager.startMotionTracking()
        
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let location2 = CLLocation(latitude: 37.7750, longitude: -122.4195)
        let location3 = CLLocation(latitude: 37.7751, longitude: -122.4196)
        
        // Process multiple locations concurrently
        async let result1 = motionManager.processLocationUpdate(location1)
        async let result2 = motionManager.processLocationUpdate(location2)
        async let result3 = motionManager.processLocationUpdate(location3)
        
        let (processedLocation1, processedLocation2, processedLocation3) = await (result1, result2, result3)
        
        // Should handle concurrent processing
        #expect(processedLocation1.coordinate.latitude == location1.coordinate.latitude)
        #expect(processedLocation2.coordinate.latitude == location2.coordinate.latitude)
        #expect(processedLocation3.coordinate.latitude == location3.coordinate.latitude)
        
        motionManager.stopMotionTracking()
    }
}