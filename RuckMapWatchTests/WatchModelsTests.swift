import Testing
import SwiftData
import Foundation
import CoreLocation
@testable import RuckMapWatch

/// Comprehensive tests for Watch-optimized data models using Swift Testing framework
@Suite("Watch Models Tests")
struct WatchModelsTests {
    
    // MARK: - WatchRuckSession Tests
    
    @Test("WatchRuckSession initialization with default values")
    func watchRuckSessionInitialization() throws {
        let session = WatchRuckSession()
        
        #expect(session.id != UUID())
        #expect(session.totalDistance == 0.0)
        #expect(session.totalDuration == 0.0)
        #expect(session.loadWeight == 0.0)
        #expect(session.totalCalories == 0.0)
        #expect(session.averagePace == 0.0)
        #expect(session.currentPace == 0.0)
        #expect(session.elevationGain == 0.0)
        #expect(session.elevationLoss == 0.0)
        #expect(session.currentElevation == 0.0)
        #expect(session.currentGrade == 0.0)
        #expect(session.isPaused == false)
        #expect(session.isActive == true)
        #expect(session.locationPoints.isEmpty)
        #expect(session.currentLatitude == nil)
        #expect(session.currentLongitude == nil)
        #expect(session.endDate == nil)
    }
    
    @Test("WatchRuckSession initialization with load weight", arguments: [10.0, 25.5, 50.0])
    func watchRuckSessionInitializationWithLoadWeight(loadWeight: Double) throws {
        let session = WatchRuckSession(loadWeight: loadWeight)
        
        #expect(session.loadWeight == loadWeight)
        #expect(session.isActive == true)
        #expect(session.duration > 0) // Should have some duration since start time is set
    }
    
    @Test("WatchRuckSession state management")
    func watchRuckSessionStateManagement() throws {
        let session = WatchRuckSession(loadWeight: 20.0)
        let initialModifiedAt = session.modifiedAt
        
        // Test pause
        session.pause()
        #expect(session.isPaused == true)
        #expect(session.modifiedAt > initialModifiedAt)
        
        // Test resume
        let pausedModifiedAt = session.modifiedAt
        session.resume()
        #expect(session.isPaused == false)
        #expect(session.modifiedAt > pausedModifiedAt)
        
        // Test completion
        let resumedModifiedAt = session.modifiedAt
        session.complete()
        #expect(session.endDate != nil)
        #expect(session.isActive == false)
        #expect(session.modifiedAt > resumedModifiedAt)
        #expect(session.totalDuration > 0)
    }
    
    @Test("WatchRuckSession duration calculation")
    func watchRuckSessionDurationCalculation() throws {
        let session = WatchRuckSession()
        let startTime = session.startDate
        
        // Duration for active session should be from start to now
        let activeDuration = session.duration
        #expect(activeDuration > 0)
        
        // Complete session and verify duration is fixed
        session.complete()
        let completedDuration = session.duration
        #expect(completedDuration > 0)
        #expect(abs(completedDuration - activeDuration) < 1.0) // Should be very close
    }
    
    @Test("WatchRuckSession net elevation calculation", arguments: [
        (10.0, 5.0, 5.0),
        (0.0, 0.0, 0.0),
        (5.0, 10.0, -5.0),
        (100.0, 50.0, 50.0)
    ])
    func watchRuckSessionNetElevationCalculation(gain: Double, loss: Double, expected: Double) throws {
        let session = WatchRuckSession()
        session.elevationGain = gain
        session.elevationLoss = loss
        
        #expect(session.netElevationChange == expected)
    }
    
    // MARK: - WatchLocationPoint Tests
    
