import Foundation
import CoreLocation
import CoreMotion
import MapKit
import UIKit
import Observation


// MARK: - Motion Pattern Analysis
/// Motion pattern characteristics for different terrain types
struct MotionPattern: Sendable {
    let accelerometerVariance: Double
    let stepFrequency: Double
    let verticalAcceleration: Double
    let stepIrregularity: Double
    
    init(variance: Double, frequency: Double, vertical: Double, irregularity: Double) {
        self.accelerometerVariance = variance
        self.stepFrequency = frequency
        self.verticalAcceleration = vertical
        self.stepIrregularity = irregularity
    }
}


// MARK: - Terrain Detection Manager
/// Manages automatic terrain detection using MapKit + motion patterns
@MainActor
@Observable
final class TerrainDetectionManager {
    
    // MARK: - Observable Properties
    private(set) var currentTerrain: TerrainDetectionResult?
    private(set) var isDetecting: Bool = false
    private(set) var detectionHistory: [TerrainDetectionResult] = []
    
    // MARK: - Manual Override
    var manualOverride: TerrainType?
    var isManualOverrideActive: Bool = false
    
    // MARK: - Configuration
    struct Configuration {
        let minConfidenceThreshold: Double = 0.6
        let motionAnalysisWindowSeconds: Double = 10.0
        let mapKitAnalysisRadiusMeters: Double = 50.0
        let detectionUpdateIntervalSeconds: Double = 10.0
        let requireMinimumSpeed: Double = 0.5 // m/s
    }
    
    private let config = Configuration()
    
    // MARK: - Dependencies
    private let motionManager = CMMotionManager()
    private var accelerometerData: [CMAccelerometerData] = []
    private let maxAccelerometerSamples = 300 // 10 seconds at ~30Hz
    private let mapKitAnalyzer = MapKitTerrainAnalyzer()
    
    // MARK: - Detection State
    private var lastDetectionTime: Date?
    private var detectionTask: Task<Void, Never>?
    private var motionUpdateTimer: Timer?
    
    // MARK: - Terrain Pattern Database
    /// Motion patterns for different terrain types based on research
    private let terrainPatterns: [TerrainType: MotionPattern] = [
        .pavedRoad: MotionPattern(variance: 0.05, frequency: 1.8, vertical: 0.3, irregularity: 0.1),
        .trail: MotionPattern(variance: 0.15, frequency: 1.6, vertical: 0.5, irregularity: 0.25),
        .gravel: MotionPattern(variance: 0.25, frequency: 1.5, vertical: 0.6, irregularity: 0.35),
        .sand: MotionPattern(variance: 0.45, frequency: 1.2, vertical: 0.8, irregularity: 0.55),
        .mud: MotionPattern(variance: 0.35, frequency: 1.3, vertical: 0.7, irregularity: 0.45),
        .snow: MotionPattern(variance: 0.30, frequency: 1.4, vertical: 0.6, irregularity: 0.40),
        .grass: MotionPattern(variance: 0.18, frequency: 1.7, vertical: 0.4, irregularity: 0.20),
        .stairs: MotionPattern(variance: 0.60, frequency: 1.0, vertical: 1.2, irregularity: 0.70)
    ]
    
    // MARK: - Initialization
    init() {
        setupMotionManager()
    }
    
