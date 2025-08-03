import Foundation
import CoreLocation
import MapKit

/// MapKit-based terrain analysis helper for TerrainDetector
/// 
/// This class provides terrain hints by analyzing MapKit data including:
/// - Map overlays and features
/// - Geocoding results for surface type classification
/// - Geographic context analysis
/// - Point of interest classification
/// 
/// Optimized for battery efficiency with intelligent caching and 
/// minimal network requests following Swift 6 concurrency patterns.
@MainActor
final class MapKitTerrainAnalyzer {
    
    // MARK: - Configuration
    
    private struct Config {
        static let analysisRadiusMeters: Double = 25.0
        static let geocodingCacheTimeout: TimeInterval = 300 // 5 minutes
        static let minimumLocationAccuracy: Double = 100.0 // meters
        static let requestTimeout: TimeInterval = 5.0 // seconds
        
        // Confidence levels
        static let baseConfidence: Double = 0.6
        static let lowConfidence: Double = 0.1
        static let defaultTrailConfidence: Double = 0.2
        static let fallbackConfidence: Double = 0.3
        static let highAltitudeThreshold: Double = 3000.0 // meters
        static let highAltitudeConfidence: Double = 0.4
        static let seaLevelThreshold: Double = 10.0 // meters
        
        // Confidence modifiers
        static let parkModifier: Double = 0.9
        static let wildernessModifier: Double = 1.1
        static let winterModifier: Double = 0.8
        static let stairsModifier: Double = 0.7
        static let urbanModifier: Double = 0.7
        static let waterProximityModifier: Double = 0.6
        static let oceanProximityModifier: Double = 0.5
        static let defaultTrailModifier: Double = 0.6
    }
    
    // MARK: - Cached Results
    
    private struct CachedResult {
        let terrain: TerrainType
        let confidence: Double
        let timestamp: Date
        let location: CLLocation
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > Config.geocodingCacheTimeout
        }
        
