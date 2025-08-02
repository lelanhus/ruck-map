import Foundation
import CoreLocation
import Observation

// MARK: - Terrain Multipliers
/// Terrain difficulty multipliers based on military load carriage studies
enum TerrainDifficultyMultiplier: Double, CaseIterable, Sendable {
    case pavement = 1.0
    case trail = 1.2
    case gravel = 1.3
    case sand = 1.8
    case mud = 1.85
    case snow = 1.5
    case grass = 1.25
    case stairs = 2.0
    
    init(from terrainType: TerrainType) {
        switch terrainType {
        case .pavedRoad:
            self = .pavement
        case .trail:
            self = .trail
        case .gravel:
            self = .gravel
        case .sand:
            self = .sand
        case .mud:
            self = .mud
        case .snow:
            self = .snow
        case .grass:
            self = .grass
        case .stairs:
            self = .stairs
        }
    }
}

// MARK: - Weather Data
/// Lightweight weather data for calorie calculations
struct WeatherData: Sendable {
    let temperature: Double  // Celsius
    let windSpeed: Double   // m/s
    let humidity: Double    // percentage
    
    init(temperature: Double, windSpeed: Double = 0, humidity: Double = 50) {
        self.temperature = temperature
        self.windSpeed = windSpeed
        self.humidity = humidity
    }
    
    init?(from conditions: WeatherConditions?) {
        guard let conditions = conditions else { return nil }
        self.temperature = conditions.temperature
        self.windSpeed = conditions.windSpeed
        self.humidity = conditions.humidity
    }
}

// MARK: - Calculation Input Parameters
/// Environmental and physiological parameters for calorie calculation
struct CalorieCalculationParameters: Sendable {
    let bodyWeight: Double           // kg
    let loadWeight: Double          // kg (pack + equipment)
    let speed: Double               // m/s
    let grade: Double               // percentage (-20 to +20)
    let temperature: Double         // Celsius
    let altitude: Double            // meters above sea level
    let windSpeed: Double           // m/s
    let terrainMultiplier: Double   // terrain difficulty factor
    let timestamp: Date
    
    /// Total weight carried (body + load)
    var totalWeight: Double {
        bodyWeight + loadWeight
    }
    
    /// Speed in mph for LCDA formula
    var speedMph: Double {
        speed * 2.237 // m/s to mph conversion
    }
    
    /// Validates that parameters are within acceptable ranges
    func validate() throws {
        guard bodyWeight > 30 && bodyWeight < 200 else {
            throw CalorieCalculationError.invalidBodyWeight(bodyWeight)
        }
        
        guard loadWeight >= 0 && loadWeight <= 100 else {
            throw CalorieCalculationError.invalidLoadWeight(loadWeight)
        }
        
        guard speed >= 0 && speed <= 3.0 else { // ~6.7 mph max
            throw CalorieCalculationError.invalidSpeed(speed)
        }
        
        guard grade >= -25 && grade <= 30 else {
            throw CalorieCalculationError.invalidGrade(grade)
        }
    }
}

// MARK: - Calculation Result
/// Comprehensive calorie calculation result with confidence metrics
struct CalorieCalculationResult: Sendable {
    let metabolicRate: Double       // kcal/min
    let totalCalories: Double       // kcal (cumulative)
    let confidenceInterval: ClosedRange<Double> // ±10% accuracy range
    let gradeAdjustmentFactor: Double
    let environmentalFactor: Double
    let terrainFactor: Double
    let altitude: Double
    let timestamp: Date
    
    /// Lower bound of confidence interval
    var lowerBound: Double {
        confidenceInterval.lowerBound
    }
    
    /// Upper bound of confidence interval
    var upperBound: Double {
        confidenceInterval.upperBound
    }
    
    /// Confidence range as percentage
    var confidenceRangePercent: Double {
        ((upperBound - lowerBound) / metabolicRate) * 100
    }
}