    deinit {
        Task { @MainActor in
            stopDetection()
        }
    }
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 1.0/30.0 // 30Hz
        motionManager.deviceMotionUpdateInterval = 1.0/10.0 // 10Hz for device motion
    }
    
    // MARK: - Public Interface
    
    /// Starts terrain detection
    func startDetection() {
        guard !isDetecting else { return }
        
        isDetecting = true
        accelerometerData.removeAll()
        
        // Start accelerometer updates
        startAccelerometerUpdates()
        
        // Start periodic terrain detection
        startPeriodicDetection()
    }
    
    /// Stops terrain detection
    func stopDetection() {
        isDetecting = false
        
        // Stop motion updates
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil
        
        // Cancel detection task
        detectionTask?.cancel()
        detectionTask = nil
        
        accelerometerData.removeAll()
    }
    
    /// Manually override terrain type
    func setManualOverride(_ terrainType: TerrainType?) {
        manualOverride = terrainType
        isManualOverrideActive = terrainType != nil
        
        if let terrain = terrainType {
            let result = TerrainDetectionResult(
                terrainType: terrain,
                confidence: 1.0,
                detectionMethod: .manualOverride,
                timestamp: Date(),
                isManualOverride: true
            )
            
            currentTerrain = result
            addToHistory(result)
        }
    }
    
    /// Clears manual override and resumes automatic detection
    func clearManualOverride() {
        manualOverride = nil
        isManualOverrideActive = false
    }
    
    /// Performs terrain detection for a specific location
    func detectTerrain(
        at location: CLLocation,
        using mapView: MKMapView? = nil
    ) async -> TerrainDetectionResult {
        
        // Use manual override if active
        if isManualOverrideActive, let override = manualOverride {
            return TerrainDetectionResult(
                terrainType: override,
                confidence: 1.0,
                detectionMethod: .manualOverride,
                timestamp: Date(),
                isManualOverride: true
            )
        }
        
        // Check minimum speed requirement
        guard location.speed >= config.requireMinimumSpeed else {
            // Default to current terrain or trail if stationary
            let defaultTerrain = currentTerrain?.terrainType ?? .trail
            return TerrainDetectionResult(
                terrainType: defaultTerrain,
                confidence: 0.3,
                detectionMethod: .fusion,
                timestamp: Date(),
                isManualOverride: false
            )
        }
        
        // Perform MapKit analysis with enhanced analyzer
        let mapKitResult = await analyzeMapKitDataEnhanced(location: location, mapView: mapView)
        
        // Perform motion analysis
        let motionResult = analyzeMotionPattern()
        
        // Combine results using fusion algorithm
        let fusedResult = fuseDetectionResults(
            mapKit: mapKitResult,
            motion: motionResult,
            location: location
        )
        
        // Update current terrain if confidence is sufficient
        if fusedResult.confidence >= config.minConfidenceThreshold {
            currentTerrain = fusedResult
            addToHistory(fusedResult)
        }
        
        return fusedResult
    }
    
    // MARK: - Private Implementation
    
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available for terrain detection")
            return
        }
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            self.accelerometerData.append(data)
            
            // Maintain sliding window
            if self.accelerometerData.count > self.maxAccelerometerSamples {
                self.accelerometerData.removeFirst()
            }
        }
    }
    
    private func startPeriodicDetection() {
        detectionTask = Task { @MainActor in
            while !Task.isCancelled && isDetecting {
                // Detection runs every 10 seconds as specified in User Story 2.2
                try? await Task.sleep(for: .seconds(config.detectionUpdateIntervalSeconds))
                
                // Trigger detection if we have sufficient data
                if accelerometerData.count >= 50 { // Minimum samples for analysis
                    // Detection will be triggered by location updates
                }
            }
        }
    }
    
    // MARK: - MapKit Analysis
    
    private func analyzeMapKitData(
        location: CLLocation,
        mapView: MKMapView?
    ) async -> (terrainType: TerrainType, confidence: Double) {
        
        // Create region around location for analysis
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: config.mapKitAnalysisRadiusMeters * 2,
            longitudinalMeters: config.mapKitAnalysisRadiusMeters * 2
        )
        
        // Analyze map type and overlays if mapView is available
        if let mapView = mapView {
            return await analyzeMapViewContext(mapView: mapView, region: region, location: location)
        }
        
        // Fallback to coordinate-based analysis
        return analyzeCoordinateContext(coordinate: location.coordinate)
    }
    
    private func analyzeMapViewContext(
        mapView: MKMapView,
        region: MKCoordinateRegion,
        location: CLLocation
    ) async -> (terrainType: TerrainType, confidence: Double) {
        
        // Check map type
        switch mapView.mapType {
        case .satellite, .hybrid, .satelliteFlyover, .hybridFlyover:
            // Satellite imagery can provide surface hints
            return await analyzeSatelliteImagery(mapView: mapView, location: location)
            
        case .standard, .mutedStandard:
            // Standard map provides road/trail information
            return analyzeStandardMapData(mapView: mapView, location: location)
            
        @unknown default:
            return (.trail, 0.3)
        }
    }
    
    private func analyzeSatelliteImagery(
        mapView: MKMapView,
        location: CLLocation
    ) async -> (terrainType: TerrainType, confidence: Double) {
        
        // For satellite imagery, we can use heuristics based on location context
        // This is a simplified implementation - could be enhanced with image analysis
        
        // Check if location is near roads or developed areas
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                return classifyFromPlacemark(placemark)
            }
        } catch {
            print("Geocoding failed: \(error)")
        }
        
        // Default fallback
        return (.trail, 0.4)
    }
    
    private func analyzeStandardMapData(
        mapView: MKMapView,
        location: CLLocation
    ) -> (terrainType: TerrainType, confidence: Double) {
        
        // Check for nearby map features
        let point = mapView.convert(location.coordinate, toPointTo: mapView)
        let rect = CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50)
        let region = mapView.convert(rect, toCoordinateFrom: mapView)
        
        // This is a simplified analysis - could be enhanced with actual map overlay checking
        // For now, use coordinate-based heuristics
        return analyzeCoordinateContext(coordinate: location.coordinate)
    }
    
    /// Enhanced MapKit analysis using the dedicated analyzer
    private func analyzeMapKitDataEnhanced(
        location: CLLocation,
        mapView: MKMapView?
    ) async -> (terrainType: TerrainType, confidence: Double) {
        
        // Use dedicated MapKit analyzer for improved accuracy
        let result = await mapKitAnalyzer.analyzeTerrainAt(location: location)
        
        // Enhance with map view context if available
        if let mapView = mapView {
            let mapViewResult = await analyzeMapViewContext(
                mapView: mapView,
                region: MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: config.mapKitAnalysisRadiusMeters * 2,
                    longitudinalMeters: config.mapKitAnalysisRadiusMeters * 2
                ),
                location: location
            )
            
            // Combine results if both have reasonable confidence
            if result.confidence > 0.5 && mapViewResult.confidence > 0.5 {
                if result.terrain == mapViewResult.terrain {
                    // Agreement - boost confidence
                    return (result.terrain, min(1.0, (result.confidence + mapViewResult.confidence) / 2.0 + 0.1))
                } else {
                    // Disagreement - favor the dedicated analyzer
                    return (result.terrain, result.confidence * 0.9)
                }
            } else if result.confidence > mapViewResult.confidence {
                return result
            } else {
                return mapViewResult
            }
        }
        
        return result
    }
    
    private func analyzeCoordinateContext(coordinate: CLLocationCoordinate2D) -> (terrainType: TerrainType, confidence: Double) {
        
        // Use coordinate-based heuristics for terrain detection
        // This is a simplified implementation that could be enhanced with geographic databases
        
        // Default terrain classification based on general geographic patterns
        // In a real implementation, this would query geographic databases or use ML models
        
        return (.trail, 0.5) // Medium confidence default
    }
    
    private func classifyFromPlacemark(_ placemark: CLPlacemark) -> (terrainType: TerrainType, confidence: Double) {
        
        // Analyze placemark properties for terrain hints
        let confidence: Double = 0.6
        
        // Check for urban vs rural indicators
        if let thoroughfare = placemark.thoroughfare,
           thoroughfare.lowercased().contains("street") || 
           thoroughfare.lowercased().contains("avenue") ||
           thoroughfare.lowercased().contains("road") {
            return (.pavedRoad, confidence)
        }
        
        // Check for natural areas
        if let areaOfInterest = placemark.areasOfInterest?.first {
            let area = areaOfInterest.lowercased()
            
            if area.contains("park") || area.contains("trail") || area.contains("forest") {
                return (.trail, confidence)
            }
            
            if area.contains("beach") || area.contains("sand") {
                return (.sand, confidence)
            }
        }
        
        // Check locality type
        if let locality = placemark.locality {
            // Urban areas likely have paved surfaces
            return (.pavedRoad, confidence * 0.8)
        }
        
        // Default to trail for natural areas
        return (.trail, confidence * 0.7)
    }
    
    // MARK: - Motion Pattern Analysis
    
    private func analyzeMotionPattern() -> (terrainType: TerrainType, confidence: Double) {
        
        guard accelerometerData.count >= 30 else {
            return (.trail, 0.0) // Insufficient data
        }
        
        // Calculate motion characteristics
        let motionCharacteristics = calculateMotionCharacteristics()
        
        // Find best matching terrain pattern
        var bestMatch: TerrainType = .trail
        var bestScore: Double = 0.0
        
        for (terrainType, pattern) in terrainPatterns {
            let score = calculatePatternMatchScore(
                characteristics: motionCharacteristics,
                pattern: pattern
            )
            
            if score > bestScore {
                bestScore = score
                bestMatch = terrainType
            }
        }
        
        // Convert score to confidence (0.0 to 1.0)
        let confidence = min(1.0, max(0.0, bestScore))
        
        return (bestMatch, confidence)
    }
    
    private func calculateMotionCharacteristics() -> MotionPattern {
        
        // Extract recent accelerometer data for analysis
        let recentData = Array(accelerometerData.suffix(100)) // Last ~3 seconds at 30Hz
        
        // Calculate accelerometer variance
        let accelerationMagnitudes = recentData.map { data in
            sqrt(data.acceleration.x * data.acceleration.x +
                 data.acceleration.y * data.acceleration.y +
                 data.acceleration.z * data.acceleration.z)
        }
        
        let variance = calculateVariance(accelerationMagnitudes)
        
        // Estimate step frequency using peak detection
        let stepFrequency = estimateStepFrequency(accelerationMagnitudes)
        
        // Calculate vertical acceleration component
        let verticalAccelerations = recentData.map { abs($0.acceleration.z) }
        let averageVertical = verticalAccelerations.reduce(0, +) / Double(verticalAccelerations.count)
        
        // Calculate step irregularity (coefficient of variation)
        let stepIrregularity = variance / accelerationMagnitudes.reduce(0, +) * Double(accelerationMagnitudes.count)
        
        return MotionPattern(
            variance: variance,
            frequency: stepFrequency,
            vertical: averageVertical,
            irregularity: stepIrregularity
        )
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count - 1)
    }
    
    private func estimateStepFrequency(_ accelerationMagnitudes: [Double]) -> Double {
        // Simple peak detection for step frequency estimation
        // This could be enhanced with more sophisticated signal processing
        
        guard accelerationMagnitudes.count > 10 else { return 1.5 } // Default
        
        var peaks = 0
        let threshold = accelerationMagnitudes.reduce(0, +) / Double(accelerationMagnitudes.count) * 1.1
        
        for i in 1..<accelerationMagnitudes.count-1 {
            if accelerationMagnitudes[i] > threshold &&
               accelerationMagnitudes[i] > accelerationMagnitudes[i-1] &&
               accelerationMagnitudes[i] > accelerationMagnitudes[i+1] {
                peaks += 1
            }
        }
        
        // Convert peaks to steps per second (approximate)
        let sampleDuration = Double(accelerationMagnitudes.count) / 30.0 // 30Hz sampling
        let stepsPerSecond = Double(peaks) / sampleDuration * 0.5 // Peaks per step
        
        return max(0.5, min(3.0, stepsPerSecond)) // Clamp to reasonable range
    }
    
    private func calculatePatternMatchScore(
        characteristics: MotionPattern,
        pattern: MotionPattern
    ) -> Double {
        
        // Calculate similarity scores for each characteristic (0.0 to 1.0)
        let varianceScore = 1.0 - min(1.0, abs(characteristics.accelerometerVariance - pattern.accelerometerVariance) / 0.5)
        let frequencyScore = 1.0 - min(1.0, abs(characteristics.stepFrequency - pattern.stepFrequency) / 1.0)
        let verticalScore = 1.0 - min(1.0, abs(characteristics.verticalAcceleration - pattern.verticalAcceleration) / 1.0)
        let irregularityScore = 1.0 - min(1.0, abs(characteristics.stepIrregularity - pattern.stepIrregularity) / 0.5)
        
        // Weighted combination (variance and irregularity are most discriminative)
        let weightedScore = (
            varianceScore * 0.4 +
            frequencyScore * 0.2 +
            verticalScore * 0.2 +
            irregularityScore * 0.2
        )
        
        return weightedScore
    }
    
    // MARK: - Fusion Algorithm
    
    private func fuseDetectionResults(
        mapKit: (terrainType: TerrainType, confidence: Double),
        motion: (terrainType: TerrainType, confidence: Double),
        location: CLLocation
    ) -> TerrainDetectionResult {
        
        // Determine detection method based on confidence levels
        let detectionMethod: TerrainDetectionResult.DetectionMethod
        let finalTerrain: TerrainType
        let finalConfidence: Double
        
        if mapKit.confidence > 0.7 && motion.confidence > 0.7 {
            // Both methods have high confidence
            if mapKit.terrainType == motion.terrainType {
                // Agreement - high confidence
                detectionMethod = .fusion
                finalTerrain = mapKit.terrainType
                finalConfidence = min(1.0, (mapKit.confidence + motion.confidence) / 2.0 + 0.2)
            } else {
                // Disagreement - use weighted average based on confidence
                if mapKit.confidence > motion.confidence {
                    detectionMethod = .fusion
                    finalTerrain = mapKit.terrainType
                    finalConfidence = mapKit.confidence * 0.8
                } else {
                    detectionMethod = .fusion
                    finalTerrain = motion.terrainType
                    finalConfidence = motion.confidence * 0.8
                }
            }
        } else if mapKit.confidence > motion.confidence && mapKit.confidence > 0.5 {
            // MapKit is more confident
            detectionMethod = .mapKitOnly
            finalTerrain = mapKit.terrainType
            finalConfidence = mapKit.confidence
        } else if motion.confidence > 0.5 {
            // Motion analysis is more confident
            detectionMethod = .motionOnly
            finalTerrain = motion.terrainType
            finalConfidence = motion.confidence
        } else {
            // Low confidence from both - use contextual default
            detectionMethod = .fusion
            finalTerrain = determineContextualDefault(location: location)
            finalConfidence = 0.3
        }
        
        return TerrainDetectionResult(
            terrainType: finalTerrain,
            confidence: finalConfidence,
            detectionMethod: detectionMethod,
            timestamp: Date(),
            isManualOverride: false
        )
    }
    
    private func determineContextualDefault(location: CLLocation) -> TerrainType {
        // Use location context to determine sensible default
        // This could be enhanced with geographic databases
        
        // For now, use trail as a reasonable default for outdoor activities
        return .trail
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ result: TerrainDetectionResult) {
        detectionHistory.append(result)
        
        // Maintain reasonable history size
        if detectionHistory.count > 100 {
            detectionHistory.removeFirst(detectionHistory.count - 100)
        }
    }
    
    // MARK: - Public API Extensions
    
    /// Gets the current terrain type with fallback
    func getCurrentTerrainType() -> TerrainType {
        if isManualOverrideActive, let override = manualOverride {
            return override
        }
        
        return currentTerrain?.terrainType ?? .trail
    }
    
    /// Gets current terrain factor for calorie calculations
    func getCurrentTerrainFactor() -> Double {
        return getCurrentTerrainType().terrainFactor
    }
    
    /// Checks if terrain detection has sufficient confidence
    func hasHighConfidenceDetection() -> Bool {
        guard let current = currentTerrain else { return false }
        return current.confidence >= 0.85 // Target from User Story 2.2
    }
    
    /// Gets terrain change log for session analysis
    func getTerrainChangeLog(since startTime: Date) -> [TerrainDetectionResult] {
        return detectionHistory.filter { $0.timestamp >= startTime }
    }
    
    /// Resets detection state (useful for new sessions)
    func reset() {
        currentTerrain = nil
        detectionHistory.removeAll()
        accelerometerData.removeAll()
        clearManualOverride()
        
        // Clear MapKit analyzer cache for fresh session
        Task { @MainActor in
            mapKitAnalyzer.clearCache()
        }
    }
    
    /// Gets debug information for troubleshooting
    func getDebugInfo() -> String {
        let currentInfo = currentTerrain.map { terrain in
            "\(terrain.terrainType.displayName) (confidence: \(String(format: "%.0f", terrain.confidence * 100))%, method: \(terrain.detectionMethod))"
        } ?? "None"
        
        let mapKitStats = mapKitAnalyzer.getCacheStats()
        
        return """
        === Terrain Detection Debug ===
        Current Terrain: \(currentInfo)
        Manual Override: \(isManualOverrideActive ? manualOverride?.displayName ?? "None" : "No")
        Detection Active: \(isDetecting)
        Accelerometer Samples: \(accelerometerData.count)
        History Entries: \(detectionHistory.count)
        Last Detection: \(lastDetectionTime?.formatted() ?? "Never")
        High Confidence: \(hasHighConfidenceDetection())
        
        MapKit Analyzer:
        Cache Entries: \(mapKitStats.totalEntries) (valid: \(mapKitStats.validEntries))
        Cache Hit Rate: \(String(format: "%.1f", mapKitStats.hitRate * 100))%
        """
    }
}

