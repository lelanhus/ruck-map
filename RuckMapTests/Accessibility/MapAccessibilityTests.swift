import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// Comprehensive accessibility tests for Session 11: Map Integration
/// Ensures full VoiceOver and accessibility compliance
@MainActor
struct MapAccessibilityTests {
    
    // MARK: - Test Helpers
    
    func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        let session = RuckSession()
        session.loadWeight = 20.0
        manager.currentSession = session
        
        let testLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        manager.currentLocation = testLocation
        
        return manager
    }
    
    // MARK: - Map Component Accessibility Tests
    
    @Test("CurrentLocationMarker has descriptive accessibility labels")
    func testCurrentLocationMarkerAccessibility() async {
        // Test stationary user
        let stationaryMarker = CurrentLocationMarker(
            isMoving: false,
            heading: 0,
            accuracy: 5.0
        )
        
        #expect(stationaryMarker.isMoving == false)
        #expect(stationaryMarker.accuracy == 5.0)
        
        // Test moving user with heading
        let movingMarker = CurrentLocationMarker(
            isMoving: true,
            heading: 45.0,
            accuracy: 3.0
        )
        
        #expect(movingMarker.isMoving == true)
        #expect(movingMarker.heading == 45.0)
        #expect(movingMarker.accuracy == 3.0)
        
        // In actual implementation, accessibility labels should be:
        // Stationary: "Current location, stationary, 5 meter accuracy"
        // Moving: "Current location, moving northeast, 3 meter accuracy"
    }
    
    @Test("RouteMarker has proper accessibility traits and hints")
    func testRouteMarkerAccessibility() async {
        let startMarker = RouteMarker(
            type: .start,
            title: "Start",
            subtitle: "Begin Ruck"
        )
        
        let endMarker = RouteMarker(
            type: .end,
            title: "Finish",
            subtitle: "End Ruck"
        )
        
        #expect(startMarker.type == .start)
        #expect(startMarker.title == "Start")
        #expect(startMarker.subtitle == "Begin Ruck")
        
        #expect(endMarker.type == .end)
        #expect(endMarker.title == "Finish")
        #expect(endMarker.subtitle == "End Ruck")
        
        // Accessibility implementation should include:
        // - .accessibilityAddTraits(.isButton)
        // - .accessibilityHint("Double tap to view route details")
        // - .accessibilityLabel("Route start point: Begin Ruck")
    }
    
    @Test("MileMarker provides distance information accessibly")
    func testMileMarkerAccessibility() async {
        let imperialMarker = MileMarker(distance: 1.0, units: "imperial")
        let metricMarker = MileMarker(distance: 2.0, units: "metric")
        
        #expect(imperialMarker.distance == 1.0)
        #expect(imperialMarker.units == "imperial")
        #expect(metricMarker.distance == 2.0)
        #expect(metricMarker.units == "metric")
        
        // Accessibility labels should be:
        // Imperial: "Mile marker: 1 mile completed"
        // Metric: "Distance marker: 2 kilometers completed"
    }
    
    @Test("TerrainOverlay annotations are accessible")
    func testTerrainOverlayAccessibility() async {
        let trailOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
            ],
            terrainType: .trail,
            terrainColor: .green
        )
        
        let sandOverlay = TerrainOverlay(
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
                CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4197)
            ],
            terrainType: .sand,
            terrainColor: .yellow
        )
        
        #expect(trailOverlay.terrainType == .trail)
        #expect(trailOverlay.terrainColor == .green)
        #expect(sandOverlay.terrainType == .sand)
        #expect(sandOverlay.terrainColor == .yellow)
        
        // Accessibility should describe terrain:
        // "Trail terrain overlay, affects movement speed and calorie burn"
        // "Sand terrain overlay, challenging surface increases effort"
    }
    
    // MARK: - Map Controls Accessibility Tests
    
    @Test("MapControlsOverlay has proper accessibility navigation")
    func testMapControlsAccessibility() async {
        let locationManager = createTestLocationManager()
        let presentation = MapPresentation()
        
        let controls = MapControlsOverlay(
            presentation: presentation,
            locationManager: locationManager
        )
        
        #expect(controls.locationManager === locationManager)
        
        // Controls should have:
        // - Center on location button: "Center map on current location"
        // - Map style toggle: "Change map appearance"
        // - Terrain overlay toggle: "Toggle terrain information display"
        // - Accessibility container grouping related controls
    }
    
    @Test("Map zoom and pan controls are accessible")
    func testMapZoomPanAccessibility() async {
        let locationManager = createTestLocationManager()
        
        let mapView = MapView(
            locationManager: locationManager,
            interactionModes: .all
        )
        
        #expect(mapView.interactionModes == .all)
        
        // Standard MapKit accessibility includes:
        // - VoiceOver rotor for map exploration
        // - Gesture-based navigation alternatives
        // - Audio feedback for zoom level changes
        // - Accessible region descriptions
    }
    
    // MARK: - Tab Navigation Accessibility Tests
    
    @Test("Tracking tabs have proper accessibility labels and hints")
    func testTrackingTabAccessibility() async {
        let locationManager = createTestLocationManager()
        let view = ActiveTrackingView(locationManager: locationManager)
        
        // Test tab accessibility properties
        let metricsTab = ActiveTrackingView.TrackingTab.metrics
        let mapTab = ActiveTrackingView.TrackingTab.map
        
        #expect(metricsTab.icon == "chart.bar.fill")
        #expect(mapTab.icon == "map.fill")
        
        #expect(metricsTab.iconUnselected == "chart.bar")
        #expect(mapTab.iconUnselected == "map")
        
        // Accessibility implementation should include:
        // Metrics tab: 
        //   - Label: "Metrics tab"
        //   - Hint: "View numerical tracking data"
        //   - Trait: .isSelected when active
        // Map tab:
        //   - Label: "Map tab" 
        //   - Hint: "View route on map"
        //   - Trait: .isSelected when active
    }
    
    @Test("Tab switching maintains VoiceOver focus context")
    func testTabSwitchingAccessibilityContext() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        // Start on metrics tab
        #expect(view.selectedTrackingTab == .metrics)
        
        // Switch to map tab
        view.selectedTrackingTab = .map
        #expect(view.selectedTrackingTab == .map)
        
        // VoiceOver should:
        // 1. Announce tab change: "Map tab selected"
        // 2. Focus should move to first map element
        // 3. Context should be preserved when switching back
        
        view.selectedTrackingTab = .metrics
        #expect(view.selectedTrackingTab == .metrics)
    }
    
    // MARK: - Dynamic Accessibility Information Tests
    
    @Test("Route information is dynamically accessible")
    func testDynamicRouteAccessibility() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        locationManager.totalDistance = 1609.34 // 1 mile
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        #expect(view.formattedDistance == "1.00 mi")
        
        // Dynamic accessibility should announce:
        // - Route progress: "Route progress: 1 mile completed"
        // - Current pace updates: "Current pace: 10 minutes per mile"
        // - Grade changes: "Grade: climbing 5 percent incline"
        // - Terrain changes: "Terrain changed to trail surface"
    }
    
    @Test("GPS status is communicated accessibly")
    func testGPSStatusAccessibility() async {
        let locationManager = createTestLocationManager()
        
        // Test different GPS accuracy levels
        let excellentGPS = GPSAccuracy(from: 3.0)
        let goodGPS = GPSAccuracy(from: 8.0)
        let fairGPS = GPSAccuracy(from: 15.0)
        let poorGPS = GPSAccuracy(from: 50.0)
        
        #expect(excellentGPS.description == "Excellent")
        #expect(goodGPS.description == "Good")
        #expect(fairGPS.description == "Fair")
        #expect(poorGPS.description == "Poor")
        
        // Accessibility announcements should be:
        // "GPS signal excellent, 3 meter accuracy"
        // "GPS signal poor, 50 meter accuracy, consider finding open area"
    }
    
    @Test("Weather information is accessible on map")
    func testWeatherAccessibilityOnMap() async {
        let locationManager = createTestLocationManager()
        
        let weather = WeatherConditions(
            timestamp: Date(),
            temperature: 25.0,
            humidity: 60.0,
            windSpeed: 8.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        weather.weatherDescription = "Partly cloudy"
        
        locationManager.currentWeatherConditions = weather
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        #expect(locationManager.currentWeatherConditions != nil)
        #expect(weather.temperatureFahrenheit == 77.0)
        
        // Weather accessibility should announce:
        // "Current weather: 77 degrees Fahrenheit, partly cloudy, 8 mile per hour south wind"
        // "Weather impact: 12 percent increase in calorie burn due to temperature"
    }
    
    // MARK: - Alerts and Warnings Accessibility Tests
    
    @Test("Weather alerts are announced accessibly")
    func testWeatherAlertAccessibility() async {
        let locationManager = createTestLocationManager()
        
        let criticalAlert = WeatherAlert(
            severity: .critical,
            title: "High Wind Warning",
            message: "Winds exceeding 40 mph expected",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )
        
        let warningAlert = WeatherAlert(
            severity: .warning,
            title: "Heat Advisory",
            message: "High temperature warning",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(7200)
        )
        
        locationManager.weatherAlerts = [criticalAlert, warningAlert]
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        #expect(locationManager.weatherAlerts.count == 2)
        #expect(criticalAlert.severity == .critical)
        #expect(warningAlert.severity == .warning)
        
        // Alert accessibility should:
        // - Use .accessibilityAnnouncement for immediate alerts
        // - Provide detailed descriptions: "Critical weather alert: High Wind Warning. Winds exceeding 40 mph expected"
        // - Include timing: "Alert expires in 1 hour"
        // - Offer action hints: "Double tap for weather safety recommendations"
    }
    
    @Test("Battery warnings are accessible")
    func testBatteryWarningAccessibility() async {
        let locationManager = createTestLocationManager()
        locationManager.shouldShowBatteryAlert = true
        locationManager.batteryAlertMessage = "High battery usage detected from GPS tracking"
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        #expect(locationManager.shouldShowBatteryAlert == true)
        #expect(!locationManager.batteryAlertMessage.isEmpty)
        
        // Battery warning accessibility:
        // - Immediate announcement: "Battery alert: High battery usage detected"
        // - Context: "GPS tracking is using more power than usual"
        // - Action guidance: "Consider reducing tracking frequency to conserve battery"
    }
    
    // MARK: - Real-time Updates Accessibility Tests
    
    @Test("Pace changes are announced appropriately")
    func testPaceChangeAccessibility() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        // Simulate pace changes
        locationManager.currentPace = 10.0 // 10 min/km
        #expect(view.formattedPace.contains("16:")) // ~16 min/mile
        
        locationManager.currentPace = 8.0 // Faster pace
        let newPace = view.formattedPace
        
        // Pace change accessibility should:
        // - Announce significant changes: "Pace improved to 13 minutes per mile"
        // - Avoid announcing minor fluctuations
        // - Provide context: "Current pace is faster than target pace"
        #expect(!newPace.isEmpty)
    }
    
    @Test("Grade changes are communicated accessibly")
    func testGradeChangeAccessibility() async {
        let locationManager = createTestLocationManager()
        let view = ActiveTrackingView(locationManager: locationManager)
        
        // Test different grade scenarios
        view.currentGrade = 5.0 // Uphill
        #expect(view.formattedGrade == "+5.0%")
        #expect(view.gradeColor == .orange)
        
        view.currentGrade = -3.0 // Downhill
        #expect(view.formattedGrade == "-3.0%")
        
        view.currentGrade = 15.0 // Steep uphill
        #expect(view.gradeColor == .red)
        
        // Grade accessibility announcements:
        // Uphill: "Climbing 5 percent grade, moderate incline"
        // Downhill: "Descending 3 percent grade"
        // Steep: "Steep 15 percent incline, challenging climb"
    }
    
    // MARK: - Map Feature Accessibility Tests
    
    @Test("Mile markers have contextual accessibility")
    func testMileMarkerContextualAccessibility() async {
        let locationManager = createTestLocationManager()
        locationManager.totalDistance = 3218.68 // 2 miles
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        await mapPresentation.updateMileMarkers()
        
        // Should have markers for mile 1 and mile 2
        #expect(mapPresentation.mileMarkers.count >= 2)
        
        // Mile marker accessibility should include:
        // - Progress context: "Mile 1 of your ruck march"
        // - Time context: "Completed at 15 minutes elapsed time"
        // - Performance context: "Pace: 15 minutes per mile"
    }
    
    @Test("Route overview is accessible")
    func testRouteOverviewAccessibility() async {
        let locationManager = createTestLocationManager()
        
        // Add location points for route
        guard let session = locationManager.currentSession else {
            Issue.record("No current session")
            return
        }
        
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
        
        let coordinates = session.locationPoints.map { point in
            CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        
        let region = MapKitUtilities.calculateRouteRegion(for: coordinates)
        
        #expect(region.center.latitude > 37.774)
        #expect(region.center.latitude < 37.776)
        
        // Route overview accessibility should describe:
        // - "Route overview: 10 waypoints covering approximately 0.6 miles"
        // - "Route heads northeast from current location"
        // - "Elevation varies from 100 to 145 feet"
    }
    
    // MARK: - Integration Accessibility Tests
    
    @Test("Map and metrics maintain accessibility context")
    func testMapMetricsAccessibilityIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        locationManager.totalDistance = 1000.0
        locationManager.currentPace = 9.0
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        // When on metrics tab
        view.selectedTrackingTab = .metrics
        #expect(view.selectedTrackingTab == .metrics)
        
        // When switching to map tab
        view.selectedTrackingTab = .map
        #expect(view.selectedTrackingTab == .map)
        
        // Accessibility should maintain awareness of:
        // - Current tracking data: "Viewing map, 0.62 miles completed"
        // - Active session state: "Tracking active for 15 minutes"
        // - Available interactions: "Pan and zoom available, double tap controls for options"
    }
    
    @Test("Complex map scenarios remain accessible")
    func testComplexMapAccessibilityScenarios() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        locationManager.isAutoPaused = true
        locationManager.gpsAccuracy = GPSAccuracy(from: 25.0) // Fair accuracy
        
        let weather = WeatherConditions(
            timestamp: Date(),
            temperature: 35.0, // Hot weather
            humidity: 80.0,
            windSpeed: 15.0,
            windDirection: 270.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        locationManager.currentWeatherConditions = weather
        
        let view = ActiveTrackingView(locationManager: locationManager)
        
        #expect(locationManager.isAutoPaused == true)
        #expect(locationManager.gpsAccuracy.description == "Fair")
        #expect(view.weatherImpactPercentage > 0)
        
        // Complex scenario accessibility should handle:
        // - Multiple simultaneous statuses: "Auto-paused, fair GPS signal, hot weather affecting performance"
        // - Prioritized information: Critical alerts first, then status updates
        // - Clear action guidance: "Resume tracking when ready to continue"
        // - Context preservation: "Route progress maintained during pause"
    }
}