// MARK: - Calculation Errors
enum CalorieCalculationError: LocalizedError, Sendable {
    case invalidBodyWeight(Double)
    case invalidLoadWeight(Double)
    case invalidSpeed(Double)
    case invalidGrade(Double)
    case calculationOverflow
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .invalidBodyWeight(let weight):
            return "Invalid body weight: \(weight) kg. Must be between 30-200 kg."
        case .invalidLoadWeight(let weight):
            return "Invalid load weight: \(weight) kg. Must be between 0-100 kg."
        case .invalidSpeed(let speed):
            return "Invalid speed: \(speed) m/s. Must be between 0-3.0 m/s."
        case .invalidGrade(let grade):
            return "Invalid grade: \(grade)%. Must be between -25% to +30%."
        case .calculationOverflow:
            return "Calculation resulted in overflow."
        case .insufficientData:
            return "Insufficient data for accurate calculation."
        }
    }
}

// MARK: - Military-Grade LCDA Calorie Calculator
/// Actor-based calorie calculator implementing the Load Carriage Decision Aid (LCDA) algorithm
/// Used by US Army for military load carriage energy expenditure predictions
@MainActor
@Observable
final class CalorieCalculator {
    
    // MARK: - Observable Properties
    private(set) var currentMetabolicRate: Double = 0.0 // kcal/min
    private(set) var totalCalories: Double = 0.0 // kcal
    private(set) var lastCalculationResult: CalorieCalculationResult?
    private(set) var isCalculating: Bool = false
    
    // MARK: - Private Properties
    private var calculationHistory: [CalorieCalculationResult] = []
    private let maxHistorySize: Int = 1000
    private var lastCalculationTime: Date?
    private var calculationTask: Task<Void, Never>?
    
    // MARK: - LCDA Algorithm Constants
    private struct LCDAConstants {
        static let baseCoefficient: Double = 1.44
        static let linearCoefficient: Double = 1.94
        static let quadraticCoefficient: Double = 0.24
        static let minSpeedMph: Double = 0.5
        static let maxSpeedMph: Double = 6.0
        static let confidenceInterval: Double = 0.10 // ±10%
    }
    
    // MARK: - Grade Adjustment Lookup Table
    private let gradeAdjustments: [Double: Double] = [
        -20.0: 0.85,  // Downhill, eccentric loading
        -15.0: 0.89,
        -10.0: 0.92,  // Slight downhill
        -5.0: 0.96,
        0.0: 1.00,    // Level terrain (baseline)
        5.0: 1.20,
        10.0: 1.45,   // Moderate uphill
        15.0: 1.75,
        20.0: 2.10    // Steep uphill
    ]
    
    // MARK: - Initialization
    init() {
        // Initialize with default values
    }
    
    deinit {
        Task { @MainActor in
            calculationTask?.cancel()
        }
    }
    
    // MARK: - Public Interface
    
    /// Calculates calorie burn rate and updates total calories
    /// - Parameter parameters: Environmental and physiological parameters
    /// - Returns: Calculation result with metabolic rate and confidence intervals
    func calculateCalories(with parameters: CalorieCalculationParameters) async throws -> CalorieCalculationResult {
        isCalculating = true
        defer { isCalculating = false }
        
        // Validate input parameters
        try parameters.validate()
        
        // Calculate time delta for total calorie accumulation
        let timeDelta = calculateTimeDelta(parameters.timestamp)
        
        // Apply LCDA base algorithm
        let baseMetabolicRate = try calculateLCDABaseRate(parameters)
        
        // Apply environmental adjustments
        let environmentalFactor = calculateEnvironmentalFactor(
            temperature: parameters.temperature,
            altitude: parameters.altitude,
            windSpeed: parameters.windSpeed
        )
        
        // Apply grade adjustment
        let gradeAdjustmentFactor = calculateGradeAdjustment(parameters.grade)
        
        // Apply terrain multiplier
        let terrainFactor = parameters.terrainMultiplier
        
        // Calculate final metabolic rate
        let adjustedMetabolicRate = baseMetabolicRate * gradeAdjustmentFactor * environmentalFactor * terrainFactor
        
        // Calculate confidence interval (±10% as per LCDA specifications)
        let confidenceRange = adjustedMetabolicRate * LCDAConstants.confidenceInterval
        let confidenceInterval = (adjustedMetabolicRate - confidenceRange)...(adjustedMetabolicRate + confidenceRange)
        
        // Update total calories based on time elapsed
        let caloriesDelta = adjustedMetabolicRate * timeDelta
        totalCalories += caloriesDelta
        
        // Create result
        let result = CalorieCalculationResult(
            metabolicRate: adjustedMetabolicRate,
            totalCalories: totalCalories,
            confidenceInterval: confidenceInterval,
            gradeAdjustmentFactor: gradeAdjustmentFactor,
            environmentalFactor: environmentalFactor,
            terrainFactor: terrainFactor,
            altitude: parameters.altitude,
            timestamp: parameters.timestamp
        )
        
        // Update published properties
        currentMetabolicRate = adjustedMetabolicRate
        lastCalculationResult = result
        lastCalculationTime = parameters.timestamp
        
        // Add to history
        addToHistory(result)
        
        return result
    }
    
