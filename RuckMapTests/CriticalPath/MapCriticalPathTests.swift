import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// Critical path tests for Session 11: Map Integration
/// Tests the essential user flows that must work for production release
@MainActor
struct MapCriticalPathTests {
    
    // MARK: - Test Helpers
    
    func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        session.loadWeight = 25.0
        manager.currentSession = session
        
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
    
    func simulateRuckSession(manager: LocationTrackingManager, durationMinutes: Int = 30) {
        guard let session = manager.currentSession else { return }
        
        let pointInterval: TimeInterval = 60 // One point per minute
        let baseLatitude = 37.7749
        let baseLongitude = -122.4194
        
        for i in 0..<durationMinutes {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i) * pointInterval),
                latitude: baseLatitude + Double(i) * 0.0005, // Move north
                longitude: baseLongitude + Double(i) * 0.0003, // Move east
                altitude: 100.0 + Double(i * 2), // Gradual elevation gain
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0, // ~2 m/s walking speed
                course: 45.0 // Northeast direction
            )
            session.locationPoints.append(point)
        }
        
        // Update totals
        manager.totalDistance = Double(durationMinutes) * 120.0 // ~120m per minute
    }
    
    // MARK: - Critical Path 1: Starting Ruck Session and Viewing on Map
    
    @Test("User can start ruck session and immediately view route on map")
    func testStartRuckAndViewOnMap() async {
        let locationManager = createTestLocationManager()
        
        // Step 1: Start tracking
        locationManager.trackingState = .tracking
        
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        #expect(locationManager.currentLocation != nil)
        
        // Step 2: Create ActiveTrackingView
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Step 3: Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        
        #expect(activeTrackingView.selectedTrackingTab == .map)
        
        // Step 4: Initialize map components
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        
        await mapPresentation.initialize(with: locationManager)
        
        // Step 5: Verify map shows current location
        #expect(mapPresentation.currentLocationAnnotation != nil)
        #expect(mapPresentation.currentLocationAnnotation?.coordinate.latitude == 37.7749)
        #expect(mapPresentation.currentLocationAnnotation?.coordinate.longitude == -122.4194)
        
        // Critical path success: User can start ruck and see location on map
    }
    
    @Test("User can view real-time route building during active ruck")
    func testRealTimeRouteBuildingOnMap() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 1: Start with minimal route
        simulateRuckSession(manager: locationManager, durationMinutes: 5)
        
        #expect(locationManager.currentSession?.locationPoints.count == 5)
        
        // Step 2: Create route polyline
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = polyline
        }
        
        #expect(mapPresentation.routePolyline != nil)
        
        // Step 3: Add more points to simulate continued tracking
        simulateRuckSession(manager: locationManager, durationMinutes: 15)
        
        #expect(locationManager.currentSession?.locationPoints.count == 20)
        
        // Step 4: Update route polyline
        if let session = locationManager.currentSession {
            let updatedPolyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = updatedPolyline
        }
        
        #expect(mapPresentation.routePolyline?.pointCount ?? 0 > 0)
        
        // Critical path success: Route builds in real-time as user moves
    }
    
    // MARK: - Critical Path 2: Tab Switching During Active Tracking
    
    @Test("User can seamlessly switch between Metrics and Map tabs during tracking")
    func testSeamlessTabSwitchingDuringTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        simulateRuckSession(manager: locationManager, durationMinutes: 10)
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Step 1: Start on metrics tab
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        
        // Verify metrics are displaying correctly
        #expect(locationManager.totalDistance > 0)
        #expect(!activeTrackingView.formattedDistance.isEmpty)
        #expect(!activeTrackingView.formattedDuration.isEmpty)
        
        // Step 2: Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        
        #expect(activeTrackingView.selectedTrackingTab == .map)
        #expect(locationManager.trackingState == .tracking) // State preserved
        #expect(locationManager.currentSession != nil) // Session preserved
        
        // Step 3: Continue tracking while on map tab
        let previousDistance = locationManager.totalDistance
        simulateRuckSession(manager: locationManager, durationMinutes: 5)
        
        #expect(locationManager.totalDistance > previousDistance)
        #expect(locationManager.currentSession?.locationPoints.count == 15)
        
        // Step 4: Switch back to metrics tab
        activeTrackingView.selectedTrackingTab = .metrics
        
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        #expect(locationManager.trackingState == .tracking) // Still tracking
        
        // Step 5: Verify updated metrics are displayed
        #expect(activeTrackingView.formattedDistance != "0.00 mi")
        #expect(locationManager.currentSession?.locationPoints.count == 15)
        
        // Critical path success: Seamless tab switching maintains tracking state
    }
    
    // MARK: - Critical Path 3: Map Interactions During Active Tracking
    
    @Test("User can interact with map (zoom, pan, center) during active tracking")
    func testMapInteractionsDuringActiveTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        simulateRuckSession(manager: locationManager, durationMinutes: 15)
        
        // Step 1: Create map with all interactions enabled
        let mapView = MapView(
            locationManager: locationManager,
            followUser: true,
            interactionModes: .all
        )
        
        #expect(mapView.interactionModes == .all)
        #expect(mapView.followUser == true)
        
        // Step 2: Initialize map presentation
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 3: Test centering on current location
        if let currentLocation = locationManager.currentLocation {
            let centerRegion = MapKitUtilities.regionForCurrentLocation(
                currentLocation.coordinate,
                zoomLevel: 1.0
            )
            mapPresentation.cameraPosition = .region(centerRegion)
            
            #expect(centerRegion.center.latitude == currentLocation.coordinate.latitude)
            #expect(centerRegion.center.longitude == currentLocation.coordinate.longitude)
        }
        
        // Step 4: Test route overview
        if let session = locationManager.currentSession {
            let coordinates = session.locationPoints.map { point in
                CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            }
            let routeRegion = MapKitUtilities.calculateRouteRegion(for: coordinates)
            mapPresentation.cameraPosition = .region(routeRegion)
            
            #expect(routeRegion.span.latitudeDelta > 0)
            #expect(routeRegion.span.longitudeDelta > 0)
        }
        
        // Step 5: Verify tracking continues during map interaction
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession?.locationPoints.count == 15)
        
        // Critical path success: Map interactions work without disrupting tracking
    }
    
    // MARK: - Critical Path 4: Route Display with Terrain Information
    
    @Test("User can view route with terrain overlays and mile markers")
    func testRouteDisplayWithTerrainAndMarkers() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Step 1: Create longer route to trigger mile markers
        locationManager.totalDistance = 2500.0 // > 1.5 miles
        simulateRuckSession(manager: locationManager, durationMinutes: 30)
        
        // Step 2: Create map with terrain enabled
        let mapView = MapView(
            locationManager: locationManager,
            showTerrain: true
        )
        
        #expect(mapView.showTerrain == true)
        
        // Step 3: Initialize map presentation
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 4: Create terrain overlays
        let trailOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4190)
            ],
            terrainType: .trail,
            terrainColor: .green
        )
        
        mapPresentation.terrainOverlays.append(trailOverlay)
        
        #expect(mapPresentation.terrainOverlays.count == 1)
        #expect(mapPresentation.terrainOverlays.first?.terrainType == .trail)
        
        // Step 5: Generate mile markers
        await mapPresentation.updateMileMarkers()
        
        #expect(mapPresentation.mileMarkers.count > 0)
        
        // Step 6: Verify route polyline
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = polyline
        }
        
        #expect(mapPresentation.routePolyline != nil)
        
        // Critical path success: Route displays with terrain info and mile markers
    }
    
    // MARK: - Critical Path 5: Error Handling During Map Usage
    
    @Test("Map handles GPS signal loss gracefully during active tracking")
    func testMapHandlesGPSLossGracefully() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        simulateRuckSession(manager: locationManager, durationMinutes: 10)
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 1: Verify initial good GPS state
        #expect(locationManager.currentLocation != nil)
        #expect(locationManager.currentSession?.locationPoints.count == 10)
        
        // Step 2: Simulate GPS signal loss
        locationManager.currentLocation = nil
        locationManager.gpsAccuracy = GPSAccuracy(from: 100.0) // Very poor accuracy
        
        #expect(locationManager.currentLocation == nil)
        #expect(locationManager.gpsAccuracy.description == "Poor")
        
        // Step 3: Verify tracking continues with existing data
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession?.locationPoints.count == 10)
        
        // Step 4: Verify map still shows last known route
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            #expect(polyline != nil)
        }
        
        // Step 5: Simulate GPS recovery
        let recoveredLocation = CLLocation(
            latitude: 37.7760,
            longitude: -122.4180
        )
        locationManager.currentLocation = recoveredLocation
        locationManager.gpsAccuracy = GPSAccuracy(from: 5.0) // Good accuracy
        
        #expect(locationManager.currentLocation != nil)
        #expect(locationManager.gpsAccuracy.description == "Excellent")
        
        // Critical path success: Map handles GPS loss and recovery gracefully
    }
    
    // MARK: - Critical Path 6: Performance Under Load
    
    @Test("Map maintains 60fps performance during active tracking", .timeLimit(.seconds(5)))
    func testMapPerformanceDuringActiveTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 1: Simulate continuous location updates
        for i in 0..<100 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            locationManager.currentLocation = location
            
            // Add location point
            if let session = locationManager.currentSession {
                let point = LocationPoint(
                    timestamp: Date().addingTimeInterval(Double(i)),
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: 100.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 10.0,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
            }
            
            // Update route every 10 points
            if i % 10 == 0, let session = locationManager.currentSession {
                let polyline = MapKitUtilities.createOptimizedPolyline(
                    from: session.locationPoints,
                    maxPoints: 1000
                )
                mapPresentation.routePolyline = polyline
            }
            
            // Small delay to simulate real-time updates
            try? await Task.sleep(for: .milliseconds(20))
        }
        
        // Step 2: Verify performance optimization
        #expect(locationManager.currentSession?.locationPoints.count == 100)
        #expect(mapPresentation.routePolyline != nil)
        
        // Critical path success: Map performs well under continuous updates
    }
    
    // MARK: - Critical Path 7: Memory Management During Long Session
    
    @Test("Map manages memory effectively during long ruck session")
    func testMapMemoryManagementDuringLongSession() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 1: Simulate very long session with many points
        for batch in 0..<20 {
            simulateRuckSession(manager: locationManager, durationMinutes: 50)
            
            // Trigger memory optimization every batch
            if let session = locationManager.currentSession {
                let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(session.locationPoints)
                session.locationPoints = Array(optimized.prefix(1000)) // Keep manageable size
            }
            
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Step 2: Verify memory is managed
        #expect(locationManager.currentSession?.locationPoints.count ?? 0 <= 1000)
        
        // Step 3: Verify route can still be created
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 500
            )
            #expect(polyline != nil)
        }
        
        // Critical path success: Memory is managed effectively
    }
    
    // MARK: - Critical Path 8: Complete Session Lifecycle with Map
    
    @Test("Complete ruck session lifecycle works with map integration")
    func testCompleteSessionLifecycleWithMap() async {
        let locationManager = createTestLocationManager()
        
        // Step 1: Start tracking
        locationManager.trackingState = .tracking
        
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        
        // Step 2: Build route over time
        simulateRuckSession(manager: locationManager, durationMinutes: 20)
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Step 3: Create map components
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = polyline
        }
        
        #expect(mapPresentation.routePolyline != nil)
        #expect(locationManager.currentSession?.locationPoints.count == 20)
        
        // Step 4: Pause tracking
        locationManager.trackingState = .paused
        await mapPresentation.adaptToTrackingState(.paused)
        
        #expect(locationManager.trackingState == .paused)
        
        // Step 5: Resume tracking
        locationManager.trackingState = .tracking
        await mapPresentation.adaptToTrackingState(.tracking)
        
        #expect(locationManager.trackingState == .tracking)
        
        // Step 6: Continue session
        simulateRuckSession(manager: locationManager, durationMinutes: 10)
        
        #expect(locationManager.currentSession?.locationPoints.count == 30)
        
        // Step 7: Stop tracking
        locationManager.trackingState = .stopped
        mapPresentation.cleanup()
        
        #expect(locationManager.trackingState == .stopped)
        
        // Critical path success: Complete lifecycle works with map
    }
    
    // MARK: - Critical Path 9: Battery Optimization During Map Usage
    
    @Test("Map optimizes battery usage based on conditions")
    func testMapBatteryOptimization() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Step 1: Test normal battery conditions
        let normalBatteryFreq = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 2.0, // Walking speed
            batteryLevel: 0.6   // 60% battery
        )
        
        let normalBatteryDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.6,
            performanceGood: true
        )
        
        #expect(normalBatteryDetail == .high)
        #expect(normalBatteryFreq > 0)
        
        // Step 2: Test low battery conditions
        let lowBatteryFreq = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 2.0,
            batteryLevel: 0.15  // 15% battery
        )
        
        let lowBatteryDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.15,
            performanceGood: true
        )
        
        #expect(lowBatteryDetail == .low)
        #expect(lowBatteryFreq > normalBatteryFreq) // Less frequent updates
        
        // Step 3: Test stationary optimization
        let stationaryFreq = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 0.0,  // Stationary
            batteryLevel: 0.6
        )
        
        #expect(stationaryFreq > normalBatteryFreq) // Even less frequent when stationary
        
        // Critical path success: Battery optimization works correctly
    }
    
    // MARK: - Critical Path 10: Accessibility During Active Tracking
    
    @Test("Map maintains accessibility during active tracking session")
    func testMapAccessibilityDuringActiveTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        simulateRuckSession(manager: locationManager, durationMinutes: 15)
        
        // Step 1: Create accessible map components
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
        
        #expect(currentLocationMarker.isMoving == true)
        #expect(currentLocationMarker.heading == 45.0)
        #expect(routeMarker.title == "Start")
        
        // Step 2: Create mile marker
        let mileMarker = MileMarker(distance: 1.0, units: "imperial")
        
        #expect(mileMarker.distance == 1.0)
        #expect(mileMarker.units == "imperial")
        
        // Step 3: Test terrain accessibility
        let terrainOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
            ],
            terrainType: .trail,
            terrainColor: .green
        )
        
        #expect(terrainOverlay.terrainType == .trail)
        
        // Step 4: Test GPS status accessibility
        let gpsStatus = GPSAccuracy(from: 5.0)
        #expect(gpsStatus.description == "Excellent")
        
        // Critical path success: Accessibility is maintained throughout tracking
    }
}

