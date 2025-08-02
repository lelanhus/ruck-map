import Foundation
import CoreMotion
import Accelerate
import Observation

/// Motion pattern analysis for terrain detection using Swift 6 concurrency
///
/// This actor provides thread-safe motion pattern analysis using accelerometer and gyroscope data
/// to detect terrain-specific motion signatures for various surfaces during rucking activities.
actor MotionPatternAnalyzer {
    
    // MARK: - Configuration
    
    private struct AnalysisConfig {
        static let sampleRate: Double = 30.0 // 30Hz for battery efficiency
        static let windowSize: Int = 150 // 5 seconds of data
        static let minSamplesForAnalysis: Int = 30 // 1 second minimum
        static let frequencyBands: [ClosedRange<Double>] = [
            0.5...2.0,   // Slow movement
            2.0...4.0,   // Normal walking
            4.0...8.0,   // Fast walking/running
            8.0...15.0   // High frequency vibrations
        ]
        static let overlappingWindow: Int = 30 // 1 second overlap for sliding window
    }
    
    // MARK: - Motion Data Types
    
    struct MotionSample: Sendable {
        let timestamp: Date
        let acceleration: SIMD3<Double>
        let rotationRate: SIMD3<Double>
        let magnitude: Double
        
        init(accelerometer: CMAccelerometerData, gyroscope: CMGyroData) {
            self.timestamp = accelerometer.timestamp > gyroscope.timestamp ? 
                Date(timeIntervalSinceReferenceDate: accelerometer.timestamp) :
                Date(timeIntervalSinceReferenceDate: gyroscope.timestamp)
            
            self.acceleration = SIMD3<Double>(
                accelerometer.acceleration.x,
                accelerometer.acceleration.y,
                accelerometer.acceleration.z
            )
            
            self.rotationRate = SIMD3<Double>(
                gyroscope.rotationRate.x,
                gyroscope.rotationRate.y,
                gyroscope.rotationRate.z
            )
            
            // Calculate magnitude with gravity removed
            self.magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
        }
    }
    
    struct MotionAnalysisResult: Sendable {
        let terrainType: TerrainType
        let confidence: Double
        let timestamp: Date
        let analysisDetails: AnalysisDetails
        
        struct AnalysisDetails: Sendable {
            let stepFrequency: Double
            let accelerationVariance: Double
            let verticalComponent: Double
            let stepRegularity: Double
            let frequencyProfile: [Double] // Power in each frequency band
            let gyroscopeVariance: Double
            let impactIntensity: Double
        }
    }
    
    // MARK: - Terrain Motion Signatures
    
    private struct TerrainSignature: Sendable {
        let stepFrequency: ClosedRange<Double>
        let accelerationVariance: ClosedRange<Double>
        let verticalComponent: ClosedRange<Double>
        let stepRegularity: ClosedRange<Double>
        let gyroscopeVariance: ClosedRange<Double>
        let impactIntensity: ClosedRange<Double>
        let frequencyProfile: [ClosedRange<Double>] // Expected power in each band
    }
    
    private let terrainSignatures: [TerrainType: TerrainSignature] = [
        .pavedRoad: TerrainSignature(
            stepFrequency: 1.6...2.0,
            accelerationVariance: 0.02...0.08,
            verticalComponent: 0.2...0.4,
            stepRegularity: 0.8...1.0,
            gyroscopeVariance: 0.1...0.3,
            impactIntensity: 0.1...0.3,
            frequencyProfile: [0.1...0.3, 0.4...0.8, 0.1...0.3, 0.0...0.1]
        ),
        .trail: TerrainSignature(
            stepFrequency: 1.4...1.8,
            accelerationVariance: 0.08...0.25,
            verticalComponent: 0.3...0.7,
            stepRegularity: 0.6...0.8,
            gyroscopeVariance: 0.2...0.5,
            impactIntensity: 0.2...0.5,
            frequencyProfile: [0.2...0.4, 0.3...0.6, 0.2...0.4, 0.1...0.2]
        ),
        .gravel: TerrainSignature(
            stepFrequency: 1.3...1.7,
            accelerationVariance: 0.15...0.35,
            verticalComponent: 0.4...0.8,
            stepRegularity: 0.5...0.7,
            gyroscopeVariance: 0.3...0.6,
            impactIntensity: 0.3...0.6,
            frequencyProfile: [0.1...0.3, 0.2...0.5, 0.3...0.6, 0.2...0.4]
        ),
        .sand: TerrainSignature(
            stepFrequency: 1.0...1.4,
            accelerationVariance: 0.25...0.55,
            verticalComponent: 0.6...1.2,
            stepRegularity: 0.3...0.5,
            gyroscopeVariance: 0.4...0.8,
            impactIntensity: 0.1...0.4, // Damped by sand
            frequencyProfile: [0.3...0.6, 0.2...0.4, 0.1...0.3, 0.0...0.2]
        ),
        .mud: TerrainSignature(
            stepFrequency: 0.8...1.2,
            accelerationVariance: 0.3...0.7,
            verticalComponent: 0.5...1.0,
            stepRegularity: 0.2...0.4,
            gyroscopeVariance: 0.5...0.9,
            impactIntensity: 0.0...0.3, // Very damped
            frequencyProfile: [0.4...0.7, 0.2...0.4, 0.1...0.2, 0.0...0.1]
        ),
        .snow: TerrainSignature(
            stepFrequency: 1.1...1.5,
            accelerationVariance: 0.2...0.4,
            verticalComponent: 0.4...0.8,
            stepRegularity: 0.4...0.6,
            gyroscopeVariance: 0.3...0.6,
            impactIntensity: 0.0...0.2, // Muffled by snow
            frequencyProfile: [0.2...0.5, 0.3...0.5, 0.1...0.3, 0.0...0.1]
        ),
        .stairs: TerrainSignature(
            stepFrequency: 0.5...1.0,
            accelerationVariance: 0.4...0.8,
            verticalComponent: 0.8...1.5,
            stepRegularity: 0.2...0.4,
            gyroscopeVariance: 0.6...1.2,
            impactIntensity: 0.4...0.8,
            frequencyProfile: [0.1...0.2, 0.2...0.4, 0.3...0.6, 0.2...0.5]
        ),
        .grass: TerrainSignature(
            stepFrequency: 1.5...1.9,
            accelerationVariance: 0.06...0.18,
            verticalComponent: 0.25...0.5,
            stepRegularity: 0.7...0.9,
            gyroscopeVariance: 0.15...0.4,
            impactIntensity: 0.15...0.4,
            frequencyProfile: [0.15...0.35, 0.35...0.7, 0.15...0.35, 0.05...0.15]
        )
    ]
    
    // MARK: - Analysis Result
    
    struct MotionAnalysisResult: Sendable {
        let terrainType: TerrainType
        let confidence: Double
        let timestamp: Date
        let analysisDetails: AnalysisDetails
        
        struct AnalysisDetails: Sendable {
            let stepFrequency: Double
            let accelerationVariance: Double
            let verticalComponent: Double
            let stepRegularity: Double
            let frequencyProfile: [Double]
            let gyroscopeVariance: Double
            let impactIntensity: Double
        }
    }
    
    // MARK: - State Management
    
    private var motionSamples: [MotionSample] = []
    private var isAnalyzing: Bool = false
    private var lastAnalysisTime: Date?
    
    // MARK: - Analysis Cache
    private var cachedAnalysis: MotionAnalysisResult?
    private var cacheExpiry: Date = Date()
    
    // MARK: - Public Interface
    
    /// Adds a new motion sample to the analysis buffer
    /// - Parameters:
    ///   - accelerometer: Accelerometer data
    ///   - gyroscope: Gyroscope data
    func addMotionSample(accelerometer: CMAccelerometerData, gyroscope: CMGyroData) {
        let sample = MotionSample(accelerometer: accelerometer, gyroscope: gyroscope)
        
        motionSamples.append(sample)
        
        // Maintain sliding window
        if motionSamples.count > AnalysisConfig.windowSize {
            motionSamples.removeFirst(motionSamples.count - AnalysisConfig.windowSize + AnalysisConfig.overlappingWindow)
        }
        
        // Invalidate cache if we have new data
        if sample.timestamp > cacheExpiry {
            cachedAnalysis = nil
        }
    }
    
    /// Performs comprehensive motion pattern analysis
    /// - Returns: Analysis result with terrain prediction and confidence
    func analyzeMotionPattern() async -> MotionAnalysisResult? {
        guard motionSamples.count >= AnalysisConfig.minSamplesForAnalysis else {
            return nil
        }
        
        // Return cached result if still valid (within 1 second)
        if let cached = cachedAnalysis, cached.timestamp.addingTimeInterval(1.0) > Date() {
            return cached
        }
        
        guard !isAnalyzing else { return cachedAnalysis }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let analysisWindow = Array(motionSamples.suffix(min(AnalysisConfig.windowSize, motionSamples.count)))
        
        // Extract acceleration and rotation data for analysis
        let accelerations = analysisWindow.map { $0.acceleration }
        let rotations = analysisWindow.map { $0.rotationRate }
        let magnitudes = analysisWindow.map { $0.magnitude }
        
        // Perform comprehensive analysis
        let stepFrequency = await calculateStepFrequency(magnitudes)
        let accelerationVariance = calculateVariance(magnitudes)
        let verticalComponent = calculateVerticalComponent(accelerations)
        let stepRegularity = calculateStepRegularity(magnitudes)
        let frequencyProfile = await calculateFrequencyProfile(magnitudes)
        let gyroscopeVariance = calculateGyroscopeVariance(rotations)
        let impactIntensity = calculateImpactIntensity(accelerations)
        
        let analysisDetails = MotionAnalysisResult.AnalysisDetails(
            stepFrequency: stepFrequency,
            accelerationVariance: accelerationVariance,
            verticalComponent: verticalComponent,
            stepRegularity: stepRegularity,
            frequencyProfile: frequencyProfile,
            gyroscopeVariance: gyroscopeVariance,
            impactIntensity: impactIntensity
        )
        
        // Find best terrain match
        let (terrainType, confidence) = findBestTerrainMatch(analysisDetails)
        
        let result = MotionAnalysisResult(
            terrainType: terrainType,
            confidence: confidence,
            timestamp: Date(),
            analysisDetails: analysisDetails
        )
        
        // Cache result
        cachedAnalysis = result
        cacheExpiry = Date().addingTimeInterval(1.0)
        lastAnalysisTime = Date()
        
        return result
    }
    
    /// Gets the confidence score for motion analysis
    /// - Returns: Confidence level (0.0 to 1.0)
    func getAnalysisConfidence() -> Double {
        guard let cached = cachedAnalysis else { return 0.0 }
        
        let timeSinceAnalysis = Date().timeIntervalSince(cached.timestamp)
        let ageFacto = max(0.0, 1.0 - timeSinceAnalysis / 5.0) // Decay over 5 seconds
        
        return cached.confidence * ageFacto
    }
    
    /// Resets all motion data and analysis state
    func reset() {
        motionSamples.removeAll()
        cachedAnalysis = nil
        lastAnalysisTime = nil
        isAnalyzing = false
    }
    
    /// Gets current sample count for debugging
    var sampleCount: Int { motionSamples.count }
    
    /// Gets time since last analysis
    var timeSinceLastAnalysis: TimeInterval? {
        guard let lastTime = lastAnalysisTime else { return nil }
        return Date().timeIntervalSince(lastTime)
    }
    
    // MARK: - Analysis Implementation
    
    private func calculateStepFrequency(_ magnitudes: [Double]) async -> Double {
        guard magnitudes.count > 10 else { return 1.5 }
        
        // Use autocorrelation to find periodicity
        let autocorrelation = await calculateAutocorrelation(magnitudes)
        let peaks = findPeaks(in: autocorrelation, minDistance: 5)
        
        guard let dominantPeak = peaks.first else {
            // Fallback to simple peak counting
            return calculateSimpleStepFrequency(magnitudes)
        }
        
        let sampleRate = AnalysisConfig.sampleRate
        let frequency = sampleRate / Double(dominantPeak)
        
        // Steps per second (one peak per step)
        return max(0.5, min(3.0, frequency))
    }
    
    private func calculateSimpleStepFrequency(_ magnitudes: [Double]) -> Double {
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let threshold = mean + (magnitudes.max() ?? mean - mean) * 0.3
        
        var peaks = 0
        var lastPeak = -10
        
        for i in 1..<magnitudes.count-1 {
            if magnitudes[i] > threshold &&
               magnitudes[i] > magnitudes[i-1] &&
               magnitudes[i] > magnitudes[i+1] &&
               i - lastPeak > 5 { // Minimum distance between peaks
                peaks += 1
                lastPeak = i
            }
        }
        
        let duration = Double(magnitudes.count) / AnalysisConfig.sampleRate
        return Double(peaks) / duration
    }
    
    private func calculateAutocorrelation(_ data: [Double]) async -> [Double] {
        let n = data.count
        let mean = data.reduce(0, +) / Double(n)
        let centered = data.map { $0 - mean }
        
        var result = Array(repeating: 0.0, count: n/2)
        
        for lag in 0..<n/2 {
            var sum = 0.0
            for i in 0..<(n-lag) {
                sum += centered[i] * centered[i + lag]
            }
            result[lag] = sum / Double(n - lag)
        }
        
        // Normalize by variance
        let variance = result[0]
        return result.map { $0 / variance }
    }
    
    private func findPeaks(in data: [Double], minDistance: Int) -> [Int] {
        var peaks: [Int] = []
        
        for i in minDistance..<(data.count - minDistance) {
            var isPeak = true
            
            // Check if this is a local maximum
            for j in (i - minDistance)...(i + minDistance) {
                if j != i && data[j] >= data[i] {
                    isPeak = false
                    break
                }
            }
            
            if isPeak && data[i] > 0.1 { // Minimum correlation threshold
                peaks.append(i)
            }
        }
        
        return peaks.sorted { data[$0] > data[$1] } // Sort by peak strength
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }
    
    private func calculateVerticalComponent(_ accelerations: [SIMD3<Double>]) -> Double {
        let verticalMagnitudes = accelerations.map { abs($0.z) }
        return verticalMagnitudes.reduce(0, +) / Double(verticalMagnitudes.count)
    }
    
    private func calculateStepRegularity(_ magnitudes: [Double]) -> Double {
        guard magnitudes.count > 1 else { return 0.0 }
        
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = calculateVariance(magnitudes)
        let coefficientOfVariation = sqrt(variance) / mean
        
        // Convert to regularity score (inverse of coefficient of variation)
        return max(0.0, 1.0 / (1.0 + coefficientOfVariation))
    }
    
    private func calculateFrequencyProfile(_ magnitudes: [Double]) async -> [Double] {
        // Simple frequency analysis using FFT-like approach
        let fftSize = min(magnitudes.count, 128)
        let window = Array(magnitudes.prefix(fftSize))
        
        var profile = Array(repeating: 0.0, count: AnalysisConfig.frequencyBands.count)
        
        for (bandIndex, band) in AnalysisConfig.frequencyBands.enumerated() {
            var bandPower = 0.0
            let startFreq = band.lowerBound
            let endFreq = band.upperBound
            
            // Simple spectral analysis
            for freq in stride(from: startFreq, through: endFreq, by: 0.1) {
                let omega = 2.0 * .pi * freq / AnalysisConfig.sampleRate
                var real = 0.0
                var imag = 0.0
                
                for (i, value) in window.enumerated() {
                    let phase = omega * Double(i)
                    real += value * cos(phase)
                    imag += value * sin(phase)
                }
                
                bandPower += sqrt(real * real + imag * imag)
            }
            
            profile[bandIndex] = bandPower / Double(window.count)
        }
        
        // Normalize profile
        let totalPower = profile.reduce(0, +)
        return totalPower > 0 ? profile.map { $0 / totalPower } : profile
    }
    
    private func calculateGyroscopeVariance(_ rotations: [SIMD3<Double>]) -> Double {
        let magnitudes = rotations.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }
        return calculateVariance(magnitudes)
    }
    
    private func calculateImpactIntensity(_ accelerations: [SIMD3<Double>]) -> Double {
        // Calculate sudden acceleration changes (impact detection)
        guard accelerations.count > 1 else { return 0.0 }
        
        var impacts: [Double] = []
        for i in 1..<accelerations.count {
            let prev = accelerations[i-1]
            let curr = accelerations[i]
            let change = sqrt(
                pow(curr.x - prev.x, 2) +
                pow(curr.y - prev.y, 2) +
                pow(curr.z - prev.z, 2)
            )
            impacts.append(change)
        }
        
        return impacts.reduce(0, +) / Double(impacts.count)
    }
    
    private func findBestTerrainMatch(_ analysis: MotionAnalysisResult.AnalysisDetails) -> (TerrainType, Double) {
        var bestTerrain: TerrainType = .trail
        var bestScore: Double = 0.0
        
        for (terrain, signature) in terrainSignatures {
            let score = calculateMatchScore(analysis: analysis, signature: signature)
            if score > bestScore {
                bestScore = score
                bestTerrain = terrain
            }
        }
        
        return (bestTerrain, bestScore)
    }
    
    private func calculateMatchScore(analysis: MotionAnalysisResult.AnalysisDetails, signature: TerrainSignature) -> Double {
        // Calculate individual component scores
        let freqScore = calculateRangeScore(value: analysis.stepFrequency, range: signature.stepFrequency)
        let varianceScore = calculateRangeScore(value: analysis.accelerationVariance, range: signature.accelerationVariance)
        let verticalScore = calculateRangeScore(value: analysis.verticalComponent, range: signature.verticalComponent)
        let regularityScore = calculateRangeScore(value: analysis.stepRegularity, range: signature.stepRegularity)
        let gyroScore = calculateRangeScore(value: analysis.gyroscopeVariance, range: signature.gyroscopeVariance)
        let impactScore = calculateRangeScore(value: analysis.impactIntensity, range: signature.impactIntensity)
        
        // Calculate frequency profile score
        var frequencyScore = 0.0
        for i in 0..<min(analysis.frequencyProfile.count, signature.frequencyProfile.count) {
            frequencyScore += calculateRangeScore(value: analysis.frequencyProfile[i], range: signature.frequencyProfile[i])
        }
        frequencyScore /= Double(min(analysis.frequencyProfile.count, signature.frequencyProfile.count))
        
        // Weighted combination
        let weights: [Double] = [0.25, 0.2, 0.15, 0.15, 0.1, 0.1, 0.05] // Step freq, variance, vertical, regularity, gyro, impact, frequency
        let scores = [freqScore, varianceScore, verticalScore, regularityScore, gyroScore, impactScore, frequencyScore]
        
        return zip(weights, scores).map(*).reduce(0, +)
    }
    
    private func calculateRangeScore(value: Double, range: ClosedRange<Double>) -> Double {
        if range.contains(value) {
            // Inside range - score based on position within range
            let center = (range.lowerBound + range.upperBound) / 2
            let halfWidth = (range.upperBound - range.lowerBound) / 2
            let distance = abs(value - center)
            return max(0.0, 1.0 - distance / halfWidth)
        } else {
            // Outside range - score based on distance from nearest boundary
            let distance = min(abs(value - range.lowerBound), abs(value - range.upperBound))
            let rangeWidth = range.upperBound - range.lowerBound
            return max(0.0, 1.0 - distance / rangeWidth)
        }
    }
}

