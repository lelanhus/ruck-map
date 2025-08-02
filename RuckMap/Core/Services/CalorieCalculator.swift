import Foundation
import CoreLocation

// MARK: - Terrain Multipliers
/// Terrain difficulty multipliers based on military load carriage studies
enum TerrainDifficultyMultiplier: Double, CaseIterable {
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
        speed / LCDAConstants.mphToMeterPerSecond // Convert m/s to mph
    }
    
    /// Validates that parameters are within acceptable ranges
    func validate() throws {
        guard bodyWeight > LCDAConstants.minBodyWeight && bodyWeight < LCDAConstants.maxBodyWeight else {
            throw CalorieCalculationError.invalidBodyWeight(bodyWeight)
        }
        
        guard loadWeight >= LCDAConstants.minLoadWeight && loadWeight <= LCDAConstants.maxLoadWeight else {
            throw CalorieCalculationError.invalidLoadWeight(loadWeight)
        }
        
        guard speed >= LCDAConstants.minSpeed && speed <= LCDAConstants.maxSpeed else {
            throw CalorieCalculationError.invalidSpeed(speed)
        }
        
        guard grade >= LCDAConstants.minGradeValidation && grade <= LCDAConstants.maxGradeValidation else {
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
        ((upperBound - lowerBound) / metabolicRate) * LCDAConstants.percentageMultiplier
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
            return "Invalid body weight: \(weight) kg. Must be between \(Int(LCDAConstants.minBodyWeight))-\(Int(LCDAConstants.maxBodyWeight)) kg."
        case .invalidLoadWeight(let weight):
            return "Invalid load weight: \(weight) kg. Must be between \(Int(LCDAConstants.minLoadWeight))-\(Int(LCDAConstants.maxLoadWeight)) kg."
        case .invalidSpeed(let speed):
            return "Invalid speed: \(speed) m/s. Must be between \(LCDAConstants.minSpeed)-\(LCDAConstants.maxSpeed) m/s."
        case .invalidGrade(let grade):
            return "Invalid grade: \(grade)%. Must be between \(Int(LCDAConstants.minGradeValidation))% to +\(Int(LCDAConstants.maxGradeValidation))%."
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
final class CalorieCalculator: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentMetabolicRate: Double = 0.0 // kcal/min
    @Published private(set) var totalCalories: Double = 0.0 // kcal
    @Published private(set) var lastCalculationResult: CalorieCalculationResult?
    @Published private(set) var isCalculating: Bool = false
    
    // MARK: - Private Properties
    private var calculationHistory: [CalorieCalculationResult] = []
    private var lastCalculationTime: Date?
    private var calculationTask: Task<Void, Never>?
    
    // MARK: - LCDA Algorithm Constants
    struct LCDAConstants {
        static let baseCoefficient: Double = 1.44
        static let linearCoefficient: Double = 1.94
        static let quadraticCoefficient: Double = 0.24
        static let minSpeedMph: Double = 0.5
        static let maxSpeedMph: Double = 6.0
        static let confidenceInterval: Double = 0.10 // ±10%
        
        // Conversion factors
        static let wattsToKcalPerMin: Double = 0.014340  // 1 watt = 0.014340 kcal/min
        static let mphToMeterPerSecond: Double = 0.44704  // 1 mph = 0.44704 m/s
        
        // Grade range limits
        static let minGrade: Double = -20.0  // Maximum downhill grade
        static let maxGrade: Double = 20.0   // Maximum uphill grade
        
        // Altitude effects
        static let altitudeReductionPerKm: Double = 0.10  // 10% VO2max reduction per 1000m
        static let altitudeThreshold: Double = 1500.0     // Altitude effects start at 1500m
        
        // Temperature thresholds (Celsius)
        static let coldThreshold: Double = -5.0
        static let coolThreshold: Double = 5.0
        static let warmThreshold: Double = 25.0
        static let hotThreshold: Double = 30.0
        
        // Wind resistance
        static let windResistanceBase: Double = 0.002  // Base wind resistance coefficient
        
        // Wind speed thresholds (m/s)
        static let windSpeedLight: Double = 5.0
        static let windSpeedModerate: Double = 10.0
        static let windSpeedStrong: Double = 15.0
        
        // Wind resistance multipliers
        static let windFactorNone: Double = 1.0
        static let windFactorLight: Double = 1.05
        static let windFactorModerate: Double = 1.1
        static let windFactorStrong: Double = 1.2
        
        // Temperature adjustment factors
        static let tempFactorNormal: Double = 1.0
        static let tempFactorMild: Double = 1.05
        static let tempFactorExtreme: Double = 1.15
        
        // Grade adjustment factors
        static let gradeFactorDefault: Double = 1.0
        
        // Body weight limits (kg)
        static let minBodyWeight: Double = 30.0
        static let maxBodyWeight: Double = 200.0
        
        // Load weight limits (kg)
        static let minLoadWeight: Double = 0.0
        static let maxLoadWeight: Double = 100.0
        
        // Speed limits (m/s)
        static let minSpeed: Double = 0.0
        static let maxSpeed: Double = 3.0  // ~6.7 mph
        
        // Grade limits (percentage)
        static let minGradeValidation: Double = -25.0
        static let maxGradeValidation: Double = 30.0
        
        // Time conversion
        static let secondsPerMinute: Double = 60.0
        
        // Default environment values
        static let defaultTemperature: Double = 20.0
        static let defaultWindSpeed: Double = 0.0
        static let defaultHumidity: Double = 50.0
        
        // Altitude conversion
        static let metersPerKilometer: Double = 1000.0
        
        // Update intervals
        static let updateIntervalSeconds: TimeInterval = 1.0
        
        // Confidence calculations
        static let percentageMultiplier: Double = 100.0
        
        // Test parameters for validation
        static let testBodyWeight: Double = 70.0
        static let testLoadWeight: Double = 15.0
        static let testSpeed: Double = 1.34  // 3 mph
        static let testGrade: Double = 0.0
        static let testExpectedMinRate: Double = 4.0
        static let testExpectedMaxRate: Double = 6.0
        static let testGradeValue: Double = 10.0
        static let testGradeExpected: Double = 1.45
        static let testGradeTolerance: Double = 0.01
        
        // History management
        static let maxHistorySize: Int = 1000  // Maximum calculation history entries
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
    
    // Pre-sorted grade keys for efficient interpolation
    private let sortedGradeKeys: [Double]
    
    // MARK: - Initialization
    init() {
        // Pre-sort grade keys once during initialization for performance
        self.sortedGradeKeys = gradeAdjustments.keys.sorted()
    }
    
    deinit {
        calculationTask?.cancel()
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
        let cutoffTime = Date().addingTimeInterval(-minutes * LCDAConstants.secondsPerMinute)
        let recentResults = calculationHistory.filter { $0.timestamp >= cutoffTime }
        
        guard !recentResults.isEmpty else { return 0.0 }
        
        let totalRate = recentResults.reduce(0) { $0 + $1.metabolicRate }
        return totalRate / Double(recentResults.count)
    }
    
    // MARK: - Private Implementation
    
    /// Implements the core LCDA walking equation: E = (1.44 + 1.94S + 0.24S²) × BW
    func calculateLCDABaseRate(_ parameters: CalorieCalculationParameters) throws -> Double {
        let speedMph = parameters.speedMph
        
        // Clamp speed to valid LCDA range (0.5-6.0 mph)
        let clampedSpeed = max(LCDAConstants.minSpeedMph, min(LCDAConstants.maxSpeedMph, speedMph))
        
        // LCDA equation: E = (1.44 + 1.94S + 0.24S²) × BW
        let energyCoefficient = LCDAConstants.baseCoefficient +
                               (LCDAConstants.linearCoefficient * clampedSpeed) +
                               (LCDAConstants.quadraticCoefficient * clampedSpeed * clampedSpeed)
        
        let metabolicRate = energyCoefficient * parameters.totalWeight
        
        // Convert from watts to kcal/min
        let kcalPerMin = metabolicRate * LCDAConstants.wattsToKcalPerMin
        
        // Validate result
        guard kcalPerMin.isFinite && kcalPerMin > 0 else {
            throw CalorieCalculationError.calculationOverflow
        }
        
        return kcalPerMin
    }
    
    /// Calculates grade adjustment factor using military load carriage research
    private func calculateGradeAdjustment(_ grade: Double) -> Double {
        // Clamp grade to supported range
        let clampedGrade = max(LCDAConstants.minGrade, min(LCDAConstants.maxGrade, grade))
        
        // If exact match exists, return it
        if let exactFactor = gradeAdjustments[clampedGrade] {
            return exactFactor
        }
        
        // Find interpolation bounds using binary search on pre-sorted array
        var lowerGrade: Double = LCDAConstants.minGrade
        var upperGrade: Double = LCDAConstants.maxGrade
        
        // Binary search for the lower bound
        let lowerIndex = sortedGradeKeys.lastIndex(where: { $0 <= clampedGrade }) ?? 0
        lowerGrade = sortedGradeKeys[lowerIndex]
        
        // Find the upper bound
        if lowerIndex < sortedGradeKeys.count - 1 {
            upperGrade = sortedGradeKeys[lowerIndex + 1]
        } else {
            upperGrade = sortedGradeKeys[lowerIndex]
        }
        
        // Perform linear interpolation
        let lowerFactor = gradeAdjustments[lowerGrade] ?? LCDAConstants.gradeFactorDefault
        let upperFactor = gradeAdjustments[upperGrade] ?? LCDAConstants.gradeFactorDefault
        
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
        if temperature < LCDAConstants.coldThreshold {
            temperatureFactor = LCDAConstants.tempFactorExtreme
        } else if temperature < LCDAConstants.coolThreshold {
            temperatureFactor = LCDAConstants.tempFactorMild
        } else if temperature > LCDAConstants.hotThreshold {
            temperatureFactor = LCDAConstants.tempFactorExtreme
        } else if temperature > LCDAConstants.warmThreshold {
            temperatureFactor = LCDAConstants.tempFactorMild
        } else {
            temperatureFactor = LCDAConstants.tempFactorNormal
        }
        
        // Altitude factor (10% VO2max reduction per 1000m above sea level)
        let altitudeFactor = 1.0 + max(0, altitude / LCDAConstants.metersPerKilometer) * LCDAConstants.altitudeReductionPerKm
        
        // Wind resistance factor (0.9-1.2 multiplier)
        let windFactor: Double
        if windSpeed > LCDAConstants.windSpeedStrong { // Strong headwind
            windFactor = LCDAConstants.windFactorStrong
        } else if windSpeed > LCDAConstants.windSpeedModerate {
            windFactor = LCDAConstants.windFactorModerate
        } else if windSpeed > LCDAConstants.windSpeedLight {
            windFactor = LCDAConstants.windFactorLight
        } else {
            windFactor = LCDAConstants.windFactorNone
        }
        
        return temperatureFactor * altitudeFactor * windFactor
    }
    
    /// Calculates time delta in minutes since last calculation
    private func calculateTimeDelta(_ timestamp: Date) -> Double {
        guard let lastTime = lastCalculationTime else {
            return 0.0 // First calculation
        }
        
        let timeDeltaSeconds = timestamp.timeIntervalSince(lastTime)
        return max(0, timeDeltaSeconds / LCDAConstants.secondsPerMinute) // Convert to minutes
    }
    
    /// Adds result to calculation history with size management
    private func addToHistory(_ result: CalorieCalculationResult) {
        calculationHistory.append(result)
        
        // Maintain history size limit
        if calculationHistory.count > LCDAConstants.maxHistorySize {
            calculationHistory.removeFirst(calculationHistory.count - LCDAConstants.maxHistorySize)
        }
    }
}

// MARK: - Real-time Calculation Support
extension CalorieCalculator {
    
    /// Starts continuous calorie calculation with location data
    func startContinuousCalculation(
        bodyWeight: Double,
        loadWeight: Double,
        locationProvider: @escaping @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?),
        weatherProvider: @escaping @Sendable () async -> WeatherData?
    ) {
        // Cancel existing calculation task
        calculationTask?.cancel()
        
        calculationTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    // Get current data
                    let (location, grade, terrain) = await locationProvider()
                    let weather = await weatherProvider()
                    
                    guard let location = location,
                          let grade = grade,
                          let terrain = terrain else {
                        // Wait and retry if data not available
                        try await Task.sleep(for: .seconds(LCDAConstants.updateIntervalSeconds))
                        continue
                    }
                    
                    // Create calculation parameters
                    let terrainMultiplier = TerrainDifficultyMultiplier(from: terrain).rawValue
                    let temperature = weather?.temperature ?? LCDAConstants.defaultTemperature
                    let windSpeed = weather?.windSpeed ?? LCDAConstants.defaultWindSpeed
                    
                    let parameters = CalorieCalculationParameters(
                        bodyWeight: bodyWeight,
                        loadWeight: loadWeight,
                        speed: max(0, location.speed), // Ensure non-negative
                        grade: grade,
                        temperature: temperature,
                        altitude: location.altitude,
                        windSpeed: windSpeed,
                        terrainMultiplier: terrainMultiplier,
                        timestamp: location.timestamp
                    )
                    
                    // Calculate calories
                    _ = try await calculateCalories(with: parameters)
                    
                    // Update every second as specified
                    try await Task.sleep(for: .seconds(LCDAConstants.updateIntervalSeconds))
                    
                } catch {
                    print("Calorie calculation error: \(error)")
                    // Continue calculation despite errors
                    try? await Task.sleep(for: .seconds(LCDAConstants.updateIntervalSeconds))
                }
            }
        }
    }
    
    /// Stops continuous calculation
    func stopContinuousCalculation() {
        calculationTask?.cancel()
        calculationTask = nil
    }
}