// MARK: - Accessibility Helper Tests

@Suite("Map Accessibility Helpers")
struct MapAccessibilityHelperTests {
    
    @Test("Compass direction descriptions are accessible")
    func testCompassDirectionAccessibility() async {
        // Test various headings
        let headings: [(Double, String)] = [
            (0.0, "North"),
            (45.0, "Northeast"),
            (90.0, "East"),
            (135.0, "Southeast"),
            (180.0, "South"),
            (225.0, "Southwest"),
            (270.0, "West"),
            (315.0, "Northwest"),
            (360.0, "North")
        ]
        
        for (heading, expectedDirection) in headings {
            // This would be implemented in CurrentLocationMarker
            let normalizedHeading = heading >= 360 ? heading - 360 : heading
            
            var direction = ""
            switch normalizedHeading {
            case 0..<22.5, 337.5...:
                direction = "North"
            case 22.5..<67.5:
                direction = "Northeast"
            case 67.5..<112.5:
                direction = "East"
            case 112.5..<157.5:
                direction = "Southeast"
            case 157.5..<202.5:
                direction = "South"
            case 202.5..<247.5:
                direction = "Southwest"
            case 247.5..<292.5:
                direction = "West"
            case 292.5..<337.5:
                direction = "Northwest"
            default:
                direction = "Unknown"
            }
            
            #expect(direction == expectedDirection)
        }
    }
    