    /// Resets the calculator state
    func reset() {
        totalCalories = 0.0
        currentMetabolicRate = 0.0
        lastCalculationResult = nil
        lastCalculationTime = nil
        calculationHistory.removeAll()
    }
    
    /// Gets calculation history for analysis
    func getCalculationHistory() -> [CalorieCalculationResult] {
        return calculationHistory
    }
    
    /// Gets average metabolic rate over recent period
    func getAverageMetabolicRate(overLastMinutes minutes: Double = 5.0) -> Double {
        let cutoffTime = Date().addingTimeInterval(-minutes * 60)
        let recentResults = calculationHistory.filter { $0.timestamp >= cutoffTime }
        
        guard !recentResults.isEmpty else { return 0.0 }
        
        let totalRate = recentResults.reduce(0) { $0 + $1.metabolicRate }
        return totalRate / Double(recentResults.count)
    }
    
    // MARK: - Private Implementation
    
    /// Implements the core LCDA walking equation: E = (1.44 + 1.94S + 0.24S²) × BW
    private func calculateLCDABaseRate(_ parameters: CalorieCalculationParameters) throws -> Double {
        let speedMph = parameters.speedMph
        
        // Clamp speed to valid LCDA range (0.5-6.0 mph)
        let clampedSpeed = max(LCDAConstants.minSpeedMph, min(LCDAConstants.maxSpeedMph, speedMph))
        
        // LCDA equation: E = (1.44 + 1.94S + 0.24S²) × BW
        let energyCoefficient = LCDAConstants.baseCoefficient +
                               (LCDAConstants.linearCoefficient * clampedSpeed) +
                               (LCDAConstants.quadraticCoefficient * clampedSpeed * clampedSpeed)
        
        let metabolicRate = energyCoefficient * parameters.totalWeight
        
        // Convert from watts to kcal/min (1 watt = 0.014340 kcal/min)
        let kcalPerMin = metabolicRate * 0.014340
        
        // Validate result
        guard kcalPerMin.isFinite && kcalPerMin > 0 else {
            throw CalorieCalculationError.calculationOverflow
        }
        
        return kcalPerMin
    }
    
    /// Calculates grade adjustment factor using military load carriage research
    private func calculateGradeAdjustment(_ grade: Double) -> Double {
        // Clamp grade to supported range
        let clampedGrade = max(-20.0, min(20.0, grade))
        
        // Find surrounding grade points for interpolation
        let sortedGrades = gradeAdjustments.keys.sorted()
        
        // If exact match exists, return it
        if let exactFactor = gradeAdjustments[clampedGrade] {
            return exactFactor
        }
        
        // Find interpolation bounds
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
        
        // Perform linear interpolation
        let lowerFactor = gradeAdjustments[lowerGrade] ?? 1.0
        let upperFactor = gradeAdjustments[upperGrade] ?? 1.0
        
        if upperGrade == lowerGrade {
            return lowerFactor
        }
        
        let interpolationRatio = (clampedGrade - lowerGrade) / (upperGrade - lowerGrade)
        return lowerFactor + interpolationRatio * (upperFactor - lowerFactor)
    }
    