        func isValidFor(location: CLLocation) -> Bool {
            return !isExpired && 
                   self.location.distance(from: location) < Config.analysisRadiusMeters
        }
    }
    
    private var cache: [String: CachedResult] = [:]
    
    // MARK: - Public Interface
    
    /// Analyzes terrain at the specified location using MapKit data
    /// - Parameter location: The location to analyze
    /// - Returns: Terrain type and confidence level (0.0 to 1.0)
    func analyzeTerrainAt(location: CLLocation) async -> (terrain: TerrainType, confidence: Double) {
        
        // Check location accuracy
        guard location.horizontalAccuracy <= Config.minimumLocationAccuracy else {
            return (.trail, Config.lowConfidence) // Low confidence for poor GPS
        }
        
        // Check cache first
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        if let cached = cache[cacheKey], cached.isValidFor(location: location) {
            return (cached.terrain, cached.confidence)
        }
        
        // Perform analysis
        let result = await performTerrainAnalysis(at: location)
        
        // Cache the result
        cache[cacheKey] = CachedResult(
            terrain: result.terrain,
            confidence: result.confidence,
            timestamp: Date(),
            location: location
        )
        
        // Clean expired cache entries
        cleanExpiredCache()
        
        return result
    }
    
    /// Clears the analysis cache
    func clearCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Implementation
    
    private func performTerrainAnalysis(at location: CLLocation) async -> (terrain: TerrainType, confidence: Double) {
        
        // Combine multiple analysis methods
        async let geocodingResult = analyzeGeocodingData(location: location)
        async let coordinateResult = analyzeCoordinateHeuristics(location: location)
        
        let geocoding = await geocodingResult
        let coordinate = await coordinateResult
        
        // Fusion analysis results
        return fuseAnalysisResults(geocoding: geocoding, coordinate: coordinate)
    }
    
    // MARK: - Geocoding Analysis
    
    private func analyzeGeocodingData(location: CLLocation) async -> (terrain: TerrainType, confidence: Double) {
        
        do {
            // Use a task with timeout
            let task = Task {
                let geocoder = CLGeocoder()
                return try await geocoder.reverseGeocodeLocation(location)
            }
            
            // Create timeout task
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(Config.requestTimeout))
                task.cancel()
            }
            
            let placemarks: [CLPlacemark]
            do {
                placemarks = try await task.value
                timeoutTask.cancel() // Cancel timeout if geocoding completes
            } catch {
                timeoutTask.cancel()
                throw error
            }
            
            if let placemark = placemarks.first {
                return classifyFromPlacemark(placemark)
            }
            
        } catch {
            // Geocoding failed - return low confidence
            return (.trail, Config.defaultTrailConfidence)
        }
        
        // No placemark found
        return (.trail, Config.defaultTrailConfidence)
    }
    
    private func classifyFromPlacemark(_ placemark: CLPlacemark) -> (terrain: TerrainType, confidence: Double) {
        
        let confidence: Double = Config.baseConfidence
        
        // Analyze thoroughfare (streets/roads)
        if let thoroughfare = placemark.thoroughfare?.lowercased() {
            if thoroughfare.contains("street") || 
               thoroughfare.contains("avenue") ||
               thoroughfare.contains("road") ||
               thoroughfare.contains("boulevard") ||
               thoroughfare.contains("drive") {
                return (.pavedRoad, confidence)
            }
            
            if thoroughfare.contains("trail") ||
               thoroughfare.contains("path") ||
               thoroughfare.contains("way") {
                return (.trail, confidence * Config.parkModifier)
            }
        }
        
        // Analyze areas of interest
        if let areas = placemark.areasOfInterest {
            for area in areas {
                let areaLower = area.lowercased()
                
                // Natural areas
                if areaLower.contains("park") ||
                   areaLower.contains("forest") ||
                   areaLower.contains("wilderness") ||
                   areaLower.contains("preserve") {
                    return (.trail, confidence)
                }
                
                if areaLower.contains("trail") ||
                   areaLower.contains("hiking") {
                    return (.trail, confidence * Config.wildernessModifier)
                }
                
                // Beach/sand areas
                if areaLower.contains("beach") ||
                   areaLower.contains("sand") ||
                   areaLower.contains("dune") {
                    return (.sand, confidence)
                }
                
                // Snow/winter areas
                if areaLower.contains("ski") ||
                   areaLower.contains("snow") ||
                   areaLower.contains("winter") {
                    return (.snow, confidence * Config.winterModifier) // Seasonal
                }
                
                // Gravel/unpaved areas
                if areaLower.contains("gravel") ||
                   areaLower.contains("dirt") ||
                   areaLower.contains("unpaved") {
                    return (.gravel, confidence)
                }
                
                // Grass/field areas
                if areaLower.contains("field") ||
                   areaLower.contains("grass") ||
                   areaLower.contains("lawn") ||
                   areaLower.contains("meadow") {
                    return (.grass, confidence)
                }
                
                // Stairs/building areas
                if areaLower.contains("building") ||
                   areaLower.contains("stairs") ||
                   areaLower.contains("steps") {
                    return (.stairs, confidence * Config.stairsModifier)
                }
            }
        }
        
        // Analyze locality and administrative areas
        if let locality = placemark.locality?.lowercased() {
            // Urban areas likely have paved surfaces
            if locality.contains("city") ||
               locality.contains("town") {
                return (.pavedRoad, confidence * Config.urbanModifier)
            }
        }
        
        // Check for inland water bodies (potential mud)
        if let inlandWater = placemark.inlandWater?.lowercased() {
            if inlandWater.contains("lake") ||
               inlandWater.contains("pond") ||
               inlandWater.contains("river") ||
               inlandWater.contains("stream") {
                return (.mud, confidence * Config.waterProximityModifier) // Near water = potentially muddy
            }
        }
        
        // Ocean proximity might indicate sand
        if placemark.ocean != nil {
            return (.sand, confidence * Config.oceanProximityModifier)
        }
        
        // Default to trail for outdoor areas
        return (.trail, confidence * Config.defaultTrailModifier)
    }
    
    // MARK: - Coordinate Heuristics
    
    private func analyzeCoordinateHeuristics(location: CLLocation) -> (terrain: TerrainType, confidence: Double) {
        
        let coordinate = location.coordinate
        
        // Basic geographic heuristics
        // These could be enhanced with geographic databases or ML models
        
        // Elevation-based heuristics
        if location.altitude > Config.highAltitudeThreshold { // High altitude - more likely snow/rock
            return (.trail, Config.highAltitudeConfidence) // Conservative confidence
        }
        
        if location.altitude < Config.seaLevelThreshold && location.altitude > -Config.seaLevelThreshold { // Sea level
            // Near sea level could indicate coastal areas
            return (.sand, Config.fallbackConfidence)
        }
        
        // Latitude-based seasonal adjustments
        let latitude = abs(coordinate.latitude)
        
        if latitude > 60 { // Arctic regions
            return (.snow, 0.5) // Higher chance of snow
        }
        
        if latitude < 30 { // Tropical/subtropical
            return (.trail, 0.4) // Varied terrain likely
        }
        
        // Speed-based heuristics
        if location.speed > 0 {
            if location.speed > 15 { // ~34 mph - likely on roads
                return (.pavedRoad, 0.5)
            } else if location.speed < 2 { // Very slow - difficult terrain
                return (.trail, 0.4)
            }
        }
        
        // Default neutral response
        return (.trail, 0.3)
    }
    
    // MARK: - Result Fusion
    
    private func fuseAnalysisResults(
        geocoding: (terrain: TerrainType, confidence: Double),
        coordinate: (terrain: TerrainType, confidence: Double)
    ) -> (terrain: TerrainType, confidence: Double) {
        
        // Weight geocoding results higher as they're more specific
        let geocodingWeight: Double = 0.8
        let coordinateWeight: Double = 0.2
        
        if geocoding.confidence > 0.6 {
            // High confidence from geocoding - use it
            return geocoding
        } else if geocoding.confidence > 0.3 && coordinate.confidence > 0.3 {
            // Medium confidence from both - check agreement
            if geocoding.terrain == coordinate.terrain {
                let fusedConfidence = min(1.0, 
                    geocoding.confidence * geocodingWeight + 
                    coordinate.confidence * coordinateWeight + 0.1
                )
                return (geocoding.terrain, fusedConfidence)
            } else {
                // Disagreement - favor geocoding but reduce confidence
                return (geocoding.terrain, geocoding.confidence * 0.8)
            }
        } else if geocoding.confidence > coordinate.confidence {
            return geocoding
        } else {
            return coordinate
        }
    }
    
    // MARK: - Cache Management
    
    private func cleanExpiredCache() {
        let now = Date()
        cache = cache.filter { _, result in
            now.timeIntervalSince(result.timestamp) <= Config.geocodingCacheTimeout
        }
    }
}

