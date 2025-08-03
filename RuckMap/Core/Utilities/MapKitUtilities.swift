import Foundation
import MapKit
import SwiftUI
import CoreLocation

/// MapKit utilities for RuckMap application
/// 
/// Provides common MapKit functionality including:
/// - Coordinate region calculations
/// - Route polyline optimization
/// - Memory-efficient map rendering
/// - Battery-optimized map operations
/// - Performance monitoring and optimization
@MainActor
struct MapKitUtilities {
    
    // MARK: - Constants
    
    /// Approximate meters per degree of latitude
    private static let metersPerDegreeLatitude: Double = 111320.0
    
    /// Default coordinate span for single-point regions
    private static let defaultCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    
    /// Default San Francisco coordinates for fallback
    private static let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    // MARK: - Region Calculations
    
    /// Calculates optimal map region for displaying a route
    /// - Parameter locations: Array of locations representing the route
    /// - Returns: MKCoordinateRegion that fits all locations with appropriate padding
    static func calculateRouteRegion(for locations: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !locations.isEmpty else {
            return MKCoordinateRegion(
                center: defaultCoordinate,
                span: defaultCoordinateSpan
            )
        }
        
        if locations.count == 1 {
            return MKCoordinateRegion(
                center: locations[0],
                span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
            )
        }
        
        let coordinates = locations
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        
        let centerLat = (maxLat + minLat) / 2
        let centerLon = (maxLon + minLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Add 20% padding to the span
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2
        
        // Ensure minimum span for very short routes
        let minSpan = 0.001
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, minSpan),
            longitudeDelta: max(lonDelta, minSpan)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    /// Calculates map region for current location with appropriate zoom level
    /// - Parameters:
    ///   - location: Current location
    ///   - zoomLevel: Desired zoom level (1.0 = close, 10.0 = far)
    /// - Returns: MKCoordinateRegion centered on location
    static func regionForCurrentLocation(
        _ location: CLLocationCoordinate2D,
        zoomLevel: Double = 1.0
    ) -> MKCoordinateRegion {
        let span = MKCoordinateSpan(
            latitudeDelta: 0.01 * zoomLevel,
            longitudeDelta: 0.01 * zoomLevel
        )
        return MKCoordinateRegion(center: location, span: span)
    }
    
    // MARK: - Route Optimization
    
    /// Optimizes route polyline for performance using Douglas-Peucker algorithm
    /// - Parameters:
    ///   - coordinates: Original route coordinates
    ///   - tolerance: Simplification tolerance in meters (higher = more simplified)
    /// - Returns: Optimized coordinate array
    static func optimizeRoutePolyline(
        coordinates: [CLLocationCoordinate2D],
        tolerance: Double = 5.0
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        
        return douglasPeucker(coordinates: coordinates, tolerance: tolerance)
    }
    
    /// Douglas-Peucker line simplification algorithm
    private static func douglasPeucker(
        coordinates: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        
        // Find the point with maximum distance from the line between first and last
        var maxDistance: Double = 0
        var maxIndex = 0
        
        let startLocation = CLLocation(
            latitude: coordinates.first!.latitude,
            longitude: coordinates.first!.longitude
        )
        let endLocation = CLLocation(
            latitude: coordinates.last!.latitude,
            longitude: coordinates.last!.longitude
        )
        
        for i in 1..<coordinates.count - 1 {
            let pointLocation = CLLocation(
                latitude: coordinates[i].latitude,
                longitude: coordinates[i].longitude
            )
            
            let distance = distanceFromPointToLine(
                point: pointLocation,
                lineStart: startLocation,
                lineEnd: endLocation
            )
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftResults = douglasPeucker(
                coordinates: Array(coordinates[0...maxIndex]),
                tolerance: tolerance
            )
            let rightResults = douglasPeucker(
                coordinates: Array(coordinates[maxIndex..<coordinates.count]),
                tolerance: tolerance
            )
            
            // Combine results, removing duplicate point at connection
            return leftResults + Array(rightResults.dropFirst())
        } else {
            // Return just endpoints if within tolerance
            return [coordinates.first!, coordinates.last!]
        }
    }
    
    /// Calculates perpendicular distance from point to line segment
    private static func distanceFromPointToLine(
        point: CLLocation,
        lineStart: CLLocation,
        lineEnd: CLLocation
    ) -> Double {
        let A = point.coordinate.latitude - lineStart.coordinate.latitude
        let B = point.coordinate.longitude - lineStart.coordinate.longitude
        let C = lineEnd.coordinate.latitude - lineStart.coordinate.latitude
        let D = lineEnd.coordinate.longitude - lineStart.coordinate.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            return point.distance(from: lineStart)
        }
        
        let param = dot / lenSq
        
        let closestPoint: CLLocationCoordinate2D
        if param < 0 {
            closestPoint = lineStart.coordinate
        } else if param > 1 {
            closestPoint = lineEnd.coordinate
        } else {
            closestPoint = CLLocationCoordinate2D(
                latitude: lineStart.coordinate.latitude + param * C,
                longitude: lineStart.coordinate.longitude + param * D
            )
        }
        
        return point.distance(from: CLLocation(
            latitude: closestPoint.latitude,
            longitude: closestPoint.longitude
        ))
    }
    
