//
//  GradeCalculator.swift
//  RuckMap
//
//  Created by Leland Husband on 8/2/25.
//

import Foundation
import CoreLocation

/// Thread-safe actor for calculating grade/slope percentages with high precision
/// Achieves 0.5% precision target for grade calculations
actor GradeCalculator {
    
    // MARK: - Types
    
    struct Configuration: Sendable {
        let minDistanceForGrade: Double // meters
        let minElevationChange: Double // meters
        let smoothingWindowSize: Int
        let maxGradePercent: Double
        let gradeNoiseThreshold: Double // meters of elevation change
        
        static let precise = Configuration(
            minDistanceForGrade: 5.0,
            minElevationChange: 0.1,
            smoothingWindowSize: 5,
            maxGradePercent: 100.0,
            gradeNoiseThreshold: 0.5
        )
        
        static let balanced = Configuration(
            minDistanceForGrade: 10.0,
            minElevationChange: 0.25,
            smoothingWindowSize: 3,
            maxGradePercent: 50.0,
            gradeNoiseThreshold: 1.0
        )
        
        static let fast = Configuration(
            minDistanceForGrade: 20.0,
            minElevationChange: 0.5,
            smoothingWindowSize: 1,
            maxGradePercent: 30.0,
            gradeNoiseThreshold: 2.0
        )
    }
    
    struct GradeResult: Sendable {
        let instantGrade: Double // percentage
        let smoothedGrade: Double // percentage
        let confidence: Double // 0-1
        let distance: Double // meters
        let elevationChange: Double // meters
        let timestamp: Date
    }
    
    struct GradeMultiplier: Sendable {
        let grade: Double
        let metabolicMultiplier: Double
        let mechanicalMultiplier: Double
        
        static func calculate(for grade: Double) -> GradeMultiplier {
            // Based on Minetti et al. (2002) and Pandolf equation adjustments
            let clampedGrade = max(-20, min(20, grade))
            
            // Metabolic cost multiplier
            let metabolic: Double
            switch clampedGrade {
            case ..<(-10):
                metabolic = 0.85 + (clampedGrade + 20) * 0.007
            case -10..<0:
                metabolic = 0.92 + clampedGrade * 0.008
            case 0..<10:
                metabolic = 1.0 + clampedGrade * 0.045
            default:
                metabolic = 1.45 + (clampedGrade - 10) * 0.065
            }
            
            // Mechanical work multiplier (eccentric vs concentric)
            let mechanical = clampedGrade < 0 ? 0.7 : 1.0
            
            return GradeMultiplier(
                grade: clampedGrade,
                metabolicMultiplier: metabolic,
                mechanicalMultiplier: mechanical
            )
        }
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private var recentGrades: [GradeResult] = []
    private let maxHistorySize = 100
    
    // Elevation tracking for gain/loss
    private var lastValidElevation: Double?
    private var cumulativeGain: Double = 0
    private var cumulativeLoss: Double = 0
    
    // MARK: - Computed Properties
    
    var elevationMetrics: (gain: Double, loss: Double) {
        (cumulativeGain, cumulativeLoss)
    }
    
    // MARK: - Initialization
    
    init(configuration: Configuration = .balanced) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Calculate grade between two points
    func calculateGrade(
        from start: CLLocation,
        to end: CLLocation,
        startElevation: Double? = nil,
        endElevation: Double? = nil
    ) -> GradeResult {
        
        // Use provided elevations or fall back to GPS
        let startElev = startElevation ?? start.altitude
        let endElev = endElevation ?? end.altitude
        
        // Calculate horizontal distance
        let distance = start.distance(from: end)
        
        // Check minimum distance requirement
        guard distance >= configuration.minDistanceForGrade else {
            return GradeResult(
                instantGrade: 0,
                smoothedGrade: getSmoothedGrade(),
                confidence: 0,
                distance: distance,
                elevationChange: 0,
                timestamp: end.timestamp
            )
        }
        
        // Calculate elevation change
        let elevationChange = endElev - startElev
        
        // Check minimum elevation change (noise filter)
        guard abs(elevationChange) >= configuration.minElevationChange else {
            return GradeResult(
                instantGrade: 0,
                smoothedGrade: getSmoothedGrade(),
                confidence: calculateConfidence(distance: distance, elevationAccuracy: end.verticalAccuracy),
                distance: distance,
                elevationChange: 0,
                timestamp: end.timestamp
            )
        }
        
        // Calculate grade percentage with 0.5% precision
        let gradePercent = (elevationChange / distance) * 100.0
        let clampedGrade = max(-configuration.maxGradePercent, min(configuration.maxGradePercent, gradePercent))
        let roundedGrade = round(clampedGrade * 2) / 2 // 0.5% precision
        
        // Calculate confidence based on GPS accuracy and distance
        let confidence = calculateConfidence(
            distance: distance,
            elevationAccuracy: max(start.verticalAccuracy, end.verticalAccuracy)
        )
        
        // Create result
        let result = GradeResult(
            instantGrade: roundedGrade,
            smoothedGrade: 0, // Will be updated below
            confidence: confidence,
            distance: distance,
            elevationChange: elevationChange,
            timestamp: end.timestamp
        )
        
        // Add to history
        addToHistory(result)
        
        // Update with smoothed grade
        return GradeResult(
            instantGrade: result.instantGrade,
            smoothedGrade: getSmoothedGrade(),
            confidence: result.confidence,
            distance: result.distance,
            elevationChange: result.elevationChange,
            timestamp: result.timestamp
        )
    }
    
    /// Update elevation gain/loss tracking
    func updateElevationMetrics(newElevation: Double, confidence: Double) {
        guard confidence > 0.5 else { return } // Require reasonable confidence
        
        if let lastElev = lastValidElevation {
            let change = newElevation - lastElev
            
            // Apply noise threshold
            if abs(change) >= configuration.gradeNoiseThreshold {
                if change > 0 {
                    cumulativeGain += change
                } else {
                    cumulativeLoss += abs(change)
                }
                lastValidElevation = newElevation
            }
        } else {
            lastValidElevation = newElevation
        }
    }
    
    /// Calculate grade between location points with elevation data
    func calculateGrade(from start: LocationPoint, to end: LocationPoint) -> GradeResult {
        let startLocation = CLLocation(
            latitude: start.latitude,
            longitude: start.longitude
        )
        let endLocation = CLLocation(
            latitude: end.latitude,
            longitude: end.longitude
        )
        
        // Prefer fused elevation if available
        let startElev = start.barometricAltitude ?? start.altitude
        let endElev = end.barometricAltitude ?? end.altitude
        
        return calculateGrade(
            from: startLocation,
            to: endLocation,
            startElevation: startElev,
            endElevation: endElev
        )
    }
    
    /// Get current smoothed grade
    func getSmoothedGrade() -> Double {
        guard !recentGrades.isEmpty else { return 0 }
        
        let windowSize = min(configuration.smoothingWindowSize, recentGrades.count)
        let recentWindow = recentGrades.suffix(windowSize)
        
        // Weight by confidence and distance
        var totalWeight: Double = 0
        var weightedSum: Double = 0
        
        for (index, grade) in recentWindow.enumerated() {
            let recencyWeight = Double(index + 1) / Double(windowSize)
            let weight = grade.confidence * grade.distance * recencyWeight
            weightedSum += grade.instantGrade * weight
            totalWeight += weight
        }
        
        guard totalWeight > 0 else { return 0 }
        
        let smoothedGrade = weightedSum / totalWeight
        return round(smoothedGrade * 2) / 2 // 0.5% precision
    }
    
    /// Get grade multiplier for calorie calculations
    func getGradeMultiplier(for grade: Double) -> GradeMultiplier {
        return GradeMultiplier.calculate(for: grade)
    }
    
    /// Reset calculator state
    func reset() {
        recentGrades.removeAll()
        lastValidElevation = nil
        cumulativeGain = 0
        cumulativeLoss = 0
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ grade: GradeResult) {
        recentGrades.append(grade)
        
        // Maintain bounded history
        if recentGrades.count > maxHistorySize {
            recentGrades.removeFirst(recentGrades.count - maxHistorySize)
        }
    }
    
    private func calculateConfidence(distance: Double, elevationAccuracy: Double) -> Double {
        // Base confidence on distance (longer = more accurate grade)
        let distanceConfidence = min(1.0, distance / 50.0)
        
        // Adjust for elevation accuracy
        let accuracyConfidence: Double
        if elevationAccuracy < 0 {
            accuracyConfidence = 0.5 // Unknown accuracy
        } else if elevationAccuracy <= 1 {
            accuracyConfidence = 1.0
        } else if elevationAccuracy <= 5 {
            accuracyConfidence = 0.8
        } else if elevationAccuracy <= 10 {
            accuracyConfidence = 0.6
        } else {
            accuracyConfidence = 0.3
        }
        
        return distanceConfidence * accuracyConfidence
    }
}

// MARK: - Extensions

extension GradeCalculator {
    /// Calculate average grade over a series of points
    func calculateAverageGrade(for points: [LocationPoint]) async -> (grade: Double, confidence: Double) {
        guard points.count >= 2 else { return (0, 0) }
        
        var totalDistance: Double = 0
        var totalElevationChange: Double = 0
        var totalConfidence: Double = 0
        var validSegments = 0
        
        for i in 0..<(points.count - 1) {
            let result = calculateGrade(from: points[i], to: points[i + 1])
            
            if result.confidence > 0.5 {
                totalDistance += result.distance
                totalElevationChange += result.elevationChange
                totalConfidence += result.confidence
                validSegments += 1
            }
        }
        
        guard validSegments > 0 && totalDistance >= configuration.minDistanceForGrade else {
            return (0, 0)
        }
        
        let averageGrade = (totalElevationChange / totalDistance) * 100.0
        let averageConfidence = totalConfidence / Double(validSegments)
        
        return (round(averageGrade * 2) / 2, averageConfidence)
    }
    
    /// Get grade statistics for analysis
    func getGradeStatistics() -> (min: Double, max: Double, average: Double, variance: Double) {
        guard !recentGrades.isEmpty else { return (0, 0, 0, 0) }
        
        let grades = recentGrades.map { $0.instantGrade }
        let min = grades.min() ?? 0
        let max = grades.max() ?? 0
        let average = grades.reduce(0, +) / Double(grades.count)
        
        let variance = grades.reduce(0) { sum, grade in
            sum + pow(grade - average, 2)
        } / Double(grades.count)
        
        return (min, max, average, variance)
    }
}