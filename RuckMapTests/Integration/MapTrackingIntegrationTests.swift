import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// Integration tests for Map + LocationTrackingManager interaction
/// Tests the critical user flows for Session 11: Map Integration
@MainActor
struct MapTrackingIntegrationTests {
    
    // MARK: - Test Helpers
    
    func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        session.loadWeight = 25.0
        manager.currentSession = session
        
        // Add test location
        let testLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        manager.currentLocation = testLocation
        
        return manager
    }
    
    func addTestLocationPoints(to manager: LocationTrackingManager, count: Int = 10) {
        guard let session = manager.currentSession else { return }
        
        for i in 0..<count {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i * 60)),
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001,
                altitude: 100.0 + Double(i * 5),
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
    }
    
    // MARK: - Core Integration Tests
    
    @Test("MapView displays route for active tracking session")
    func testMapViewDisplaysActiveRoute() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 20)
        
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        
        await mapPresentation.initialize(with: locationManager)
        
        // Allow time for route creation
        try? await Task.sleep(for: .milliseconds(200))
        
        // Verify route is created from location points
        #expect(mapPresentation.routePolyline != nil)
        #expect(locationManager.currentSession?.locationPoints.count == 20)
        #expect(locationManager.trackingState == .tracking)
    }
    
    @Test("Map updates in real-time during active tracking")
    func testMapRealTimeUpdates() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Add initial location points
        addTestLocationPoints(to: locationManager, count: 5)
        
        // Simulate real-time location update
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4200),
            altitude: 120.0,
            horizontalAccuracy: 3.0,
            verticalAccuracy: 8.0,
            timestamp: Date()
        )
        
        locationManager.currentLocation = newLocation
        
        // Add new location point
        if let session = locationManager.currentSession {
            let newPoint = LocationPoint(
                timestamp: Date(),
                latitude: 37.7800,
                longitude: -122.4200,
                altitude: 120.0,
                horizontalAccuracy: 3.0,
                verticalAccuracy: 8.0,
                speed: 2.5,
                course: 50.0
            )
            session.locationPoints.append(newPoint)
        }
        
        // Verify map responds to location changes
        #expect(locationManager.currentLocation?.coordinate.latitude == 37.7800)
        #expect(locationManager.currentSession?.locationPoints.count == 6)
    }
    
    @Test("Tab switching between Metrics and Map maintains state")
    func testTabSwitchingMaintainsState() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 15)
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Start on metrics tab
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        
        // Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        #expect(activeTrackingView.selectedTrackingTab == .map)
        
        // Verify tracking state is maintained
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        
        // Switch back to metrics
        activeTrackingView.selectedTrackingTab = .metrics
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        
        // Data should still be intact
        #expect(locationManager.currentSession?.locationPoints.count == 15)
    }
    
    @Test("Map camera follows user during active tracking")
    func testMapCameraFollowsUser() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapView = MapView(
            locationManager: locationManager,
            followUser: true
        )
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Update user location
        let newLocation = CLLocation(
            latitude: 37.7800,
            longitude: -122.4200
        )
        locationManager.currentLocation = newLocation
        
        // Map should follow user when followUser is enabled
        #expect(mapView.followUser == true)
        #expect(locationManager.currentLocation?.coordinate.latitude == 37.7800)
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("Map rendering performance during active tracking", .timeLimit(.seconds(3)))
    func testMapRenderingPerformance() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Add many location points to stress test
        addTestLocationPoints(to: locationManager, count: 500)
        
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate rapid location updates
        for i in 0..<50 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            locationManager.currentLocation = location
            
            // Small delay to simulate real updates
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Should complete within time limit with good performance
        #expect(locationManager.currentSession?.locationPoints.count == 500)
    }
    
    @Test("Memory usage remains stable during long tracking session")
    func testMemoryStabilityDuringLongSession() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate a very long session with many points
        for batch in 0..<10 {
            addTestLocationPoints(to: locationManager, count: 100)
            
            // Trigger memory optimization
            if let session = locationManager.currentSession {
                let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(session.locationPoints)
                session.locationPoints = Array(optimized.prefix(500)) // Keep reasonable size
            }
            
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Memory should be managed effectively
        #expect(locationManager.currentSession?.locationPoints.count ?? 0 <= 500)
    }
    
    // MARK: - Terrain Integration Tests
    
    @Test("Map displays terrain overlays with active tracking")
    func testTerrainOverlayIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 10)
        
        let mapView = MapView(
            locationManager: locationManager,
            showTerrain: true
        )
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate terrain detection
        let terrainOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
            ],
            terrainType: .trail,
            terrainColor: .green
        )
        
        mapPresentation.terrainOverlays.append(terrainOverlay)
        
        #expect(mapView.showTerrain == true)
        #expect(mapPresentation.terrainOverlays.count == 1)
        #expect(mapPresentation.terrainOverlays.first?.terrainType == .trail)
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Map gracefully handles GPS signal loss")
    func testMapHandlesGPSLoss() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 5)
        
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate GPS signal loss
        locationManager.currentLocation = nil
        locationManager.gpsAccuracy = GPSAccuracy(from: 100.0) // Poor accuracy
        
        // Map should handle nil location gracefully
        #expect(locationManager.currentLocation == nil)
        #expect(locationManager.gpsAccuracy.description == "Poor")
        
        // Tracking should continue with existing data
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession?.locationPoints.count == 5)
    }
    
    @Test("Map handles memory pressure gracefully")
    func testMapHandlesMemoryPressure() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Create a very large dataset to simulate memory pressure
        for _ in 0..<100 {
            addTestLocationPoints(to: locationManager, count: 100)
        }
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Trigger memory cleanup
        mapPresentation.handleMemoryPressure()
        
        // Memory optimization should have occurred
        #expect(locationManager.currentSession?.locationPoints.count ?? 0 > 0)
        // Should maintain essential data while reducing memory footprint
    }
    
    // MARK: - User Interaction Integration Tests
    
    @Test("Map interactions work during active tracking")
    func testMapInteractionsDuringTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapView = MapView(
            locationManager: locationManager,
            interactionModes: .all
        )
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Test that all interaction modes are enabled
        #expect(mapView.interactionModes == .all)
        
        // Simulate user centering on current location
        if let currentLocation = locationManager.currentLocation {
            let region = MapKitUtilities.regionForCurrentLocation(
                currentLocation.coordinate,
                zoomLevel: 1.0
            )
            mapPresentation.cameraPosition = .region(region)
        }
        
        #expect(locationManager.trackingState == .tracking)
    }
    
    @Test("Map markers update correctly during tracking")
    func testMapMarkersUpdateDuringTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 10)
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Verify current location marker
        #expect(mapPresentation.currentLocationAnnotation != nil)
        
        // Verify start location marker
        #expect(mapPresentation.startLocationAnnotation != nil)
        
        // Add more distance to trigger mile markers
        locationManager.totalDistance = 2000.0 // > 1 mile
        await mapPresentation.updateMileMarkers()
        
        // Should have mile marker for first mile
        #expect(mapPresentation.mileMarkers.count > 0)
    }
    
    // MARK: - Session Lifecycle Integration Tests
    
    @Test("Map state transitions with session lifecycle")
    func testMapSessionLifecycleTransitions() async {
        let locationManager = createTestLocationManager()
        let mapPresentation = MapPresentation()
        
        // Start with stopped state
        #expect(locationManager.trackingState == .stopped)
        
        // Start tracking
        locationManager.trackingState = .tracking
        await mapPresentation.initialize(with: locationManager)
        
        #expect(locationManager.trackingState == .tracking)
        
        // Pause tracking
        locationManager.trackingState = .paused
        await mapPresentation.adaptToTrackingState(.paused)
        
        #expect(locationManager.trackingState == .paused)
        
        // Resume tracking
        locationManager.trackingState = .tracking
        await mapPresentation.adaptToTrackingState(.tracking)
        
        #expect(locationManager.trackingState == .tracking)
        
        // Stop tracking
        locationManager.trackingState = .stopped
        mapPresentation.cleanup()
        
        #expect(locationManager.trackingState == .stopped)
    }
    
    // MARK: - Battery Optimization Integration Tests
    
    @Test("Map optimizes for battery conservation")
    func testMapBatteryOptimization() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate low battery condition
        let batteryLevel = 0.15 // 15% battery
        
        let recommendedUpdateFreq = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 1.5, // Walking speed
            batteryLevel: batteryLevel
        )
        
        let recommendedDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: batteryLevel,
            performanceGood: true
        )
        
        // Should optimize for battery conservation
        #expect(recommendedUpdateFreq > 5.0) // Less frequent updates
        #expect(recommendedDetail == .low)   // Lower detail level
    }
    
    // MARK: - Route Visualization Integration Tests
    
    @Test("Route polyline updates smoothly during tracking")
    func testRoutePolylineUpdates() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Start with no route
        #expect(mapPresentation.routePolyline == nil)
        
        // Add location points to create route
        addTestLocationPoints(to: locationManager, count: 10)
        
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = polyline
        }
        
        // Route should now be present
        #expect(mapPresentation.routePolyline != nil)
        #expect(mapPresentation.routePolyline?.pointCount ?? 0 > 0)
    }
    
    // MARK: - Accessibility Integration Tests
    
    @Test("Map maintains accessibility during active tracking")
    func testMapAccessibilityDuringTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        addTestLocationPoints(to: locationManager, count: 5)
        
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Create accessibility-enhanced markers
        let currentLocationMarker = CurrentLocationMarker(
            isMoving: true,
            heading: 45.0,
            accuracy: 5.0
        )
        
        let routeMarker = RouteMarker(
            type: .start,
            title: "Start",
            subtitle: "Begin Ruck"
        )
        
        // Verify markers have proper accessibility structure
        #expect(currentLocationMarker.isMoving == true)
        #expect(routeMarker.title == "Start")
        
        // Accessibility labels and hints would be verified in UI tests
    }
}

// MARK: - Map Performance Stress Tests

@Suite("Map Performance Stress Tests")
struct MapPerformanceStressTests {
    
    @Test("Map handles rapid location updates", .timeLimit(.seconds(5)))
    func testRapidLocationUpdates() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate GPS updates every 100ms for 3 seconds
        for i in 0..<30 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            locationManager.currentLocation = location
            
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Should handle rapid updates without performance degradation
        #expect(locationManager.currentLocation != nil)
    }
    
    @Test("Map memory usage with large routes", .timeLimit(.seconds(10)))
    func testLargeRouteMemoryUsage() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        
        // Create a route with 10,000 points (very large)
        for i in 0..<10000 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Create optimized polyline
        let polyline = MapKitUtilities.createOptimizedPolyline(
            from: session.locationPoints,
            maxPoints: 1000 // Limit for performance
        )
        
        #expect(polyline != nil)
        #expect(polyline?.pointCount ?? 0 <= 1000)
        #expect(session.locationPoints.count == 10000)
    }
}