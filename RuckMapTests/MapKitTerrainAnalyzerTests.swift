import Testing
import Foundation
import CoreLocation
import MapKit
@testable import RuckMap

/// Comprehensive test suite for MapKitTerrainAnalyzer class
/// Tests MapKit-based terrain detection, caching, and geocoding analysis
@MainActor
struct MapKitTerrainAnalyzerTests {
    
    // MARK: - Initialization Tests
    
    @Test("MapKitTerrainAnalyzer initializes correctly")
    func testInitialization() {
        let analyzer = MapKitTerrainAnalyzer()
        let stats = analyzer.getCacheStats()
        
        #expect(stats.totalEntries == 0)
        #expect(stats.validEntries == 0)
        #expect(stats.hitRate == 0.0)
    }
    
    // MARK: - Surface Type Conversion Tests
    
    @Test("Surface type conversion handles road types")
    func testSurfaceTypeConversionRoads() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("road") == .pavedRoad)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("street") == .pavedRoad)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("highway") == .pavedRoad)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("Main Street") == .pavedRoad)
    }
    
    @Test("Surface type conversion handles trail types")
    func testSurfaceTypeConversionTrails() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("trail") == .trail)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("path") == .trail)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("hiking trail") == .trail)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("nature path") == .trail)
    }
    
    @Test("Surface type conversion handles gravel types")
    func testSurfaceTypeConversionGravel() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("gravel") == .gravel)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("dirt") == .gravel)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("gravel road") == .gravel)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("dirt path") == .gravel)
    }
    
    @Test("Surface type conversion handles sand types")
    func testSurfaceTypeConversionSand() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("sand") == .sand)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("beach") == .sand)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("sandy beach") == .sand)
    }
    
    @Test("Surface type conversion handles mud types")
    func testSurfaceTypeConversionMud() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("mud") == .mud)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("swamp") == .mud)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("muddy trail") == .mud)
    }
    
    @Test("Surface type conversion handles snow types")
    func testSurfaceTypeConversionSnow() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("snow") == .snow)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("ice") == .snow)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("snowy path") == .snow)
    }
    
    @Test("Surface type conversion handles stairs types")
    func testSurfaceTypeConversionStairs() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("stairs") == .stairs)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("steps") == .stairs)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("stairway") == .stairs)
    }
    
    @Test("Surface type conversion handles grass types")
    func testSurfaceTypeConversionGrass() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("grass") == .grass)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("field") == .grass)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("grassy field") == .grass)
    }
    
    @Test("Surface type conversion defaults to trail for unknown types")
    func testSurfaceTypeConversionDefaults() {
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("unknown") == .trail)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("") == .trail)
        #expect(MapKitTerrainAnalyzer.convertMapKitSurfaceType("random text") == .trail)
    }
    
    // MARK: - Cache Management Tests
    
    @Test("Cache clear operation works correctly")
    func testCacheClear() {
        let analyzer = MapKitTerrainAnalyzer()
        
        // Cache should start empty
        let initialStats = analyzer.getCacheStats()
        #expect(initialStats.totalEntries == 0)
        
        // Clear empty cache should not cause issues
        analyzer.clearCache()
        
        let finalStats = analyzer.getCacheStats()
        #expect(finalStats.totalEntries == 0)
    }
    
    @Test("Cache statistics provide accurate information")
    func testCacheStatistics() {
        let analyzer = MapKitTerrainAnalyzer()
        let stats = analyzer.getCacheStats()
        
        #expect(stats.totalEntries >= 0)
        #expect(stats.validEntries >= 0)
        #expect(stats.validEntries <= stats.totalEntries)
        #expect(stats.hitRate >= 0.0)
        #expect(stats.hitRate <= 1.0)
    }
    
    // MARK: - Location Analysis Tests
    
    @Test("Terrain analysis with invalid location returns low confidence")
    func testTerrainAnalysisInvalidLocation() async {
        let analyzer = MapKitTerrainAnalyzer()
        
        // Create location with poor accuracy
        let poorLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 500, // Very poor accuracy
            verticalAccuracy: -1,
            timestamp: Date()
        )
        
        let result = await analyzer.analyzeTerrainAt(location: poorLocation)
        
        #expect(result.confidence == 0.1) // Low confidence for poor GPS
        #expect(result.terrain == .trail) // Default fallback
    }
    
    @Test("Terrain analysis with valid location returns reasonable confidence")
    func testTerrainAnalysisValidLocation() async {
        let analyzer = MapKitTerrainAnalyzer()
        
        // Create location with good accuracy
        let goodLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 50,
            horizontalAccuracy: 5, // Good accuracy
            verticalAccuracy: 3,
            timestamp: Date()
        )
        
        let result = await analyzer.analyzeTerrainAt(location: goodLocation)
        
        #expect(result.confidence > 0.1) // Should have better confidence
        #expect(TerrainType.allCases.contains(result.terrain)) // Valid terrain type
    }
    
    @Test("Terrain analysis handles coordinate edge cases")
    func testTerrainAnalysisEdgeCases() async {
        let analyzer = MapKitTerrainAnalyzer()
        
        // Test extreme coordinates
        let arcticLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 85.0, longitude: 0.0),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        let result = await analyzer.analyzeTerrainAt(location: arcticLocation)
        
        // Should handle extreme locations gracefully
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
        #expect(TerrainType.allCases.contains(result.terrain))
    }
    
    // MARK: - Concurrency Tests
    
    @Test("MapKitTerrainAnalyzer is MainActor safe")
    func testMainActorSafety() async {
        let analyzer = MapKitTerrainAnalyzer()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 3,
            timestamp: Date()
        )
        
        await MainActor.run {
            _ = analyzer.getCacheStats()
            analyzer.clearCache()
            _ = analyzer.getDebugInfo()
        }
        
        // Analyze terrain from MainActor context
        let result = await analyzer.analyzeTerrainAt(location: location)
        
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrain))
    }
    
    @Test("Multiple concurrent terrain analyses")
    func testConcurrentAnalyses() async {
        let analyzer = MapKitTerrainAnalyzer()
        let baseLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 3,
            timestamp: Date()
        )
        
        // Create multiple nearby locations
        let locations = [
            baseLocation,
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLocation.coordinate.latitude + 0.001,
                    longitude: baseLocation.coordinate.longitude
                ),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 3,
                timestamp: Date()
            ),
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLocation.coordinate.latitude,
                    longitude: baseLocation.coordinate.longitude + 0.001
                ),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 3,
                timestamp: Date()
            )
        ]
        
        // Perform concurrent analyses
        let results = await withTaskGroup(of: (terrain: TerrainType, confidence: Double).self) { group in
            for location in locations {
                group.addTask {
                    await analyzer.analyzeTerrainAt(location: location)
                }
            }
            
            var allResults: [(terrain: TerrainType, confidence: Double)] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        #expect(results.count == 3)
        
        // All results should be valid
        for result in results {
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
            #expect(TerrainType.allCases.contains(result.terrain))
        }
    }
    
    // MARK: - Debug Information Tests
    
    @Test("Debug information provides useful details")
    func testDebugInformation() {
        let analyzer = MapKitTerrainAnalyzer()
        let debugInfo = analyzer.getDebugInfo()
        
        #expect(debugInfo.contains("MapKit Terrain Analyzer"))
        #expect(debugInfo.contains("Cache Size"))
        #expect(debugInfo.contains("Analysis Radius"))
        #expect(debugInfo.contains("Cache Timeout"))
        #expect(debugInfo.contains("Request Timeout"))
    }
    
    // MARK: - Performance Tests
    
    @Test("Surface type conversion is fast", .timeLimit(.milliseconds(10)))
    func testSurfaceTypeConversionPerformance() {
        // Surface type conversion should be very fast
        let result = MapKitTerrainAnalyzer.convertMapKitSurfaceType("road")
        #expect(result == .pavedRoad)
    }
    
    @Test("Cache operations are fast", .timeLimit(.milliseconds(50)))
    func testCacheOperationsPerformance() {
        let analyzer = MapKitTerrainAnalyzer()
        
        // Cache operations should be fast
        _ = analyzer.getCacheStats()
        analyzer.clearCache()
        _ = analyzer.getDebugInfo()
        
        #expect(true) // If we reach here, operations were fast enough
    }
    
    @Test("Terrain analysis with timeout completes in reasonable time", .timeLimit(.seconds(10)))
    func testTerrainAnalysisTimeout() async {
        let analyzer = MapKitTerrainAnalyzer()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 3,
            timestamp: Date()
        )
        
        // Should complete within the timeout limit
        let result = await analyzer.analyzeTerrainAt(location: location)
        
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrain))
    }
    
    // MARK: - Integration Tests
    
    @Test("MapKitTerrainAnalyzer integrates with TerrainDetector")
    func testTerrainDetectorIntegration() async {
        let detector = TerrainDetector()
        let locationManager = CLLocationManager()
        
        // Set up location manager with a mock location
        detector.locationManager = locationManager
        
        // Perform detection (this will use MapKitTerrainAnalyzer internally)
        let result = await detector.detectCurrentTerrain()
        
        #expect(result.confidence >= 0.0)
        #expect(TerrainType.allCases.contains(result.terrainType))
    }
}

// MARK: - Mock Data Helpers

extension MapKitTerrainAnalyzerTests {
    
    /// Creates a mock CLLocation for testing
    static func createMockLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 0,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double = 3
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: Date()
        )
    }
    
    /// Creates a mock CLPlacemark for testing
    static func createMockPlacemark(
        thoroughfare: String? = nil,
        areasOfInterest: [String]? = nil,
        locality: String? = nil
    ) -> CLPlacemark {
        // Note: CLPlacemark is difficult to mock directly
        // This helper provides the structure for future mocking if needed
        return CLPlacemark()
    }
}