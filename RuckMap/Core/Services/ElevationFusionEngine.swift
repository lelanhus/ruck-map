import Foundation
import CoreLocation

/// Actor-based elevation fusion engine using Kalman filtering for optimal sensor fusion
actor ElevationFusionEngine {
    
    // MARK: - Kalman Filter State
    private var state: Double = 0.0              // Current altitude estimate (meters)
    private var covariance: Double = 1000.0      // Uncertainty in current estimate
    private var processNoise: Double = 0.05      // Process noise (system uncertainty)
    private var measurementNoise: Double = 0.2   // Measurement noise (sensor uncertainty)
    
    // MARK: - Sensor Fusion Properties
    private var lastBarometricUpdate: Date?
    private var lastGPSUpdate: Date?
    private var lastPressureReading: Double?
    private var calibrationOffset: Double = 0.0
    
    // MARK: - Stability Tracking
    private var recentMeasurements: [Double] = []
    private let maxMeasurements = 10
    private var _stabilityFactor: Double = 0.0
    
    // MARK: - Configuration
    private var configuration: ElevationConfiguration
    
    // MARK: - GPS Altitude Tracking
    private struct GPSMeasurement {
        let altitude: Double
        let accuracy: Double
        let timestamp: Date
        let weight: Double
    }
    
    private var recentGPSMeasurements: [GPSMeasurement] = []
    private let maxGPSMeasurements = 5
    
    // MARK: - Initialization
    init(configuration: ElevationConfiguration) {
        self.configuration = configuration
        self.processNoise = configuration.kalmanProcessNoise
        self.measurementNoise = configuration.kalmanMeasurementNoise
    }
    
    // MARK: - Public Interface
    
    /// Updates the Kalman filter configuration
    func updateConfiguration(_ newConfiguration: ElevationConfiguration) {
        configuration = newConfiguration
        processNoise = newConfiguration.kalmanProcessNoise
        measurementNoise = newConfiguration.kalmanMeasurementNoise
    }
    
    /// Calibrates the fusion engine with a known elevation reference
    func calibrate(knownElevation: Double, pressureReading: Double) {
        state = knownElevation
        calibrationOffset = knownElevation
        covariance = 1.0 // High confidence after calibration
        lastPressureReading = pressureReading
        recentMeasurements.removeAll()
        _stabilityFactor = 1.0
    }
    
    /// Processes a new barometric altitude measurement through the Kalman filter
    func processMeasurement(
        barometricAltitude: Double,
        pressure: Double,
        timestamp: Date
    ) -> Double {
        
        // Apply time-based prediction step
        if let lastUpdate = lastBarometricUpdate {
            let deltaTime = timestamp.timeIntervalSince(lastUpdate)
            applyTimeUpdate(deltaTime: deltaTime)
        }
        
        // Determine measurement noise based on pressure stability
        let adaptiveMeasurementNoise = calculateAdaptiveMeasurementNoise(pressure: pressure)
        
        // Apply Kalman filter measurement update
        let filteredAltitude = kalmanUpdate(
            measurement: barometricAltitude,
            measurementNoise: adaptiveMeasurementNoise
        )
        
        // Update tracking variables
        lastBarometricUpdate = timestamp
        lastPressureReading = pressure
        
        // Update stability tracking
        updateStabilityTracking(measurement: filteredAltitude)
        
        return filteredAltitude
    }
    
    /// Updates GPS altitude for sensor fusion weighting
    func updateGPSAltitude(_ gpsAltitude: Double, accuracy: Double, timestamp: Date) {
        // Calculate weight based on GPS accuracy (better accuracy = higher weight)
        let weight = max(0.1, min(1.0, 10.0 / accuracy))
        
        let gpsMeasurement = GPSMeasurement(
            altitude: gpsAltitude,
            accuracy: accuracy,
            timestamp: timestamp,
            weight: weight
        )
        
        // Add to recent measurements
        recentGPSMeasurements.append(gpsMeasurement)
        if recentGPSMeasurements.count > maxGPSMeasurements {
            recentGPSMeasurements.removeFirst()
        }
        
        lastGPSUpdate = timestamp
        
        // Apply GPS-based correction if GPS is significantly more accurate
        if accuracy <= 5.0 && recentGPSMeasurements.count >= 3 {
            applyGPSCorrection(gpsAltitude, weight: weight)
        }
    }
    
    /// Returns the current stability factor (0.0 to 1.0)
    var stabilityFactor: Double {
        _stabilityFactor
    }
    
    /// Returns current fused altitude estimate
    var currentAltitude: Double {
        state
    }
    
    /// Returns current estimate uncertainty
    var uncertainty: Double {
        sqrt(covariance)
    }
    
    // MARK: - Private Kalman Filter Implementation
    
    private func applyTimeUpdate(deltaTime: TimeInterval) {
        // Predict step: state remains the same (assuming constant altitude)
        // Covariance increases with time due to process noise
        covariance += processNoise * deltaTime
    }
    
    private func kalmanUpdate(measurement: Double, measurementNoise: Double) -> Double {
        // Calculate Kalman gain
        let kalmanGain = covariance / (covariance + measurementNoise)
        
        // Update state estimate
        state = state + kalmanGain * (measurement - state)
        
        // Update covariance
        covariance = (1.0 - kalmanGain) * covariance
        
        return state
    }
    
    private func calculateAdaptiveMeasurementNoise(pressure: Double) -> Double {
        var adaptiveNoise = measurementNoise
        
        // Increase noise if pressure is changing rapidly (weather front)
        if let lastPressure = lastPressureReading {
            let pressureChange = abs(pressure - lastPressure)
            if pressureChange > 0.5 { // Significant pressure change
                adaptiveNoise *= (1.0 + pressureChange)
            }
        }
        
        // Reduce noise if measurements are stable
        if _stabilityFactor > 0.8 {
            adaptiveNoise *= (2.0 - _stabilityFactor)
        }
        
        return max(0.01, adaptiveNoise)
    }
    
    private func applyGPSCorrection(_ gpsAltitude: Double, weight: Double) {
        // Calculate weighted average of recent GPS readings
        let totalWeight = recentGPSMeasurements.reduce(0) { $0 + $1.weight }
        let weightedSum = recentGPSMeasurements.reduce(0) { $0 + $1.altitude * $1.weight }
        let averageGPSAltitude = weightedSum / totalWeight
        
        // Apply correction if GPS significantly disagrees with barometric
        let altitudeDifference = abs(averageGPSAltitude - state)
        
        if altitudeDifference > 5.0 && weight > 0.7 {
            // Gradually adjust state towards GPS reading
            let correctionFactor = min(0.2, weight * 0.3)
            state = state + correctionFactor * (averageGPSAltitude - state)
            
            // Increase uncertainty to reflect the correction
            covariance += altitudeDifference * 0.1
        }
    }
    
    private func updateStabilityTracking(measurement: Double) {
        recentMeasurements.append(measurement)
        if recentMeasurements.count > maxMeasurements {
            recentMeasurements.removeFirst()
        }
        
        // Calculate stability based on measurement consistency
        if recentMeasurements.count >= 5 {
            let recent = Array(recentMeasurements.suffix(5))
            let average = recent.reduce(0, +) / Double(recent.count)
            let variance = recent.map { pow($0 - average, 2) }.reduce(0, +) / Double(recent.count)
            let standardDeviation = sqrt(variance)
            
            // Stability factor inversely related to standard deviation
            _stabilityFactor = max(0.0, min(1.0, 1.0 - (standardDeviation / 5.0)))
        } else {
            _stabilityFactor = 0.5 // Neutral stability with insufficient data
        }
    }
    
    // MARK: - Advanced Sensor Fusion
    
    /// Detects and corrects for systematic barometric drift
    private func detectBarometricDrift() -> Double? {
        guard recentGPSMeasurements.count >= 3,
              let lastGPS = recentGPSMeasurements.last,
              lastGPS.accuracy <= 10.0 else { return nil }
        
        // Calculate trend in GPS vs barometric difference
        let differences = recentGPSMeasurements.suffix(3).map { $0.altitude - state }
        
        if differences.count >= 3 {
            let avgDifference = differences.reduce(0, +) / Double(differences.count)
            
            // If there's a consistent bias > 3 meters, return correction
            if abs(avgDifference) > 3.0 {
                return avgDifference * 0.1 // Apply 10% of the detected drift
            }
        }
        
        return nil
    }
    
    /// Applies environmental corrections for barometric pressure
    private func applyEnvironmentalCorrections(
        pressure: Double,
        temperature: Double? = nil
    ) -> Double {
        var correctedPressure = pressure
        
        // Apply temperature correction if available
        if let temp = temperature {
            let tempCorrectionFactor = 1.0 + (temp - 15.0) * 0.004 / 100.0
            correctedPressure *= tempCorrectionFactor
        }
        
        // Apply sea level pressure correction for long-term stability
        let seaLevelPressure = 101.325 // Standard sea level pressure in kPa
        let pressureDeviation = pressure - seaLevelPressure
        
        // If pressure deviates significantly from standard, apply gradual correction
        if abs(pressureDeviation) > 5.0 {
            let correctionFactor = 1.0 - (pressureDeviation / 1000.0)
            correctedPressure *= correctionFactor
        }
        
        return correctedPressure
    }
    
    // MARK: - Quality Assessment
    
    /// Assesses the quality of the current fusion state
    func assessFusionQuality() -> (quality: Double, factors: [String: Double]) {
        var quality: Double = 1.0
        var factors: [String: Double] = [:]
        
        // Factor 1: Measurement stability
        factors["stability"] = _stabilityFactor
        quality *= (0.5 + 0.5 * _stabilityFactor)
        
        // Factor 2: GPS agreement (if available)
        if let lastGPS = recentGPSMeasurements.last,
           lastGPS.accuracy <= 20.0 {
            let agreement = max(0.0, 1.0 - abs(lastGPS.altitude - state) / 20.0)
            factors["gps_agreement"] = agreement
            quality *= (0.7 + 0.3 * agreement)
        } else {
            factors["gps_agreement"] = 0.5 // Neutral when GPS unavailable
        }
        
        // Factor 3: Estimation uncertainty
        let uncertaintyFactor = max(0.0, 1.0 - uncertainty / 10.0)
        factors["uncertainty"] = uncertaintyFactor
        quality *= (0.6 + 0.4 * uncertaintyFactor)
        
        // Factor 4: Data recency
        let recencyFactor: Double
        if let lastUpdate = lastBarometricUpdate {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            recencyFactor = max(0.0, 1.0 - timeSinceUpdate / 60.0) // Decay over 1 minute
        } else {
            recencyFactor = 0.0
        }
        factors["recency"] = recencyFactor
        quality *= (0.8 + 0.2 * recencyFactor)
        
        return (min(1.0, max(0.0, quality)), factors)
    }
    
    // MARK: - Debug Information
    
    var debugInfo: String {
        let (quality, factors) = assessFusionQuality()
        
        return """
        Elevation Fusion Engine Debug:
        - Current State: \(state.formatted(.number.precision(.fractionLength(2)))) m
        - Uncertainty: ±\(uncertainty.formatted(.number.precision(.fractionLength(2)))) m
        - Stability Factor: \(_stabilityFactor.formatted(.number.precision(.fractionLength(2))))
        - Fusion Quality: \(quality.formatted(.number.precision(.fractionLength(2))))
        - Process Noise: \(processNoise)
        - Measurement Noise: \(measurementNoise)
        - Recent Measurements: \(recentMeasurements.count)
        - GPS Measurements: \(recentGPSMeasurements.count)
        - Quality Factors: \(factors.map { "\($0.key): \($0.value.formatted(.number.precision(.fractionLength(2))))" }.joined(separator: ", "))
        """
    }
}

