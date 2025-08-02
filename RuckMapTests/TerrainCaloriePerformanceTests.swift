import Testing
import Foundation
import CoreLocation
@testable import RuckMap

/// Performance tests for CalorieCalculator and TerrainDetector integration
/// Validates system performance under realistic load conditions
struct TerrainCaloriePerformanceTests {
    
    // MARK: - Performance Benchmarks
    
    @Test("Terrain factor update latency performance")
    func testTerrainFactorUpdateLatency() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        await detector.startDetection()
        
        // Measure terrain factor update latency
        let iterations = 50
        var latencies: [TimeInterval] = []
        
        for i in 0..<iterations {
            let terrain: TerrainType = (i % 2 == 0) ? .trail : .sand
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            await detector.setManualTerrain(terrain)
            let factor = await detector.getTerrainFactor()
            await calculator.updateTerrainFactor(factor)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            latencies.append(endTime - startTime)
        }
        
        await detector.stopDetection()
        
        // Calculate performance metrics
        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0
        let minLatency = latencies.min() ?? 0
        
        print("Terrain Factor Update Performance:")
        print("  Average Latency: \(String(format: "%.3f", averageLatency * 1000))ms")
        print("  Max Latency: \(String(format: "%.3f", maxLatency * 1000))ms")
        print("  Min Latency: \(String(format: "%.3f", minLatency * 1000))ms")
        
