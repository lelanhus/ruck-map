import Foundation
import CoreLocation
import Observation

// MARK: - Watch-Optimized Calorie Calculator

/// Simplified calorie calculator optimized for Apple Watch constraints
@MainActor
@Observable
final class WatchCalorieCalculator {
    
    // MARK: - Published Properties
    private(set) var currentMetabolicRate: Double = 0.0 // kcal/min
    private(set) var totalCalories: Double = 0.0
    private(set) var isCalculating: Bool = false
    
    // MARK: - Private Properties
    private var bodyWeight: Double = 70.0 // kg
    private var loadWeight: Double = 0.0 // kg
    private var lastCalculationTime: Date?
    private var calculationTimer: Timer?
    
    // Simplified terrain multiplier (no complex terrain detection on Watch)
    private var currentTerrainMultiplier: Double = 1.2 // Default trail factor
    
    // MARK: - LCDA Algorithm Constants (simplified)
    private struct LCDAConstants {
        static let baseCoefficient: Double = 1.44
        static let linearCoefficient: Double = 1.94
        static let quadraticCoefficient: Double = 0.24
        static let minSpeedMph: Double = 0.5
        static let maxSpeedMph: Double = 6.0
    }
    
    // Simplified grade adjustments
    private let gradeAdjustments: [Double: Double] = [
        -20.0: 0.85,
        -10.0: 0.92,
        0.0: 1.00,    // Level terrain baseline
        10.0: 1.45,
        20.0: 2.10
    ]
    
    // MARK: - Public Interface
    
    /// Start calorie calculation
    func startCalculation(bodyWeight: Double, loadWeight: Double) {
        self.bodyWeight = bodyWeight
        self.loadWeight = loadWeight
        self.isCalculating = true
        self.totalCalories = 0.0
        self.lastCalculationTime = Date()
        
        // Start calculation timer (every 2 seconds for Watch)
        startCalculationTimer()
    }
    
    /// Pause calculation
    func pauseCalculation() {
        stopCalculationTimer()
        isCalculating = false
    }
    
    /// Resume calculation
    func resumeCalculation() {
        isCalculating = true
        lastCalculationTime = Date()
        startCalculationTimer()
    }
    
    /// Stop calculation
    func stopCalculation() {
        stopCalculationTimer()
        isCalculating = false
    }
    
    /// Update with new location and grade
    func updateLocation(_ location: CLLocation, grade: Double) {
        guard isCalculating else { return }
        
        let speed = max(0, location.speed) // Ensure non-negative
        let result = calculateMetabolicRate(
            speed: speed,
            grade: grade,
            altitude: location.altitude
        )
        
        currentMetabolicRate = result.metabolicRate
        
        // Update total calories based on time elapsed
        updateTotalCalories()
    }
    
    /// Reset calculator
    func reset() {
        stopCalculation()
        totalCalories = 0.0
        currentMetabolicRate = 0.0
        lastCalculationTime = nil
    }
    
    // MARK: - Private Implementation
    
    private func startCalculationTimer() {
        stopCalculationTimer()
        
        calculationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTotalCalories()
            }
        }
    }
    
    private func stopCalculationTimer() {
        calculationTimer?.invalidate()
        calculationTimer = nil
    }
    
    private func updateTotalCalories() {
        guard let lastTime = lastCalculationTime else { return }
        
        let timeDelta = Date().timeIntervalSince(lastTime) / 60.0 // Convert to minutes
        let caloriesDelta = currentMetabolicRate * timeDelta
        
        totalCalories += caloriesDelta
        lastCalculationTime = Date()
    }
    
    private func calculateMetabolicRate(speed: Double, grade: Double, altitude: Double) -> CalorieResult {
        // Convert m/s to mph
        let speedMph = speed * 2.237
        let clampedSpeed = max(LCDAConstants.minSpeedMph, min(LCDAConstants.maxSpeedMph, speedMph))
        
        // LCDA base equation: E = (1.44 + 1.94S + 0.24S²) × TotalWeight
        let energyCoefficient = LCDAConstants.baseCoefficient +
                               (LCDAConstants.linearCoefficient * clampedSpeed) +
                               (LCDAConstants.quadraticCoefficient * clampedSpeed * clampedSpeed)
        
        let totalWeight = bodyWeight + loadWeight
        let baseMetabolicRate = energyCoefficient * totalWeight
        
        // Convert from watts to kcal/min
        let baseKcalPerMin = baseMetabolicRate * 0.014340
        
        // Apply grade adjustment
        let gradeAdjustment = calculateGradeAdjustment(grade)
        
        // Apply environmental factors (simplified for Watch)
        let environmentalFactor = calculateEnvironmentalFactor(altitude: altitude)
        
        // Apply terrain multiplier
        let finalMetabolicRate = baseKcalPerMin * gradeAdjustment * environmentalFactor * currentTerrainMultiplier
        
        return CalorieResult(
            metabolicRate: finalMetabolicRate,
            gradeAdjustment: gradeAdjustment,
            environmentalFactor: environmentalFactor,
            terrainFactor: currentTerrainMultiplier
        )
    }
    
    private func calculateGradeAdjustment(_ grade: Double) -> Double {
        let clampedGrade = max(-20.0, min(20.0, grade))
        
        // Find surrounding grade points for interpolation
        let sortedGrades = gradeAdjustments.keys.sorted()
        
        // If exact match exists, return it
        if let exactFactor = gradeAdjustments[clampedGrade] {
            return exactFactor
        }
        
        // Linear interpolation between adjacent points
        var lowerGrade: Double = -20.0
        var upperGrade: Double = 20.0
        
        for gradePoint in sortedGrades {
            if gradePoint <= clampedGrade {
                lowerGrade = gradePoint
            }
            if gradePoint >= clampedGrade && upperGrade == 20.0 {
                upperGrade = gradePoint
            }
        }
        
        let lowerFactor = gradeAdjustments[lowerGrade] ?? 1.0
        let upperFactor = gradeAdjustments[upperGrade] ?? 1.0
        
        if upperGrade == lowerGrade {
            return lowerFactor
        }
        
        let interpolationRatio = (clampedGrade - lowerGrade) / (upperGrade - lowerGrade)
        return lowerFactor + interpolationRatio * (upperFactor - lowerFactor)
    }
    
    private func calculateEnvironmentalFactor(altitude: Double) -> Double {
        // Simplified environmental factor for Watch
        // Altitude factor: 10% VO2max reduction per 1000m above sea level
        let altitudeFactor = 1.0 + max(0, altitude / 1000.0) * 0.10
        
        // Temperature factor (assuming moderate conditions on Watch)
        let temperatureFactor = 1.05
        
        return altitudeFactor * temperatureFactor
    }
    
    /// Update terrain multiplier based on simple heuristics
    func updateTerrainMultiplier(for grade: Double) {
        // Simple terrain estimation based on grade
        if abs(grade) > 15 {
            currentTerrainMultiplier = 1.8 // Steep terrain
        } else if abs(grade) > 8 {
            currentTerrainMultiplier = 1.4 // Moderate terrain
        } else {
            currentTerrainMultiplier = 1.2 // Trail terrain
        }
    }
}

// MARK: - Supporting Types

private struct CalorieResult {
    let metabolicRate: Double
    let gradeAdjustment: Double
    let environmentalFactor: Double
    let terrainFactor: Double
}