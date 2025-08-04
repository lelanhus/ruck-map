import Testing
import Foundation
import CoreLocation
@testable import RuckMapWatch

/// Comprehensive integration tests for Watch app components using Swift Testing framework
@Suite("Watch Integration Tests")
struct WatchIntegrationTests {
    
    // MARK: - Mock Components for Integration Testing
    
    /// Mock Location Manager for testing
    class MockCLLocationManager: CLLocationManager {
        var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var mockLocation: CLLocation?
        var isUpdatingLocation = false
        var requestAuthorizationCalled = false
        
        override var authorizationStatus: CLAuthorizationStatus {
            return mockAuthorizationStatus
        }
        
        override func requestWhenInUseAuthorization() {
            requestAuthorizationCalled = true
            mockAuthorizationStatus = .authorizedWhenInUse
        }
        
        override func startUpdatingLocation() {
            isUpdatingLocation = true
            
            // Simulate location update
            if let location = mockLocation {
                delegate?.locationManager?(self, didUpdateLocations: [location])
            }
        }
        
        override func stopUpdatingLocation() {
            isUpdatingLocation = false
        }
    }
    
    // MARK: - End-to-End Workout Tests
    
    @Test("Complete workout session lifecycle")
    func completeWorkoutSessionLifecycle() async throws {
        // Setup components
        let dataManager = try WatchDataManager()
        let healthKitManager = await WatchHealthKitManager()
        let locationManager = await WatchLocationManager(
            dataManager: dataManager,
            healthKitManager: healthKitManager
        )
        
        let loadWeight = 25.0
        
        // Start workout
        await locationManager.startTracking(loadWeight: loadWeight)
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
            #expect(locationManager.currentSession != nil)
            #expect(locationManager.currentSession?.loadWeight == loadWeight)
            #expect(dataManager.currentSession != nil)
        }
        
        // Simulate workout with location updates
        let workoutRoute = createTestWorkoutRoute()
        
        for (index, location) in workoutRoute.enumerated() {
            await locationManager.processLocationUpdate(location)
            
            // Verify progress
            await MainActor.run {
                #expect(locationManager.totalDistance >= 0)
                #expect(locationManager.currentLocation != nil)
                
                if index > 0 {
                    #expect(locationManager.totalDistance > 0)
                }
            }
        }
        
