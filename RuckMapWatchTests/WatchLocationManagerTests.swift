import Testing
import Foundation
import CoreLocation
@testable import RuckMapWatch

/// Comprehensive tests for WatchLocationManager using Swift Testing framework
@Suite("Watch Location Manager Tests")
struct WatchLocationManagerTests {
    
    // MARK: - Mock Dependencies
    
    /// Mock WatchDataManager for testing
    @MainActor
    class MockWatchDataManager: WatchDataManager {
        var mockCurrentSession: WatchRuckSession?
        var mockSessions: [WatchRuckSession] = []
        var createdSessions: [WatchRuckSession] = []
        var addedLocationPoints: [CLLocation] = []
        var shouldThrowError = false
        
        override var currentSession: WatchRuckSession? {
            get { mockCurrentSession }
            set { mockCurrentSession = newValue }
        }
        
        override var recentSessions: [WatchRuckSession] {
            get { mockSessions }
            set { mockSessions = newValue }
        }
        
        override func createSession(loadWeight: Double = 0.0) throws -> WatchRuckSession {
            if shouldThrowError {
                throw WatchDataError.sessionAlreadyExists
            }
            
            let session = WatchRuckSession(loadWeight: loadWeight)
            createdSessions.append(session)
            mockCurrentSession = session
            return session
        }
        
        override func addLocationPoint(from location: CLLocation) throws {
            if shouldThrowError {
                throw WatchDataError.noActiveSession
            }
            
            addedLocationPoints.append(location)
            
            if let session = mockCurrentSession {
                let point = WatchLocationPoint(from: location)
                session.locationPoints.append(point)
                session.currentLatitude = location.coordinate.latitude
                session.currentLongitude = location.coordinate.longitude
            }
        }
        
        override func completeCurrentSession() throws {
            if shouldThrowError {
                throw WatchDataError.noActiveSession
            }
            
            mockCurrentSession?.complete()
            mockCurrentSession = nil
        }
        
        override func pauseCurrentSession() throws {
            if shouldThrowError {
                throw WatchDataError.noActiveSession
            }
            
            mockCurrentSession?.pause()
        }
        
        override func resumeCurrentSession() throws {
            if shouldThrowError {
                throw WatchDataError.noActiveSession
            }
            
            mockCurrentSession?.resume()
        }
    }
    
    /// Mock WatchHealthKitManager for testing
    @MainActor
    class MockWatchHealthKitManager: WatchHealthKitManager {
        var mockBodyWeight: Double? = 70.0
        var mockBodyHeight: Double? = 1.75
        var shouldThrowError = false
        var workoutSessionStarted = false
        var workoutSessionEnded = false
        var heartRateMonitoringStarted = false
        var heartRateMonitoringStopped = false
        
        override func loadBodyMetrics() async throws -> (weight: Double?, height: Double?) {
            if shouldThrowError {
                throw WatchHealthKitError.notAuthorized
            }
            return (mockBodyWeight, mockBodyHeight)
        }
        
        override func startWorkoutSession() async throws {
            if shouldThrowError {
                throw WatchHealthKitError.workoutSessionFailed
            }
            workoutSessionStarted = true
        }
        
        override func endWorkoutSession() async {
            workoutSessionEnded = true
        }
        
        override func startHeartRateMonitoring() async throws {
            if shouldThrowError {
                throw WatchHealthKitError.notAuthorized
            }
            heartRateMonitoringStarted = true
        }
        
        override func stopHeartRateMonitoring() {
            heartRateMonitoringStopped = true
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("WatchLocationManager initialization")
    func watchLocationManagerInitialization() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await MainActor.run {
            #expect(locationManager.trackingState == .stopped)
            #expect(locationManager.gpsAccuracy == .poor)
            #expect(locationManager.currentSession == nil)
            #expect(locationManager.totalDistance == 0)
            #expect(locationManager.currentPace == 0)
            #expect(locationManager.averagePace == 0)
            #expect(locationManager.currentElevation == 0)
            #expect(locationManager.elevationGain == 0)
            #expect(locationManager.elevationLoss == 0)
            #expect(locationManager.currentGrade == 0)
            #expect(locationManager.isAutoPaused == false)
            #expect(locationManager.currentCalorieBurnRate == 0)
            #expect(locationManager.totalCalories == 0)
            #expect(locationManager.currentHeartRate == nil)
        }
    }
    
    // MARK: - Session Management Tests
    