    // MARK: - Performance Optimization
    
    /// Creates memory-efficient polyline with coordinate compression
    /// - Parameters:
    ///   - locations: Array of LocationPoint objects
    ///   - maxPoints: Maximum number of points to include (for memory management)
    /// - Returns: Optimized MKPolyline
    static func createOptimizedPolyline(
        from locations: [LocationPoint],
        maxPoints: Int = 1000
    ) -> MKPolyline? {
        guard !locations.isEmpty else { return nil }
        
        // Filter for accuracy and extract coordinates
        var coordinates = locations
            .filter { $0.isAccurate }
            .map { $0.coordinate }
        
        // Limit points for memory efficiency
        if coordinates.count > maxPoints {
            let step = coordinates.count / maxPoints
            coordinates = stride(from: 0, to: coordinates.count, by: step)
                .map { coordinates[$0] }
        }
        
        // Optimize using Douglas-Peucker
        coordinates = optimizeRoutePolyline(coordinates: coordinates)
        
        guard coordinates.count >= 2 else { return nil }
        
        let clCoordinates = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        
        return MKPolyline(coordinates: clCoordinates, count: clCoordinates.count)
    }
    
    // MARK: - Map Style Utilities
    
    /// Determines optimal map style based on terrain and conditions
    /// - Parameters:
    ///   - terrainType: Current terrain type
    ///   - weatherConditions: Current weather (optional)
    /// - Returns: Recommended MapStyle
    static func recommendedMapStyle(
        for terrainType: TerrainType,
        weatherConditions: WeatherConditions? = nil
    ) -> MapStyle {
        // Weather-based adjustments
        if let weather = weatherConditions {
            if weather.weatherDescription?.lowercased().contains("snow") == true {
                return .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
            }
            if weather.weatherDescription?.lowercased().contains("rain") == true {
                return .standard(elevation: .realistic)
            }
        }
        
        // Terrain-based recommendations
        switch terrainType {
        case .trail, .gravel, .mud:
            return .hybrid(elevation: .realistic)
        case .sand:
            return .imagery(elevation: .realistic)
        case .snow:
            return .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .pavedRoad, .stairs:
            return .standard(elevation: .realistic)
        case .grass:
            return .standard(elevation: .realistic)
        }
    }
    
    // MARK: - Distance and Location Utilities
    
    /// Finds location at specific distance along route
    /// - Parameters:
    ///   - targetDistance: Distance in meters
    ///   - locations: Route locations
    /// - Returns: Location at target distance or nil if not found
    static func locationAtDistance(
        _ targetDistance: Double,
        in locations: [CLLocation]
    ) -> CLLocation? {
        guard !locations.isEmpty else { return nil }
        
        var accumulatedDistance: Double = 0
        
        for i in 1..<locations.count {
            let segmentDistance = locations[i-1].distance(from: locations[i])
            
            if accumulatedDistance + segmentDistance >= targetDistance {
                // Interpolate between the two points
                let remainingDistance = targetDistance - accumulatedDistance
                let ratio = remainingDistance / segmentDistance
                
                let lat1 = locations[i-1].coordinate.latitude
                let lon1 = locations[i-1].coordinate.longitude
                let lat2 = locations[i].coordinate.latitude
                let lon2 = locations[i].coordinate.longitude
                
                let interpolatedLat = lat1 + (lat2 - lat1) * ratio
                let interpolatedLon = lon1 + (lon2 - lon1) * ratio
                
                return CLLocation(latitude: interpolatedLat, longitude: interpolatedLon)
            }
            
            accumulatedDistance += segmentDistance
        }
        
        return locations.last
    }
    
    /// Calculates total distance of route
    /// - Parameter locations: Route locations
    /// - Returns: Total distance in meters
    static func calculateTotalDistance(for locations: [CLLocation]) -> Double {
        guard locations.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 1..<locations.count {
            totalDistance += locations[i-1].distance(from: locations[i])
        }
        
        return totalDistance
    }
    