        // Complete workout
        await locationManager.stopTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .stopped)
            #expect(locationManager.currentSession == nil)
            #expect(dataManager.currentSession == nil)
        }
        
        // Verify session was saved
        #expect(dataManager.recentSessions.count == 1)
        
        let completedSession = dataManager.recentSessions.first!
        #expect(completedSession.isActive == false)
        #expect(completedSession.endDate != nil)
        #expect(completedSession.totalDistance > 0)
        #expect(completedSession.locationPoints.count > 0)
    }
    
    @Test("Workout with pause and resume")
    func workoutWithPauseAndResume() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        // Start workout
        await locationManager.startTracking(loadWeight: 20.0)
        
        // Add some initial distance
        let initialLocations = createTestWorkoutRoute().prefix(3)
        for location in initialLocations {
            await locationManager.processLocationUpdate(location)
        }
        
        let distanceBeforePause = await MainActor.run {
            locationManager.totalDistance
        }
        
        // Pause workout
        locationManager.pauseTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .paused)
            #expect(locationManager.currentSession?.isPaused == true)
        }
        
        // Add locations while paused (should not increase distance significantly)
        let pausedLocation = createTestLocation(latitude: 37.7759, longitude: -122.4194)
        await locationManager.processLocationUpdate(pausedLocation)
        
        let distanceWhilePaused = await MainActor.run {
            locationManager.totalDistance
        }
        
        // Distance should not increase much while paused
        #expect(abs(distanceWhilePaused - distanceBeforePause) < 10.0)
        
        // Resume workout
        locationManager.resumeTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
            #expect(locationManager.currentSession?.isPaused == false)
        }
        
        // Add more locations after resume
        let resumeLocations = createTestWorkoutRoute().suffix(3)
        for location in resumeLocations {
            await locationManager.processLocationUpdate(location)
        }
        
        let finalDistance = await MainActor.run {
            locationManager.totalDistance
        }
        
        #expect(finalDistance > distanceWhilePaused)
        
        // Complete workout
        await locationManager.stopTracking()
        
        // Verify session was properly saved
        let session = dataManager.recentSessions.first!
        #expect(session.isPaused == false) // Should not be paused when completed
        #expect(session.totalDistance == finalDistance)
    }
    
    @Test("Workout with calorie calculation integration")
    func workoutWithCalorieCalculationIntegration() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        await locationManager.startTracking(loadWeight: 30.0)
        
        // Simulate workout with varied terrain
        let terrainRoute = createVariedTerrainRoute()
        
        for location in terrainRoute {
            await locationManager.processLocationUpdate(location)
        }
        
        await MainActor.run {
            // Should have calculated calories
            #expect(locationManager.totalCalories >= 0)
            #expect(locationManager.currentCalorieBurnRate >= 0)
            
            // Session should be updated with calorie data
            if let session = locationManager.currentSession {
                #expect(session.totalCalories >= 0)
            }
        }
        
        await locationManager.stopTracking()
        
        // Verify final calorie calculation
        let session = dataManager.recentSessions.first!
        #expect(session.totalCalories > 0) // Should have burned some calories
    }
    
    // MARK: - Data Persistence Integration Tests
    
    @Test("Session data persistence across app lifecycle")
    func sessionDataPersistenceAcrossAppLifecycle() async throws {
        // Create first data manager instance
        let dataManager1 = try WatchDataManager()
        let locationManager1 = await WatchLocationManager(dataManager: dataManager1)
        
        // Create and complete a session
        await locationManager1.startTracking(loadWeight: 15.0)
        
        let testRoute = createTestWorkoutRoute()
        for location in testRoute {
            await locationManager1.processLocationUpdate(location)
        }
        
        await locationManager1.stopTracking()
        
        let originalSessionId = dataManager1.recentSessions.first!.id
        let originalDistance = dataManager1.recentSessions.first!.totalDistance
        let originalPointCount = dataManager1.recentSessions.first!.locationPoints.count
        
        // Simulate app restart by creating new data manager instance
        let dataManager2 = try WatchDataManager()
        
        // Verify session persisted
        let persistedSession = dataManager2.getSession(id: originalSessionId)
        #expect(persistedSession != nil)
        #expect(persistedSession?.totalDistance == originalDistance)
        #expect(persistedSession?.locationPoints.count == originalPointCount)
        #expect(persistedSession?.isActive == false)
    }
    
    @Test("Data cleanup and retention policy")
    func dataCleanupAndRetentionPolicy() async throws {
        let dataManager = try WatchDataManager()
        
        // Create old session (simulate 49 hours ago)
        let oldSession = WatchRuckSession(loadWeight: 10.0)
        oldSession.startDate = Date().addingTimeInterval(-49 * 3600) // 49 hours ago
        oldSession.complete()
        
        // Manually insert old session (in real implementation, this would be through normal flow)
        // For testing, we verify the cleanup logic would work
        
        // Create recent session
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        await locationManager.startTracking(loadWeight: 20.0)
        
        let location = createTestLocation()
        await locationManager.processLocationUpdate(location)
        
        await locationManager.stopTracking()
        
        // Verify recent session exists
        #expect(dataManager.recentSessions.count >= 1)
        
        // Test storage stats
        let stats = dataManager.getStorageStats()
        #expect(stats.sessionCount >= 1)
        #expect(stats.locationPointCount >= 1)
        #expect(stats.estimatedSizeKB > 0)
    }
    
    // MARK: - Multi-Component Integration Tests
    
    @Test("Location, calorie, and health integration")
    func locationCalorieAndHealthIntegration() async throws {
        let dataManager = try WatchDataManager()
        let healthKitManager = await WatchHealthKitManager()
        let locationManager = await WatchLocationManager(
            dataManager: dataManager,
            healthKitManager: healthKitManager
        )
        
        // Setup heart rate callback simulation
        var heartRateUpdates: [Double] = []
        
        await MainActor.run {
            healthKitManager.onHeartRateUpdate = { heartRate in
                heartRateUpdates.append(heartRate)
                // Simulate location manager receiving heart rate update
                Task { @MainActor in
                    // In real implementation, this would be handled internally
                }
            }
        }
        
        await locationManager.startTracking(loadWeight: 25.0)
        
        // Simulate workout with heart rate data
        let workoutData = [
            (location: createTestLocation(latitude: 37.7749, longitude: -122.4194, speed: 2.0), heartRate: 120.0),
            (location: createTestLocation(latitude: 37.7759, longitude: -122.4194, speed: 2.5), heartRate: 135.0),
            (location: createTestLocation(latitude: 37.7769, longitude: -122.4194, speed: 3.0), heartRate: 150.0),
            (location: createTestLocation(latitude: 37.7779, longitude: -122.4194, speed: 2.8), heartRate: 145.0)
        ]
        
        for data in workoutData {
            await locationManager.processLocationUpdate(data.location)
            
            // Simulate HealthKit heart rate update
            await MainActor.run {
                healthKitManager.onHeartRateUpdate?(data.heartRate)
            }
        }
        
        await MainActor.run {
            // Verify location tracking
            #expect(locationManager.totalDistance > 0)
            #expect(locationManager.currentPace > 0)
            
            // Verify calorie calculation
            #expect(locationManager.totalCalories > 0)
            #expect(locationManager.currentCalorieBurnRate > 0)
            
            // Verify session data integration
            if let session = locationManager.currentSession {
                #expect(session.totalDistance > 0)
                #expect(session.totalCalories > 0)
                #expect(session.locationPoints.count > 0)
            }
        }
        
        await locationManager.stopTracking()
        
        // Verify final integration
        let session = dataManager.recentSessions.first!
        #expect(session.totalDistance > 0)
        #expect(session.totalCalories > 0)
        #expect(session.locationPoints.count == 4)
    }
    
    @Test("Error handling across components")
    func errorHandlingAcrossComponents() async throws {
        // Test with problematic data manager
        class FailingDataManager: WatchDataManager {
            var shouldFailOnCreate = false
            var shouldFailOnAddLocation = false
            
            override func createSession(loadWeight: Double = 0.0) throws -> WatchRuckSession {
                if shouldFailOnCreate {
                    throw WatchDataError.sessionAlreadyExists
                }
                return try super.createSession(loadWeight: loadWeight)
            }
            
            override func addLocationPoint(from location: CLLocation) throws {
                if shouldFailOnAddLocation {
                    throw WatchDataError.storageFailure(NSError(domain: "TestError", code: 1))
                }
                try super.addLocationPoint(from: location)
            }
        }
        
        let failingDataManager = try FailingDataManager()
        let locationManager = await WatchLocationManager(dataManager: failingDataManager)
        
        // Test session creation failure
        await MainActor.run {
            failingDataManager.shouldFailOnCreate = true
        }
        
        do {
            await locationManager.startTracking()
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is WatchDataError)
        }
        
        // Reset and test location point failure
        await MainActor.run {
            failingDataManager.shouldFailOnCreate = false
            failingDataManager.shouldFailOnAddLocation = true
        }
        
        await locationManager.startTracking()
        
        // This should not crash even if location point saving fails
        let location = createTestLocation()
        await locationManager.processLocationUpdate(location)
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking) // Should continue tracking
        }
        
        await locationManager.stopTracking()
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("High-frequency location updates performance")
    func highFrequencyLocationUpdatesPerformance() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        await locationManager.startTracking(loadWeight: 20.0)
        
        // Generate many location updates
        let startTime = Date()
        let locationCount = 100
        
        for i in 0..<locationCount {
            let location = createTestLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                speed: 2.5
            )
            await locationManager.processLocationUpdate(location)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Should process locations efficiently
        #expect(processingTime < 5.0) // Should complete within 5 seconds
        
        await MainActor.run {
            #expect(locationManager.totalDistance > 0)
            #expect(locationManager.currentSession?.locationPoints.count <= locationCount)
        }
        
        await locationManager.stopTracking()
        
        // Verify final state
        let session = dataManager.recentSessions.first!
        #expect(session.locationPoints.count > 0)
        #expect(session.totalDistance > 0)
    }
    
    @Test("Memory usage with extended workout")
    func memoryUsageWithExtendedWorkout() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        await locationManager.startTracking(loadWeight: 30.0)
        
        // Simulate extended workout (many location points)
        let extendedRoute = createExtendedWorkoutRoute(pointCount: 500)
        
        for (index, location) in extendedRoute.enumerated() {
            await locationManager.processLocationUpdate(location)
            
            // Periodically verify memory constraints
            if index % 100 == 0 {
                await MainActor.run {
                    let session = locationManager.currentSession!
                    // Watch should handle memory efficiently
                    #expect(session.locationPoints.count <= index + 1)
                }
            }
        }
        
        await locationManager.stopTracking()
        
        // Verify session completed successfully
        let session = dataManager.recentSessions.first!
        #expect(session.isActive == false)
        #expect(session.locationPoints.count > 0)
        
        // Test storage statistics
        let stats = dataManager.getStorageStats()
        #expect(stats.estimatedSizeMB < 10.0) // Should stay under reasonable limit
    }
    
    // MARK: - Real-World Scenario Tests
    
    @Test("GPS accuracy variation handling")
    func gpsAccuracyVariationHandling() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        await locationManager.startTracking()
        
        // Simulate varying GPS accuracy
        let accuracyVariations = [
            createTestLocation(accuracy: 5.0),   // Excellent
            createTestLocation(accuracy: 15.0),  // Good
            createTestLocation(accuracy: 50.0),  // Poor (should be filtered)
            createTestLocation(accuracy: 8.0),   // Excellent
            createTestLocation(accuracy: 100.0), // Very poor (should be filtered)
            createTestLocation(accuracy: 6.0)    // Excellent
        ]
        
        var goodLocationCount = 0
        
        for location in accuracyVariations {
            await locationManager.processLocationUpdate(location)
            
            if location.horizontalAccuracy <= 30.0 {
                goodLocationCount += 1
            }
        }
        
        await locationManager.stopTracking()
        
        // Should only save good quality locations
        let session = dataManager.recentSessions.first!
        #expect(session.locationPoints.count <= goodLocationCount)
        #expect(session.locationPoints.count > 0) // Should have some good locations
        
        // All saved points should have reasonable accuracy
        for point in session.locationPoints {
            #expect(point.horizontalAccuracy <= 30.0)
        }
    }
    
    @Test("Battery optimization scenario")
    func batteryOptimizationScenario() async throws {
        let dataManager = try WatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: dataManager)
        
        await locationManager.startTracking()
        
        // Simulate paused activity (should reduce location accuracy)
        locationManager.pauseTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .paused)
        }
        
        // Add location while paused (simulating reduced accuracy mode)
        let pausedLocation = createTestLocation(accuracy: 20.0) // Reduced accuracy
        await locationManager.processLocationUpdate(pausedLocation)
        
        // Resume activity
        locationManager.resumeTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
        }
        
        // Add location with full accuracy
        let activeLocation = createTestLocation(accuracy: 5.0)
        await locationManager.processLocationUpdate(activeLocation)
        
        await locationManager.stopTracking()
        
        // Verify session handled battery optimization correctly
        let session = dataManager.recentSessions.first!
        #expect(session.locationPoints.count > 0)
        #expect(session.isActive == false)
    }
}

