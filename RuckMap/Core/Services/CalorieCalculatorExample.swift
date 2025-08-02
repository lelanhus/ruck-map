import Foundation
import CoreLocation

/**
 # CalorieCalculator Usage Examples
 
 This file demonstrates various usage patterns for the military-grade LCDA CalorieCalculator
 implementation. These examples show how to integrate the calculator into real-world scenarios.
 */

// MARK: - Example Usage Scenarios

/// Example 1: Basic single calculation
func basicCalorieCalculation() async throws {
    let calculator = CalorieCalculator()
    
    // Scenario: 75kg soldier with 20kg pack, walking at 2.5 mph on level pavement in moderate conditions
    let parameters = CalorieCalculationParameters(
        bodyWeight: 75.0,           // kg
        loadWeight: 20.0,           // kg
        speed: 1.12,                // m/s (2.5 mph)
        grade: 0.0,                 // level terrain
        temperature: 15.0,          // °C (59°F)
        altitude: 100.0,            // meters above sea level
        windSpeed: 2.0,             // m/s (light breeze)
        terrainMultiplier: 1.0,     // pavement
        timestamp: Date()
    )
    
    let result = try await calculator.calculateCalories(with: parameters)
    
    print("=== Basic Calculation Example ===")
    print("Metabolic Rate: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    print("Confidence Range: \(String(format: "%.2f", result.lowerBound)) - \(String(format: "%.2f", result.upperBound)) kcal/min")
    print("Environmental Factor: \(String(format: "%.2f", result.environmentalFactor))")
    print("Grade Adjustment: \(String(format: "%.2f", result.gradeAdjustmentFactor))")
    print("Terrain Factor: \(String(format: "%.2f", result.terrainFactor))")
}

/// Example 2: Uphill hike with heavy load
func uphillHikeCalculation() async throws {
    let calculator = CalorieCalculator()
    
    // Scenario: Steep uphill hike with full military load
    let parameters = CalorieCalculationParameters(
        bodyWeight: 80.0,           // kg
        loadWeight: 35.0,           // kg (heavy load)
        speed: 0.89,                // m/s (2 mph - slower due to load and grade)
        grade: 15.0,                // 15% uphill grade
        temperature: 25.0,          // °C (77°F)
        altitude: 1500.0,           // meters (high altitude effect)
        windSpeed: 8.0,             // m/s (moderate headwind)
        terrainMultiplier: 1.2,     // trail terrain
        timestamp: Date()
    )
    
    let result = try await calculator.calculateCalories(with: parameters)
    
    print("\n=== Uphill Hike Example ===")
    print("Heavy Load: \(parameters.bodyWeight + parameters.loadWeight) kg total")
    print("Metabolic Rate: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    print("Grade Impact: \(String(format: "%.0f", (result.gradeAdjustmentFactor - 1.0) * 100))% increase")
    print("Altitude Impact: Calculated at \(parameters.altitude)m elevation")
    print("Estimated calories per hour: \(String(format: "%.0f", result.metabolicRate * 60)) kcal/hr")
}

/// Example 3: Desert conditions with sand terrain
func desertMarchCalculation() async throws {
    let calculator = CalorieCalculator()
    
    // Scenario: Desert march in challenging conditions
    let parameters = CalorieCalculationParameters(
        bodyWeight: 70.0,           // kg
        loadWeight: 25.0,           // kg
        speed: 1.0,                 // m/s (slower in sand)
        grade: 3.0,                 // slight uphill
        temperature: 40.0,          // °C (104°F - extreme heat)
        altitude: 200.0,            // meters
        windSpeed: 12.0,            // m/s (strong desert wind)
        terrainMultiplier: 1.8,     // sand terrain
        timestamp: Date()
    )
    
    let result = try await calculator.calculateCalories(with: parameters)
    
    print("\n=== Desert March Example ===")
    print("Extreme Conditions: \(parameters.temperature)°C, sand terrain")
    print("Metabolic Rate: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    print("Environmental Stress Factor: \(String(format: "%.2f", result.environmentalFactor))")
    print("Terrain Difficulty: \(String(format: "%.0f", (result.terrainFactor - 1.0) * 100))% increase")
    print("Total multiplier vs. ideal conditions: \(String(format: "%.2f", result.gradeAdjustmentFactor * result.environmentalFactor * result.terrainFactor))x")
}

/// Example 4: Cold weather operation
func coldWeatherCalculation() async throws {
    let calculator = CalorieCalculator()
    
    // Scenario: Winter operation in sub-zero temperatures
    let parameters = CalorieCalculationParameters(
        bodyWeight: 85.0,           // kg (heavier with winter gear)
        loadWeight: 30.0,           // kg
        speed: 0.67,                // m/s (1.5 mph - slow in snow)
        grade: -5.0,                // slight downhill
        temperature: -15.0,         // °C (5°F - extreme cold)
        altitude: 800.0,            // meters
        windSpeed: 15.0,            // m/s (strong cold wind)
        terrainMultiplier: 1.5,     // snow terrain
        timestamp: Date()
    )
    
    let result = try await calculator.calculateCalories(with: parameters)
    
    print("\n=== Cold Weather Operation Example ===")
    print("Extreme Cold: \(parameters.temperature)°C with \(parameters.windSpeed) m/s wind")
    print("Metabolic Rate: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    print("Cold Stress Factor: \(String(format: "%.2f", result.environmentalFactor))")
    print("Downhill Benefit: \(String(format: "%.0f", (1.0 - result.gradeAdjustmentFactor) * 100))% reduction")
    print("Net energy cost: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
}

/// Example 5: Time-series calculation simulation
func timeSeriesCalculation() async throws {
    let calculator = CalorieCalculator()
    
    print("\n=== Time Series Simulation ===")
    print("Simulating 30-minute march with varying conditions...")
    
    var totalTime: Double = 0
    let timeStep: Double = 5.0 // 5-minute intervals
    
    // Simulate march with changing grade and conditions
    for minute in stride(from: 0, to: 30, by: timeStep) {
        // Simulate changing grade over time (hilly terrain)
        let grade = sin(Double(minute) * 0.1) * 10.0 // Varies between -10% and +10%
        
        // Simulate slight fatigue (slower speed over time)
        let speed = 1.34 - (Double(minute) * 0.01) // Starts at 3 mph, gradually slows
        
        let parameters = CalorieCalculationParameters(
            bodyWeight: 75.0,
            loadWeight: 20.0,
            speed: speed,
            grade: grade,
            temperature: 20.0,
            altitude: 500.0,
            windSpeed: 3.0,
            terrainMultiplier: 1.2,
            timestamp: Date().addingTimeInterval(Double(minute) * 60)
        )
        
        let result = try await calculator.calculateCalories(with: parameters)
        
        print("Minute \(Int(minute)): Grade \(String(format: "%+.1f", grade))%, " +
              "Speed \(String(format: "%.2f", speed)) m/s, " +
              "Rate \(String(format: "%.2f", result.metabolicRate)) kcal/min, " +
              "Total \(String(format: "%.1f", result.totalCalories)) kcal")
    }
    
    print("Final total calories: \(String(format: "%.1f", calculator.totalCalories)) kcal")
    print("Average burn rate: \(String(format: "%.2f", calculator.getAverageMetabolicRate())) kcal/min")
}

/// Example 6: Validation against research data
func researchValidation() async throws {
    let calculator = CalorieCalculator()
    
    print("\n=== Research Data Validation ===")
    
    // Test case from Pandolf et al. (1977)
    // 70kg person, 15kg load, 3 mph (1.34 m/s), level terrain
    let researchParameters = CalorieCalculationParameters(
        bodyWeight: 70.0,
        loadWeight: 15.0,
        speed: 1.34,
        grade: 0.0,
        temperature: 20.0,
        altitude: 0.0,
        windSpeed: 0.0,
        terrainMultiplier: 1.0,
        timestamp: Date()
    )
    
    let result = try await calculator.calculateCalories(with: researchParameters)
    
    print("Research Test Case (Pandolf et al., 1977):")
    print("Parameters: 70kg + 15kg load, 3 mph, level terrain")
    print("Calculated: \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    print("Expected range: 4.5-5.5 kcal/min")
    print("Within range: \(result.metabolicRate >= 4.5 && result.metabolicRate <= 5.5 ? "✓" : "✗")")
    
    // Run built-in validation
    let validationResults = calculator.validateAgainstResearchData()
    for result in validationResults {
        print(result)
    }
}

/// Example 7: Terrain comparison
func terrainComparison() async throws {
    let calculator = CalorieCalculator()
    
    print("\n=== Terrain Comparison ===")
    
    let baseParameters = CalorieCalculationParameters(
        bodyWeight: 75.0,
        loadWeight: 20.0,
        speed: 1.34,
        grade: 0.0,
        temperature: 20.0,
        altitude: 0.0,
        windSpeed: 0.0,
        terrainMultiplier: 1.0,
        timestamp: Date()
    )
    
    let terrainTypes: [(String, Double)] = [
        ("Pavement", 1.0),
        ("Trail", 1.2),
        ("Gravel", 1.3),
        ("Grass", 1.2),
        ("Snow", 1.5),
        ("Sand", 1.8),
        ("Mud", 1.8)
    ]
    
    for (terrainName, multiplier) in terrainTypes {
        calculator.reset()
        
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: multiplier,
            timestamp: params.timestamp
        )
        
        let result = try await calculator.calculateCalories(with: params)
        let increase = ((result.metabolicRate / terrainTypes[0].1) - 1.0) * 100
        
        print("\(terrainName): \(String(format: "%.2f", result.metabolicRate)) kcal/min " +
              "(\(String(format: "%+.0f", increase))% vs pavement)")
    }
}

// MARK: - Example Integration with Location Data

/// Example 8: Integration with Core Location
func locationIntegrationExample() async throws {
    let calculator = CalorieCalculator()
    
    print("\n=== Location Integration Example ===")
    
    // Simulate location data from a real hike
    let locations = [
        // Start at sea level
        (CLLocation(latitude: 37.7749, longitude: -122.4194), 0.0, 1.34, TerrainType.trail),
        // Climb uphill
        (CLLocation(latitude: 37.7750, longitude: -122.4193), 8.0, 1.0, TerrainType.trail),
        // Continue climbing
        (CLLocation(latitude: 37.7751, longitude: -122.4192), 12.0, 0.89, TerrainType.trail),
        // Level section
        (CLLocation(latitude: 37.7752, longitude: -122.4191), 2.0, 1.2, TerrainType.trail),
        // Downhill
        (CLLocation(latitude: 37.7753, longitude: -122.4190), -6.0, 1.5, TerrainType.trail)
    ]
    
    for (index, (location, grade, speed, terrain)) in locations.enumerated() {
        let terrainMultiplier = TerrainDifficultyMultiplier(from: terrain).rawValue
        
        let parameters = CalorieCalculationParameters(
            bodyWeight: 75.0,
            loadWeight: 20.0,
            speed: speed,
            grade: grade,
            temperature: 18.0,
            altitude: location.altitude,
            windSpeed: 2.0,
            terrainMultiplier: terrainMultiplier,
            timestamp: Date().addingTimeInterval(Double(index) * 60)
        )
        
        let result = try await calculator.calculateCalories(with: parameters)
        
        print("Point \(index + 1): " +
              "Grade \(String(format: "%+.1f", grade))%, " +
              "Speed \(String(format: "%.1f", speed)) m/s, " +
              "Rate \(String(format: "%.2f", result.metabolicRate)) kcal/min")
    }
    
    print("Total accumulated: \(String(format: "%.1f", calculator.totalCalories)) kcal")
}

// MARK: - Demo Runner

/// Runs all examples to demonstrate the CalorieCalculator capabilities
@MainActor
func runAllExamples() async {
    print("🔥 LCDA Military-Grade Calorie Calculator Examples 🔥\n")
    
    do {
        try await basicCalorieCalculation()
        try await uphillHikeCalculation()
        try await desertMarchCalculation()
        try await coldWeatherCalculation()
        try await timeSeriesCalculation()
        try await researchValidation()
        try await terrainComparison()
        try await locationIntegrationExample()
        
        print("\n✅ All examples completed successfully!")
        print("\nThe CalorieCalculator is ready for integration into RuckMap.")
        
    } catch {
        print("❌ Error running examples: \(error)")
    }
}