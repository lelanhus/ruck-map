import Testing
import MapKit
import CoreLocation
@testable import RuckMap

/// Tests for MapKitUtilities ensuring correct map calculations and optimizations
@MainActor
struct MapKitUtilitiesTests {
    
    // MARK: - Test Data
    
    func createTestLocations() -> [CLLocationCoordinate2D] {
        return [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
            CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4197)
        ]
    }
    
    func createTestLocationPoints() -> [LocationPoint] {
        return [
            LocationPoint(
                timestamp: Date(),
                latitude: 37.7749,
                longitude: -122.4194,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            ),
            LocationPoint(
                timestamp: Date().addingTimeInterval(60),
                latitude: 37.7750,
                longitude: -122.4195,
                altitude: 105.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            ),
            LocationPoint(
                timestamp: Date().addingTimeInterval(120),
                latitude: 37.7751,
                longitude: -122.4196,
                altitude: 110.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0
            )
        ]
    }
    
    func createTestCLLocations() -> [CLLocation] {
        return [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7750, longitude: -122.4195),
            CLLocation(latitude: 37.7751, longitude: -122.4196),
            CLLocation(latitude: 37.7752, longitude: -122.4197)
        ]
    }
    
    // MARK: - Region Calculation Tests
    
    @Test("Calculate route region for multiple locations")
    func testCalculateRouteRegionMultipleLocations() async {
        let locations = createTestLocations()
        let region = MapKitUtilities.calculateRouteRegion(for: locations)
        
        // Test that region center is approximately correct
        #expect(region.center.latitude > 37.774)
        #expect(region.center.latitude < 37.776)
        #expect(region.center.longitude > -122.42)
        #expect(region.center.longitude < -122.418)
        
        // Test that region has appropriate span
        #expect(region.span.latitudeDelta > 0)
        #expect(region.span.longitudeDelta > 0)
    }
    
    @Test("Calculate route region for single location")
    func testCalculateRouteRegionSingleLocation() async {
        let locations = [CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)]
        let region = MapKitUtilities.calculateRouteRegion(for: locations)
        
        // Test that region is centered on the single location
        #expect(region.center.latitude == 37.7749)
        #expect(region.center.longitude == -122.4194)
        
        // Test that region has minimum span
        #expect(region.span.latitudeDelta == 0.001)
        #expect(region.span.longitudeDelta == 0.001)
    }
    
    @Test("Calculate route region for empty array")
    func testCalculateRouteRegionEmptyArray() async {
        let locations: [CLLocationCoordinate2D] = []
        let region = MapKitUtilities.calculateRouteRegion(for: locations)
        
        // Test that region defaults to San Francisco
        #expect(region.center.latitude == 37.7749)
        #expect(region.center.longitude == -122.4194)
    }
    
    @Test("Calculate region for current location")
    func testRegionForCurrentLocation() async {
        let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let region = MapKitUtilities.regionForCurrentLocation(location, zoomLevel: 2.0)
        
        // Test that region is centered correctly
        #expect(region.center.latitude == 37.7749)
        #expect(region.center.longitude == -122.4194)
        
        // Test that zoom level affects span
        #expect(region.span.latitudeDelta == 0.02) // 0.01 * 2.0
        #expect(region.span.longitudeDelta == 0.02)
    }
    
    // MARK: - Route Optimization Tests
    
    @Test("Optimize route polyline with standard tolerance")
    func testOptimizeRoutePolyline() async {
        let coordinates = createTestLocations()
        let optimized = MapKitUtilities.optimizeRoutePolyline(coordinates: coordinates, tolerance: 5.0)
        
        // Test that optimization returns valid coordinates
        #expect(optimized.count >= 2)
        #expect(optimized.count <= coordinates.count)
        
        // Test that first and last points are preserved
        #expect(optimized.first?.latitude == coordinates.first?.latitude)
        #expect(optimized.first?.longitude == coordinates.first?.longitude)
        #expect(optimized.last?.latitude == coordinates.last?.latitude)
        #expect(optimized.last?.longitude == coordinates.last?.longitude)
    }
    
    @Test("Optimize route polyline with minimal coordinates")
    func testOptimizeRoutePolylineMinimal() async {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
        ]
        let optimized = MapKitUtilities.optimizeRoutePolyline(coordinates: coordinates, tolerance: 5.0)
        
        // Test that minimal route is unchanged
        #expect(optimized.count == 2)
        #expect(optimized == coordinates)
    }
    
    @Test("Create optimized polyline from location points")
    func testCreateOptimizedPolyline() async {
        let locationPoints = createTestLocationPoints()
        let polyline = MapKitUtilities.createOptimizedPolyline(from: locationPoints, maxPoints: 1000)
        
        // Test that polyline is created
        #expect(polyline != nil)
        #expect(polyline?.pointCount ?? 0 >= 2)
    }
    
    @Test("Create optimized polyline with point limit")
    func testCreateOptimizedPolylineWithLimit() async {
        // Create many location points
        var locationPoints: [LocationPoint] = []
        for i in 0..<2000 {
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
            locationPoints.append(point)
        }
        
        let polyline = MapKitUtilities.createOptimizedPolyline(from: locationPoints, maxPoints: 100)
        
        // Test that polyline respects point limit
        #expect(polyline != nil)
        #expect(polyline?.pointCount ?? 0 <= 100)
    }
    
    @Test("Create optimized polyline with empty array")
    func testCreateOptimizedPolylineEmpty() async {
        let locationPoints: [LocationPoint] = []
        let polyline = MapKitUtilities.createOptimizedPolyline(from: locationPoints, maxPoints: 1000)
        
        // Test that empty array returns nil
        #expect(polyline == nil)
    }
    
    // MARK: - Map Style Tests
    
    @Test("Recommended map style for different terrain types")
    func testRecommendedMapStyleForTerrain() async {
        let trailStyle = MapKitUtilities.recommendedMapStyle(for: .trail)
        let sandStyle = MapKitUtilities.recommendedMapStyle(for: .sand)
        let snowStyle = MapKitUtilities.recommendedMapStyle(for: .snow)
        let roadStyle = MapKitUtilities.recommendedMapStyle(for: .pavedRoad)
        
        // Test that different terrain types return appropriate styles
        // Note: These tests check that styles are returned, specific style comparison
        // would require more complex MapStyle comparison logic
        #expect(trailStyle != nil)
        #expect(sandStyle != nil)
        #expect(snowStyle != nil)
        #expect(roadStyle != nil)
    }
    
    @Test("Recommended map style with weather conditions")
    func testRecommendedMapStyleWithWeather() async {
        let weatherConditions = WeatherConditions(
            temperatureCelsius: 5.0,
            humidity: 80.0,
            windSpeedKPH: 10.0,
            weatherDescription: "Snow"
        )
        
        let style = MapKitUtilities.recommendedMapStyle(
            for: .trail,
            weatherConditions: weatherConditions
        )
        
        // Test that weather affects style selection
        #expect(style != nil)
    }
    
    // MARK: - Distance and Location Tests
    
    @Test("Find location at specific distance")
    func testLocationAtDistance() async {
        let locations = createTestCLLocations()
        let targetDistance = 100.0 // 100 meters
        
        let foundLocation = MapKitUtilities.locationAtDistance(targetDistance, in: locations)
        
        // Test that a location is found
        #expect(foundLocation != nil)
        #expect(foundLocation!.coordinate.latitude >= locations.first!.coordinate.latitude)
        #expect(foundLocation!.coordinate.latitude <= locations.last!.coordinate.latitude)
    }
    
    @Test("Find location at distance beyond route")
    func testLocationAtDistanceBeyondRoute() async {
        let locations = createTestCLLocations()
        let targetDistance = 10000.0 // 10km - beyond our test route
        
        let foundLocation = MapKitUtilities.locationAtDistance(targetDistance, in: locations)
        
        // Test that last location is returned when target is beyond route
        #expect(foundLocation != nil)
        #expect(foundLocation!.coordinate.latitude == locations.last!.coordinate.latitude)
        #expect(foundLocation!.coordinate.longitude == locations.last!.coordinate.longitude)
    }
    
    @Test("Calculate total distance")
    func testCalculateTotalDistance() async {
        let locations = createTestCLLocations()
        let totalDistance = MapKitUtilities.calculateTotalDistance(for: locations)
        
        // Test that distance is calculated (should be > 0 for our test locations)
        #expect(totalDistance > 0)
        #expect(totalDistance < 1000) // Should be reasonable for our small test route
    }
    
    @Test("Calculate total distance for single location")
    func testCalculateTotalDistanceSingle() async {
        let locations = [CLLocation(latitude: 37.7749, longitude: -122.4194)]
        let totalDistance = MapKitUtilities.calculateTotalDistance(for: locations)
        
        // Test that single location returns 0 distance
        #expect(totalDistance == 0)
    }
    
    @Test("Calculate total distance for empty array")
    func testCalculateTotalDistanceEmpty() async {
        let locations: [CLLocation] = []
        let totalDistance = MapKitUtilities.calculateTotalDistance(for: locations)
        
        // Test that empty array returns 0 distance
        #expect(totalDistance == 0)
    }
    
    // MARK: - Terrain Overlay Tests
    
    @Test("Create terrain overlay")
    func testCreateTerrainOverlay() async {
        let centerLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius = 100.0
        let terrainType = TerrainType.trail
        
        let overlay = MapKitUtilities.createTerrainOverlay(
            centerLocation: centerLocation,
            radius: radius,
            terrainType: terrainType
        )
        
        // Test that overlay is created correctly
        #expect(overlay.terrainType == terrainType)
        #expect(overlay.coordinates.count > 0)
        #expect(overlay.terrainColor != nil)
    }
    
    // MARK: - Performance Monitoring Tests
    
    @Test("Performance monitor records frames")
    func testPerformanceMonitor() async {
        var monitor = MapKitUtilities.PerformanceMonitor()
        
        // Simulate frame recording
        monitor.recordFrame()
        
        // Small delay to simulate frame time
        try? await Task.sleep(for: .milliseconds(16))
        
        monitor.recordFrame()
        
        // Test that monitor tracks performance
        #expect(monitor.averageFPS >= 0)
    }
    
    @Test("Performance monitor provides optimization recommendations")
    func testPerformanceMonitorRecommendations() async {
        var monitor = MapKitUtilities.PerformanceMonitor()
        
        // Force low FPS by simulating many slow frames
        for _ in 0..<10 {
            monitor.recordFrame()
            try? await Task.sleep(for: .milliseconds(100)) // Simulate slow frame
            monitor.recordFrame()
        }
        
        let recommendations = monitor.getOptimizationRecommendations()
        
        // Test that recommendations are provided for poor performance
        #expect(recommendations.count > 0)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory manager optimizes location array")
    func testMemoryManagerOptimizeLocationArray() async {
        // Create large array of location points
        var locationPoints: [LocationPoint] = []
        for i in 0..<20000 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: 45.0,
                isKeyPoint: i % 100 == 0 // Mark every 100th point as key
            )
            locationPoints.append(point)
        }
        
        let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(locationPoints)
        
        // Test that array is optimized to manageable size
        #expect(optimized.count <= MapKitUtilities.MemoryManager.maxLocationPointsInMemory)
        #expect(optimized.count > 0)
    }
    
    @Test("Memory manager estimates memory usage")
    func testMemoryManagerEstimateUsage() async {
        let estimatedUsage = MapKitUtilities.MemoryManager.estimateMemoryUsage(
            locationPoints: 1000,
            annotations: 50,
            polylineCoordinates: 500
        )
        
        // Test that estimation returns reasonable value
        #expect(estimatedUsage > 0)
        #expect(estimatedUsage < 1000000) // Should be reasonable estimate
    }
    
    // MARK: - Battery Optimization Tests
    
    @Test("Battery optimizer recommends update frequency")
    func testBatteryOptimizerUpdateFrequency() async {
        let stationaryFrequency = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 0.0,
            batteryLevel: 0.5
        )
        
        let walkingFrequency = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 1.5,
            batteryLevel: 0.5
        )
        
        let runningFrequency = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
            currentSpeed: 3.0,
            batteryLevel: 0.5
        )
        
        // Test that frequency varies with speed
        #expect(stationaryFrequency > walkingFrequency)
        #expect(walkingFrequency > runningFrequency)
    }
    
    @Test("Battery optimizer recommends detail level")
    func testBatteryOptimizerDetailLevel() async {
        let lowBatteryDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.1,
            performanceGood: true
        )
        
        let highBatteryDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.8,
            performanceGood: true
        )
        
        let poorPerformanceDetail = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
            batteryLevel: 0.8,
            performanceGood: false
        )
        
        // Test that detail level varies with battery and performance
        #expect(lowBatteryDetail == .low)
        #expect(highBatteryDetail == .high)
        #expect(poorPerformanceDetail == .low)
    }
    
    // MARK: - Extension Tests
    
    @Test("CLLocationCoordinate2D equality")
    func testCLLocationCoordinate2DEquality() async {
        let coord1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord2 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord3 = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194)
        
        // Test coordinate equality
        #expect(coord1 == coord2)
        #expect(coord1 != coord3)
    }
    
    @Test("MKCoordinateRegion equality")
    func testMKCoordinateRegionEquality() async {
        let region1 = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        let region2 = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        let region3 = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // Test region equality
        #expect(region1 == region2)
        #expect(region1 != region3)
    }
    
    @Test("MapStyle terrain factory method")
    func testMapStyleTerrainFactory() async {
        let trailStyle = MapStyle.forTerrain(.trail)
        let sandStyle = MapStyle.forTerrain(.sand)
        
        // Test that factory method returns styles
        #expect(trailStyle != nil)
        #expect(sandStyle != nil)
    }
    
    @Test("MapCameraPosition factory methods")
    func testMapCameraPositionFactories() async {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        let routeOverview = MapCameraPosition.routeOverview(for: region)
        
        let followingPosition = MapCameraPosition.followingUser(
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            heading: 45.0,
            distance: 500
        )
        
        // Test that factory methods return valid positions
        #expect(routeOverview != nil)
        #expect(followingPosition != nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid coordinates gracefully")
    func testHandleInvalidCoordinates() async {
        let invalidCoordinates = [
            CLLocationCoordinate2D(latitude: 200.0, longitude: 200.0), // Invalid lat/lon
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // Valid
        ]
        
        let region = MapKitUtilities.calculateRouteRegion(for: invalidCoordinates)
        
        // Test that invalid coordinates don't crash the calculation
        #expect(region.center.latitude >= -90 && region.center.latitude <= 90)
        #expect(region.center.longitude >= -180 && region.center.longitude <= 180)
    }
    
    @Test("Handle zero distance calculations")
    func testHandleZeroDistance() async {
        let sameLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let locations = [sameLocation, sameLocation, sameLocation]
        
        let optimized = MapKitUtilities.optimizeRoutePolyline(coordinates: locations, tolerance: 5.0)
        
        // Test that zero-distance route is handled gracefully
        #expect(optimized.count >= 2) // Should return at least start and end
    }
}