        // Performance expectations for real-time operation
        #expect(averageLatency < 0.010, "Average terrain factor update should be under 10ms")
        #expect(maxLatency < 0.050, "Maximum terrain factor update should be under 50ms")
    }
    
    @Test("Continuous calculation throughput")
    func testContinuousCalculationThroughput() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        await detector.startDetection()
        
        // Setup providers for high-frequency testing
        var locationCallCount = 0
        let locationProvider: @Sendable () async -> (CLLocation?, Double?, TerrainType?) = {
            locationCallCount += 1
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                course: 0.0,
                speed: 1.34,
                timestamp: Date()
            )
            return (location, 5.0, .trail)
        }
        
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return WeatherData(temperature: 20.0)
        }
        
        var terrainFactorCallCount = 0
        let terrainFactorProvider: @Sendable () async -> Double = {
            terrainFactorCallCount += 1
            return await detector.getTerrainFactor()
        }
        
        // Start continuous calculation
        let startTime = CFAbsoluteTimeGetCurrent()
        
        calculator.startContinuousCalculation(
            bodyWeight: 75.0,
            loadWeight: 20.0,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            terrainFactorProvider: terrainFactorProvider
        )
        
        // Run for 5 seconds to measure throughput
        try await Task.sleep(for: .seconds(5))
        
        calculator.stopContinuousCalculation()
        await detector.stopDetection()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Calculate throughput metrics
        let calculationHistory = calculator.getCalculationHistory()
        let calculationsPerSecond = Double(calculationHistory.count) / duration
        
        print("Continuous Calculation Performance:")
        print("  Duration: \(String(format: "%.2f", duration))s")
        print("  Total Calculations: \(calculationHistory.count)")
        print("  Calculations/Second: \(String(format: "%.1f", calculationsPerSecond))")
        print("  Location Provider Calls: \(locationCallCount)")
        print("  Terrain Factor Provider Calls: \(terrainFactorCallCount)")
        
        // Performance expectations
        #expect(calculationsPerSecond >= 0.8, "Should achieve at least 0.8 calculations per second")
        #expect(calculationHistory.count >= 4, "Should have multiple calculation entries in 5 seconds")
    }
    
    @Test("Memory usage during extended session")
    func testMemoryUsageDuringExtendedSession() async throws {
        let calculator = CalorieCalculator()
        let detector = TerrainDetector()
        
        await detector.startDetection()
        
        // Simulate extended session with frequent terrain changes
        let sessionDuration: TimeInterval = 10 // 10 seconds for testing
        let terrainChangeInterval: TimeInterval = 0.5 // Change terrain every 0.5 seconds
        
        let startTime = Date()
        var changeCount = 0
        
        let sessionTask = Task {
            while Date().timeIntervalSince(startTime) < sessionDuration {
                let terrains: [TerrainType] = [.pavedRoad, .trail, .gravel, .sand, .mud, .snow, .stairs, .grass]
                let terrain = terrains[changeCount % terrains.count]
                
                await detector.setManualTerrain(terrain)
                let factor = await detector.getTerrainFactor()
                await calculator.updateTerrainFactor(factor)
                
                changeCount += 1
                try? await Task.sleep(for: .seconds(terrainChangeInterval))
            }
        }
        
        await sessionTask.value
        await detector.stopDetection()
        
        // Check memory usage indicators
        let terrainHistory = await detector.detectionHistory
        let calculationHistory = calculator.getCalculationHistory()
        
        print("Extended Session Memory Usage:")
        print("  Session Duration: \(String(format: "%.1f", sessionDuration))s")
        print("  Terrain Changes: \(changeCount)")
        print("  Terrain History Count: \(terrainHistory.count)")
        print("  Calculation History Count: \(calculationHistory.count)")
        
        // Memory usage expectations
        #expect(terrainHistory.count <= 100, "Terrain history should be bounded to prevent memory growth")
        #expect(calculationHistory.count <= 1000, "Calculation history should be bounded to prevent memory growth")
        #expect(changeCount > 15, "Should have processed multiple terrain changes")
    }
    
    @Test("Concurrent terrain factor stream performance")
    func testConcurrentTerrainFactorStreamPerformance() async throws {
        let detector = TerrainDetector()
        await detector.startDetection()
        
        var streamUpdates: [(factor: Double, confidence: Double, terrainType: TerrainType)] = []
        let updateLimit = 20
        
        // Start terrain factor stream monitoring
        let streamTask = Task {
            for await update in detector.terrainFactorStream() {
                streamUpdates.append(update)
                if streamUpdates.count >= updateLimit {
                    break
                }
            }
        }
        
        // Generate rapid terrain changes concurrently
        let changeTask = Task {
            let terrains: [TerrainType] = [.pavedRoad, .trail, .sand, .mud, .snow]
            
            for i in 0..<updateLimit {
                let terrain = terrains[i % terrains.count]
                await detector.setManualTerrain(terrain)
                
                // Small delay to allow stream processing
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Wait for both tasks to complete
        await changeTask.value
        await streamTask.value
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        await detector.stopDetection()
        
        // Calculate stream performance metrics
        let updatesPerSecond = Double(streamUpdates.count) / duration
        
        print("Terrain Factor Stream Performance:")
        print("  Duration: \(String(format: "%.2f", duration))s")
        print("  Stream Updates: \(streamUpdates.count)")
        print("  Updates/Second: \(String(format: "%.1f", updatesPerSecond))")
        
        // Performance expectations
        #expect(streamUpdates.count >= updateLimit / 2, "Should receive significant portion of terrain changes")
        #expect(updatesPerSecond > 5.0, "Stream should process updates efficiently")
        #expect(duration < 5.0, "Stream processing should complete quickly")
    }
    
    @Test("Battery optimization impact on performance")
    func testBatteryOptimizationPerformance() async throws {
        let detector = TerrainDetector()
        
        // Test performance in normal mode
        await detector.startDetection()
        detector.setBatteryOptimizedMode(false)
        
        let normalModeStart = CFAbsoluteTimeGetCurrent()
        
        // Perform terrain changes
        for i in 0..<10 {
            let terrain: TerrainType = (i % 2 == 0) ? .trail : .sand
            await detector.setManualTerrain(terrain)
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        let normalModeDuration = CFAbsoluteTimeGetCurrent() - normalModeStart
        await detector.stopDetection()
        
        // Test performance in battery optimized mode
        await detector.startDetection()
        detector.setBatteryOptimizedMode(true)
        
        let batteryModeStart = CFAbsoluteTimeGetCurrent()
        
        // Perform same terrain changes
        for i in 0..<10 {
            let terrain: TerrainType = (i % 2 == 0) ? .trail : .sand
            await detector.setManualTerrain(terrain)
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        let batteryModeDuration = CFAbsoluteTimeGetCurrent() - batteryModeStart
        await detector.stopDetection()
        
        print("Battery Optimization Performance Impact:")
        print("  Normal Mode Duration: \(String(format: "%.3f", normalModeDuration))s")
        print("  Battery Mode Duration: \(String(format: "%.3f", batteryModeDuration))s")
        print("  Performance Delta: \(String(format: "%.1f", (batteryModeDuration / normalModeDuration - 1.0) * 100))%")
        
        // Battery optimization should not significantly impact terrain detection performance
        let performanceRatio = batteryModeDuration / normalModeDuration
        #expect(performanceRatio < 1.5, "Battery optimization should not degrade performance by more than 50%")
    }
    
    @Test("Large calculation history performance")
    func testLargeCalculationHistoryPerformance() async throws {
        let calculator = CalorieCalculator()
        
        // Generate large number of calculations to test history management
        let iterations = 1500 // Exceeds max history size of 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            let parameters = CalorieCalculationParameters(
                bodyWeight: 75.0,
                loadWeight: 20.0,
                speed: 1.34,
                grade: Double(i % 20 - 10), // Vary grade from -10% to +10%
                temperature: 20.0,
                altitude: 100.0,
                windSpeed: 0.0,
                terrainMultiplier: [1.0, 1.2, 1.8, 2.1][i % 4], // Cycle through terrain factors
                timestamp: Date().addingTimeInterval(Double(i))
            )
            
            _ = try await calculator.calculateCalories(with: parameters)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Check history management performance
        let history = calculator.getCalculationHistory()
        let calculationsPerSecond = Double(iterations) / duration
        
        print("Large History Performance:")
        print("  Total Calculations: \(iterations)")
        print("  Duration: \(String(format: "%.2f", duration))s")
        print("  Calculations/Second: \(String(format: "%.0f", calculationsPerSecond))")
        print("  History Size: \(history.count)")
        print("  Total Calories: \(String(format: "%.1f", calculator.totalCalories)) kcal")
        
        // Performance and memory management expectations
        #expect(history.count <= 1000, "History should be bounded to prevent memory growth")
        #expect(calculationsPerSecond > 100, "Should process calculations efficiently")
        #expect(duration < 20.0, "Large number of calculations should complete reasonably quickly")
        #expect(calculator.totalCalories > 0, "Should accumulate calories correctly")
    }
}