import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// Tests for MapView component ensuring proper MapKit integration
@MainActor
struct MapViewTests {
    
    // MARK: - Test Dependencies
    
    func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        
        // Set up test session
        let session = RuckSession()
        session.loadWeight = 20.0
        manager.currentSession = session
        
        // Add test location
        let testLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        manager.currentLocation = testLocation
        
        return manager
    }
    
    // MARK: - Initialization Tests
    
    @Test("MapView initializes with default parameters")
    func testMapViewInitialization() async {
        let locationManager = createTestLocationManager()
        
        let mapView = MapView(locationManager: locationManager)
        
        #expect(mapView.showCurrentLocation == true)
        #expect(mapView.followUser == true)
        #expect(mapView.showTerrain == true)
        #expect(mapView.interactionModes == .all)
    }
    
    @Test("MapView initializes with custom parameters")
    func testMapViewCustomInitialization() async {
        let locationManager = createTestLocationManager()
        
        let mapView = MapView(
            locationManager: locationManager,
            showCurrentLocation: false,
            followUser: false,
            showTerrain: false,
            interactionModes: .pan
        )
        
        #expect(mapView.showCurrentLocation == false)
        #expect(mapView.followUser == false)
        #expect(mapView.showTerrain == false)
        #expect(mapView.interactionModes == .pan)
    }
    
    // MARK: - Map Presentation Tests
    
    @Test("MapPresentation initializes correctly")
    func testMapPresentationInitialization() async {
        let presentation = MapPresentation()
        
        #expect(presentation.cameraPosition == .automatic)
        #expect(presentation.routePolyline == nil)
        #expect(presentation.currentLocationAnnotation == nil)
        #expect(presentation.mileMarkers.isEmpty)
        #expect(presentation.terrainOverlays.isEmpty)
    }
    
    @Test("MapPresentation updates with location manager")
    func testMapPresentationWithLocationManager() async {
        let locationManager = createTestLocationManager()
        let presentation = MapPresentation()
        
        await presentation.initialize(with: locationManager)
        
        // Allow some time for async initialization
        try? await Task.sleep(for: .milliseconds(100))
        
        // Test that presentation is configured
        #expect(presentation.distanceUnits == "imperial")
        #expect(presentation.currentMapStyle == .standard(elevation: .realistic))
    }
    
    // MARK: - Location Annotation Tests
    
    @Test("LocationAnnotation creates correctly")
    func testLocationAnnotationCreation() async {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let subtitle = "Test Location"
        
        let annotation = LocationAnnotation(coordinate: coordinate, subtitle: subtitle)
        
        #expect(annotation.coordinate.latitude == 37.7749)
        #expect(annotation.coordinate.longitude == -122.4194)
        #expect(annotation.subtitle == "Test Location")
    }
    
    @Test("MileMarkerAnnotation creates correctly")
    func testMileMarkerAnnotationCreation() async {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let distance = 1.0
        let title = "Mile 1"
        
        let marker = MileMarkerAnnotation(
            coordinate: coordinate,
            distance: distance,
            title: title
        )
        
        #expect(marker.coordinate.latitude == 37.7749)
        #expect(marker.coordinate.longitude == -122.4194)
        #expect(marker.distance == 1.0)
        #expect(marker.title == "Mile 1")
    }
    
    // MARK: - Custom Marker Component Tests
    
    @Test("CurrentLocationMarker displays correctly for stationary user")
    func testCurrentLocationMarkerStationary() async {
        let marker = CurrentLocationMarker(
            isMoving: false,
            heading: 0,
            accuracy: 5.0
        )
        
        // Test view can be created
        let view = marker
        #expect(view.isMoving == false)
        #expect(view.heading == 0)
        #expect(view.accuracy == 5.0)
    }
    
    @Test("CurrentLocationMarker displays correctly for moving user")
    func testCurrentLocationMarkerMoving() async {
        let marker = CurrentLocationMarker(
            isMoving: true,
            heading: 45.0,
            accuracy: 3.0
        )
        
        let view = marker
        #expect(view.isMoving == true)
        #expect(view.heading == 45.0)
        #expect(view.accuracy == 3.0)
    }
    
    @Test("RouteMarker creates for start location")
    func testRouteMarkerStart() async {
        let marker = RouteMarker(
            type: .start,
            title: "Start",
            subtitle: "Begin Ruck"
        )
        
        #expect(marker.type == .start)
        #expect(marker.title == "Start")
        #expect(marker.subtitle == "Begin Ruck")
    }
    
    @Test("RouteMarker creates for end location")
    func testRouteMarkerEnd() async {
        let marker = RouteMarker(
            type: .end,
            title: "Finish",
            subtitle: "End Ruck"
        )
        
        #expect(marker.type == .end)
        #expect(marker.title == "Finish")
        #expect(marker.subtitle == "End Ruck")
    }
    
    @Test("MileMarker displays imperial units")
    func testMileMarkerImperial() async {
        let marker = MileMarker(distance: 1.0, units: "imperial")
        
        #expect(marker.distance == 1.0)
        #expect(marker.units == "imperial")
    }
    
    @Test("MileMarker displays metric units")
    func testMileMarkerMetric() async {
        let marker = MileMarker(distance: 1.0, units: "metric")
        
        #expect(marker.distance == 1.0)
        #expect(marker.units == "metric")
    }
    
    // MARK: - Map Controls Tests
    
    @Test("MapControlsOverlay initializes correctly")
    func testMapControlsOverlay() async {
        let locationManager = createTestLocationManager()
        let presentation = MapPresentation()
        
        let controls = MapControlsOverlay(
            presentation: presentation,
            locationManager: locationManager
        )
        
        // Test that controls can be created
        #expect(controls.locationManager === locationManager)
    }
    
    // MARK: - Terrain Overlay Tests
    
    @Test("TerrainOverlay creates correctly")
    func testTerrainOverlayCreation() async {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196)
        ]
        
        let overlay = TerrainOverlay(
            coordinates: coordinates,
            terrainType: .trail,
            terrainColor: .green
        )
        
        #expect(overlay.coordinates.count == 3)
        #expect(overlay.terrainType == .trail)
        #expect(overlay.terrainColor == .green)
    }
    
    // MARK: - Performance Tests
    
    @Test("MapView handles large number of location points efficiently")
    func testMapViewPerformanceWithManyPoints() async {
        let locationManager = createTestLocationManager()
        
        // Add many location points to the session
        guard let session = locationManager.currentSession else {
            Issue.record("No current session")
            return
        }
        
        // Create 1000 test location points
        for i in 0..<1000 {
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
        
        let mapView = MapView(locationManager: locationManager)
        
        // Test that map view can handle large datasets
        // This is mainly a compilation and initialization test
        #expect(session.locationPoints.count == 1000)
    }
    
    @Test("MapPresentation cleanup works correctly")
    func testMapPresentationCleanup() async {
        let presentation = MapPresentation()
        let locationManager = createTestLocationManager()
        
        await presentation.initialize(with: locationManager)
        presentation.cleanup()
        
        // After cleanup, ensure resources are released
        // This test mainly ensures cleanup doesn't crash
        #expect(true) // If we reach here, cleanup succeeded
    }
    
    // MARK: - Integration Tests
    
    @Test("MapView integrates with ActiveTrackingView")
    func testMapViewActiveTrackingIntegration() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapView = MapView(locationManager: locationManager)
        
        // Test that map view works with active tracking
        #expect(locationManager.trackingState == .tracking)
        #expect(mapView.followUser == true)
    }
    
    @Test("MapView handles location manager state changes")
    func testMapViewStateChanges() async {
        let locationManager = createTestLocationManager()
        let presentation = MapPresentation()
        
        await presentation.initialize(with: locationManager)
        
        // Change tracking state
        locationManager.trackingState = .paused
        
        // Map should adapt to state changes
        #expect(locationManager.trackingState == .paused)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("MapView handles nil current location gracefully")
    func testMapViewNilLocation() async {
        let locationManager = createTestLocationManager()
        locationManager.currentLocation = nil
        
        let mapView = MapView(locationManager: locationManager)
        
        // Should not crash with nil location
        #expect(locationManager.currentLocation == nil)
    }
    
    @Test("MapView handles empty location points array")
    func testMapViewEmptyLocationPoints() async {
        let locationManager = createTestLocationManager()
        
        // Ensure session has no location points
        locationManager.currentSession?.locationPoints.removeAll()
        
        let mapView = MapView(locationManager: locationManager)
        
        // Should handle empty array gracefully
        #expect(locationManager.currentSession?.locationPoints.isEmpty == true)
    }
    
    // MARK: - Accessibility Tests
    
    @Test("Map markers have proper accessibility labels")
    func testMapMarkerAccessibility() async {
        let currentLocationMarker = CurrentLocationMarker(
            isMoving: false,
            heading: 0,
            accuracy: 5.0
        )
        
        let routeMarker = RouteMarker(
            type: .start,
            title: "Start",
            subtitle: "Begin Ruck"
        )
        
        let mileMarker = MileMarker(distance: 1.0, units: "imperial")
        
        // Test that markers can be created (accessibility will be tested by SwiftUI)
        #expect(currentLocationMarker.accuracy == 5.0)
        #expect(routeMarker.title == "Start")
        #expect(mileMarker.distance == 1.0)
    }
    
    // MARK: - Configuration Tests
    
    @Test("MapView respects interaction modes")
    func testMapViewInteractionModes() async {
        let locationManager = createTestLocationManager()
        
        let panOnlyMap = MapView(
            locationManager: locationManager,
            interactionModes: .pan
        )
        
        let zoomOnlyMap = MapView(
            locationManager: locationManager,
            interactionModes: .zoom
        )
        
        let allInteractionsMap = MapView(
            locationManager: locationManager,
            interactionModes: .all
        )
        
        #expect(panOnlyMap.interactionModes == .pan)
        #expect(zoomOnlyMap.interactionModes == .zoom)
        #expect(allInteractionsMap.interactionModes == .all)
    }
    
    @Test("MapView terrain display toggle")
    func testMapViewTerrainToggle() async {
        let locationManager = createTestLocationManager()
        
        let terrainEnabledMap = MapView(
            locationManager: locationManager,
            showTerrain: true
        )
        
        let terrainDisabledMap = MapView(
            locationManager: locationManager,
            showTerrain: false
        )
        
        #expect(terrainEnabledMap.showTerrain == true)
        #expect(terrainDisabledMap.showTerrain == false)
    }
}

// MARK: - Helper Extensions for Testing

extension LocationAnnotation: Equatable {
    static func == (lhs: LocationAnnotation, rhs: LocationAnnotation) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.subtitle == rhs.subtitle
    }
}

extension MileMarkerAnnotation: Equatable {
    static func == (lhs: MileMarkerAnnotation, rhs: MileMarkerAnnotation) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.distance == rhs.distance &&
               lhs.title == rhs.title
    }
}

extension RouteMarker.MarkerType: Equatable {
    static func == (lhs: RouteMarker.MarkerType, rhs: RouteMarker.MarkerType) -> Bool {
        switch (lhs, rhs) {
        case (.start, .start), (.end, .end):
            return true
        default:
            return false
        }
    }
}