import Testing
import Foundation
import CoreLocation
@testable import RuckMap

/// Comprehensive tests for CalorieCalculator and TerrainDetector integration
/// Validates real-time terrain factor updates and calorie calculation accuracy
struct TerrainCalorieIntegrationTests {
    
    // MARK: - Test Data
    
    private static let testBodyWeight: Double = 75.0 // kg
    private static let testLoadWeight: Double = 20.0 // kg (standard ruck weight)
    private static let testSpeed: Double = 1.34 // m/s (3 mph)
    private static let testGrade: Double = 5.0 // 5% grade
    
    /// Mock location for consistent testing
    private static func createMockLocation(
        speed: Double = testSpeed,
        altitude: Double = 100.0
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: altitude,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 0.0,
            speed: speed,
            timestamp: Date()
        )
    }
    
    // MARK: - Basic Integration Tests
    
    @Test("CalorieCalculator accepts dynamic terrain factors")
    func testDynamicTerrainFactorIntegration() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        // Manually set different terrain types and verify factor updates
        await detector.setManualTerrain(.pavedRoad)
        let pavedFactor = await detector.getTerrainFactor()
        #expect(pavedFactor == 1.0, "Paved road should have baseline factor of 1.0")
        
        await detector.setManualTerrain(.sand)
        let sandFactor = await detector.getTerrainFactor()
        #expect(sandFactor == 2.1, "Sand should have factor of 2.1 based on Session 7 research")
        
        await detector.setManualTerrain(.snow)
        let snowFactor = await detector.getTerrainFactor()
        #expect(snowFactor == 2.5, "Snow should have factor of 2.5 based on Session 7 research")
    }
    
    @Test("CalorieCalculator real-time terrain factor updates")
    func testRealTimeTerrainFactorUpdates() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        // Start with trail terrain
        await detector.setManualTerrain(.trail)
        
        // Create calculation parameters
        let baseParameters = CalorieCalculationParameters(
            bodyWeight: testBodyWeight,
            loadWeight: testLoadWeight,
            speed: testSpeed,
            grade: testGrade,
            temperature: 20.0,
            altitude: 100.0,
            windSpeed: 0.0,
            terrainMultiplier: await detector.getTerrainFactor(),
            timestamp: Date()
        )
        
        // Initial calculation
        let trailResult = try await calculator.calculateCalories(with: baseParameters)
        let trailRate = trailResult.metabolicRate
        
        // Update terrain to sand
        await detector.setManualTerrain(.sand)
        await calculator.updateTerrainFactor(await detector.getTerrainFactor())
        
        // Verify terrain factor was updated
        #expect(calculator.currentTerrainFactor == 2.1, "Calculator should reflect sand terrain factor")
        
        // Verify calorie rate increased proportionally
        let expectedSandRate = (trailRate / 1.2) * 2.1 // Convert trail to baseline, then apply sand factor
        let actualSandRate = calculator.currentMetabolicRate
        let rateDifference = abs(actualSandRate - expectedSandRate) / expectedSandRate
        
        #expect(rateDifference < 0.05, "Sand terrain should increase calorie rate by expected proportion")
    }
    
    @Test("Enhanced terrain factor with grade compensation")
    func testEnhancedTerrainFactorWithGrade() async throws {
        let detector = TerrainDetector()
        
        // Test flat terrain
        await detector.setManualTerrain(.sand)
        let flatFactor = await detector.getEnhancedTerrainFactor(grade: 0.0)
        #expect(flatFactor == 2.1, "Flat sand should have base factor of 2.1")
        
        // Test steep uphill
        let steepFactor = await detector.getEnhancedTerrainFactor(grade: 20.0)
        #expect(steepFactor > flatFactor, "Steep grade should increase terrain factor")
        #expect(steepFactor <= flatFactor * 1.02, "Grade compensation should be reasonable (≤2% increase)")
        
        // Test downhill (should not reduce factor below base)
        let downhillFactor = await detector.getEnhancedTerrainFactor(grade: -10.0)
        #expect(downhillFactor == flatFactor, "Downhill grade should not reduce terrain factor below base")
    }
    
    // MARK: - Terrain Factor Stream Tests
    
    @Test("Terrain factor stream provides updates")
    func testTerrainFactorStream() async throws {
        let detector = TerrainDetector()
        await detector.startDetection()
        
        var receivedUpdates: [(factor: Double, confidence: Double, terrainType: TerrainType)] = []
        
        // Collect updates for a short period
        let streamTask = Task {
            for await update in detector.terrainFactorStream() {
                receivedUpdates.append(update)
                if receivedUpdates.count >= 2 {
                    break
                }
            }
        }
        
        // Trigger terrain changes
        await detector.setManualTerrain(.trail)
        try await Task.sleep(for: .milliseconds(100))
        
        await detector.setManualTerrain(.sand)
        try await Task.sleep(for: .milliseconds(100))
        
        await streamTask.value
        await detector.stopDetection()
        
        #expect(receivedUpdates.count >= 1, "Should receive at least one terrain factor update")
        
        if let lastUpdate = receivedUpdates.last {
            #expect(lastUpdate.terrainType == .sand, "Last update should reflect sand terrain")
            #expect(lastUpdate.factor == 2.1, "Sand terrain factor should be 2.1")
            #expect(lastUpdate.confidence == 1.0, "Manual terrain should have 100% confidence")
        }
    }
    
    // MARK: - Continuous Calculation Integration Tests
    
    @Test("Continuous calculation with terrain factor provider")
    func testContinuousCalculationWithTerrainProvider() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        // Mock location provider
        let locationProvider: @Sendable () async -> (CLLocation?, Double?, TerrainType?) = {
            return (createMockLocation(), testGrade, .trail)
        }
        
        // Mock weather provider
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return WeatherData(temperature: 20.0)
        }
        
        // Mock terrain factor provider that changes over time
        var terrainFactorCallCount = 0
        let terrainFactorProvider: @Sendable () async -> Double = {
            terrainFactorCallCount += 1
            // Start with trail, then switch to sand after first call
            return terrainFactorCallCount == 1 ? 1.2 : 2.1
        }
        
        // Start continuous calculation
        calculator.startContinuousCalculation(
            bodyWeight: testBodyWeight,
            loadWeight: testLoadWeight,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            terrainFactorProvider: terrainFactorProvider
        )
        
        // Wait for multiple calculation cycles
        try await Task.sleep(for: .seconds(2.5))
        
        calculator.stopContinuousCalculation()
        
        // Verify terrain factor was updated during calculation
        #expect(calculator.currentTerrainFactor > 1.2, "Terrain factor should have been updated to sand value")
        #expect(calculator.totalCalories > 0, "Should have accumulated calories during calculation")
        
        let history = calculator.getCalculationHistory()
        #expect(history.count >= 2, "Should have multiple calculation history entries")
        
        // Verify terrain factor progression in history
        if history.count >= 2 {
            let firstEntry = history[0]
            let lastEntry = history.last!
            
            #expect(firstEntry.terrainFactor <= lastEntry.terrainFactor, 
                   "Terrain factor should increase from trail to sand")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Terrain detection failure handling")
    func testTerrainDetectionFailureHandling() async throws {
        let detector = TerrainDetector()
        
        // Start with unknown terrain (low confidence)
        await detector.reset()
        
        // Simulate detection failure
        await detector.handleDetectionFailure(TerrainDetectionError.lowConfidence(0.2))
        
        // Verify fallback behavior
        let fallbackTerrain = await detector.getCurrentTerrainType()
        #expect(fallbackTerrain == .trail, "Should fallback to trail terrain on detection failure")
        
        let fallbackFactor = await detector.getTerrainFactor()
        #expect(fallbackFactor == 1.2, "Should use trail factor as fallback")
    }
    
    @Test("CalorieCalculator handles invalid terrain factors gracefully")
    func testInvalidTerrainFactorHandling() async throws {
        let calculator = CalorieCalculator()
        
        let parameters = CalorieCalculationParameters(
            bodyWeight: testBodyWeight,
            loadWeight: testLoadWeight,
            speed: testSpeed,
            grade: testGrade,
            temperature: 20.0,
            altitude: 100.0,
            windSpeed: 0.0,
            terrainMultiplier: 0.0, // Invalid terrain factor
            timestamp: Date()
        )
        
        // Should not crash with invalid terrain factor
        let result = try await calculator.calculateCalories(with: parameters)
        
        // Verify reasonable result despite invalid input
        #expect(result.metabolicRate > 0, "Should produce valid metabolic rate even with invalid terrain factor")
        #expect(result.terrainFactor == 0.0, "Should preserve original terrain factor in result")
    }
    
    // MARK: - Performance Tests
    
    @Test("Terrain factor updates performance")
    func testTerrainFactorUpdatePerformance() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        await detector.startDetection()
        
        let startTime = Date()
        
        // Perform multiple rapid terrain factor updates
        for i in 0..<100 {
            let terrain: TerrainType = (i % 2 == 0) ? .trail : .sand
            await detector.setManualTerrain(terrain)
            let factor = await detector.getTerrainFactor()
            await calculator.updateTerrainFactor(factor)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        await detector.stopDetection()
        
        // Performance expectation: 100 updates should complete in under 1 second
        #expect(duration < 1.0, "100 terrain factor updates should complete quickly")
        
        // Verify final state is consistent
        let finalFactor = calculator.currentTerrainFactor
        #expect(finalFactor == 2.1, "Final terrain factor should match last update (sand)")
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test("Multi-terrain ruck session simulation")
    func testMultiTerrainRuckSession() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        await detector.startDetection()
        
        // Simulate 5-minute ruck session with terrain changes
        let terrainSequence: [(TerrainType, TimeInterval)] = [
            (.pavedRoad, 60),  // 1 minute on pavement
            (.trail, 120),     // 2 minutes on trail
            (.sand, 90),       // 1.5 minutes on sand
            (.trail, 30)       // 30 seconds back to trail
        ]
        
        var totalCalories: Double = 0
        var calculationHistory: [CalorieCalculationResult] = []
        
        for (terrain, duration) in terrainSequence {
            await detector.setManualTerrain(terrain)
            
            let parameters = CalorieCalculationParameters(
                bodyWeight: testBodyWeight,
                loadWeight: testLoadWeight,
                speed: testSpeed,
                grade: testGrade,
                temperature: 20.0,
                altitude: 100.0,
                windSpeed: 0.0,
                terrainMultiplier: await detector.getTerrainFactor(),
                timestamp: Date()
            )
            
            let result = try await calculator.calculateCalories(with: parameters)
            
            // Simulate calories accumulated during this terrain segment
            let segmentCalories = result.metabolicRate * (duration / 60.0)
            totalCalories += segmentCalories
            calculationHistory.append(result)
        }
        
        await detector.stopDetection()
        
        // Verify realistic calorie totals
        #expect(totalCalories > 0, "Should accumulate calories during session")
        #expect(calculationHistory.count == 4, "Should have calculation for each terrain segment")
        
        // Verify terrain factor progression matches expected sequence
        let factors = calculationHistory.map { $0.terrainFactor }
        #expect(factors[0] == 1.0, "First segment should be pavement (1.0)")
        #expect(factors[1] == 1.2, "Second segment should be trail (1.2)")
        #expect(factors[2] == 2.1, "Third segment should be sand (2.1)")
        #expect(factors[3] == 1.2, "Fourth segment should be trail (1.2)")
        
        // Verify sand segment had highest calorie burn rate
        let metabolicRates = calculationHistory.map { $0.metabolicRate }
        let maxRate = metabolicRates.max() ?? 0
        let sandRate = metabolicRates[2]
        #expect(sandRate == maxRate, "Sand segment should have highest calorie burn rate")
    }
    
    @Test("Backward compatibility with legacy CalorieCalculator API")
    func testBackwardCompatibility() async throws {
        let calculator = CalorieCalculator()
        
        // Test legacy API still works
        let locationProvider: @Sendable () async -> (CLLocation?, Double?, TerrainType?) = {
            return (createMockLocation(), testGrade, .trail)
        }
        
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return WeatherData(temperature: 20.0)
        }
        
        // Legacy method call should work without terrain factor provider
        calculator.startContinuousCalculation(
            bodyWeight: testBodyWeight,
            loadWeight: testLoadWeight,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider
        )
        
        try await Task.sleep(for: .seconds(1.5))
        calculator.stopContinuousCalculation()
        
        // Verify it produced results
        #expect(calculator.totalCalories > 0, "Legacy API should still produce calorie calculations")
        #expect(calculator.currentTerrainFactor > 0, "Should have valid terrain factor from legacy API")
    }
}