    // MARK: - Terrain Overlay Utilities
    
    /// Creates terrain overlay polygon for visualization
    /// - Parameters:
    ///   - centerLocation: Center of terrain area
    ///   - radius: Radius in meters
    ///   - terrainType: Type of terrain
    /// - Returns: TerrainOverlay for map display
    static func createTerrainOverlay(
        centerLocation: CLLocationCoordinate2D,
        radius: Double,
        terrainType: TerrainType
    ) -> TerrainOverlay {
        // Create circular polygon around center point
        let coordinates = createCircularPolygon(
            center: centerLocation,
            radius: radius,
            points: 20
        )
        
        return TerrainOverlay(
            coordinates: coordinates,
            terrainType: terrainType,
            terrainColor: colorForTerrainType(terrainType)
        )
    }
    
    /// Creates circular polygon coordinates
    private static func createCircularPolygon(
        center: CLLocationCoordinate2D,
        radius: Double,
        points: Int
    ) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Approximate conversion from meters to degrees (rough, but sufficient for visualization)
        let latitudeDelta = radius / metersPerDegreeLatitude
        let longitudeDelta = radius / (metersPerDegreeLatitude * cos(center.latitude * .pi / 180))
        
        for i in 0..<points {
            let angle = Double(i) * 2 * .pi / Double(points)
            let lat = center.latitude + latitudeDelta * sin(angle)
            let lon = center.longitude + longitudeDelta * cos(angle)
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return coordinates
    }
    
    /// Returns appropriate color for terrain type
    private static func colorForTerrainType(_ terrainType: TerrainType) -> Color {
        switch terrainType {
        case .pavedRoad:
            return .gray
        case .trail:
            return .brown
        case .gravel:
            return .orange
        case .sand:
            return .yellow
        case .mud:
            return Color(red: 0.4, green: 0.2, blue: 0.1) // Brown
        case .snow:
            return .white
        case .stairs:
            return .purple
        case .grass:
            return .green
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Monitors map rendering performance
    struct PerformanceMonitor {
        private var lastFrameTime: CFTimeInterval = 0
        private var frameCount: Int = 0
        private var fpsHistory: [Double] = []
        
        mutating func recordFrame() {
            let currentTime = CACurrentMediaTime()
            
            if lastFrameTime > 0 {
                let frameDuration = currentTime - lastFrameTime
                let fps = 1.0 / frameDuration
                
                fpsHistory.append(fps)
                if fpsHistory.count > 60 { // Keep last 60 frames
                    fpsHistory.removeFirst()
                }
            }
            
            lastFrameTime = currentTime
            frameCount += 1
        }
        
        var averageFPS: Double {
            guard !fpsHistory.isEmpty else { return 0 }
            return fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        }
        
        var isPerformanceGood: Bool {
            averageFPS >= 55.0 // Target near 60fps
        }
        
        func getOptimizationRecommendations() -> [String] {
            var recommendations: [String] = []
            
            if averageFPS < 30 {
                recommendations.append("Reduce polyline complexity")
                recommendations.append("Increase coordinate tolerance")
                recommendations.append("Limit annotation count")
            } else if averageFPS < 45 {
                recommendations.append("Consider reducing update frequency")
                recommendations.append("Optimize terrain overlays")
            }
            
            return recommendations
        }
    }
    
    // MARK: - Memory Management
    
    /// Manages memory usage for map components
    struct MemoryManager {
        static let maxLocationPointsInMemory = 10000
        static let maxAnnotationsVisible = 100
        static let maxPolylineCoordinates = 5000
        
        /// Optimizes location array for memory efficiency
        static func optimizeLocationArray(_ locations: [LocationPoint]) -> [LocationPoint] {
            guard locations.count > maxLocationPointsInMemory else { return locations }
            
            // Keep recent points and key points (those marked as important)
            let recentCount = maxLocationPointsInMemory / 2
            let recentPoints = Array(locations.suffix(recentCount))
            
            // Keep key points from earlier in the route
            let keyPoints = locations.prefix(locations.count - recentCount)
                .filter { $0.isKeyPoint }
                .prefix(maxLocationPointsInMemory - recentCount)
            
            return Array(keyPoints) + recentPoints
        }
        
        /// Estimates memory usage for map components
        static func estimateMemoryUsage(
            locationPoints: Int,
            annotations: Int,
            polylineCoordinates: Int
        ) -> Int {
            // Rough estimates in bytes
            let locationPointSize = 100 // Approximate size per LocationPoint
            let annotationSize = 200 // Approximate size per annotation
            let coordinateSize = 16 // Size per coordinate (lat/lon doubles)
            
            return (locationPoints * locationPointSize) +
                   (annotations * annotationSize) +
                   (polylineCoordinates * coordinateSize)
        }
    }
    
    // MARK: - Battery Optimization
    
    /// Battery optimization recommendations for map usage
    struct BatteryOptimizer {
        
        /// Recommends map update frequency based on movement and battery level
        static func recommendedUpdateFrequency(
            currentSpeed: Double,
            batteryLevel: Float
        ) -> TimeInterval {
            // Base frequency: 1 second
            var frequency: TimeInterval = 1.0
            
            // Adjust based on speed
            if currentSpeed < 0.5 { // Stationary
                frequency = 5.0
            } else if currentSpeed < 2.0 { // Walking
                frequency = 2.0
            } else { // Running/cycling
                frequency = 0.5
            }
            
            // Adjust based on battery level
            if batteryLevel < 0.2 { // Below 20%
                frequency *= 2.0
            } else if batteryLevel < 0.5 { // Below 50%
                frequency *= 1.5
            }
            
            return frequency
        }
        
        /// Recommends map detail level based on battery and performance
        static func recommendedDetailLevel(
            batteryLevel: Float,
            performanceGood: Bool
        ) -> MapDetailLevel {
            if batteryLevel < 0.2 || !performanceGood {
                return .low
            } else if batteryLevel < 0.5 {
                return .medium
            } else {
                return .high
            }
        }
    }
    
    enum MapDetailLevel {
        case low
        case medium
        case high
        
        var polylineTolerance: Double {
            switch self {
            case .low: return 20.0
            case .medium: return 10.0
            case .high: return 5.0
            }
        }
        
        var maxAnnotations: Int {
            switch self {
            case .low: return 20
            case .medium: return 50
            case .high: return 100
            }
        }
    }
}

// MARK: - Extensions

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center == rhs.center &&
               abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < 0.000001 &&
               abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < 0.000001
    }
}