    @Test("WatchLocationPoint initialization from CLLocation")
    func watchLocationPointInitializationFromCLLocation() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            course: 45.0,
            speed: 2.5,
            timestamp: Date()
        )
        
        let point = WatchLocationPoint(from: location)
        
        #expect(point.latitude == 37.7749)
        #expect(point.longitude == -122.4194)
        #expect(point.altitude == 100.0)
        #expect(point.horizontalAccuracy == 5.0)
        #expect(point.verticalAccuracy == 3.0)
        #expect(point.course == 45.0)
        #expect(point.speed == 2.5)
        #expect(point.bestAltitude == 100.0)
        #expect(point.timestamp == location.timestamp)
    }
    
    @Test("WatchLocationPoint initialization with negative speed")
    func watchLocationPointInitializationWithNegativeSpeed() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            course: -1.0, // Invalid course
            speed: -2.5, // Negative speed
            timestamp: Date()
        )
        
        let point = WatchLocationPoint(from: location)
        
        #expect(point.speed == 0.0) // Should be clamped to 0
        #expect(point.course == 0.0) // Invalid course should be set to 0
    }
    
    @Test("WatchLocationPoint accuracy validation", arguments: [
        (5.0, true),   // Good accuracy
        (10.0, true),  // Acceptable accuracy
        (15.0, false), // Poor accuracy
        (-1.0, false), // Invalid accuracy
        (0.0, false)   // Zero accuracy
    ])
    func watchLocationPointAccuracyValidation(accuracy: Double, expectedAccurate: Bool) throws {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 100.0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let point = WatchLocationPoint(from: location)
        #expect(point.isAccurate == expectedAccurate)
    }
    
    @Test("WatchLocationPoint distance calculation")
    func watchLocationPointDistanceCalculation() throws {
        let coordinate1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coordinate2 = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4194)
        
        let location1 = CLLocation(coordinate: coordinate1, altitude: 100.0, horizontalAccuracy: 5.0, verticalAccuracy: 3.0, timestamp: Date())
        let location2 = CLLocation(coordinate: coordinate2, altitude: 100.0, horizontalAccuracy: 5.0, verticalAccuracy: 3.0, timestamp: Date())
        
        let point1 = WatchLocationPoint(from: location1)
        let point2 = WatchLocationPoint(from: location2)
        
        let distance = point1.distance(to: point2)
        
        // Should be approximately 1111 meters (1 degree latitude ≈ 111.1 km)
        #expect(distance > 1100.0)
        #expect(distance < 1200.0)
    }
    
    @Test("WatchLocationPoint elevation calculations")
    func watchLocationPointElevationCalculations() throws {
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4194),
            altitude: 150.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let point1 = WatchLocationPoint(from: location1)
        let point2 = WatchLocationPoint(from: location2)
        
        // Test elevation change
        let elevationChange = point1.elevationChange(to: point2)
        #expect(elevationChange == 50.0)
        
        // Test grade calculation
        let grade = point1.gradeTo(point2)
        let expectedGrade = (50.0 / point1.distance(to: point2)) * 100.0
        #expect(abs(grade - expectedGrade) < 0.1)
    }
    
    @Test("WatchLocationPoint grade clamping")
    func watchLocationPointGradeClamping() throws {
        // Create points with extreme elevation difference to test clamping
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749001, longitude: -122.4194), // Very close horizontally
            altitude: 1000.0, // Very high elevation difference
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let point1 = WatchLocationPoint(from: location1)
        let point2 = WatchLocationPoint(from: location2)
        
        let grade = point1.gradeTo(point2)
        
        // Grade should be clamped to ±20%
        #expect(grade <= 20.0)
        #expect(grade >= -20.0)
    }
    
    @Test("WatchLocationPoint heart rate updates")
    func watchLocationPointHeartRateUpdates() throws {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        let point = WatchLocationPoint(from: location)
        
        // Initially no heart rate
        #expect(point.heartRate == nil)
        
        // Update with heart rate
        point.updateHeartRate(150.0)
        #expect(point.heartRate == 150.0)
        
        // Update with nil (sensor disconnected)
        point.updateHeartRate(nil)
        #expect(point.heartRate == nil)
    }
    
    @Test("WatchLocationPoint CLLocation conversion")
    func watchLocationPointCLLocationConversion() throws {
        let originalLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            course: 45.0,
            speed: 2.5,
            timestamp: Date()
        )
        
        let point = WatchLocationPoint(from: originalLocation)
        let convertedLocation = point.clLocation
        
        #expect(convertedLocation.coordinate.latitude == originalLocation.coordinate.latitude)
        #expect(convertedLocation.coordinate.longitude == originalLocation.coordinate.longitude)
        #expect(convertedLocation.altitude == originalLocation.altitude)
        #expect(convertedLocation.horizontalAccuracy == originalLocation.horizontalAccuracy)
        #expect(convertedLocation.verticalAccuracy == originalLocation.verticalAccuracy)
        #expect(convertedLocation.course == originalLocation.course)
        #expect(convertedLocation.speed == originalLocation.speed)
        #expect(convertedLocation.timestamp == originalLocation.timestamp)
    }
    
    // MARK: - WatchStorageStats Tests
    
    @Test("WatchStorageStats initialization and calculations")
    func watchStorageStatsCalculations() throws {
        let stats = WatchStorageStats(
            sessionCount: 5,
            locationPointCount: 1000,
            estimatedSizeKB: 500.0
        )
        
        #expect(stats.sessionCount == 5)
        #expect(stats.locationPointCount == 1000)
        #expect(stats.estimatedSizeKB == 500.0)
        #expect(stats.estimatedSizeMB == 500.0 / 1024.0)
    }
    
    // MARK: - WatchDataError Tests
    
    @Test("WatchDataError descriptions")
    func watchDataErrorDescriptions() throws {
        let noActiveSessionError = WatchDataError.noActiveSession
        #expect(noActiveSessionError.errorDescription == "No active ruck session")
        
        let sessionExistsError = WatchDataError.sessionAlreadyExists
        #expect(sessionExistsError.errorDescription == "A session is already in progress")
        
        let storageError = WatchDataError.storageFailure(NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
        #expect(storageError.errorDescription?.contains("Storage error: Test error") == true)
    }
}

// MARK: - Test Helpers

extension WatchModelsTests {
    
    /// Create a test WatchLocationPoint for testing
    private func createTestLocationPoint(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 100.0,
        accuracy: Double = 5.0,
        speed: Double = 2.0
    ) -> WatchLocationPoint {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3.0,
            course: 45.0,
            speed: speed,
            timestamp: Date()
        )
        return WatchLocationPoint(from: location)
    }
}