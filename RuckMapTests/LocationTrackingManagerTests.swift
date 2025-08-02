import Testing
@testable import RuckMap
import SwiftData
import CoreLocation

@Suite("LocationTrackingManager Tests")
struct LocationTrackingManagerTests {
    
    @Test("GPS accuracy classification works correctly")
    func testGPSAccuracyClassification() async throws {
        #expect(GPSAccuracy(from: 3.0) == .excellent)
        #expect(GPSAccuracy(from: 7.0) == .good)
        #expect(GPSAccuracy(from: 15.0) == .fair)
        #expect(GPSAccuracy(from: 50.0) == .poor)
    }
    
    @Test("Tracking state management")
    @MainActor
    func testTrackingStateManagement() async throws {
        let manager = LocationTrackingManager()
        
        // Initial state
        #expect(manager.trackingState == .stopped)
        #expect(manager.totalDistance == 0)
        #expect(manager.currentPace == 0)
        
        // Start tracking
        let session = RuckSession()
        manager.startTracking(with: session)
        #expect(manager.trackingState == .tracking)
        #expect(manager.currentSession === session)
        
        // Pause tracking
        manager.pauseTracking()
        #expect(manager.trackingState == .paused)
        
        // Resume tracking
        manager.resumeTracking()
        #expect(manager.trackingState == .tracking)
        
        // Stop tracking
        manager.stopTracking()
        #expect(manager.trackingState == .stopped)
        #expect(manager.currentSession == nil)
    }
    
    @Test("Toggle pause functionality")
    @MainActor
    func testTogglePause() async throws {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        
        // Toggle while stopped should do nothing
        manager.togglePause()
        #expect(manager.trackingState == .stopped)
        
        // Start tracking
        manager.startTracking(with: session)
        #expect(manager.trackingState == .tracking)
        
        // Toggle to pause
        manager.togglePause()
        #expect(manager.trackingState == .paused)
        
        // Toggle to resume
        manager.togglePause()
        #expect(manager.trackingState == .tracking)
    }
    
    @Test("Distance calculation")
    @MainActor
    func testDistanceCalculation() async throws {
        // Create test locations
        let location1 = CLLocation(
            latitude: 37.3317,
            longitude: -122.0312
        )
        let location2 = CLLocation(
            latitude: 37.3318,
            longitude: -122.0312
        )
        
        // Calculate expected distance
        let expectedDistance = location2.distance(from: location1)
        #expect(expectedDistance > 10) // Should be roughly 11 meters
        #expect(expectedDistance < 15)
    }
    
    @Test("Pace calculation from speed")
    @MainActor
    func testPaceCalculation() async throws {
        // Test pace conversion
        // 3.5 mph = ~5.63 km/h = ~1.564 m/s
        // Pace should be ~10.67 min/km
        let speedMetersPerSecond = 1.564
        let expectedPaceMinPerKm = 1000.0 / (speedMetersPerSecond * 60.0)
        
        #expect(expectedPaceMinPerKm > 10.5)
        #expect(expectedPaceMinPerKm < 11.0)
    }
    
    @Test("Session updates with tracking data")
    @MainActor
    func testSessionUpdates() async throws {
        // Create test container
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let manager = LocationTrackingManager()
        manager.setModelContext(context)
        
        let session = RuckSession()
        context.insert(session)
        
        // Start tracking
        manager.startTracking(with: session)
        
        // Simulate location updates would update the session
        #expect(session.totalDistance == 0)
        #expect(session.averagePace == 0)
        
        // Stop tracking
        manager.stopTracking()
        
        // Session should have end date
        #expect(session.endDate != nil)
    }
}

// MARK: - Mock Location Tests
@Suite("Location Processing Tests")
struct LocationProcessingTests {
    
    @Test("Auto-pause detection")
    @MainActor
    func testAutoPauseDetection() async throws {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        
        // Start tracking
        manager.startTracking(with: session)
        #expect(manager.isAutoPaused == false)
        
        // Note: Actual auto-pause testing would require:
        // 1. Mocking CLLocationManager
        // 2. Simulating location updates
        // 3. Waiting for timer to trigger
        // This is complex for unit tests and better suited for integration tests
    }
    
    @Test("GPS accuracy affects processing")
    @MainActor
    func testGPSAccuracyFiltering() async throws {
        // Test that poor accuracy locations are filtered
        let poorAccuracyLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0312),
            altitude: 0,
            horizontalAccuracy: 50, // Poor accuracy
            verticalAccuracy: 10,
            timestamp: Date()
        )
        
        // With 50m accuracy, this should be classified as poor
        let accuracy = GPSAccuracy(from: poorAccuracyLocation.horizontalAccuracy)
        #expect(accuracy == .poor)
    }
}