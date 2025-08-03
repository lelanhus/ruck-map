import Foundation
import CoreLocation
import CoreMotion
import MapKit
import Observation
import SwiftData

/// Errors that can occur during terrain detection
enum TerrainDetectionError: LocalizedError, Sendable {
    case lowConfidence(Double)
    case sensorFailure(String)
    case locationUnavailable
    case motionDataInsufficient
    case analysisTimeout
    
    var errorDescription: String? {
        switch self {
        case .lowConfidence(let confidence):
            return "Terrain detection confidence too low: \(String(format: "%.1f", confidence * 100))%"
        case .sensorFailure(let sensor):
            return "Sensor failure: \(sensor)"
        case .locationUnavailable:
            return "Location data unavailable for terrain detection"
        case .motionDataInsufficient:
            return "Insufficient motion data for terrain analysis"
        case .analysisTimeout:
            return "Terrain analysis timed out"
        }
    }
}


/// Terrain detection result with confidence metrics
struct TerrainDetectionResult: Sendable {
    let terrainType: TerrainType
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    let detectionMethod: DetectionMethod
    let isManualOverride: Bool
    
    enum DetectionMethod: Sendable {
        case motion
        case location
        case mapKit
        case mapKitOnly
        case motionOnly
        case fusion
        case manual
        case manualOverride
    }
    
    private static let highConfidenceThreshold: Double = 0.85
    
    var isHighConfidence: Bool {
        confidence >= Self.highConfidenceThreshold
    }
    
    var terrainFactor: Double {
        terrainType.terrainFactor
    }
}

/// Advanced terrain detection using motion patterns and location data
/// 
/// This class analyzes device motion characteristics and location context
/// to automatically identify terrain types during rucking activities.
/// Follows Swift 6 concurrency patterns with @MainActor for UI thread safety.
@MainActor
@Observable
final class TerrainDetector {
    
    // MARK: - Published Properties
    
    /// Current detected terrain type
    private(set) var currentTerrain: TerrainType = .trail
    
    /// Confidence level of current detection (0.0 to 1.0)
    private(set) var confidence: Double = 0.0
    
    /// Historical terrain detection results
    private(set) var detectionHistory: [TerrainDetectionResult] = []
    
    /// Whether terrain detection is actively running
    private(set) var isDetecting: Bool = false
    
    // MARK: - Core Dependencies
    
    /// Motion manager for accelerometer and gyroscope data
    private let motionManager = CMMotionManager()
    
    /// Advanced motion pattern analyzer
    private let motionAnalyzer = MotionPatternAnalyzer()
    
    /// Reference to location manager for geographical context
    weak var locationManager: CLLocationManager?
    
    /// MapKit terrain analyzer for surface type detection
    private let mapKitAnalyzer = MapKitTerrainAnalyzer()
    
    /// Local search instance for geocoding
    private let localSearch = MKLocalSearch.self
    
    // MARK: - Detection Configuration
    
    private struct DetectionConfig {
        static let updateInterval: TimeInterval = 10.0 // seconds
        static let motionSampleRate: TimeInterval = 1.0/30.0 // 30Hz - battery efficient
        static let minimumConfidenceThreshold: Double = 0.6
        static let historyMaxSize: Int = 100
        static let motionAnalysisWindowSize: Int = 150 // ~5 seconds at 30Hz
        static let gyroSampleRate: TimeInterval = 1.0/30.0 // 30Hz for gyroscope
        
        // Confidence thresholds
        static let highConfidenceThreshold: Double = 0.85
        static let fallbackConfidence: Double = 0.3
        static let manualOverrideConfidence: Double = 1.0
        
        // Motion analysis
        static let minimumAccelerometerSamples: Int = 30
        static let motionSyncTimeDiffThreshold: TimeInterval = 0.1
        
        // Terrain factor monitoring
        static let terrainFactorChangeThreshold: Double = 0.1
        static let terrainFactorUpdateInterval: TimeInterval = 5.0
        static let terrainFactorCheckInterval: TimeInterval = 2.0
    }
    
    // MARK: - Motion Analysis Data
    
    private var accelerometerData: [CMAccelerometerData] = []
    private var gyroscopeData: [CMGyroData] = []
    private var lastDetectionTime: Date?
    private var detectionTimer: Timer?
    
    /// Battery optimization state
    private var batteryOptimizedMode: Bool = false
    
    /// Motion confidence from pattern analyzer
    private var motionConfidence: Double = 0.0
    
    
    // MARK: - Initialization
    
    init() {
        setupMotionManager()
    }
    