// MARK: - Kalman Filter Mathematics Extensions
extension ElevationFusionEngine {
    
    /// Advanced Kalman filter with dynamic noise adaptation
    private func adaptiveKalmanUpdate(
        measurement: Double,
        baseMeasurementNoise: Double,
        dynamicFactors: [String: Double]
    ) -> Double {
        
        // Adapt measurement noise based on dynamic factors
        var adaptedNoise = baseMeasurementNoise
        
        // Increase noise during rapid altitude changes
        if let altitudeRate = dynamicFactors["altitude_rate"] {
            adaptedNoise *= (1.0 + abs(altitudeRate) * 0.1)
        }
        
        // Increase noise during low GPS accuracy
        if let gpsAccuracy = dynamicFactors["gps_accuracy"] {
            if gpsAccuracy > 20.0 {
                adaptedNoise *= (1.0 + (gpsAccuracy - 20.0) / 50.0)
            }
        }
        
        // Reduce noise during stable conditions
        if _stabilityFactor > 0.8 {
            adaptedNoise *= (2.0 - _stabilityFactor)
        }
        
        return kalmanUpdate(measurement: measurement, measurementNoise: adaptedNoise)
    }
    
    /// Implements extended Kalman filter for non-linear altitude estimation
    private func extendedKalmanUpdate(
        measurement: Double,
        pressureAltitudeModel: (Double) -> Double
    ) -> Double {
        
        // For barometric altitude, the relationship is approximately linear
        // in the altitude ranges we're interested in (0-3000m typical hiking)
        // So we can use the standard Kalman filter
        
        // However, if we need to account for non-linear pressure-altitude relationship:
        // h = 44330 * (1 - (P/P0)^0.1903)
        // We would implement the extended Kalman filter here
        
        return kalmanUpdate(measurement: measurement, measurementNoise: measurementNoise)
    }
}