// MARK: - Validation and Testing Support
extension CalorieCalculator {
    
    /// Validates calculation against known research data points
    func validateAgainstResearchData() -> [String] {
        var validationResults: [String] = []
        
        // Test case 1: Standard military research validation parameters
        do {
            let testParams = CalorieCalculationParameters(
                bodyWeight: LCDAConstants.testBodyWeight,
                loadWeight: LCDAConstants.testLoadWeight,
                speed: LCDAConstants.testSpeed, // 3 mph
                grade: LCDAConstants.testGrade,
                temperature: LCDAConstants.defaultTemperature,
                altitude: 0.0,
                windSpeed: LCDAConstants.defaultWindSpeed,
                terrainMultiplier: LCDAConstants.gradeFactorDefault,
                timestamp: Date()
            )
            
            let result = try calculateLCDABaseRate(testParams)
            let expectedRange = LCDAConstants.testExpectedMinRate...LCDAConstants.testExpectedMaxRate // Expected kcal/min range from research
            
            if expectedRange.contains(result) {
                validationResults.append("✓ Test case 1 passed: \(String(format: "%.2f", result)) kcal/min")
            } else {
                validationResults.append("✗ Test case 1 failed: \(String(format: "%.2f", result)) kcal/min (expected \(expectedRange))")
            }
        } catch {
            validationResults.append("✗ Test case 1 error: \(error)")
        }
        
        // Test case 2: Grade adjustment validation
        let gradeTest = calculateGradeAdjustment(LCDAConstants.testGradeValue)
        if abs(gradeTest - LCDAConstants.testGradeExpected) < LCDAConstants.testGradeTolerance {
            validationResults.append("✓ Grade adjustment test passed: \(gradeTest)")
        } else {
            validationResults.append("✗ Grade adjustment test failed: \(gradeTest) (expected \(LCDAConstants.testGradeExpected))")
        }
        
        return validationResults
    }
}