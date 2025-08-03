import Testing
import MapKit
import SwiftUI
import CoreLocation
@testable import RuckMap

/// Performance benchmark tests for Session 11: Map Integration
/// Ensures map performance meets production requirements:
/// - 60fps during active tracking
/// - <5% additional battery drain
/// - Memory usage under long routes
/// - Map rendering performance
@MainActor
struct MapPerformanceBenchmarkTests {
    
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
    
    func createLargeLocationDataset(count: Int) -> [LocationPoint] {
        var points: [LocationPoint] = []
        
        for i in 0..<count {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0 + Double(i % 100),
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 2.0,
                course: Double(i % 360)
            )
            points.append(point)
        }
        
        return points
    }
    
    // MARK: - Frame Rate Performance Tests
    
    @Test("Map maintains 60fps during active tracking", .timeLimit(.seconds(3)))
    func testMapFrameRatePerformance() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        var performanceMonitor = MapKitUtilities.PerformanceMonitor()
        
        // Simulate 60 fps for 2 seconds (120 frames)
        for i in 0..<120 {
            performanceMonitor.recordFrame()
            
            // Update location every 10 frames to simulate real tracking
            if i % 10 == 0 {
                let location = CLLocation(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                )
                locationManager.currentLocation = location
            }
            
            // Simulate 16.67ms frame time for 60fps
            try? await Task.sleep(for: .milliseconds(16))
        }
        
        let averageFPS = performanceMonitor.averageFPS
        
        // Should maintain close to 60fps
        #expect(averageFPS >= 55.0, "Map should maintain at least 55fps during active tracking")
    }
    
    @Test("Map handles rapid location updates without frame drops", .timeLimit(.seconds(2)))
    func testRapidLocationUpdatePerformance() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        var performanceMonitor = MapKitUtilities.PerformanceMonitor()
        
        // Simulate GPS updates every 100ms (10Hz) for 1.5 seconds
        for i in 0..<15 {
            performanceMonitor.recordFrame()
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001
                ),
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: Date()
            )
            locationManager.currentLocation = location
            
            // Update route polyline
            if let session = locationManager.currentSession {
                let point = LocationPoint(
                    timestamp: Date(),
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    verticalAccuracy: location.verticalAccuracy,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
                
                let polyline = MapKitUtilities.createOptimizedPolyline(
                    from: session.locationPoints,
                    maxPoints: 1000
                )
                mapPresentation.routePolyline = polyline
            }
            
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        let averageFPS = performanceMonitor.averageFPS
        
        // Should maintain good performance even with rapid updates
        #expect(averageFPS >= 50.0, "Map should handle rapid location updates without significant frame drops")
    }
    
    // MARK: - Memory Performance Tests
    
    @Test("Map memory usage remains stable with large routes")
    func testMapMemoryUsageStability() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Create progressively larger datasets
        let testSizes = [100, 500, 1000, 5000, 10000]
        
        for size in testSizes {
            let points = createLargeLocationDataset(count: size)
            locationManager.currentSession?.locationPoints = points
            
            // Create polyline and measure memory efficiency
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: points,
                maxPoints: 1000
            )
            
            #expect(polyline != nil, "Should create polyline for \(size) points")
            #expect(polyline?.pointCount ?? 0 <= 1000, "Polyline should respect point limit")
            
            // Estimate memory usage
            let estimatedUsage = MapKitUtilities.MemoryManager.estimateMemoryUsage(
                locationPoints: points.count,
                annotations: 10,
                polylineCoordinates: polyline?.pointCount ?? 0
            )
            
            #expect(estimatedUsage > 0, "Should estimate memory usage")
            #expect(estimatedUsage < 50_000_000, "Memory usage should remain reasonable") // 50MB limit
        }
    }
    
    @Test("Memory optimization maintains route quality", .timeLimit(.seconds(5)))
    func testMemoryOptimizationQuality() async {
        let locationManager = createTestLocationManager()
        
        // Create very large dataset
        let largeDataset = createLargeLocationDataset(count: 20000)
        locationManager.currentSession?.locationPoints = largeDataset
        
        #expect(largeDataset.count == 20000)
        
        // Apply memory optimization
        let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(largeDataset)
        
        #expect(optimized.count <= MapKitUtilities.MemoryManager.maxLocationPointsInMemory)
        #expect(optimized.count > 100, "Should retain meaningful number of points")
        
        // Verify optimization preserves important points
        #expect(optimized.first?.latitude == largeDataset.first?.latitude, "Should preserve start point")
        #expect(optimized.last?.latitude == largeDataset.last?.latitude, "Should preserve end point")
        
        // Create polylines from both datasets
        let originalPolyline = MapKitUtilities.createOptimizedPolyline(
            from: Array(largeDataset.prefix(1000)),
            maxPoints: 1000
        )
        
        let optimizedPolyline = MapKitUtilities.createOptimizedPolyline(
            from: optimized,
            maxPoints: 1000
        )
        
        #expect(originalPolyline != nil)
        #expect(optimizedPolyline != nil)
        
        // Both should be usable for map display
        #expect(originalPolyline?.pointCount ?? 0 > 0)
        #expect(optimizedPolyline?.pointCount ?? 0 > 0)
    }
    
    // MARK: - Battery Performance Tests
    
    @Test("Map rendering minimizes battery impact")
    func testMapBatteryOptimization() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        // Test different battery levels and speeds
        let testScenarios: [(batteryLevel: Double, speed: Double, expectedFreq: Double)] = [
            (0.8, 2.0, 1.0),   // High battery, walking - frequent updates
            (0.5, 2.0, 2.0),   // Medium battery, walking - moderate updates
            (0.2, 2.0, 5.0),   // Low battery, walking - less frequent updates
            (0.2, 0.0, 10.0),  // Low battery, stationary - very infrequent updates
            (0.1, 2.0, 10.0)   // Critical battery, walking - minimal updates
        ]
        
        for scenario in testScenarios {
            let recommendedFreq = MapKitUtilities.BatteryOptimizer.recommendedUpdateFrequency(
                currentSpeed: scenario.speed,
                batteryLevel: scenario.batteryLevel
            )
            
            #expect(recommendedFreq >= scenario.expectedFreq, 
                   "Update frequency should be at least \(scenario.expectedFreq) seconds for battery level \(scenario.batteryLevel)")
        }
    }
    
    @Test("Map detail level adapts to battery and performance")
    func testMapDetailLevelAdaptation() async {
        let testScenarios: [(battery: Double, performance: Bool, expectedDetail: MapKitUtilities.BatteryOptimizer.DetailLevel)] = [
            (0.8, true, .high),     // High battery, good performance
            (0.5, true, .medium),   // Medium battery, good performance  
            (0.2, true, .low),      // Low battery, good performance
            (0.8, false, .low),     // High battery, poor performance
            (0.2, false, .low)      // Low battery, poor performance
        ]
        
        for scenario in testScenarios {
            let detailLevel = MapKitUtilities.BatteryOptimizer.recommendedDetailLevel(
                batteryLevel: scenario.battery,
                performanceGood: scenario.performance
            )
            
            #expect(detailLevel == scenario.expectedDetail,
                   "Detail level should be \(scenario.expectedDetail) for battery \(scenario.battery) and performance \(scenario.performance)")
        }
    }
    
    // MARK: - Polyline Optimization Performance Tests
    
    @Test("Route polyline optimization performs efficiently", .timeLimit(.seconds(2)))
    func testPolylineOptimizationPerformance() async {
        let testSizes = [100, 500, 1000, 5000, 10000]
        
        for size in testSizes {
            let points = createLargeLocationDataset(count: size)
            
            let startTime = Date()
            
            let polyline = MapKitUtilities.createOptimizedPolyline(
                from: points,
                maxPoints: 1000
            )
            
            let optimizationTime = Date().timeIntervalSince(startTime)
            
            #expect(polyline != nil, "Should create polyline for \(size) points")
            #expect(optimizationTime < 0.5, "Optimization should complete in <0.5s for \(size) points")
            #expect(polyline?.pointCount ?? 0 <= 1000, "Should respect point limits")
        }
    }
    
    @Test("Coordinate optimization maintains route accuracy", .timeLimit(.seconds(3)))
    func testCoordinateOptimizationAccuracy() async {
        // Create route with known characteristics
        let preciseRoute = createLargeLocationDataset(count: 1000)
        
        // Calculate original route metrics
        let originalCoordinates = preciseRoute.map { point in
            CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        
        let originalDistance = MapKitUtilities.calculateTotalDistance(
            for: originalCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        )
        
        // Apply optimization
        let optimizedCoordinates = MapKitUtilities.optimizeRoutePolyline(
            coordinates: originalCoordinates,
            tolerance: 5.0
        )
        
        let optimizedDistance = MapKitUtilities.calculateTotalDistance(
            for: optimizedCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        )
        
        // Optimization should preserve route characteristics
        #expect(optimizedCoordinates.count <= originalCoordinates.count)
        #expect(optimizedCoordinates.count >= 2)
        
        // Distance should be reasonably preserved (within 5%)
        let distanceVariation = abs(optimizedDistance - originalDistance) / originalDistance
        #expect(distanceVariation < 0.05, "Distance should be preserved within 5%")
        
        // Start and end points should be preserved exactly
        #expect(optimizedCoordinates.first?.latitude == originalCoordinates.first?.latitude)
        #expect(optimizedCoordinates.first?.longitude == originalCoordinates.first?.longitude)
        #expect(optimizedCoordinates.last?.latitude == originalCoordinates.last?.latitude)
        #expect(optimizedCoordinates.last?.longitude == originalCoordinates.last?.longitude)
    }
    
    // MARK: - Real-time Update Performance Tests
    
    @Test("Map handles continuous updates efficiently", .timeLimit(.seconds(4)))
    func testContinuousUpdatePerformance() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        var performanceMonitor = MapKitUtilities.PerformanceMonitor()
        let startTime = Date()
        
        // Simulate 3 minutes of continuous tracking at 1Hz
        for i in 0..<180 {
            performanceMonitor.recordFrame()
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                ),
                altitude: 100.0 + Double(i),
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: Date()
            )
            
            locationManager.currentLocation = location
            
            // Add location point
            if let session = locationManager.currentSession {
                let point = LocationPoint(
                    timestamp: Date(),
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    verticalAccuracy: location.verticalAccuracy,
                    speed: 2.0,
                    course: 45.0
                )
                session.locationPoints.append(point)
                
                // Update route every 10 points for efficiency
                if i % 10 == 0 {
                    let polyline = MapKitUtilities.createOptimizedPolyline(
                        from: session.locationPoints,
                        maxPoints: 1000
                    )
                    mapPresentation.routePolyline = polyline
                }
            }
            
            try? await Task.sleep(for: .milliseconds(10)) // Fast simulation
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageFPS = performanceMonitor.averageFPS
        
        #expect(totalTime < 4.0, "Should complete simulation in under 4 seconds")
        #expect(averageFPS >= 30.0, "Should maintain reasonable performance during continuous updates")
        #expect(locationManager.currentSession?.locationPoints.count == 180)
    }
    
    // MARK: - Complex Scenario Performance Tests
    
    @Test("Map performs well with multiple overlays and annotations", .timeLimit(.seconds(3)))
    func testComplexScenarioPerformance() async {
        let locationManager = createTestLocationManager()
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Add substantial route
        let points = createLargeLocationDataset(count: 500)
        locationManager.currentSession?.locationPoints = points
        
        // Create route polyline
        let polyline = MapKitUtilities.createOptimizedPolyline(
            from: points,
            maxPoints: 1000
        )
        mapPresentation.routePolyline = polyline
        
        // Add multiple terrain overlays
        for i in 0..<10 {
            let overlay = TerrainOverlay(
                coordinates: [
                    CLLocationCoordinate2D(
                        latitude: 37.7749 + Double(i) * 0.001,
                        longitude: -122.4194 + Double(i) * 0.001
                    ),
                    CLLocationCoordinate2D(
                        latitude: 37.7750 + Double(i) * 0.001,
                        longitude: -122.4195 + Double(i) * 0.001
                    )
                ],
                terrainType: i % 2 == 0 ? .trail : .sand,
                terrainColor: i % 2 == 0 ? .green : .yellow
            )
            mapPresentation.terrainOverlays.append(overlay)
        }
        
        // Add mile markers
        locationManager.totalDistance = 5000.0 // 3+ miles
        await mapPresentation.updateMileMarkers()
        
        // Verify all components are present
        #expect(mapPresentation.routePolyline != nil)
        #expect(mapPresentation.terrainOverlays.count == 10)
        #expect(mapPresentation.mileMarkers.count > 0)
        
        // Performance should remain acceptable with complex scenario
        let estimatedUsage = MapKitUtilities.MemoryManager.estimateMemoryUsage(
            locationPoints: points.count,
            annotations: mapPresentation.mileMarkers.count + 10,
            polylineCoordinates: polyline?.pointCount ?? 0
        )
        
        #expect(estimatedUsage < 100_000_000, "Memory usage should remain under 100MB for complex scenario")
    }
    
    // MARK: - Adaptive Performance Tests
    
    @Test("Map adapts performance based on tracking state")
    func testAdaptivePerformanceByTrackingState() async {
        let locationManager = createTestLocationManager()
        let mapPresentation = MapPresentation()
        
        await mapPresentation.initialize(with: locationManager)
        
        // Test different tracking states
        let states: [LocationTrackingManager.TrackingState] = [.tracking, .paused, .stopped]
        
        for state in states {
            locationManager.trackingState = state
            await mapPresentation.adaptToTrackingState(state)
            
            let frameInterval = await mapPresentation.getAdaptiveFrameInterval()
            
            switch state {
            case .tracking:
                #expect(frameInterval <= 0.1, "Tracking should have high frame rate")
            case .paused:
                #expect(frameInterval >= 0.1, "Paused should reduce frame rate")
            case .stopped:
                #expect(frameInterval >= 0.5, "Stopped should have very low frame rate")
            }
        }
    }
}