    /// Convenience initializer for CalorieCalculator integration
    convenience init(withCalorieCalculatorIntegration: Bool) {
        self.init()
        
        if withCalorieCalculatorIntegration {
            // Configure for optimized calorie calculation integration
            setBatteryOptimizedMode(false) // Higher accuracy for calorie calculations
        }
    }
    
    
    // MARK: - Public Interface
    
    /// Starts terrain detection with motion pattern analysis
    func startDetection() {
        guard !isDetecting else { return }
        
        isDetecting = true
        accelerometerData.removeAll()
        lastDetectionTime = nil
        
        startMotionUpdates()
        startPeriodicDetection()
    }
    
    /// Stops terrain detection and cleans up resources
    func stopDetection() {
        isDetecting = false
        
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        detectionTimer?.invalidate()
        detectionTimer = nil
        accelerometerData.removeAll()
        gyroscopeData.removeAll()
        
        // Reset motion analyzer
        Task {
            await motionAnalyzer.reset()
        }
    }
    
    /// Manually override terrain type with high confidence
    func setManualTerrain(_ terrain: TerrainType) {
        currentTerrain = terrain
        confidence = DetectionConfig.manualOverrideConfidence
        
        let result = TerrainDetectionResult(
            terrainType: terrain,
            confidence: DetectionConfig.manualOverrideConfidence,
            timestamp: Date(),
            detectionMethod: .manual,
            isManualOverride: true
        )
        
        addToHistory(result)
    }
    
    /// Performs immediate terrain detection based on current data
    func detectCurrentTerrain() async -> TerrainDetectionResult {
        guard accelerometerData.count >= DetectionConfig.minimumAccelerometerSamples else {
            return TerrainDetectionResult(
                terrainType: currentTerrain,
                confidence: 0.0,
                timestamp: Date(),
                detectionMethod: .motion,
                isManualOverride: false
            )
        }
        
        let motionResult = await analyzeMotionPatternLocal()
        let locationResult = analyzeLocationContext()
        let mapKitResult = await analyzeMapKitData()
        let fusedResult = fuseDetectionResults(
            motion: motionResult,
            location: locationResult,
            mapKit: mapKitResult
        )
        
        if fusedResult.confidence >= DetectionConfig.minimumConfidenceThreshold {
            currentTerrain = fusedResult.terrainType
            confidence = fusedResult.confidence
            addToHistory(fusedResult)
        }
        
        return fusedResult
    }
    
    /// Gets terrain factor for calorie calculations
    func getCurrentTerrainFactor() -> Double {
        currentTerrain.terrainFactor
    }
    
    /// Gets terrain factor asynchronously for concurrent access
    func getTerrainFactor() async -> Double {
        return await MainActor.run {
            getCurrentTerrainFactor()
        }
    }
    
    /// Starts real-time terrain factor monitoring for calorie calculation integration
    func startTerrainFactorMonitoring(
        factorUpdateHandler: @escaping @Sendable (Double, TerrainType, Double) async -> Void
    ) {
        guard isDetecting else { return }
        
        Task {
            var lastTerrainFactor: Double = 0
            var lastUpdateTime = Date()
            
            while !Task.isCancelled && isDetecting {
                let currentFactor = await getTerrainFactor()
                let currentType = currentTerrain
                let confidence = self.confidence
                
                // Update if terrain factor changed significantly or enough time has passed
                let factorChanged = abs(currentFactor - lastTerrainFactor) > DetectionConfig.terrainFactorChangeThreshold
                let timeElapsed = Date().timeIntervalSince(lastUpdateTime) > DetectionConfig.terrainFactorUpdateInterval
                
                if factorChanged || timeElapsed {
                    await factorUpdateHandler(currentFactor, currentType, confidence)
                    lastTerrainFactor = currentFactor
                    lastUpdateTime = Date()
                }
                
                // Check every 2 seconds for terrain factor changes
                try? await Task.sleep(for: .seconds(DetectionConfig.terrainFactorCheckInterval))
            }
        }
    }
    
    /// Sets battery optimization mode for efficient sensor sampling
    func setBatteryOptimizedMode(_ enabled: Bool) {
        batteryOptimizedMode = enabled
        
        if enabled {
            // Reduce update intervals for battery efficiency
            motionManager.accelerometerUpdateInterval = DetectionConfig.motionSampleRate * 2 // 15Hz
            motionManager.gyroUpdateInterval = DetectionConfig.gyroSampleRate * 2 // 15Hz
        } else {
            // Standard 30Hz sampling
            motionManager.accelerometerUpdateInterval = DetectionConfig.motionSampleRate
            motionManager.gyroUpdateInterval = DetectionConfig.gyroSampleRate
        }
    }
    
