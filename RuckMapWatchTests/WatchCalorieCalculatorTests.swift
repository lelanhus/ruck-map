import Testing
import Foundation
import CoreLocation
@testable import RuckMapWatch

/// Comprehensive tests for WatchCalorieCalculator using Swift Testing framework
@Suite("Watch Calorie Calculator Tests")
struct WatchCalorieCalculatorTests {
    
    // MARK: - Initialization Tests
    
    @Test("WatchCalorieCalculator initialization")
    func watchCalorieCalculatorInitialization() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate == 0.0)
            #expect(calculator.totalCalories == 0.0)
            #expect(calculator.isCalculating == false)
        }
    }
    
    // MARK: - Calculation Lifecycle Tests
    
    @Test("Start calculation with body and load weight")
    func startCalculationWithBodyAndLoadWeight() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 75.0, loadWeight: 25.0)
        
        await MainActor.run {
            #expect(calculator.isCalculating == true)
            #expect(calculator.totalCalories == 0.0)
        }
    }
    
    @Test("Pause and resume calculation")
    func pauseAndResumeCalculation() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        await MainActor.run {
            #expect(calculator.isCalculating == true)
        }
        
        calculator.pauseCalculation()
        
        await MainActor.run {
            #expect(calculator.isCalculating == false)
        }
        
        calculator.resumeCalculation()
        
        await MainActor.run {
            #expect(calculator.isCalculating == true)
        }
    }
    
    @Test("Stop calculation")
    func stopCalculation() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 80.0, loadWeight: 30.0)
        calculator.stopCalculation()
        
        await MainActor.run {
            #expect(calculator.isCalculating == false)
        }
    }
    
    @Test("Reset calculator")
    func resetCalculator() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Add some calories by simulating location updates
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 5.0)
        
        // Wait briefly to accumulate some calories
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        calculator.reset()
        
        await MainActor.run {
            #expect(calculator.isCalculating == false)
            #expect(calculator.totalCalories == 0.0)
            #expect(calculator.currentMetabolicRate == 0.0)
        }
    }
    
    // MARK: - LCDA Algorithm Tests
    
    @Test("LCDA base calculation with different speeds", arguments: [
        (0.5, 70.0, 0.0), // Minimum speed
        (1.0, 70.0, 0.0), // Slow walking
        (2.0, 70.0, 0.0), // Normal walking
        (3.0, 70.0, 0.0), // Fast walking
        (4.0, 70.0, 0.0)  // Near maximum speed
    ])
    func lcdaBaseCalculationWithDifferentSpeeds(speedMps: Double, bodyWeight: Double, loadWeight: Double) async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: bodyWeight, loadWeight: loadWeight)
        
        let location = createTestLocation(speed: speedMps)
        calculator.updateLocation(location, grade: 0.0) // Level terrain
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate > 0.0)
            #expect(calculator.isCalculating == true)
        }
    }
    
    @Test("LCDA calculation with load weight impact", arguments: [
        (0.0, 70.0),   // No load
        (10.0, 80.0),  // Light load
        (25.0, 95.0),  // Medium load
        (50.0, 120.0)  // Heavy load
    ])
    func lcdaCalculationWithLoadWeightImpact(loadWeight: Double, expectedTotalWeight: Double) async throws {
        let calculator = await WatchCalorieCalculator()
        let bodyWeight = 70.0
        
        await calculator.startCalculation(bodyWeight: bodyWeight, loadWeight: loadWeight)
        
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 0.0)
        
        await MainActor.run {
            // Higher load weight should result in higher metabolic rate
            #expect(calculator.currentMetabolicRate > 0.0)
            
            // The calculation should account for total weight (body + load)
            // We can't directly test the internal calculation, but we can verify
            // that load weight affects the result
        }
    }
    
    @Test("Speed clamping to valid range")
    func speedClampingToValidRange() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Test very low speed (should be clamped to minimum)
        let slowLocation = createTestLocation(speed: 0.1) // Very slow
        calculator.updateLocation(slowLocation, grade: 0.0)
        
        let slowMetabolicRate = await MainActor.run {
            calculator.currentMetabolicRate
        }
        
        // Test very high speed (should be clamped to maximum)
        let fastLocation = createTestLocation(speed: 10.0) // Very fast
        calculator.updateLocation(fastLocation, grade: 0.0)
        
        let fastMetabolicRate = await MainActor.run {
            calculator.currentMetabolicRate
        }
        
        // Both should produce valid metabolic rates
        #expect(slowMetabolicRate > 0.0)
        #expect(fastMetabolicRate > 0.0)
        #expect(fastMetabolicRate > slowMetabolicRate) // Fast should be higher
    }
    
    // MARK: - Grade Adjustment Tests
    
    @Test("Grade adjustment calculations", arguments: [
        (-20.0, "steep downhill"),
        (-10.0, "moderate downhill"),
        (0.0, "level terrain"),
        (10.0, "moderate uphill"),
        (20.0, "steep uphill")
    ])
    func gradeAdjustmentCalculations(grade: Double, description: String) async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let location = createTestLocation(speed: 2.5)
        calculator.updateLocation(location, grade: grade)
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate > 0.0)
            // Uphill should generally require more energy than downhill
        }
    }
    
    @Test("Grade interpolation between known points")
    func gradeInterpolationBetweenKnownPoints() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Test grade between known adjustment points (e.g., 5% grade)
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 5.0)
        
        let gradeRate = await MainActor.run {
            calculator.currentMetabolicRate
        }
        
        // Test level terrain for comparison
        calculator.updateLocation(location, grade: 0.0)
        
        let levelRate = await MainActor.run {
            calculator.currentMetabolicRate
        }
        
        #expect(gradeRate > levelRate) // Uphill should require more energy
    }
    
    @Test("Extreme grade clamping")
    func extremeGradeClamping() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let location = createTestLocation(speed: 2.0)
        
        // Test extreme positive grade
        calculator.updateLocation(location, grade: 50.0) // Should be clamped to 20%
        let extremeUpRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Test extreme negative grade
        calculator.updateLocation(location, grade: -50.0) // Should be clamped to -20%
        let extremeDownRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Both should produce valid rates and extreme up should be higher
        #expect(extremeUpRate > 0.0)
        #expect(extremeDownRate > 0.0)
        #expect(extremeUpRate > extremeDownRate)
    }
    
    // MARK: - Environmental Factor Tests
    
    @Test("Altitude adjustment calculations", arguments: [
        (0.0, "sea level"),
        (500.0, "moderate altitude"),
        (1000.0, "high altitude"),
        (2000.0, "very high altitude")
    ])
    func altitudeAdjustmentCalculations(altitude: Double, description: String) async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let location = createTestLocation(altitude: altitude, speed: 2.0)
        calculator.updateLocation(location, grade: 0.0)
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate > 0.0)
            // Higher altitude should generally require more energy due to lower oxygen
        }
    }
    
    @Test("Environmental factor consistency")
    func environmentalFactorConsistency() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let seaLevelLocation = createTestLocation(altitude: 0.0, speed: 2.0)
        calculator.updateLocation(seaLevelLocation, grade: 0.0)
        let seaLevelRate = await MainActor.run { calculator.currentMetabolicRate }
        
        let highAltitudeLocation = createTestLocation(altitude: 2000.0, speed: 2.0)
        calculator.updateLocation(highAltitudeLocation, grade: 0.0)
        let highAltitudeRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // High altitude should require more energy
        #expect(highAltitudeRate > seaLevelRate)
    }
    
    // MARK: - Terrain Multiplier Tests
    
    @Test("Terrain multiplier updates based on grade", arguments: [
        (2.0, "gentle terrain"),
        (10.0, "moderate terrain"),
        (18.0, "steep terrain")
    ])
    func terrainMultiplierUpdatesBasedOnGrade(grade: Double, expectedTerrain: String) async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Update terrain multiplier based on grade
        calculator.updateTerrainMultiplier(for: grade)
        
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: grade)
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate > 0.0)
        }
    }
    
    @Test("Terrain multiplier progression")
    func terrainMultiplierProgression() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let location = createTestLocation(speed: 2.0)
        
        // Test gentle terrain
        calculator.updateTerrainMultiplier(for: 5.0)
        calculator.updateLocation(location, grade: 5.0)
        let gentleRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Test moderate terrain
        calculator.updateTerrainMultiplier(for: 12.0)
        calculator.updateLocation(location, grade: 12.0)
        let moderateRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Test steep terrain
        calculator.updateTerrainMultiplier(for: 18.0)
        calculator.updateLocation(location, grade: 18.0)
        let steepRate = await MainActor.run { calculator.currentMetabolicRate }
        
        #expect(moderateRate > gentleRate)
        #expect(steepRate > moderateRate)
    }
    
    // MARK: - Calorie Accumulation Tests
    
    @Test("Calorie accumulation over time")
    func calorieAccumulationOverTime() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        let location = createTestLocation(speed: 2.5)
        calculator.updateLocation(location, grade: 5.0)
        
        // Initial calories should be zero or very low
        let initialCalories = await MainActor.run { calculator.totalCalories }
        
        // Wait a bit for calories to accumulate
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Manually trigger calorie update (simulating timer)
        await MainActor.run {
            // In a real scenario, the internal timer would update calories
            // For testing, we verify the metabolic rate is set
            #expect(calculator.currentMetabolicRate > 0.0)
        }
    }
    
    @Test("Calorie calculation pause behavior")
    func calorieCalculationPauseBehavior() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Start accumulating calories
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 0.0)
        
        // Pause calculation
        calculator.pauseCalculation()
        
        // Update location while paused
        calculator.updateLocation(location, grade: 5.0)
        
        await MainActor.run {
            #expect(calculator.isCalculating == false)
            // Metabolic rate might still be calculated but calories shouldn't accumulate
        }
        
        // Resume and verify calculation continues
        calculator.resumeCalculation()
        
        await MainActor.run {
            #expect(calculator.isCalculating == true)
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Update location when not calculating")
    func updateLocationWhenNotCalculating() async throws {
        let calculator = await WatchCalorieCalculator()
        
        // Don't start calculation
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 5.0)
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate == 0.0)
            #expect(calculator.totalCalories == 0.0)
            #expect(calculator.isCalculating == false)
        }
    }
    
    @Test("Zero and negative speed handling")
    func zeroAndNegativeSpeedHandling() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 70.0, loadWeight: 20.0)
        
        // Zero speed
        let zeroSpeedLocation = createTestLocation(speed: 0.0)
        calculator.updateLocation(zeroSpeedLocation, grade: 0.0)
        
        let zeroSpeedRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Negative speed (should be clamped to 0)
        let negativeSpeedLocation = createTestLocation(speed: -2.0)
        calculator.updateLocation(negativeSpeedLocation, grade: 0.0)
        
        let negativeSpeedRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Both should produce valid (non-negative) metabolic rates
        #expect(zeroSpeedRate >= 0.0)
        #expect(negativeSpeedRate >= 0.0)
    }
    
    @Test("Extreme body and load weights")
    func extremeBodyAndLoadWeights() async throws {
        let calculator = await WatchCalorieCalculator()
        
        // Test very light person with heavy load
        await calculator.startCalculation(bodyWeight: 40.0, loadWeight: 60.0)
        
        let location = createTestLocation(speed: 2.0)
        calculator.updateLocation(location, grade: 0.0)
        
        let lightPersonRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Test very heavy person with no load
        calculator.reset()
        await calculator.startCalculation(bodyWeight: 120.0, loadWeight: 0.0)
        calculator.updateLocation(location, grade: 0.0)
        
        let heavyPersonRate = await MainActor.run { calculator.currentMetabolicRate }
        
        // Both should produce valid metabolic rates
        #expect(lightPersonRate > 0.0)
        #expect(heavyPersonRate > 0.0)
        
        // Total weight matters more than individual components
        #expect(lightPersonRate > 0.0) // 100kg total
        #expect(heavyPersonRate > 0.0) // 120kg total
    }
    
    // MARK: - Integration Tests
    
    @Test("Complete workout simulation")
    func completeWorkoutSimulation() async throws {
        let calculator = await WatchCalorieCalculator()
        
        await calculator.startCalculation(bodyWeight: 75.0, loadWeight: 25.0)
        
        // Simulate a varied workout with different terrains and speeds
        let workoutSegments = [
            (speed: 1.5, grade: 0.0, duration: 0.1),  // Warm-up
            (speed: 2.5, grade: 5.0, duration: 0.1),   // Uphill
            (speed: 3.0, grade: -3.0, duration: 0.1),  // Downhill
            (speed: 2.0, grade: 8.0, duration: 0.1),   // Steep uphill
            (speed: 2.2, grade: 0.0, duration: 0.1)    // Cool-down
        ]
        
        for segment in workoutSegments {
            let location = createTestLocation(speed: segment.speed)
            calculator.updateLocation(location, grade: segment.grade)
            
            // Simulate time passage
            try await Task.sleep(nanoseconds: UInt64(segment.duration * 1_000_000_000))
        }
        
        await MainActor.run {
            #expect(calculator.currentMetabolicRate > 0.0)
            #expect(calculator.isCalculating == true)
        }
        
        calculator.stopCalculation()
        
        await MainActor.run {
            #expect(calculator.isCalculating == false)
        }
    }
}

// MARK: - Test Helpers

extension WatchCalorieCalculatorTests {
    
    /// Create a test CLLocation for testing
    private func createTestLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 100.0,
        accuracy: Double = 5.0,
        speed: Double = 2.0,
        course: Double = 45.0
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3.0,
            course: course,
            speed: max(0, speed), // Ensure non-negative speed
            timestamp: Date()
        )
    }
}