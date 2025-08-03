import Testing
import CoreLocation
@testable import RuckMap

// MARK: - CalorieCalculator Weather Integration Tests

@Suite("CalorieCalculator Weather Integration")
struct CalorieCalculatorWeatherTests {
    
    // MARK: - Mock Weather Data Provider
    
    actor MockWeatherDataProvider: Sendable {
        private var weatherData: WeatherData?
        private var shouldReturnNil = false
        
        func setWeatherData(_ data: WeatherData?) {
            weatherData = data
            shouldReturnNil = (data == nil)
        }
        
        func setShouldReturnNil(_ returnNil: Bool) {
            shouldReturnNil = returnNil
        }
        
        func getWeatherData() async -> WeatherData? {
            if shouldReturnNil {
                return nil
            }
            return weatherData
        }
    }
    
    private func createTestCalorieCalculator() -> CalorieCalculator {
        return CalorieCalculator()
    }
    
    // MARK: - Temperature Factor Tests
    
    @Test("Temperature factor calculations are accurate", 
          arguments: [
            (-15.0, 1.15), // Extreme cold
            (-5.0, 1.15),  // Cold
            (0.0, 1.05),   // Cool
            (15.0, 1.0),   // Comfortable
            (25.0, 1.0),   // Comfortable
            (30.0, 1.05),  // Warm
            (35.0, 1.15),  // Hot
            (40.0, 1.15)   // Extreme hot
          ])
    func temperatureFactorCalculations(temperature: Double, expectedFactor: Double) {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: temperature,
            humidity: 50.0
        )
        