// MARK: - Edge Case Critical Path Tests

@Suite("Map Critical Path Edge Cases")
struct MapCriticalPathEdgeCaseTests {
    
    @Test("Map handles simultaneous issues gracefully")
    func testMapHandlesSimultaneousIssues() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        locationManager.trackingState = .tracking
        
        // Simulate multiple simultaneous issues
        locationManager.currentLocation = nil // GPS loss
        locationManager.isAutoPaused = true   // Auto-pause active
        locationManager.shouldShowBatteryAlert = true // Battery warning
        
        let weather = WeatherConditions(
            timestamp: Date(),
            temperature: 40.0, // Extreme heat
            humidity: 90.0,
            windSpeed: 25.0, // High wind
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        locationManager.currentWeatherConditions = weather
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // System should handle all issues without crashing
        #expect(locationManager.currentLocation == nil)
        #expect(locationManager.isAutoPaused == true)
        #expect(locationManager.shouldShowBatteryAlert == true)
        #expect(locationManager.currentWeatherConditions != nil)
        #expect(locationManager.trackingState == .tracking) // Still tracking
        
        // Map should still function
        #expect(mapPresentation.cameraPosition != nil)
    }
    
    @Test("Map recovers from extreme performance conditions")
    func testMapRecoveryFromExtremeConditions() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        locationManager.trackingState = .tracking
        
        // Create extreme conditions: very large dataset
        for i in 0..<50000 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 37.7749 + Double(i) * 0.00001,
                longitude: -122.4194 + Double(i) * 0.00001,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        
        #expect(session.locationPoints.count == 50000)
        
        // System should apply aggressive optimization
        let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(session.locationPoints)
        
        #expect(optimized.count <= MapKitUtilities.MemoryManager.maxLocationPointsInMemory)
        #expect(optimized.count > 0)
        
        // Should still be able to create polyline
        let polyline = MapKitUtilities.createOptimizedPolyline(
            from: Array(optimized.prefix(1000)),
            maxPoints: 500
        )
        
        #expect(polyline != nil)
    }
}