// MARK: - Integration Support
extension TerrainDetectionManager {
    
    /// Creates a terrain segment for a ruck session
    func createTerrainSegment(
        startTime: Date,
        endTime: Date,
        grade: Double
    ) -> TerrainSegment {
        let terrainType = getCurrentTerrainType()
        let confidence = currentTerrain?.confidence ?? 0.5
        let isManual = isManualOverrideActive
        
        return TerrainSegment(
            startTime: startTime,
            endTime: endTime,
            terrainType: terrainType,
            grade: grade,
            confidence: confidence,
            isManuallySet: isManual
        )
    }
    
    /// Validates detection accuracy against known routes
    func validateAgainstKnownRoute(expectedTerrain: TerrainType) -> Double {
        guard let current = currentTerrain else { return 0.0 }
        
        // Simple validation - could be enhanced with route-specific analysis
        if current.terrainType == expectedTerrain {
            return current.confidence
        } else {
            return 0.0
        }
    }
    
    /// Provides terrain factor update stream for CalorieCalculator integration
    func terrainFactorStream() -> AsyncStream<(factor: Double, confidence: Double, terrainType: TerrainType)> {
        AsyncStream { continuation in
            let monitoringTask = Task { @MainActor in
                var lastFactor: Double = 0
                
                while !Task.isCancelled && isDetecting {
                    let factor = getCurrentTerrainFactor()
                    let confidence = currentTerrain?.confidence ?? 0.0
                    let terrainType = getCurrentTerrainType()
                    
                    // Only send updates when factor changes or confidence improves
                    if abs(factor - lastFactor) > 0.05 || confidence > 0.8 {
                        continuation.yield((factor: factor, confidence: confidence, terrainType: terrainType))
                        lastFactor = factor
                    }
                    
                    try? await Task.sleep(for: .seconds(1))
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                monitoringTask.cancel()
            }
        }
    }
    
    /// Enhanced terrain factor calculation with grade compensation
    func getEnhancedTerrainFactor(grade: Double = 0) async -> Double {
        let baseFactor = await MainActor.run { getCurrentTerrainFactor() }
        
        // Apply grade compensation for more accurate terrain impact
        // Steep grades on difficult terrain compound the difficulty
        let gradeMultiplier = 1.0 + max(0, grade / 100.0) * 0.1
        
        return baseFactor * gradeMultiplier
    }
    
    /// Handles terrain detection failures gracefully
    func handleDetectionFailure(_ error: Error) async {
        await MainActor.run {
            print("Terrain detection failed: \(error.localizedDescription)")
            
            // Fallback to default terrain with reduced confidence
            let fallbackResult = TerrainDetectionResult(
                terrainType: .trail,
                confidence: 0.3,
                detectionMethod: .fusion,
                timestamp: Date(),
                isManualOverride: false
            )
            
            if let current = currentTerrain, current.confidence < 0.3 {
                currentTerrain = fallbackResult
                addToHistory(fallbackResult)
            } else if currentTerrain == nil {
                currentTerrain = fallbackResult
                addToHistory(fallbackResult)
            }
        }
    }
}