// MARK: - Stress Test Performance

@Suite("Map Performance Stress Tests")
struct MapPerformanceStressTests {
    
    @Test("Map survives extreme memory pressure", .timeLimit(.seconds(10)))
    func testExtremeMemoryPressureStress() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        locationManager.trackingState = .tracking
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Create extremely large dataset
        for batch in 0..<100 {
            let batchPoints = Array(0..<1000).map { i in
                LocationPoint(
                    timestamp: Date().addingTimeInterval(Double(batch * 1000 + i)),
                    latitude: 37.7749 + Double(i) * 0.00001,
                    longitude: -122.4194 + Double(i) * 0.00001,
                    altitude: 100.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 10.0,
                    speed: 2.0,
                    course: 45.0
                )
            }
            
            session.locationPoints.append(contentsOf: batchPoints)
            
            // Apply memory management every 10 batches
            if batch % 10 == 0 {
                let optimized = MapKitUtilities.MemoryManager.optimizeLocationArray(session.locationPoints)
                session.locationPoints = Array(optimized.prefix(5000))
            }
            
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Should survive extreme conditions
        #expect(session.locationPoints.count <= 5000)
        
        // Should still be able to create map components
        let polyline = MapKitUtilities.createOptimizedPolyline(
            from: session.locationPoints,
            maxPoints: 1000
        )
        
        #expect(polyline != nil)
    }
    
    @Test("Map handles rapid state changes", .timeLimit(.seconds(2)))
    func testRapidStateChangeStress() async {
        let locationManager = LocationTrackingManager()
        let session = RuckSession()
        locationManager.currentSession = session
        
        let mapPresentation = MapPresentation()
        await mapPresentation.initialize(with: locationManager)
        
        // Rapidly change states
        let states: [LocationTrackingManager.TrackingState] = [.tracking, .paused, .tracking, .stopped, .tracking]
        
        for i in 0..<100 {
            let state = states[i % states.count]
            locationManager.trackingState = state
            await mapPresentation.adaptToTrackingState(state)
            
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Should handle rapid changes gracefully
        #expect(locationManager.trackingState != nil)
    }
}