    /// Handles terrain detection failures gracefully
    func handleDetectionFailure(_ error: Error) async {
        print("Terrain detection failed: \(error.localizedDescription)")
        
        // Fallback to default terrain with reduced confidence
        let fallbackResult = TerrainDetectionResult(
            terrainType: .trail,
            confidence: DetectionConfig.fallbackConfidence,
            timestamp: Date(),
            detectionMethod: .fusion,
            isManualOverride: false
        )
        
        if confidence < DetectionConfig.fallbackConfidence {
            currentTerrain = .trail
            confidence = DetectionConfig.fallbackConfidence
            addToHistory(fallbackResult)
        }
    }
    
    /// Gets motion analysis confidence score
    func getMotionConfidence() -> Double {
        return motionConfidence
    }
    
    /// Resets detection state for new session
    func reset() {
        currentTerrain = .trail
        confidence = 0.0
        detectionHistory.removeAll()
        accelerometerData.removeAll()
        gyroscopeData.removeAll()
        lastDetectionTime = nil
        motionConfidence = 0.0
        
        Task {
            await motionAnalyzer.reset()
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = DetectionConfig.motionSampleRate
        motionManager.gyroUpdateInterval = DetectionConfig.gyroSampleRate
    }
    
    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable && motionManager.isGyroAvailable else { return }
        
        // Start accelerometer updates
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            self.accelerometerData.append(data)
            
            // Maintain sliding window
            if self.accelerometerData.count > DetectionConfig.motionAnalysisWindowSize {
                self.accelerometerData.removeFirst()
            }
            
            // Send to motion analyzer if we have corresponding gyro data
            self.processMotionData()
        }
        
        // Start gyroscope updates
        motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            self.gyroscopeData.append(data)
            
            // Maintain sliding window
            if self.gyroscopeData.count > DetectionConfig.motionAnalysisWindowSize {
                self.gyroscopeData.removeFirst()
            }
            
            // Send to motion analyzer if we have corresponding accelerometer data
            self.processMotionData()
        }
    }
    
    private func startPeriodicDetection() {
        detectionTimer = Timer.scheduledTimer(withTimeInterval: DetectionConfig.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicDetection()
            }
        }
    }
    
    private func performPeriodicDetection() {
        guard isDetecting else { return }
        
        Task {
            let result = await detectCurrentTerrain()
            lastDetectionTime = Date()
            
            // Log detection for debugging
            print("Terrain detected: \(result.terrainType.displayName) (confidence: \(String(format: "%.0f", result.confidence * 100))%)")
        }
    }
    
    // MARK: - Motion Pattern Analysis
    
    /// Processes synchronized motion data from accelerometer and gyroscope
    private func processMotionData() {
        // Find matching accelerometer and gyroscope samples (within 0.1 seconds)
        guard let latestAccel = accelerometerData.last,
              let latestGyro = gyroscopeData.last else { return }
        
        let timeDiff = abs(latestAccel.timestamp - latestGyro.timestamp)
        guard timeDiff < DetectionConfig.motionSyncTimeDiffThreshold else { return } // Samples must be synchronized
        
        // Send synchronized data to motion analyzer
        Task {
            await motionAnalyzer.addMotionSample(accelerometer: latestAccel, gyroscope: latestGyro)
        }
    }
    
    private func analyzeMotionPatternLocal() async -> (terrain: TerrainType, confidence: Double) {
        // Use the advanced motion pattern analyzer
        guard let analysisResult = await motionAnalyzer.analyzeMotionPattern() else {
            return (.trail, 0.0)
        }
        
        motionConfidence = analysisResult.confidence
        return (analysisResult.terrainType, analysisResult.confidence)
    }
    
    
    // MARK: - Location Context Analysis
    
    private func analyzeLocationContext() -> (terrain: TerrainType, confidence: Double) {
        guard locationManager?.location != nil else {
            return (.trail, 0.0)
        }
        
        // Basic location context analysis
        // This could be enhanced with more sophisticated geographic analysis
        return (.trail, 0.3)
    }
    
    // MARK: - MapKit Terrain Analysis
    
    /// Analyzes MapKit data for terrain hints
    private func analyzeMapKitData() async -> (terrain: TerrainType, confidence: Double) {
        guard let location = locationManager?.location else {
            return (.trail, 0.0)
        }
        
        return await mapKitAnalyzer.analyzeTerrainAt(location: location)
    }
    
    // MARK: - Fusion Algorithm
    
    private func fuseDetectionResults(
        motion: (terrain: TerrainType, confidence: Double),
        location: (terrain: TerrainType, confidence: Double),
        mapKit: (terrain: TerrainType, confidence: Double)
    ) -> TerrainDetectionResult {
        
        let detectionMethod: TerrainDetectionResult.DetectionMethod
        let finalTerrain: TerrainType
        let finalConfidence: Double
        
        // Weight the different detection methods
        let motionWeight: Double = 0.4
        let locationWeight: Double = 0.2
        let mapKitWeight: Double = 0.4
        
        // Find the highest confidence detection
        let maxConfidence = max(motion.confidence, location.confidence, mapKit.confidence)
        
        if maxConfidence >= 0.8 {
            // High confidence detection - use the best source
            if motion.confidence == maxConfidence {
                detectionMethod = .motion
                finalTerrain = motion.terrain
                finalConfidence = motion.confidence
            } else if mapKit.confidence == maxConfidence {
                detectionMethod = .mapKit
                finalTerrain = mapKit.terrain
                finalConfidence = mapKit.confidence
            } else {
                detectionMethod = .location
                finalTerrain = location.terrain
                finalConfidence = location.confidence
            }
        } else if motion.confidence > 0.6 && mapKit.confidence > 0.6 {
            // Medium confidence from multiple sources - use fusion
            if motion.terrain == mapKit.terrain {
                detectionMethod = .fusion
                finalTerrain = motion.terrain
                finalConfidence = min(1.0, (motion.confidence * motionWeight + mapKit.confidence * mapKitWeight) / (motionWeight + mapKitWeight) + 0.15)
            } else {
                // Disagreement - favor motion analysis with reduced confidence
                detectionMethod = .fusion
                finalTerrain = motion.confidence > mapKit.confidence ? motion.terrain : mapKit.terrain
                finalConfidence = max(motion.confidence, mapKit.confidence) * 0.8
            }
        } else {
            // Low confidence - use weighted average or default
            let weightedScore = (
                motion.confidence * motionWeight +
                location.confidence * locationWeight +
                mapKit.confidence * mapKitWeight
            )
            
            if weightedScore > 0.4 {
                detectionMethod = .fusion
                finalTerrain = motion.confidence > mapKit.confidence ? motion.terrain : mapKit.terrain
                finalConfidence = weightedScore
            } else {
                detectionMethod = .fusion
                finalTerrain = .trail // Default fallback
                finalConfidence = 0.3
            }
        }
        
        return TerrainDetectionResult(
            terrainType: finalTerrain,
            confidence: finalConfidence,
            timestamp: Date(),
            detectionMethod: detectionMethod,
            isManualOverride: false
        )
    }
    
    // MARK: - Utility Functions
    
    private func addToHistory(_ result: TerrainDetectionResult) {
        detectionHistory.append(result)
        
        if detectionHistory.count > DetectionConfig.historyMaxSize {
            detectionHistory.removeFirst()
        }
    }
    
}