// MARK: - MapKit SwiftUI Helpers

extension MapStyle {
    /// Creates terrain-appropriate map style
    static func forTerrain(_ terrainType: TerrainType) -> MapStyle {
        return MapKitUtilities.recommendedMapStyle(for: terrainType)
    }
    
    /// Provides accessibility description for map style
    var accessibilityDescription: String {
        switch self {
        case .standard:
            return "Standard map with roads and labels"
        case .hybrid:
            return "Hybrid map showing satellite imagery with roads"
        case .imagery:
            return "Satellite imagery map"
        default:
            return "Map view"
        }
    }
}

extension MapCameraPosition {
    /// Creates camera position for route overview
    static func routeOverview(for region: MKCoordinateRegion) -> MapCameraPosition {
        return .region(region)
    }
    
    /// Creates camera position following user with accessibility support
    static func followingUser(
        location: CLLocationCoordinate2D,
        heading: Double = 0,
        distance: Double = 500
    ) -> MapCameraPosition {
        return .camera(
            MapCamera(
                centerCoordinate: location,
                distance: distance,
                heading: heading,
                pitch: 45
            )
        )
    }
    
    /// Creates accessible camera position with smooth animation
    static func accessibleFollowingUser(
        location: CLLocationCoordinate2D,
        heading: Double = 0,
        distance: Double = 500,
        animationDuration: Double = 1.0
    ) -> MapCameraPosition {
        return .camera(
            MapCamera(
                centerCoordinate: location,
                distance: distance,
                heading: heading,
                pitch: 30 // Reduced pitch for better accessibility
            )
        )
    }
}

// MARK: - SwiftUI Performance Extensions

extension MapKitUtilities {
    
    /// Performance-optimized polyline creation for SwiftUI
    static func createSwiftUIOptimizedPolyline(
        from locations: [LocationPoint],
        trackingState: TrackingState,
        maxPoints: Int = 1000
    ) -> MKPolyline? {
        // Adjust optimization based on tracking state
        let optimizedMaxPoints = trackingState == .tracking ? maxPoints : maxPoints / 2
        
        return createOptimizedPolyline(from: locations, maxPoints: optimizedMaxPoints)
    }
    
    /// Adaptive update frequency for SwiftUI performance
    static func getSwiftUIUpdateFrequency(for state: TrackingState) -> TimeInterval {
        switch state {
        case .tracking:
            return 1.0/60.0 // 60fps for smooth tracking
        case .paused:
            return 1.0/10.0 // 10fps when paused
        case .stopped:
            return 1.0/5.0  // 5fps when stopped
        }
    }
}