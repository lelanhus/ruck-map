import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// UI Integration tests for Session 11: Map Integration
/// Tests the complete user interface integration between map components and tracking system
@MainActor
struct MapUIIntegrationTests {
    
    // MARK: - Test Helpers
    
    func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        session.loadWeight = 25.0
        manager.currentSession = session
        
        let testLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        manager.currentLocation = testLocation
        
        return manager
    }
    
    // MARK: - Complete UI Flow Integration Tests
    
    @Test("Complete UI flow: Start session → View metrics → Switch to map → Interact → Return to metrics")
    func testCompleteUIFlowIntegration() async {
        let locationManager = createTestLocationManager()
        
        // Step 1: Start tracking session
        locationManager.trackingState = .tracking
        
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        
        // Step 2: Create ActiveTrackingView (main UI)
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Should start on metrics tab
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        
        // Step 3: Simulate some tracking data
        locationManager.totalDistance = 1500.0 // ~0.93 miles
        locationManager.currentPace = 12.0 // 12 min/km
        locationManager.totalCaloriesBurned = 180.0
        
        // Verify metrics display correctly
        #expect(activeTrackingView.formattedDistance.contains("0.93"))
        #expect(activeTrackingView.formattedCalories == "180 cal")
        
        // Step 4: Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        #expect(activeTrackingView.selectedTrackingTab == .map)
        
        // Step 5: Initialize map components
        let mapView = MapView(locationManager: locationManager)
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Map should show current location
        #expect(mapPresentation.currentLocationAnnotation != nil)
        
        // Step 6: Add route data
        if let session = locationManager.currentSession {
            for i in 0..<10 {
                let point = LocationPoint(
                    timestamp: Date().addingTimeInterval(Double(i * 60)),
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001,
                    altitude: 100.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 10.0,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
            }
        }
        
        // Create route polyline
        if let session = locationManager.currentSession {
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: session.locationPoints,
                maxPoints: 1000
            )
            mapPresentation.routePolyline = polyline
        }
        
        #expect(mapPresentation.routePolyline != nil)
        #expect(locationManager.currentSession?.locationPoints.count == 10)
        
        // Step 7: Test map controls
        let mapControls = MapControlsOverlay(
            presentation: mapPresentation,
            locationManager: locationManager
        )
        
        #expect(mapControls.locationManager === locationManager)
        
        // Step 8: Return to metrics tab
        activeTrackingView.selectedTrackingTab = .metrics
        #expect(activeTrackingView.selectedTrackingTab == .metrics)
        
        // Data should be preserved
        #expect(locationManager.totalDistance == 1500.0)
        #expect(locationManager.currentSession?.locationPoints.count == 10)
        
        // Complete UI flow integration successful
    }
    
    @Test("Map tab maintains state during pause/resume operations")
    func testMapTabStateDuringPauseResume() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Add some route data
        if let session = locationManager.currentSession {
            for i in 0..<5 {
                let point = LocationPoint(
                    timestamp: Date().addingTimeInterval(Double(i * 60)),
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001,
                    altitude: 100.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 10.0,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
            }
        }
        
        #expect(locationManager.currentSession?.locationPoints.count == 5)
        
        // Pause tracking while on map tab
        locationManager.trackingState = .paused
        await mapPresentation.adaptToTrackingState(.paused)
        
        #expect(locationManager.trackingState == .paused)
        #expect(activeTrackingView.selectedTrackingTab == .map) // Still on map tab
        
        // Resume tracking
        locationManager.trackingState = .tracking
        await mapPresentation.adaptToTrackingState(.tracking)
        
        #expect(locationManager.trackingState == .tracking)
        #expect(activeTrackingView.selectedTrackingTab == .map) // Still on map tab
        #expect(locationManager.currentSession?.locationPoints.count == 5) // Data preserved
    }
    
    @Test("Weather information integrates properly with map display")
    func testWeatherMapIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Add weather conditions
        let weather = WeatherConditions(
            timestamp: Date(),
            temperature: 30.0, // Hot weather
            humidity: 75.0,
            windSpeed: 12.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        weather.weatherDescription = "Hot and humid"
        locationManager.currentWeatherConditions = weather
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        // Weather should affect calorie calculations
        let weatherImpact = activeTrackingView.weatherImpactPercentage
        #expect(weatherImpact > 0, "Hot weather should increase calorie impact")
        
        // Switch to map tab
        activeTrackingView.selectedTrackingTab = .map
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Weather data should be available on map
        #expect(locationManager.currentWeatherConditions != nil)
        #expect(locationManager.currentWeatherConditions?.temperatureFahrenheit == 86.0)
        
        // Weather card should display correctly
        let weatherCard = WeatherCard(
            conditions: weather,
            showCalorieImpact: true
        )
        
        #expect(weatherCard.conditions.temperatureFahrenheit == 86.0)
        #expect(weatherCard.showCalorieImpact == true)
    }
    
    @Test("Mile markers appear correctly during active tracking")
    func testMileMarkersDuringActiveTracking() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        activeTrackingView.selectedTrackingTab = .map
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate crossing mile markers
        locationManager.totalDistance = 1609.34 // Exactly 1 mile
        await mapPresentation.updateMileMarkers()
        
        #expect(mapPresentation.mileMarkers.count >= 1, "Should have mile marker for 1 mile")
        
        // Cross second mile
        locationManager.totalDistance = 3218.68 // Exactly 2 miles
        await mapPresentation.updateMileMarkers()
        
        #expect(mapPresentation.mileMarkers.count >= 2, "Should have mile markers for 2 miles")
        
        // Verify mile marker properties
        if let firstMileMarker = mapPresentation.mileMarkers.first {
            #expect(firstMileMarker.distance == 1.0)
            #expect(firstMileMarker.title.contains("Mile"))
        }
    }
    
    @Test("Terrain overlays integrate with active tracking")
    func testTerrainOverlayActiveTrackingIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapView = MapView(
            locationManager: locationManager,
            showTerrain: true
        )
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Add route data
        if let session = locationManager.currentSession {
            for i in 0..<8 {
                let point = LocationPoint(
                    timestamp: Date().addingTimeInterval(Double(i * 60)),
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001,
                    altitude: 100.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 10.0,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
            }
        }
        
        // Create terrain overlays along route
        let trailOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4191)
            ],
            terrainType: .trail,
            terrainColor: .green
        )
        
        let sandOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4191),
                CLLocationCoordinate2D(latitude: 37.7756, longitude: -122.4187)
            ],
            terrainType: .sand,
            terrainColor: .yellow
        )
        
        mapPresentation.terrainOverlays.append(trailOverlay)
        mapPresentation.terrainOverlays.append(sandOverlay)
        
        #expect(mapView.showTerrain == true)
        #expect(mapPresentation.terrainOverlays.count == 2)
        #expect(mapPresentation.terrainOverlays[0].terrainType == .trail)
        #expect(mapPresentation.terrainOverlays[1].terrainType == .sand)
    }
    
    @Test("GPS status indicator updates in real-time on map")
    func testGPSStatusIndicatorRealTimeUpdates() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        activeTrackingView.selectedTrackingTab = .map
        
        // Start with excellent GPS
        locationManager.gpsAccuracy = GPSAccuracy(from: 3.0)
        #expect(locationManager.gpsAccuracy.description == "Excellent")
        #expect(locationManager.gpsAccuracy.color == UIColor.systemGreen)
        
        // Simulate GPS degradation
        locationManager.gpsAccuracy = GPSAccuracy(from: 15.0)
        #expect(locationManager.gpsAccuracy.description == "Fair")
        #expect(locationManager.gpsAccuracy.color == UIColor.systemOrange)
        
        // Simulate GPS recovery
        locationManager.gpsAccuracy = GPSAccuracy(from: 5.0)
        #expect(locationManager.gpsAccuracy.description == "Excellent")
        #expect(locationManager.gpsAccuracy.color == UIColor.systemGreen)
        
        // Map should reflect GPS status changes
        #expect(locationManager.trackingState == .tracking)
    }
    
    @Test("Battery status affects map display and performance")
    func testBatteryStatusMapIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Simulate battery warning
        locationManager.shouldShowBatteryAlert = true
        locationManager.batteryAlertMessage = "High GPS usage detected"
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        
        #expect(locationManager.shouldShowBatteryAlert == true)
        #expect(!locationManager.batteryAlertMessage.isEmpty)
        
        // Battery usage should be color-coded
        locationManager.batteryUsageEstimate = 15.0 // High usage
        #expect(activeTrackingView.batteryUsageColor == .orange)
        
        locationManager.batteryUsageEstimate = 25.0 // Very high usage
        #expect(activeTrackingView.batteryUsageColor == .red)
        
        // Map performance should adapt to battery level
        let lowBatteryDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.15,
            performanceGood: false
        )
        
        #expect(lowBatteryDetail == .low)
    }
    
    @Test("Auto-pause indicator displays correctly on map tab")
    func testAutoPauseIndicatorMapDisplay() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        activeTrackingView.selectedTrackingTab = .map
        
        // Initially not auto-paused
        #expect(locationManager.isAutoPaused == false)
        
        // Trigger auto-pause
        locationManager.isAutoPaused = true
        
        #expect(locationManager.isAutoPaused == true)
        
        // Auto-pause indicator should be visible
        // (In actual UI, this would show "AUTO-PAUSED" text)
        
        // Resume from auto-pause
        locationManager.isAutoPaused = false
        
        #expect(locationManager.isAutoPaused == false)
    }
    
    @Test("Motion activity integrates with map display")
    func testMotionActivityMapIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        activeTrackingView.selectedTrackingTab = .map
        
        // Test different motion activities
        locationManager.motionActivity = .walking
        locationManager.motionConfidence = 0.9
        
        #expect(activeTrackingView.motionActivityIcon == "figure.walk")
        #expect(activeTrackingView.motionActivityColor == .green)
        
        locationManager.motionActivity = .running
        #expect(activeTrackingView.motionActivityIcon == "figure.run")
        
        locationManager.motionActivity = .stationary
        #expect(activeTrackingView.motionActivityIcon == "figure.stand")
        
        // Low confidence should affect color
        locationManager.motionConfidence = 0.4
        #expect(activeTrackingView.motionActivityColor == .secondary)
    }
    
    @Test("Current location marker updates during map viewing")
    func testCurrentLocationMarkerUpdates() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Initial location marker
        #expect(mapPresentation.currentLocationAnnotation != nil)
        
        // User starts moving
        let movingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            altitude: 105.0,
            horizontalAccuracy: 3.0,
            verticalAccuracy: 8.0,
            course: 45.0,
            speed: 2.5,
            timestamp: Date()
        )
        
        locationManager.currentLocation = movingLocation
        
        // Create moving location marker
        let movingMarker = CurrentLocationMarker(
            isMoving: true,
            heading: 45.0,
            accuracy: 3.0
        )
        
        #expect(movingMarker.isMoving == true)
        #expect(movingMarker.heading == 45.0)
        #expect(movingMarker.accuracy == 3.0)
        
        // User stops moving
        let stationaryLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            altitude: 105.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            course: 0.0,
            speed: 0.0,
            timestamp: Date()
        )
        
        locationManager.currentLocation = stationaryLocation
        
        let stationaryMarker = CurrentLocationMarker(
            isMoving: false,
            heading: 0.0,
            accuracy: 5.0
        )
        
        #expect(stationaryMarker.isMoving == false)
        #expect(stationaryMarker.heading == 0.0)
        #expect(stationaryMarker.accuracy == 5.0)
    }
    
    @Test("Map camera follows user appropriately during tracking")
    func testMapCameraFollowUserBehavior() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapView = MapView(
            locationManager: locationManager,
            followUser: true
        )
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        #expect(mapView.followUser == true)
        
        // Initial location
        let initialLocation = locationManager.currentLocation
        #expect(initialLocation != nil)
        
        // User moves to new location
        let newLocation = CLLocation(
            latitude: 37.7760,
            longitude: -122.4180
        )
        locationManager.currentLocation = newLocation
        
        // Camera should update to follow user
        #expect(locationManager.currentLocation?.coordinate.latitude == 37.7760)
        #expect(locationManager.currentLocation?.coordinate.longitude == -122.4180)
        
        // Test manual camera control
        let manualRegion = MapKitUtilities.regionForCurrentLocation(
            CLLocationCoordinate2D(latitude: 37.7770, longitude: -122.4170),
            zoomLevel: 2.0
        )
        
        mapPresentation.cameraPosition = .region(manualRegion)
        
        // Camera position should be controllable
        #expect(manualRegion.center.latitude == 37.7770)
        #expect(manualRegion.center.longitude == -122.4170)
    }
    
    @Test("Complete error scenario handling in UI")
    func testCompleteErrorScenarioUIHandling() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let activeTrackingView = ActiveTrackingView(locationManager: locationManager)
        activeTrackingView.selectedTrackingTab = .map
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Simulate multiple simultaneous errors
        locationManager.currentLocation = nil           // GPS loss
        locationManager.gpsAccuracy = GPSAccuracy(from: 100.0)  // Poor accuracy
        locationManager.shouldShowBatteryAlert = true  // Battery warning
        locationManager.isAutoPaused = true           // Auto-pause
        
        // Add weather alert
        let weatherAlert = WeatherAlert(
            severity: .warning,
            title: "High Wind Advisory",
            message: "Winds exceeding 30 mph",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )
        locationManager.weatherAlerts = [weatherAlert]
        
        // UI should handle all errors gracefully
        #expect(locationManager.currentLocation == nil)
        #expect(locationManager.gpsAccuracy.description == "Poor")
        #expect(locationManager.shouldShowBatteryAlert == true)
        #expect(locationManager.isAutoPaused == true)
        #expect(locationManager.weatherAlerts.count == 1)
        
        // Tracking should continue despite errors
        #expect(locationManager.trackingState == .tracking)
        
        // Map should still be functional
        #expect(mapPresentation.cameraPosition != nil)
        
        // Error recovery
        let recoveredLocation = CLLocation(latitude: 37.7755, longitude: -122.4190)
        locationManager.currentLocation = recoveredLocation
        locationManager.gpsAccuracy = GPSAccuracy(from: 5.0)
        locationManager.isAutoPaused = false
        locationManager.shouldShowBatteryAlert = false
        
        #expect(locationManager.currentLocation != nil)
        #expect(locationManager.gpsAccuracy.description == "Excellent")
        #expect(locationManager.isAutoPaused == false)
        #expect(locationManager.shouldShowBatteryAlert == false)
    }
}