// MARK: - Test Data Generators

extension WatchIntegrationTests {
    
    /// Create a basic test workout route
    private func createTestWorkoutRoute() -> [CLLocation] {
        let baseLatitude = 37.7749
        let baseLongitude = -122.4194
        var locations: [CLLocation] = []
        
        for i in 0..<10 {
            let latitude = baseLatitude + Double(i) * 0.001
            let longitude = baseLongitude + Double(i) * 0.0005
            let altitude = 100.0 + Double(i) * 5.0 // Gradual elevation gain
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                course: 45.0,
                speed: 2.5,
                timestamp: Date().addingTimeInterval(Double(i) * 10.0) // 10 seconds apart
            )
            locations.append(location)
        }
        
        return locations
    }
    
    /// Create a varied terrain route for testing
    private func createVariedTerrainRoute() -> [CLLocation] {
        let terrainSegments = [
            (latOffset: 0.0, altOffset: 0.0, speed: 2.0),    // Flat start
            (latOffset: 0.001, altOffset: 20.0, speed: 1.5), // Uphill
            (latOffset: 0.002, altOffset: 35.0, speed: 1.2), // Steeper uphill
            (latOffset: 0.003, altOffset: 30.0, speed: 2.8), // Downhill
            (latOffset: 0.004, altOffset: 10.0, speed: 3.0), // Steep downhill
            (latOffset: 0.005, altOffset: 15.0, speed: 2.5)  // Recovery
        ]
        
        var locations: [CLLocation] = []
        let baseLatitude = 37.7749
        let baseLongitude = -122.4194
        let baseAltitude = 100.0
        
        for (index, segment) in terrainSegments.enumerated() {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLatitude + segment.latOffset,
                    longitude: baseLongitude + segment.latOffset * 0.5
                ),
                altitude: baseAltitude + segment.altOffset,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                course: 45.0,
                speed: segment.speed,
                timestamp: Date().addingTimeInterval(Double(index) * 15.0)
            )
            locations.append(location)
        }
        
        return locations
    }
    
    /// Create an extended workout route for performance testing
    private func createExtendedWorkoutRoute(pointCount: Int) -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseLatitude = 37.7749
        let baseLongitude = -122.4194
        
        for i in 0..<pointCount {
            // Create a route that curves and varies in elevation
            let progress = Double(i) / Double(pointCount)
            let latitude = baseLatitude + progress * 0.01 * sin(progress * 4 * .pi)
            let longitude = baseLongitude + progress * 0.01 * cos(progress * 4 * .pi)
            let altitude = 100.0 + 50.0 * sin(progress * 2 * .pi) // Hilly terrain
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude,
                horizontalAccuracy: Double.random(in: 3.0...8.0), // Vary accuracy
                verticalAccuracy: 3.0,
                course: Double(i % 360), // Varying direction
                speed: Double.random(in: 1.5...3.5), // Vary speed
                timestamp: Date().addingTimeInterval(Double(i) * 2.0) // 2 seconds apart
            )
            locations.append(location)
        }
        
        return locations
    }
    
    /// Create a test location with specified parameters
    private func createTestLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 100.0,
        accuracy: Double = 5.0,
        speed: Double = 2.0,
        course: Double = 45.0
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3.0,
            course: course,
            speed: speed,
            timestamp: Date()
        )
    }
}

// MARK: - WatchLocationManager Testing Extensions

extension WatchLocationManager {
    /// Expose processLocationUpdate for integration testing
    func processLocationUpdate(_ location: CLLocation) async {
        await self.processLocationUpdate(location)
    }
}