// MARK: - Debug Support

extension MotionPatternAnalyzer {
    
    /// Returns detailed debug information about the current analysis state
    func getDebugInfo() async -> String {
        let confidence = await getAnalysisConfidence()
        let timeSinceAnalysis = timeSinceLastAnalysis?.formatted(.number.precision(.fractionLength(1))) ?? "Never"
        
        return """
        === Motion Pattern Analyzer Debug ===
        Sample Count: \(sampleCount)
        Analysis Confidence: \(String(format: "%.0f", confidence * 100))%
        Time Since Last Analysis: \(timeSinceAnalysis)s
        Is Analyzing: \(isAnalyzing)
        Cache Valid: \(cachedAnalysis != nil)
        Window Size: \(AnalysisConfig.windowSize)
        Sample Rate: \(AnalysisConfig.sampleRate)Hz
        """
    }
    
    // MARK: - Public Interface
    
    /// Adds a motion sample for analysis
    func addMotionSample(accelerometer: CMAccelerometerData, gyroscope: CMGyroData) async {
        let sample = MotionSample(accelerometer: accelerometer, gyroscope: gyroscope)
        
        motionSamples.append(sample)
        
        // Maintain sliding window
        if motionSamples.count > AnalysisConfig.windowSize {
            motionSamples.removeFirst()
        }
    }
    
    /// Analyzes the current motion pattern and returns terrain classification
    func analyzeMotionPattern() async -> MotionAnalysisResult? {
        return await performAnalysis()
    }
    
    /// Gets the current number of samples
    var sampleCount: Int {
        motionSamples.count
    }
    
    /// Gets the time since last analysis
    var timeSinceLastAnalysis: TimeInterval? {
        guard let lastAnalysis = cachedAnalysis?.timestamp else { return nil }
        return Date().timeIntervalSince(lastAnalysis)
    }
    
    /// Resets the analyzer state
    func reset() async {
        motionSamples.removeAll()
        cachedAnalysis = nil
        isAnalyzing = false
    }
    
    /// Gets current analysis confidence
    func getAnalysisConfidence() async -> Double {
        return cachedAnalysis?.confidence ?? 0.0
    }
}