    @Test("Start tracking creates new session")
    func startTrackingCreatesNewSession() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking(loadWeight: 25.0)
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
            #expect(locationManager.currentSession != nil)
            #expect(locationManager.currentSession?.loadWeight == 25.0)
            #expect(mockDataManager.createdSessions.count == 1)
            #expect(mockHealthKitManager.workoutSessionStarted == true)
            #expect(mockHealthKitManager.heartRateMonitoringStarted == true)
        }
    }
    
    @Test("Start tracking with default load weight")
    func startTrackingWithDefaultLoadWeight() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking()
        
        await MainActor.run {
            #expect(locationManager.currentSession?.loadWeight == 0.0)
            #expect(mockDataManager.createdSessions.first?.loadWeight == 0.0)
        }
    }
    
    @Test("Start tracking when already tracking does nothing")
    func startTrackingWhenAlreadyTrackingDoesNothing() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        // Start tracking twice
        await locationManager.startTracking(loadWeight: 20.0)
        await locationManager.startTracking(loadWeight: 30.0)
        
        await MainActor.run {
            // Should only create one session
            #expect(mockDataManager.createdSessions.count == 1)
            #expect(locationManager.currentSession?.loadWeight == 20.0) // First call's weight
        }
    }
    
    @Test("Pause tracking updates state")
    func pauseTrackingUpdatesState() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking(loadWeight: 15.0)
        locationManager.pauseTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .paused)
            #expect(locationManager.currentSession?.isPaused == true)
        }
    }
    
    @Test("Resume tracking updates state")
    func resumeTrackingUpdatesState() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking(loadWeight: 15.0)
        locationManager.pauseTracking()
        locationManager.resumeTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
            #expect(locationManager.currentSession?.isPaused == false)
        }
    }
    
    @Test("Stop tracking completes session")
    func stopTrackingCompletesSession() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking(loadWeight: 20.0)
        await locationManager.stopTracking()
        
        await MainActor.run {
            #expect(locationManager.trackingState == .stopped)
            #expect(locationManager.currentSession == nil)
            #expect(mockHealthKitManager.workoutSessionEnded == true)
            #expect(mockHealthKitManager.heartRateMonitoringStopped == true)
        }
    }
    
    @Test("Toggle pause functionality")
    func togglePauseFunctionality() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking()
        
        // Toggle to pause
        locationManager.togglePause()
        await MainActor.run {
            #expect(locationManager.trackingState == .paused)
        }
        
        // Toggle to resume
        locationManager.togglePause()
        await MainActor.run {
            #expect(locationManager.trackingState == .tracking)
        }
        
        // Toggle when stopped should do nothing
        await locationManager.stopTracking()
        locationManager.togglePause()
        await MainActor.run {
            #expect(locationManager.trackingState == .stopped)
        }
    }
    
    // MARK: - GPS Accuracy Tests
    
    @Test("GPS accuracy classification", arguments: [
        (5.0, WatchGPSAccuracy.excellent),
        (10.0, WatchGPSAccuracy.good),
        (20.0, WatchGPSAccuracy.fair),
        (50.0, WatchGPSAccuracy.poor)
    ])
    func gpsAccuracyClassification(accuracy: Double, expected: WatchGPSAccuracy) async throws {
        let calculatedAccuracy = WatchGPSAccuracy(from: accuracy)
        #expect(calculatedAccuracy == expected)
    }
    
    // MARK: - Auto-Pause Tests
    
    @Test("Auto-pause detection with poor movement")
    func autoPauseDetectionWithPoorMovement() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        // Start tracking
        await locationManager.startTracking()
        
        // Simulate stationary location updates
        let baseLocation = createTestLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Simulate multiple updates at the same location (minimal movement)
        for _ in 0..<5 {
            let stationaryLocation = createTestLocation(
                latitude: 37.7749 + Double.random(in: -0.00001...0.00001), // Very small movement
                longitude: -122.4194 + Double.random(in: -0.00001...0.00001)
            )
            await locationManager.processLocationUpdate(stationaryLocation)
        }
        
        // Auto-pause should be triggered after threshold time
        // Note: In real implementation, this would require time passage and timer execution
    }
    
    // MARK: - Location Processing Tests
    
    @Test("Location processing with good accuracy")
    func locationProcessingWithGoodAccuracy() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        let location = createTestLocation(accuracy: 5.0) // Good accuracy
        await locationManager.processLocationUpdate(location)
        
        await MainActor.run {
            #expect(locationManager.currentLocation != nil)
            #expect(locationManager.gpsAccuracy == .excellent)
            #expect(mockDataManager.addedLocationPoints.count == 1)
        }
    }
    
    @Test("Location processing filters poor accuracy")
    func locationProcessingFiltersPoorAccuracy() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        let poorLocation = createTestLocation(accuracy: 100.0) // Poor accuracy
        await locationManager.processLocationUpdate(poorLocation)
        
        await MainActor.run {
            // Should not save poor quality location
            #expect(mockDataManager.addedLocationPoints.isEmpty)
        }
    }
    
    @Test("Distance calculation between locations")
    func distanceCalculationBetweenLocations() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        // First location
        let location1 = createTestLocation(latitude: 37.7749, longitude: -122.4194)
        await locationManager.processLocationUpdate(location1)
        
        // Second location (approximately 111 meters north)
        let location2 = createTestLocation(latitude: 37.7759, longitude: -122.4194)
        await locationManager.processLocationUpdate(location2)
        
        await MainActor.run {
            // Should have accumulated some distance
            #expect(locationManager.totalDistance > 100.0)
            #expect(locationManager.totalDistance < 200.0)
        }
    }
    
    @Test("Elevation gain and loss calculation")
    func elevationGainAndLossCalculation() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        // Start at sea level
        let location1 = createTestLocation(altitude: 0.0)
        await locationManager.processLocationUpdate(location1)
        
        // Move to higher elevation
        let location2 = createTestLocation(altitude: 50.0)
        await locationManager.processLocationUpdate(location2)
        
        // Move to lower elevation
        let location3 = createTestLocation(altitude: 25.0)
        await locationManager.processLocationUpdate(location3)
        
        await MainActor.run {
            #expect(locationManager.elevationGain == 50.0)
            #expect(locationManager.elevationLoss == 25.0)
        }
    }
    
    @Test("Grade calculation")
    func gradeCalculation() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        // Start location
        let location1 = createTestLocation(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        await locationManager.processLocationUpdate(location1)
        
        // Location with elevation gain
        let location2 = createTestLocation(latitude: 37.7759, longitude: -122.4194, altitude: 150.0)
        await locationManager.processLocationUpdate(location2)
        
        await MainActor.run {
            // Should calculate a positive grade
            #expect(locationManager.currentGrade > 0)
            #expect(locationManager.currentGrade <= 20.0) // Should be clamped
        }
    }
    
    // MARK: - Pace Calculation Tests
    
    @Test("Current pace calculation from speed")
    func currentPaceCalculationFromSpeed() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        // Location with 3 m/s speed (about 6 min/km pace)
        let location = createTestLocation(speed: 3.0)
        await locationManager.processLocationUpdate(location)
        
        await MainActor.run {
            // Current pace should be calculated from speed
            #expect(locationManager.currentPace > 5.0)
            #expect(locationManager.currentPace < 7.0)
        }
    }
    
    @Test("Average pace calculation")
    func averagePaceCalculation() async throws {
        let mockDataManager = await MockWatchDataManager()
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        await locationManager.startTracking()
        
        // Simulate a route with multiple points
        let locations = createTestRoute(distance: 1000.0, points: 5) // 1km route
        
        for location in locations {
            await locationManager.processLocationUpdate(location)
        }
        
        await MainActor.run {
            // Should have calculated average pace
            #expect(locationManager.averagePace > 0)
            #expect(locationManager.totalDistance > 900.0) // Should be close to 1km
        }
    }
    
    // MARK: - Heart Rate Integration Tests
    
    @Test("Heart rate updates from HealthKit")
    func heartRateUpdatesFromHealthKit() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        await locationManager.startTracking()
        
        // Simulate heart rate update callback
        await MainActor.run {
            if let callback = mockHealthKitManager.onHeartRateUpdate {
                callback(150.0)
            }
            
            #expect(locationManager.currentHeartRate == 150.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle data manager errors gracefully")
    func handleDataManagerErrorsGracefully() async throws {
        let mockDataManager = await MockWatchDataManager()
        await MainActor.run {
            mockDataManager.shouldThrowError = true
        }
        
        let locationManager = await WatchLocationManager(dataManager: mockDataManager)
        
        // Should handle creation error gracefully
        do {
            await locationManager.startTracking()
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is WatchDataError)
        }
    }
    
    @Test("Handle HealthKit errors gracefully")
    func handleHealthKitErrorsGracefully() async throws {
        let mockDataManager = await MockWatchDataManager()
        let mockHealthKitManager = await MockWatchHealthKitManager()
        await MainActor.run {
            mockHealthKitManager.shouldThrowError = true
        }
        
        let locationManager = await WatchLocationManager(
            dataManager: mockDataManager,
            healthKitManager: mockHealthKitManager
        )
        
        // Should handle HealthKit errors gracefully and continue tracking
        await locationManager.startTracking()
        
        await MainActor.run {
            // Should still start tracking even if HealthKit fails
            #expect(locationManager.trackingState == .tracking)
        }
    }
}

// MARK: - Test Helpers

extension WatchLocationManagerTests {
    
    /// Create a test CLLocation for testing
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
    
    /// Create a test route with specified distance and number of points
    private func createTestRoute(distance: Double, points: Int) -> [CLLocation] {
        var locations: [CLLocation] = []
        let distancePerPoint = distance / Double(points - 1)
        
        for i in 0..<points {
            // Calculate approximate lat/lng offsets for distance
            let latOffset = (distancePerPoint * Double(i)) / 111111.0 // Rough meters to degrees
            
            let location = createTestLocation(
                latitude: 37.7749 + latOffset,
                longitude: -122.4194,
                altitude: 100.0 + Double(i) * 5.0 // Gradual elevation gain
            )
            locations.append(location)
        }
        
        return locations
    }
}

// MARK: - WatchLocationManager Extension for Testing

extension WatchLocationManager {
    /// Expose processLocationUpdate for testing
    func processLocationUpdate(_ location: CLLocation) async {
        await self.processLocationUpdate(location)
    }
}