// MARK: - MapKit Surface Type Extensions

extension MapKitTerrainAnalyzer {
    
    /// Converts MapKit-specific surface hints to TerrainType
    /// This method can be extended to handle MKMapItem or other MapKit-specific data
    static func convertMapKitSurfaceType(_ surfaceHint: String) -> TerrainType {
        let hint = surfaceHint.lowercased()
        
        switch hint {
        case let h where h.contains("road") || h.contains("street") || h.contains("highway"):
            return .pavedRoad
        case let h where h.contains("trail") || h.contains("path"):
            return .trail
        case let h where h.contains("gravel") || h.contains("dirt"):
            return .gravel
        case let h where h.contains("sand") || h.contains("beach"):
            return .sand
        case let h where h.contains("mud") || h.contains("swamp"):
            return .mud
        case let h where h.contains("snow") || h.contains("ice"):
            return .snow
        case let h where h.contains("stairs") || h.contains("steps"):
            return .stairs
        case let h where h.contains("grass") || h.contains("field"):
            return .grass
        default:
            return .trail
        }
    }
}

// MARK: - Debug Support

extension MapKitTerrainAnalyzer {
    
    /// Returns debug information about the analyzer state
    func getDebugInfo() -> String {
        return """
        === MapKit Terrain Analyzer Debug ===
        Cache Size: \(cache.count) entries
        Analysis Radius: \(Config.analysisRadiusMeters)m
        Cache Timeout: \(Config.geocodingCacheTimeout)s
        Request Timeout: \(Config.requestTimeout)s
        """
    }
    
    /// Gets cache statistics for monitoring
    func getCacheStats() -> (totalEntries: Int, validEntries: Int, hitRate: Double) {
        let total = cache.count
        let valid = cache.values.filter { !$0.isExpired }.count
        let hitRate = total > 0 ? Double(valid) / Double(total) : 0.0
        
        return (total, valid, hitRate)
    }
}