    /// Calculates environmental adjustment factor
    private func calculateEnvironmentalFactor(temperature: Double, altitude: Double, windSpeed: Double) -> Double {
        // Temperature factor (0.95-1.15 range)
        let temperatureFactor: Double
        if temperature < -5 {
            temperatureFactor = 1.15
        } else if temperature < 5 {
            temperatureFactor = 1.05
        } else if temperature > 30 {
            temperatureFactor = 1.15
        } else if temperature > 25 {
            temperatureFactor = 1.05
        } else {
            temperatureFactor = 1.0
        }
        
        // Altitude factor (10% VO2max reduction per 1000m above sea level)
        let altitudeFactor = 1.0 + max(0, altitude / 1000.0) * 0.10
        
        // Wind resistance factor (0.9-1.2 multiplier)
        let windFactor: Double
        if windSpeed > 15 { // Strong headwind
            windFactor = 1.2
        } else if windSpeed > 10 {
            windFactor = 1.1
        } else if windSpeed > 5 {
            windFactor = 1.05
        } else {
            windFactor = 1.0
        }
        
        return temperatureFactor * altitudeFactor * windFactor
    }
    
    /// Calculates time delta in minutes since last calculation
    private func calculateTimeDelta(_ timestamp: Date) -> Double {
        guard let lastTime = lastCalculationTime else {
            return 0.0 // First calculation
        }
        
        let timeDeltaSeconds = timestamp.timeIntervalSince(lastTime)
        return max(0, timeDeltaSeconds / 60.0) // Convert to minutes
    }
    
    /// Adds result to calculation history with size management
    private func addToHistory(_ result: CalorieCalculationResult) {
        calculationHistory.append(result)
        
        // Maintain history size limit
        if calculationHistory.count > maxHistorySize {
            calculationHistory.removeFirst(calculationHistory.count - maxHistorySize)
        }
    }
}

// MARK: - Real-time Calculation Support
extension CalorieCalculator {
    
    /// Starts continuous calorie calculation with location data and real-time terrain detection
    func startContinuousCalculation(
        bodyWeight: Double,
        loadWeight: Double,
        locationProvider: @escaping @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?),
        weatherProvider: @escaping @Sendable () async -> WeatherData?,
        terrainFactorProvider: @escaping @Sendable () async -> Double
    ) {
        // Cancel existing calculation task
        calculationTask?.cancel()
        
        calculationTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    // Get current data concurrently for better performance
                    async let locationData = locationProvider()
                    async let weatherData = weatherProvider()
                    async let terrainFactor = terrainFactorProvider()
                    
                    let (location, grade, terrain) = await locationData
                    let weather = await weatherData
                    let dynamicTerrainFactor = await terrainFactor
                    
                    guard let location = location,
                          let grade = grade else {
                        // Wait and retry if essential data not available
                        try await Task.sleep(for: .seconds(1))
                        continue
                    }
                    
                    // Use dynamic terrain factor from TerrainDetector, fallback to terrain-based calculation
                    let finalTerrainMultiplier: Double
                    if dynamicTerrainFactor > 0 {
                        finalTerrainMultiplier = dynamicTerrainFactor
                    } else if let terrain = terrain {
                        finalTerrainMultiplier = TerrainDifficultyMultiplier(from: terrain).rawValue
                    } else {
                        finalTerrainMultiplier = 1.2 // Default trail factor
                    }
                    
                    let temperature = weather?.temperature ?? 20.0
                    let windSpeed = weather?.windSpeed ?? 0.0
                    
                    let parameters = CalorieCalculationParameters(
                        bodyWeight: bodyWeight,
                        loadWeight: loadWeight,
                        speed: max(0, location.speed), // Ensure non-negative
                        grade: grade,
                        temperature: temperature,
                        altitude: location.altitude,
                        windSpeed: windSpeed,
                        terrainMultiplier: finalTerrainMultiplier,
                        timestamp: location.timestamp
                    )
                    
                    // Calculate calories
                    _ = try await calculateCalories(with: parameters)
                    
                    // Update every 1 second as specified
                    try await Task.sleep(for: .seconds(1))
                    
                } catch {
                    print("Calorie calculation error: \(error)")
                    // Continue calculation despite errors
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }
    
    /// Legacy method maintained for backward compatibility
    func startContinuousCalculation(
        bodyWeight: Double,
        loadWeight: Double,
        locationProvider: @escaping @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?),
        weatherProvider: @escaping @Sendable () async -> WeatherData?
    ) {
        startContinuousCalculation(
            bodyWeight: bodyWeight,
            loadWeight: loadWeight,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            terrainFactorProvider: {
                // Fallback to terrain-based calculation
                let (_, _, terrain) = await locationProvider()
                return terrain?.terrainFactor ?? 1.2
            }
        )
    }
    
    /// Stops continuous calculation
    func stopContinuousCalculation() {
        calculationTask?.cancel()
        calculationTask = nil
    }
}

