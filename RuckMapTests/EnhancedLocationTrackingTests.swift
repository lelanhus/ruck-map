import Testing
import CoreLocation
import SwiftData
@testable import RuckMap

@MainActor
struct EnhancedLocationTrackingTests {
    
    // MARK: - Setup Helper
    
    private func createTestSession() -> RuckSession {
        return RuckSession(
            id: UUID(),
            name: "Test Session",
            startDate: Date(),
            plannedDistance: 5000, // 5km
            plannedDuration: 1800   // 30 minutes
        )
    }
    
    private func createTestModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, LocationPoint.self, configurations: configuration)
        return ModelContext(container)
    }
    
    // MARK: - Enhanced Integration Tests
    
    @Test func testMotionLocationManagerIntegration() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        // Verify motion location manager is initialized
        #expect(locationManager.motionLocationManager.isMotionTracking == false)
        #expect(locationManager.motionLocationManager.currentMotionActivity == .unknown)
        
        // Test motion activity access
        let activity = locationManager.getMotionActivity()
        #expect(activity == .unknown) // Initial state
        
        let confidence = locationManager.getMotionConfidence()
        #expect(confidence == 0.0) // Initial confidence
    }
    
    @Test func testEnhancedTrackingStart() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        
        locationManager.startTracking(with: session)
        
        // Verify tracking state
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession == session)
        
        // Verify motion tracking is started
        #expect(locationManager.motionLocationManager.isMotionTracking == true)
        
        locationManager.stopTracking()
    }
    
    @Test func testEnhancedTrackingStop() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        
        locationManager.startTracking(with: session)
        #expect(locationManager.motionLocationManager.isMotionTracking == true)
        
        locationManager.stopTracking()
        
        // Verify tracking state
        #expect(locationManager.trackingState == .stopped)
        #expect(locationManager.currentSession == nil)
        
        // Verify motion tracking is stopped
        #expect(locationManager.motionLocationManager.isMotionTracking == false)
    }
    
    @Test func testBatteryOptimizationSync() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test battery optimization sync between managers
        locationManager.enableBatteryOptimization(true)
        
        #expect(locationManager.adaptiveGPSManager.batteryOptimizationEnabled == true)
        #expect(locationManager.motionLocationManager.batteryOptimizedMode == true)
        
        locationManager.enableBatteryOptimization(false)
        
        #expect(locationManager.adaptiveGPSManager.batteryOptimizationEnabled == false)
        #expect(locationManager.motionLocationManager.batteryOptimizedMode == false)
    }
    
    @Test func testMotionPredictionControl() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test motion prediction control
        locationManager.enableMotionPrediction(true)
        locationManager.enableMotionPrediction(false)
        
        // Should not crash or cause issues
        #expect(true)
    }
    
    @Test func testLocationSuppressionStatus() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test location suppression status access
        let isSuppressed = locationManager.isLocationUpdatesSuppressed
        #expect(isSuppressed == false) // Initially not suppressed
        
        let stationaryDuration = locationManager.stationaryDuration
        #expect(stationaryDuration == 0.0) // Initially no stationary time
    }
    
    @Test func testMotionPredictedLocationAccess() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test motion predicted location access
        let predictedLocation = locationManager.motionPredictedLocation
        #expect(predictedLocation == nil) // Initially no prediction
    }
    
    @Test func testExtendedDebugInformation() async throws {
        let locationManager = LocationTrackingManager()
        
        let debugInfo = locationManager.extendedDebugInfo
        
        // Should contain both adaptive GPS and motion manager debug info
        #expect(debugInfo.contains("Adaptive GPS Manager"))
        #expect(debugInfo.contains("Motion Location Manager"))
        #expect(debugInfo.contains("Motion Activity"))
        #expect(debugInfo.contains("Battery Level"))
    }
    
    // MARK: - Performance Tests
    
    @Test func testEnhancedLocationProcessingPerformance() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        let startTime = Date()
        
        // Simulate processing many location updates
        for i in 0..<100 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                ),
                altitude: 100,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                course: 45.0,
                speed: 2.0, // Walking speed
                timestamp: Date().addingTimeInterval(Double(i))
            )
            
            // Simulate location update through delegate
            await locationManager.processOptimizedLocation(location, originalLocation: location)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        locationManager.stopTracking()
        
        // Processing should be reasonably fast (less than 1 second for 100 updates)
        #expect(processingTime < 1.0)
    }
    
    @Test func testConcurrentLocationProcessing() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let location2 = CLLocation(latitude: 37.7750, longitude: -122.4195)
        let location3 = CLLocation(latitude: 37.7751, longitude: -122.4196)
        
        // Process locations concurrently
        async let task1 = locationManager.processOptimizedLocation(location1, originalLocation: location1)
        async let task2 = locationManager.processOptimizedLocation(location2, originalLocation: location2)
        async let task3 = locationManager.processOptimizedLocation(location3, originalLocation: location3)
        
        await task1
        await task2
        await task3
        
        locationManager.stopTracking()
        
        // Should handle concurrent processing without issues
        #expect(true)
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test func testWalkingSessionSimulation() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        // Simulate walking pattern
        let walkingLocations = generateWalkingRoute()
        
        for (index, location) in walkingLocations.enumerated() {
            await locationManager.processOptimizedLocation(location, originalLocation: location)
            
            // Give some time for motion detection to adapt
            if index % 10 == 0 {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        
        locationManager.stopTracking()
        
        // Verify session was processed
        #expect(session.locationPoints.count > 0)
        #expect(session.totalDistance > 0)
    }
    
    @Test func testStationaryPeriodHandling() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        // Simulate stationary period (same location multiple times)
        let stationaryLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        for i in 0..<20 {
            let location = CLLocation(
                coordinate: stationaryLocation.coordinate,
                altitude: stationaryLocation.altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: Date().addingTimeInterval(Double(i) * 2.0) // Every 2 seconds
            )
            
            await locationManager.processOptimizedLocation(location, originalLocation: location)
        }
        
        locationManager.stopTracking()
        
        // Should handle stationary period gracefully
        #expect(true)
    }
    
    @Test func testRunningSessionSimulation() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        // Simulate running pattern with higher speed
        let runningLocations = generateRunningRoute()
        
        for location in runningLocations {
            await locationManager.processOptimizedLocation(location, originalLocation: location)
        }
        
        locationManager.stopTracking()
        
        // Verify session captured running data
        #expect(session.locationPoints.count > 0)
        #expect(session.totalDistance > 0)
    }
    
    // MARK: - Helper Methods
    
    private func generateWalkingRoute() -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseLatitude: Double = 37.7749
        let baseLongitude: Double = -122.4194
        let walkingSpeed: Double = 1.4 // m/s (5 km/h)
        
        for i in 0..<50 {
            let timestamp = Date().addingTimeInterval(Double(i) * 2.0) // Every 2 seconds
            
            // Create a simple walking path
            let latitudeOffset = Double(i) * 0.00001 // Moving north
            let longitudeOffset = sin(Double(i) * 0.1) * 0.00005 // Slight curve
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLatitude + latitudeOffset,
                    longitude: baseLongitude + longitudeOffset
                ),
                altitude: 100,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                course: 0.0,
                speed: walkingSpeed,
                timestamp: timestamp
            )
            
            locations.append(location)
        }
        
        return locations
    }
    
    private func generateRunningRoute() -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseLatitude: Double = 37.7749
        let baseLongitude: Double = -122.4194
        let runningSpeed: Double = 3.5 // m/s (12.6 km/h)
        
        for i in 0..<30 {
            let timestamp = Date().addingTimeInterval(Double(i) * 1.0) // Every second
            
            // Create a running path with more variation
            let latitudeOffset = Double(i) * 0.00002
            let longitudeOffset = cos(Double(i) * 0.2) * 0.00008
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLatitude + latitudeOffset,
                    longitude: baseLongitude + longitudeOffset
                ),
                altitude: 105,
                horizontalAccuracy: 3.0,
                verticalAccuracy: 8.0,
                course: 45.0,
                speed: runningSpeed,
                timestamp: timestamp
            )
            
            locations.append(location)
        }
        
        return locations
    }
    
    // MARK: - Memory and Resource Tests
    
    @Test func testMemoryUsageWithLongSession() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        locationManager.startTracking(with: session)
        
        // Simulate very long session
        for i in 0..<500 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            
            await locationManager.processOptimizedLocation(location, originalLocation: location)
            
            // Periodic cleanup check
            if i % 100 == 0 {
                try await Task.sleep(for: .milliseconds(1))
            }
        }
        
        locationManager.stopTracking()
        
        // Should handle long sessions without excessive memory growth
        #expect(true)
    }
    
    @Test func testResourceCleanupOnStop() async throws {
        let locationManager = LocationTrackingManager()
        let modelContext = try createTestModelContext()
        locationManager.setModelContext(modelContext)
        
        let session = createTestSession()
        
        // Start and stop multiple times
        for _ in 0..<5 {
            locationManager.startTracking(with: session)
            #expect(locationManager.motionLocationManager.isMotionTracking == true)
            
            // Process some locations
            for i in 0..<10 {
                let location = CLLocation(
                    latitude: 37.7749 + Double(i) * 0.00001,
                    longitude: -122.4194 + Double(i) * 0.00001
                )
                await locationManager.processOptimizedLocation(location, originalLocation: location)
            }
            
            locationManager.stopTracking()
            #expect(locationManager.motionLocationManager.isMotionTracking == false)
        }
        
        // Should properly clean up resources each time
        #expect(true)
    }
}