        let actualFactor = conditions.temperatureAdjustmentFactor
        #expect(abs(actualFactor - expectedFactor) < 0.01, 
               "Temperature \(temperature)°C should have factor \(expectedFactor), got \(actualFactor)")
    }
    
    @Test("Apparent temperature calculation includes wind chill")
    func apparentTemperatureWindChill() {
        // Test wind chill conditions (temp ≤ 10°C, wind > 4.8 km/h)
        let coldWindyConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 5.0, // 5°C
            humidity: 60.0,
            windSpeed: 8.0, // 8 m/s = 28.8 km/h > 4.8 km/h
            windDirection: 270.0
        )
        
        let apparentTemp = coldWindyConditions.apparentTemperature
        #expect(apparentTemp < coldWindyConditions.temperature, 
               "Wind chill should make apparent temperature lower than actual")
    }
    
    @Test("Apparent temperature calculation includes heat index")
    func apparentTemperatureHeatIndex() {
        // Test heat index conditions (temp ≥ 27°C)
        let hotHumidConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 30.0, // 30°C = 86°F > 27°C
            humidity: 80.0, // High humidity
            windSpeed: 2.0
        )
        
        let apparentTemp = hotHumidConditions.apparentTemperature
        #expect(apparentTemp > hotHumidConditions.temperature, 
               "Heat index should make apparent temperature higher than actual")
    }
    
    @Test("Moderate temperature conditions have no adjustment")
    func moderateTemperatureNoAdjustment() {
        let comfortableConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // Comfortable temperature
            humidity: 50.0,
            windSpeed: 5.0
        )
        
        #expect(comfortableConditions.temperatureAdjustmentFactor == 1.0)
        #expect(comfortableConditions.apparentTemperature == comfortableConditions.temperature)
    }
    
    // MARK: - Wind Resistance Calculation Tests
    
    @Test("Wind resistance affects calorie calculations", 
          arguments: [
            (0.0, 1.0),   // No wind
            (5.0, 1.0),   // Light wind
            (10.0, 1.05), // Moderate wind
            (15.0, 1.1),  // Strong wind
            (20.0, 1.2)   // Very strong wind
          ])
    func windResistanceFactors(windSpeed: Double, expectedFactor: Double) async throws {
        let calculator = createTestCalorieCalculator()
        
        let parameters = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34, // 3 mph
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: windSpeed,
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        let result = try await calculator.calculateCalories(with: parameters)
        
        // Environmental factor should include wind resistance
        let windFactor = result.environmentalFactor
        #expect(abs(windFactor - expectedFactor) < 0.15, 
               "Wind speed \(windSpeed) m/s should have factor close to \(expectedFactor), got \(windFactor)")
    }
    
    @Test("High wind creates significant calorie increase")
    func highWindSignificantIncrease() async throws {
        let calculator = createTestCalorieCalculator()
        
        // No wind scenario
        let noWindParams = CalorieCalculationParameters(
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
        
        // High wind scenario
        let highWindParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 0.0,
            windSpeed: 20.0, // 20 m/s = 45 mph
            terrainMultiplier: 1.0,
            timestamp: Date().addingTimeInterval(1)
        )
        
        let noWindResult = try await calculator.calculateCalories(with: noWindParams)
        calculator.reset()
        let highWindResult = try await calculator.calculateCalories(with: highWindParams)
        
        #expect(highWindResult.metabolicRate > noWindResult.metabolicRate,
               "High wind should increase metabolic rate")
        
        let increase = (highWindResult.metabolicRate - noWindResult.metabolicRate) / noWindResult.metabolicRate
        #expect(increase > 0.1, "High wind should increase calorie burn by at least 10%")
    }
    
    // MARK: - Environmental Factor Integration Tests
    
    @Test("Multiple environmental factors combine correctly")
    func multipleEnvironmentalFactorsCombine() async throws {
        let calculator = createTestCalorieCalculator()
        
        // Extreme conditions: cold, high wind, high altitude
        let extremeParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 20.0,
            speed: 1.34,
            grade: 0.0,
            temperature: -10.0, // Very cold
            altitude: 2000.0, // High altitude
            windSpeed: 18.0, // Strong wind
            terrainMultiplier: 1.0,
            timestamp: Date()
        )
        
        let result = try await calculator.calculateCalories(with: extremeParams)
        
        // Environmental factor should be significantly > 1.0
        #expect(result.environmentalFactor > 1.3, 
               "Combined extreme conditions should have environmental factor > 1.3, got \(result.environmentalFactor)")
        
        // Temperature adjustment should reflect cold conditions
        #expect(result.environmentalFactor > 1.0)
    }
    
    @Test("Altitude affects calorie calculations correctly")
    func altitudeAffectsCalories() async throws {
        let calculator = createTestCalorieCalculator()
        
        // Sea level
        let seaLevelParams = CalorieCalculationParameters(
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
        
        // High altitude
        let highAltitudeParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.34,
            grade: 0.0,
            temperature: 20.0,
            altitude: 3000.0, // 3000m altitude
            windSpeed: 0.0,
            terrainMultiplier: 1.0,
            timestamp: Date().addingTimeInterval(1)
        )
        
        let seaLevelResult = try await calculator.calculateCalories(with: seaLevelParams)
        calculator.reset()
        let highAltitudeResult = try await calculator.calculateCalories(with: highAltitudeParams)
        
        #expect(highAltitudeResult.metabolicRate > seaLevelResult.metabolicRate,
               "High altitude should increase metabolic rate")
        
        // Should be about 30% increase for 3000m (10% per 1000m)
        let expectedIncrease = 0.25 // Allow some tolerance
        let actualIncrease = (highAltitudeResult.metabolicRate - seaLevelResult.metabolicRate) / seaLevelResult.metabolicRate
        #expect(actualIncrease > expectedIncrease, 
               "High altitude should increase calorie burn by at least \(expectedIncrease * 100)%")
    }
    
    // MARK: - Weather Data Integration Tests
    
    @Test("WeatherData from WeatherConditions conversion works correctly")
    func weatherDataConversionFromConditions() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 25.0,
            humidity: 65.0,
            windSpeed: 12.0,
            windDirection: 180.0
        )
        
        let weatherData = WeatherData(from: conditions)
        
        #expect(weatherData.temperature == 25.0)
        #expect(weatherData.humidity == 65.0)
        #expect(weatherData.windSpeed == 12.0)
    }
    
    @Test("WeatherData optional initializer works correctly")
    func weatherDataOptionalInitializer() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 18.0,
            humidity: 70.0,
            windSpeed: 8.0
        )
        
        let weatherData = WeatherData(from: conditions)
        #require(weatherData != nil)
        #expect(weatherData!.temperature == 18.0)
        #expect(weatherData!.humidity == 70.0)
        #expect(weatherData!.windSpeed == 8.0)
        
        // Test with nil conditions
        let nilWeatherData: WeatherConditions? = nil
        let nilData = WeatherData(from: nilWeatherData)
        #expect(nilData == nil)
    }
    
    @Test("Weather provider integration with continuous calculation")
    func weatherProviderContinuousCalculation() async throws {
        let calculator = createTestCalorieCalculator()
        let mockProvider = MockWeatherDataProvider()
        
        // Set up mock weather data
        let testWeatherData = WeatherData(temperature: 28.0, windSpeed: 10.0, humidity: 75.0)
        await mockProvider.setWeatherData(testWeatherData)
        
        // Mock location provider
        let locationProvider: @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?) = {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date()
            )
            location.setValue(1.5, forKey: "speed")
            return (location, 3.0, .trail)
        }
        
        // Weather provider using mock
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return await mockProvider.getWeatherData()
        }
        
        // Start continuous calculation
        calculator.startContinuousCalculation(
            bodyWeight: 75.0,
            loadWeight: 20.0,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider
        )
        
        // Allow some calculation time
        try await Task.sleep(for: .milliseconds(200))
        
        // Verify calculation is working
        #expect(calculator.totalCalories >= 0)
        #expect(calculator.currentMetabolicRate >= 0)
        
        calculator.stopContinuousCalculation()
    }
    
    @Test("Weather provider returns nil gracefully handles missing data")
    func weatherProviderNilHandling() async throws {
        let calculator = createTestCalorieCalculator()
        let mockProvider = MockWeatherDataProvider()
        
        // Set provider to return nil
        await mockProvider.setShouldReturnNil(true)
        
        let locationProvider: @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?) = {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 50.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date()
            )
            location.setValue(1.2, forKey: "speed")
            return (location, 0.0, .pavedRoad)
        }
        
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return await mockProvider.getWeatherData()
        }
        
        // Should handle nil weather data gracefully
        calculator.startContinuousCalculation(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider
        )
        
        try await Task.sleep(for: .milliseconds(100))
        
        // Should still work without weather data
        #expect(calculator.totalCalories >= 0)
        
        calculator.stopContinuousCalculation()
    }
    
    // MARK: - Weather Impact on Different Terrain Tests
    
    @Test("Weather impact varies by terrain type", 
          arguments: [
            (TerrainType.pavedRoad, 1.0),
            (.trail, 1.2),
            (.sand, 1.8),
            (.snow, 1.5),
            (.mud, 1.85)
          ])
    func weatherImpactByTerrain(terrain: TerrainType, expectedMultiplier: Double) {
        let terrainMultiplier = TerrainDifficultyMultiplier(from: terrain)
        #expect(abs(terrainMultiplier.rawValue - expectedMultiplier) < 0.01)
    }
    
    @Test("Cold weather on difficult terrain compounds calorie burn")
    func coldWeatherDifficultTerrainCompound() async throws {
        let calculator = createTestCalorieCalculator()
        
        // Cold weather on sand (difficult terrain)
        let coldSandParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 20.0,
            speed: 1.2,
            grade: 0.0,
            temperature: -5.0, // Cold
            altitude: 0.0,
            windSpeed: 5.0,
            terrainMultiplier: 1.8, // Sand terrain
            timestamp: Date()
        )
        
        // Warm weather on pavement (easy terrain)  
        let warmPavementParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 20.0,
            speed: 1.2,
            grade: 0.0,
            temperature: 20.0, // Comfortable
            altitude: 0.0,
            windSpeed: 0.0,
            terrainMultiplier: 1.0, // Pavement
            timestamp: Date().addingTimeInterval(1)
        )
        
        let coldSandResult = try await calculator.calculateCalories(with: coldSandParams)
        calculator.reset()
        let warmPavementResult = try await calculator.calculateCalories(with: warmPavementParams)
        
        // Cold weather + difficult terrain should significantly increase calorie burn
        let ratioIncrease = coldSandResult.metabolicRate / warmPavementResult.metabolicRate
        #expect(ratioIncrease > 1.8, 
               "Cold weather on sand should increase calorie burn by at least 80%")
    }
    
    // MARK: - Real-time Weather Adjustment Tests
    
    @Test("Real-time weather changes update calorie calculations")
    func realTimeWeatherChanges() async throws {
        let calculator = createTestCalorieCalculator()
        let mockProvider = MockWeatherDataProvider()
        
        // Start with mild weather
        await mockProvider.setWeatherData(WeatherData(temperature: 20.0, windSpeed: 3.0, humidity: 50.0))
        
        let locationProvider: @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?) = {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 50.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date()
            )
            location.setValue(1.3, forKey: "speed")
            return (location, 0.0, .trail)
        }
        
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return await mockProvider.getWeatherData()
        }
        
        calculator.startContinuousCalculation(
            bodyWeight: 75.0,
            loadWeight: 18.0,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider
        )
        
        // Allow initial calculation
        try await Task.sleep(for: .milliseconds(100))
        let initialRate = calculator.currentMetabolicRate
        
        // Change to extreme weather
        await mockProvider.setWeatherData(WeatherData(temperature: -10.0, windSpeed: 20.0, humidity: 80.0))
        
        // Allow time for weather change to take effect
        try await Task.sleep(for: .milliseconds(200))
        let extremeWeatherRate = calculator.currentMetabolicRate
        
        calculator.stopContinuousCalculation()
        
        // Extreme weather should increase metabolic rate
        #expect(extremeWeatherRate > initialRate, 
               "Extreme weather should increase metabolic rate from \(initialRate) to \(extremeWeatherRate)")
    }
    
    // MARK: - Performance Tests
    
    @Test("Weather calculations don't impact performance", .timeLimit(.seconds(1)))
    func weatherCalculationPerformance() async throws {
        let calculator = createTestCalorieCalculator()
        
        // Test 100 calculations with different weather conditions
        for i in 0..<100 {
            let params = CalorieCalculationParameters(
                bodyWeight: 70.0,
                loadWeight: 15.0,
                speed: 1.3,
                grade: Double(i % 10) - 5.0, // -5 to 4 percent grade
                temperature: Double(i % 40) - 10.0, // -10 to 29°C
                altitude: Double(i % 20) * 100, // 0 to 1900m
                windSpeed: Double(i % 25), // 0 to 24 m/s
                terrainMultiplier: 1.0 + Double(i % 10) * 0.1, // 1.0 to 1.9
                timestamp: Date().addingTimeInterval(Double(i))
            )
            
            _ = try await calculator.calculateCalories(with: params)
        }
        
        // Should complete within time limit
        #expect(calculator.totalCalories > 0)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Extreme weather values are handled correctly")
    func extremeWeatherValuesHandling() async throws {
        let calculator = createTestCalorieCalculator()
        
        // Extreme values that might occur in real conditions
        let extremeParams = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 15.0,
            speed: 1.0,
            grade: 0.0,
            temperature: -40.0, // Extreme cold
            altitude: 5000.0, // High altitude
            windSpeed: 50.0, // Hurricane-force wind
            terrainMultiplier: 2.0, // Extreme terrain
            timestamp: Date()
        )
        
        // Should not throw or produce invalid results
        let result = try await calculator.calculateCalories(with: extremeParams)
        
        #expect(result.metabolicRate.isFinite)
        #expect(result.metabolicRate > 0)
        #expect(result.environmentalFactor.isFinite)
        #expect(result.environmentalFactor > 0)
    }
    
    @Test("Weather calculation confidence intervals are reasonable")
    func weatherCalculationConfidenceIntervals() async throws {
        let calculator = createTestCalorieCalculator()
        
        let params = CalorieCalculationParameters(
            bodyWeight: 70.0,
            loadWeight: 20.0,
            speed: 1.5,
            grade: 5.0,
            temperature: 25.0,
            altitude: 1000.0,
            windSpeed: 10.0,
            terrainMultiplier: 1.3,
            timestamp: Date()
        )
        
        let result = try await calculator.calculateCalories(with: params)
        
        // Confidence interval should be ±10% of metabolic rate
        let expectedRange = result.metabolicRate * 0.10
        let actualRange = result.upperBound - result.lowerBound
        
        #expect(abs(actualRange - (expectedRange * 2)) < 0.1, 
               "Confidence interval should be ±10% of metabolic rate")
        
        // Range should be reasonable (not too wide or narrow)
        #expect(result.confidenceRangePercent > 15.0 && result.confidenceRangePercent < 25.0,
               "Confidence range should be between 15-25%")
    }
    
    // MARK: - Weather Severity Integration
    
    @Test("Weather severity affects calorie multipliers correctly")
    func weatherSeverityAffectsMultipliers() {
        // Mild weather - low severity
        let mildConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 22.0,
            humidity: 50.0,
            windSpeed: 3.0,
            precipitation: 0.0
        )
        
        #expect(mildConditions.weatherSeverityScore == 1.0)
        #expect(mildConditions.temperatureAdjustmentFactor == 1.0)
        
        // Severe weather - high severity
        let severeConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -15.0, // Extreme cold
            humidity: 90.0,
            windSpeed: 25.0, // High wind
            precipitation: 20.0 // Heavy rain
        )
        
        #expect(severeConditions.weatherSeverityScore > 1.5)
        #expect(severeConditions.temperatureAdjustmentFactor > 1.0)
        #expect(severeConditions.isHarshConditions == true)
    }
}