// MARK: - Terrain Integration Support
extension CalorieCalculator {
    
    /// Updates terrain factor in real-time during calculation
    /// - Parameter terrainFactor: Dynamic terrain factor from TerrainDetector
    func updateTerrainFactor(_ terrainFactor: Double) {
        guard isCalculating else { return }
        
        // Update the current calculation with new terrain factor if available
        if let lastResult = lastCalculationResult {
            // Recalculate with new terrain factor
            let adjustedMetabolicRate = (lastResult.metabolicRate / lastResult.terrainFactor) * terrainFactor
            
            // Create updated result
            let updatedResult = CalorieCalculationResult(
                metabolicRate: adjustedMetabolicRate,
                totalCalories: lastResult.totalCalories,
                confidenceInterval: (adjustedMetabolicRate * 0.9)...(adjustedMetabolicRate * 1.1),
                gradeAdjustmentFactor: lastResult.gradeAdjustmentFactor,
                environmentalFactor: lastResult.environmentalFactor,
                terrainFactor: terrainFactor,
                altitude: lastResult.altitude,
                timestamp: Date()
            )
            
            currentMetabolicRate = adjustedMetabolicRate
            lastCalculationResult = updatedResult
            addToHistory(updatedResult)
        }
    }
    
    /// Gets the current terrain factor being used in calculations
    var currentTerrainFactor: Double {
        lastCalculationResult?.terrainFactor ?? 1.0
    }
    
    /// Gets terrain factor impact on calorie burn rate
    var terrainFactorImpact: Double {
        let factor = currentTerrainFactor
        return ((factor - 1.0) * 100) // Percentage increase over baseline
    }
}

// MARK: - Validation and Testing Support
extension CalorieCalculator {
    
    /// Validates calculation against known research data points
    func validateAgainstResearchData() -> [String] {
        var validationResults: [String] = []
        
        // Test case 1: 70kg person, 15kg load, 1.34 m/s (3 mph), level terrain
        do {
            let testParams = CalorieCalculationParameters(
                bodyWeight: 70.0,
                loadWeight: 15.0,
                speed: 1.34, // 3 mph
                grade: 0.0,
                temperature: 20.0,
                altitude: 0.0,
                windSpeed: 0.0,
                terrainMultiplier: 1.0,
                timestamp: Date()
            )
            
            let result = try calculateLCDABaseRate(testParams)
            let expectedRange = 4.0...6.0 // Expected kcal/min range from research
            
            if expectedRange.contains(result) {
                validationResults.append("✓ Test case 1 passed: \(String(format: "%.2f", result)) kcal/min")
            } else {
                validationResults.append("✗ Test case 1 failed: \(String(format: "%.2f", result)) kcal/min (expected \(expectedRange))")
            }
        } catch {
            validationResults.append("✗ Test case 1 error: \(error)")
        }
        
        // Test case 2: Grade adjustment validation
        let gradeTest = calculateGradeAdjustment(10.0)
        if abs(gradeTest - 1.45) < 0.01 {
            validationResults.append("✓ Grade adjustment test passed: \(gradeTest)")
        } else {
            validationResults.append("✗ Grade adjustment test failed: \(gradeTest) (expected 1.45)")
        }
        
        return validationResults
    }
    
}