// MARK: - Supporting Types

// MARK: - Calorie Calculator Integration

extension TerrainDetector {
    
    /// Provides terrain factor update stream for CalorieCalculator integration
    func terrainFactorStream() -> AsyncStream<(factor: Double, confidence: Double, terrainType: TerrainType)> {
        AsyncStream { continuation in
            let monitoringTask = Task {
                var lastFactor: Double = 0
                
                while !Task.isCancelled && isDetecting {
                    let factor = await getTerrainFactor()
                    let confidence = await MainActor.run { self.confidence }
                    let terrainType = await MainActor.run { self.currentTerrain }
                    
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
        let baseFactor = await getTerrainFactor()
        
        // Apply grade compensation for more accurate terrain impact
        // Steep grades on difficult terrain compound the difficulty
        let gradeMultiplier = 1.0 + max(0, grade / 100.0) * 0.1
        
        return baseFactor * gradeMultiplier
    }
}

// MARK: - Debug Support

extension TerrainDetector {
    /// Returns debug information for troubleshooting
    func getDebugInfo() async -> String {
        let motionAnalyzerDebug = await motionAnalyzer.getDebugInfo()
        let motionSampleCount = await motionAnalyzer.sampleCount
        let timeSinceAnalysis = await motionAnalyzer.timeSinceLastAnalysis
        
        return """
        === Terrain Detector Debug ===
        Current Terrain: \(currentTerrain.displayName)
        Confidence: \(String(format: "%.0f", confidence * 100))%
        Motion Confidence: \(String(format: "%.0f", motionConfidence * 100))%
        Detection Active: \(isDetecting)
        Accelerometer Samples: \(accelerometerData.count)
        Gyroscope Samples: \(gyroscopeData.count)
        Motion Analyzer Samples: \(motionSampleCount)
        Battery Optimized: \(batteryOptimizedMode)
        History Count: \(detectionHistory.count)
        Last Detection: \(lastDetectionTime?.formatted() ?? "Never")
        Time Since Motion Analysis: \(timeSinceAnalysis?.formatted(.number.precision(.fractionLength(1))) ?? "Never")s
        Terrain Factor: \(getCurrentTerrainFactor())
        
        \(motionAnalyzerDebug)
        """
    }
}