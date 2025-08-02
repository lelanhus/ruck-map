import Testing
import CoreLocation
@testable import RuckMap

@Suite("LCDA Calorie Calculator Tests")
struct CalorieCalculatorTests {
    
    // MARK: - LCDA Base Algorithm Tests
    
    @Test("LCDA base calculation with research data")
    func testLCDABaseCalculation() async throws {
        let calculator = CalorieCalculator()
        
        // Test case from military research: 70kg person, 15kg load, 3 mph (1.34 m/s), level terrain
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
        
        let result = try await calculator.calculateCalories(with: parameters)
        
        // Expected range based on LCDA research: approximately 4.5-5.5 kcal/min
        #expect(result.metabolicRate > 4.0, "Metabolic rate should be greater than 4 kcal/min")
        #expect(result.metabolicRate < 6.0, "Metabolic rate should be less than 6 kcal/min")
        
        // Verify confidence interval is within ±10%
        let expectedConfidenceRange = result.metabolicRate * 0.10
        #expect(abs(result.confidenceInterval.lowerBound - (result.metabolicRate - expectedConfidenceRange)) < 0.01)
        #expect(abs(result.confidenceInterval.upperBound - (result.metabolicRate + expectedConfidenceRange)) < 0.01)
    }
    
    @Test("Speed range validation")
    func testSpeedRangeValidation() async throws {
        let calculator = CalorieCalculator()
        let baseParameters = CalorieCalculationParameters(
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
        
        // Test minimum speed (0.5 mph = 0.22 m/s)
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: 0.22,
            grade: params.grade,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let minResult = try await calculator.calculateCalories(with: params)
        #expect(minResult.metabolicRate > 0, "Should calculate positive metabolic rate for minimum speed")
        
        // Test maximum speed (6.0 mph = 2.68 m/s)
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: 2.68,
            grade: params.grade,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let maxResult = try await calculator.calculateCalories(with: params)
        #expect(maxResult.metabolicRate > minResult.metabolicRate, "Higher speed should result in higher metabolic rate")
    }
    
    // MARK: - Grade Adjustment Tests
    
    @Test("Grade adjustments")
    func testGradeAdjustments() async throws {
        let calculator = CalorieCalculator()
        let baseParameters = CalorieCalculationParameters(
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
        
        // Test level terrain (baseline)
        let levelResult = try await calculator.calculateCalories(with: baseParameters)
        
        // Test uphill (+10% grade should increase metabolic rate by ~45%)
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: 10.0,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let uphillResult = try await calculator.calculateCalories(with: params)
        #expect(uphillResult.metabolicRate > levelResult.metabolicRate, "Uphill should increase metabolic rate")
        
        let expectedUphillIncrease = levelResult.metabolicRate * 1.45
        #expect(abs(uphillResult.metabolicRate - expectedUphillIncrease) < 0.1, "10% grade should increase rate by ~45%")
        
        // Test downhill (-10% grade should decrease metabolic rate)
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: -10.0,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let downhillResult = try await calculator.calculateCalories(with: params)
        #expect(downhillResult.metabolicRate < levelResult.metabolicRate, "Downhill should decrease metabolic rate")
    }
    
    // MARK: - Environmental Factor Tests
    
    @Test("Temperature adjustments")
    func testTemperatureAdjustments() async throws {
        let calculator = CalorieCalculator()
        let baseParameters = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0, // Optimal temperature
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        let normalResult = try await calculator.calculateCalories(with: baseParameters)
        
        // Test cold temperature (-10°C should increase metabolic rate)
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: -10.0,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let coldResult = try await calculator.calculateCalories(with: params)
        #expect(coldResult.metabolicRate > normalResult.metabolicRate, "Cold temperature should increase metabolic rate")
        
        // Test hot temperature (35°C should increase metabolic rate)
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: 35.0,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let hotResult = try await calculator.calculateCalories(with: params)
        #expect(hotResult.metabolicRate > normalResult.metabolicRate, "Hot temperature should increase metabolic rate")
    }
    
    @Test("Altitude adjustment")
    func testAltitudeAdjustment() async throws {
        let calculator = CalorieCalculator()
        let baseParameters = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0, // Sea level
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        let seaLevelResult = try await calculator.calculateCalories(with: baseParameters)
        
        // Test high altitude (1000m should increase metabolic rate by ~10%)
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: params.temperature,
            altitude: 1000.0,
            windSpeed: params.windSpeed,
            terrainMultiplier: params.terrainMultiplier,
            timestamp: params.timestamp
        )
        
        let highAltitudeResult = try await calculator.calculateCalories(with: params)
        #expect(highAltitudeResult.metabolicRate > seaLevelResult.metabolicRate, "High altitude should increase metabolic rate")
        
        let expectedIncrease = seaLevelResult.metabolicRate * 1.10
        #expect(abs(highAltitudeResult.metabolicRate - expectedIncrease) < 0.1, "1000m altitude should increase rate by ~10%")
    }
    
    // MARK: - Terrain Multiplier Tests
    
    @Test("Terrain multipliers")
    func testTerrainMultipliers() async throws {
        let calculator = CalorieCalculator()
        let baseParameters = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0, // Pavement baseline
            timestamp: Date()
        )
        
        let pavementResult = try await calculator.calculateCalories(with: baseParameters)
        
        // Test sand terrain (1.8x multiplier)
        var params = baseParameters
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: 1.8,
            timestamp: params.timestamp
        )
        