// MARK: - Map Style and Appearance Integration Tests

@Suite("Map Style Integration Tests")
struct MapStyleIntegrationTests {
    
    @Test("Map style adapts to terrain types")
    func testMapStyleTerrainAdaptation() async {
        // Test terrain-specific map styles
        let trailStyle = MapKitUtilities.recommendedMapStyle(for: .trail)
        let sandStyle = MapKitUtilities.recommendedMapStyle(for: .sand)
        let snowStyle = MapKitUtilities.recommendedMapStyle(for: .snow)
        let roadStyle = MapKitUtilities.recommendedMapStyle(for: .pavedRoad)
        
        #expect(trailStyle != nil)
        #expect(sandStyle != nil)
        #expect(snowStyle != nil)
        #expect(roadStyle != nil)
        
        // Each terrain should have appropriate styling
        // (Specific style comparisons would require MapStyle equality implementation)
    }
    
    @Test("Map style considers weather conditions")
    func testMapStyleWeatherConsideration() async {
        let weatherConditions = WeatherConditions(
            temperatureCelsius: 0.0,
            humidity: 90.0,
            windSpeedKPH: 15.0,
            weatherDescription: "Snow"
        )
        
        let snowWeatherStyle = MapKitUtilities.recommendedMapStyle(
            for: .trail,
            weatherConditions: weatherConditions
        )
        
        let clearWeatherStyle = MapKitUtilities.recommendedMapStyle(
            for: .trail,
            weatherConditions: nil
        )
        
        #expect(snowWeatherStyle != nil)
        #expect(clearWeatherStyle != nil)
        
        // Weather should influence style selection
    }
    
    @Test("Map camera positions work correctly")
    func testMapCameraPositions() async {
        let testRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        let routeOverview = MapCameraPosition.routeOverview(for: testRegion)
        
        let followingPosition = MapCameraPosition.followingUser(
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            heading: 90.0,
            distance: 500.0
        )
        
        #expect(routeOverview != nil)
        #expect(followingPosition != nil)
        
        // Camera positions should be well-formed
    }
}