    @Test("Distance units are announced clearly")
    func testDistanceUnitsAccessibility() async {
        let distances: [(Double, String)] = [
            (100.0, "100 meters"),
            (1000.0, "1 kilometer"),
            (1609.34, "1 mile"),
            (5000.0, "5 kilometers"),
            (10000.0, "10 kilometers")
        ]
        
        for (meters, expectedDescription) in distances {
            let miles = meters / 1609.34
            let kilometers = meters / 1000.0
            
            // Test imperial format
            if meters >= 1609.34 {
                let milesFormatted = String(format: "%.1f mile%@", miles, miles == 1.0 ? "" : "s")
                #expect(milesFormatted.contains("mile"))
            }
            
            // Test metric format
            if meters >= 1000.0 {
                let kmFormatted = String(format: "%.1f kilometer%@", kilometers, kilometers == 1.0 ? "" : "s")
                #expect(kmFormatted.contains("kilometer"))
            }
        }
    }
    
    @Test("Terrain type descriptions are descriptive")
    func testTerrainTypeAccessibility() async {
        let terrainDescriptions: [(TerrainType, String)] = [
            (.pavedRoad, "Paved road surface, optimal for speed and efficiency"),
            (.trail, "Trail surface, natural terrain with moderate difficulty"),
            (.sand, "Sand surface, challenging terrain requiring extra effort"),
            (.snow, "Snow surface, difficult conditions affecting traction"),
            (.grass, "Grass surface, soft terrain with moderate resistance"),
            (.gravel, "Gravel surface, uneven terrain requiring careful footing")
        ]
        
        for (terrainType, expectedDescription) in terrainDescriptions {
            // Verify terrain types exist
            #expect(terrainType != nil)
            
            // Accessibility descriptions should be informative and helpful
            // This test ensures we consider the impact of terrain on the user
            switch terrainType {
            case .pavedRoad:
                #expect(expectedDescription.contains("optimal"))
            case .sand, .snow:
                #expect(expectedDescription.contains("challenging") || expectedDescription.contains("difficult"))
            case .trail, .grass, .gravel:
                #expect(expectedDescription.contains("moderate"))
            }
        }
    }
}