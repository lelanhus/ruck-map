import XCTest
import CoreLocation
@testable import RuckMap

final class CalorieCalculatorSimpleTest: XCTestCase {
    
    func testBasicCalorieCalculation() async throws {
        // Create calculator
        let calculator = CalorieCalculator()
        
        // Test parameters: 70kg person, 15kg load, 3 mph, level terrain
        let parameters = CalorieCalculationParameters(
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
        
        // Calculate
        let result = try await calculator.calculateCalories(with: parameters)
        
        // Verify result
        XCTAssertGreaterThan(result.metabolicRate, 4.0, "Should burn more than 4 kcal/min")
        XCTAssertLessThan(result.metabolicRate, 6.0, "Should burn less than 6 kcal/min")
        XCTAssertEqual(result.totalWeight, 85.0, accuracy: 0.01)
        
        print("✅ Calorie Calculator Test Passed!")
        print("Metabolic Rate: \(result.metabolicRate) kcal/min")
        print("Confidence Interval: \(result.confidenceInterval.lowerBound) - \(result.confidenceInterval.upperBound)")
    }
}