        let sandResult = try await calculator.calculateCalories(with: params)
        #expect(abs(sandResult.metabolicRate - (pavementResult.metabolicRate * 1.8)) < 0.01, "Sand terrain should be 1.8x harder")
        
        // Test trail terrain (1.2x multiplier)
        params = CalorieCalculationParameters(
            bodyWeight: params.bodyWeight,
            loadWeight: params.loadWeight,
            speed: params.speed,
            grade: params.grade,
            temperature: params.temperature,
            altitude: params.altitude,
            windSpeed: params.windSpeed,
            terrainMultiplier: 1.2,
            timestamp: params.timestamp
        )
        
        let trailResult = try await calculator.calculateCalories(with: params)
        #expect(abs(trailResult.metabolicRate - (pavementResult.metabolicRate * 1.2)) < 0.01, "Trail terrain should be 1.2x harder")
    }
    
    // MARK: - Cumulative Calorie Tests
    
    @Test("Cumulative calorie calculation")
    func testCumulativeCalorieCalculation() async throws {
        let calculator = CalorieCalculator()
        calculator.reset()
        
        let parameters = CalorieCalculationParameters(
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
        
        // First calculation
        let result1 = try await calculator.calculateCalories(with: parameters)
        #expect(abs(result1.totalCalories - 0.0) < 0.01, "First calculation should have zero total calories")
        
        // Wait a bit and calculate again
        let futureDate = Date().addingTimeInterval(60) // 1 minute later
        var params2 = parameters
        params2 = CalorieCalculationParameters(
            bodyWeight: params2.bodyWeight,
            loadWeight: params2.loadWeight,
            speed: params2.speed,
            grade: params2.grade,
            temperature: params2.temperature,
            altitude: params2.altitude,
            windSpeed: params2.windSpeed,
            terrainMultiplier: params2.terrainMultiplier,
            timestamp: futureDate
        )
        
        let result2 = try await calculator.calculateCalories(with: params2)
        
        // Total calories should equal metabolic rate * time elapsed (1 minute)
        let expectedCalories = result1.metabolicRate * 1.0 // 1 minute
        #expect(abs(result2.totalCalories - expectedCalories) < 0.1, "Total calories should accumulate correctly")
    }
    
    // MARK: - Input Validation Tests
    
    @Test("Invalid input validation")
    func testInvalidInputValidation() async {
        let calculator = CalorieCalculator()
        // Test invalid body weight
        let invalidBodyWeight = CalorieCalculationParameters(
            bodyWeight: 250.0, // Too high
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        do {
            _ = try await calculator.calculateCalories(with: invalidBodyWeight)
            #expect(Bool(false), "Should throw error for invalid body weight")
        } catch CalorieCalculationError.invalidBodyWeight {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
        
        // Test invalid load weight
        let invalidLoadWeight = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 150.0, // Too high
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        do {
            _ = try await calculator.calculateCalories(with: invalidLoadWeight)
            #expect(Bool(false), "Should throw error for invalid load weight")
        } catch CalorieCalculationError.invalidLoadWeight {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
        
        // Test invalid speed
        let invalidSpeed = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 5.0, // Too high (over 3 m/s)
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        do {
            _ = try await calculator.calculateCalories(with: invalidSpeed)
            #expect(Bool(false), "Should throw error for invalid speed")
        } catch CalorieCalculationError.invalidSpeed {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
    
    // MARK: - Research Data Validation Tests
    
    @Test("Research data validation")
    func testResearchDataValidation() {
        let calculator = CalorieCalculator()
        let validationResults = calculator.validateAgainstResearchData()
        
        // Ensure validation passes
        for result in validationResults {
            #expect(result.hasPrefix("✓"), "Validation should pass: \(result)")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Calculation performance")
    func testCalculationPerformance() async throws {
        let calculator = CalorieCalculator()
        let parameters = CalorieCalculationParameters(
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
        
        // Performance test - ensure calculations complete in reasonable time
        let startTime = Date()
        for _ in 0..<100 {
            do {
                _ = try await calculator.calculateCalories(with: parameters)
            } catch {
                #expect(Bool(false), "Calculation should not fail: \(error)")
            }
        }
        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 1.0, "100 calculations should complete in under 1 second")
    }
    
    // MARK: - Thread Safety Tests
    
    @Test("Thread safety")
    func testThreadSafety() async throws {
        let calculator = CalorieCalculator()
        let parameters = CalorieCalculationParameters(
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
        
        // Run multiple concurrent calculations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await calculator.calculateCalories(with: parameters)
                    } catch {
                        #expect(Bool(false), "Concurrent calculation should not fail: \(error)")
                    }
                }
            }
        }
        
        // Verify state consistency
        #expect(calculator.totalCalories > 0, "Total calories should accumulate from concurrent calculations")
    }
}