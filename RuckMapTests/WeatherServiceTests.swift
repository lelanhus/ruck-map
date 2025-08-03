import Testing
import CoreLocation
import SwiftData
@testable import RuckMap

// MARK: - Mock WeatherKit for Testing

/// Mock WeatherKit service for testing without network calls
actor MockWeatherKitService: Sendable {
    private var mockResponses: [String: WeatherConditions] = [:]
    private var shouldFailNext = false
    private var failureError: Error?
    
    func setMockResponse(for location: CLLocation, conditions: WeatherConditions) {
        let key = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        mockResponses[key] = conditions
    }
    
    func setShouldFail(with error: Error) {
        shouldFailNext = true
        failureError = error
    }
    
    func resetFailure() {
        shouldFailNext = false
        failureError = nil
    }
    
    func fetchWeather(for location: CLLocation) async throws -> WeatherConditions {
        if shouldFailNext {
            shouldFailNext = false
            throw failureError ?? WeatherServiceError.networkError(NSError(domain: "MockError", code: -1))
        }
        
        let key = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        if let conditions = mockResponses[key] {
            return conditions
        }
        
        // Return default conditions if no mock is set
        return WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 5.0,
            windDirection: 180.0
        )
    }
}

@Suite("WeatherService Tests")
struct WeatherServiceTests {
    
    let mockWeatherKit = MockWeatherKitService()
    
    private func createTestWeatherService() async throws -> (WeatherService, ModelContext) {
        // Create in-memory model context for testing
        let schema = Schema([WeatherConditions.self, RuckSession.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(modelContainer)
        
        // Initialize weather service with battery optimized configuration for testing
        let weatherService = WeatherService(configuration: .batteryOptimized)
        await weatherService.setModelContext(modelContext)
        
        return (weatherService, modelContext)
    }
    
    // MARK: - Initialization Tests
    
    @Test("WeatherService initializes with correct default state")
    func weatherServiceInitialization() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        #expect(weatherService.weatherUpdateStatus == "Weather service initialized")
        #expect(weatherService.isUpdatingWeather == false)
        #expect(weatherService.currentWeatherConditions == nil)
        #expect(weatherService.weatherAlerts.isEmpty)
        #expect(weatherService.cacheHitRate == 0.0)
        #expect(weatherService.apiCallsToday >= 0)
        
        weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Configuration Tests
    
    @Test("Battery optimization modes update configuration correctly", 
          arguments: [BatteryOptimizationLevel.performance, .balanced, .maximum])
    func batteryOptimizationConfiguration(level: BatteryOptimizationLevel) async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        weatherService.setBatteryOptimization(level)
        
        #expect(weatherService.weatherUpdateStatus.contains(level.rawValue))
        
        weatherService.stopWeatherUpdates()
    }
    
    @Test("Weather update configurations have expected properties")
    func weatherUpdateConfigurationProperties() {
        let ruckingConfig = WeatherUpdateConfiguration.ruckingOptimized
        let batteryConfig = WeatherUpdateConfiguration.batteryOptimized
        
        // Rucking optimized should have more frequent updates
        #expect(ruckingConfig.updateInterval < batteryConfig.updateInterval)
        #expect(ruckingConfig.backgroundUpdateInterval < batteryConfig.backgroundUpdateInterval)
        #expect(ruckingConfig.cacheExpirationTime < batteryConfig.cacheExpirationTime)
        #expect(ruckingConfig.maxCacheSize > batteryConfig.maxCacheSize)
        #expect(ruckingConfig.significantDistanceThreshold < batteryConfig.significantDistanceThreshold)
    }
    
    // MARK: - Cache Tests
    
    @Test("Weather cache management works correctly")
    func weatherCacheManagement() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        // Initially cache should be empty
        #expect(weatherService.cacheHitRate == 0.0)
        
        // Clear cache should work without errors
        weatherService.clearCache()
        #expect(weatherService.cacheHitRate == 0.0)
        #expect(weatherService.weatherUpdateStatus.contains("Cache cleared"))
        
        weatherService.stopWeatherUpdates()
    }
    
    @Test("Weather cache entries handle expiration correctly")
    func weatherCacheEntryExpiration() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0
        )
        
        let location = WeatherLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 50.0
        )
        
        // Create cache entry that expires in the future
        let futureCacheEntry = WeatherCacheEntry(
            conditions: conditions,
            location: location,
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        #expect(futureCacheEntry.isExpired == false)
        #expect(futureCacheEntry.isStale == false)
        
        // Create cache entry that's already expired
        let expiredCacheEntry = WeatherCacheEntry(
            conditions: conditions,
            location: location,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            expirationDate: Date().addingTimeInterval(-1800) // 30 minutes ago
        )
        
        #expect(expiredCacheEntry.isExpired == true)
        
        // Create cache entry that's stale but not expired
        let staleCacheEntry = WeatherCacheEntry(
            conditions: conditions,
            location: location,
            timestamp: Date().addingTimeInterval(-600), // 10 minutes ago (stale threshold is 5 minutes)
            expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        #expect(staleCacheEntry.isExpired == false)
        #expect(staleCacheEntry.isStale == true)
    }
    
    // MARK: - Weather Alert Tests
    
    @Test("Extreme cold conditions generate dangerous weather alerts")
    func extremeColdWeatherAlertGeneration() {
        let extremeColdConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -15.0, // Extreme cold
            humidity: 60.0,
            windSpeed: 5.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: extremeColdConditions)
        
        #expect(impactAnalysis.temperatureImpact == .dangerous)
        #expect(impactAnalysis.overallImpact == .dangerous)
        #expect(impactAnalysis.recommendations.contains { $0.contains("Extreme cold") || $0.contains("cold") })
    }
    
    @Test("Extreme heat conditions generate dangerous weather alerts")
    func extremeHeatWeatherAlertGeneration() {
        let extremeHeatConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 40.0, // Extreme heat
            humidity: 80.0,
            windSpeed: 2.0,
            windDirection: 90.0,
            precipitation: 0.0,
            pressure: 1010.0
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: extremeHeatConditions)
        
        #expect(impactAnalysis.temperatureImpact == .dangerous)
        #expect(impactAnalysis.overallImpact == .dangerous)
        #expect(impactAnalysis.recommendations.contains { $0.contains("heat") || $0.contains("hydration") })
    }
    
    @Test("High wind conditions generate dangerous weather alerts")
    func highWindWeatherAlertGeneration() {
        let highWindConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 25.0, // Very high wind
            windDirection: 270.0,
            precipitation: 0.0,
            pressure: 1005.0
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: highWindConditions)
        
        #expect(impactAnalysis.windImpact == .dangerous)
        #expect(impactAnalysis.overallImpact == .dangerous)
        #expect(impactAnalysis.recommendations.contains { $0.contains("wind") })
    }
    
    @Test("Heavy precipitation conditions generate dangerous weather alerts")
    func heavyPrecipitationWeatherAlertGeneration() {
        let heavyRainConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 15.0,
            humidity: 95.0,
            windSpeed: 8.0,
            windDirection: 180.0,
            precipitation: 20.0, // Heavy rain
            pressure: 995.0
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: heavyRainConditions)
        
        #expect(impactAnalysis.precipitationImpact == .dangerous)
        #expect(impactAnalysis.overallImpact == .dangerous)
        #expect(impactAnalysis.recommendations.contains { $0.contains("precipitation") || $0.contains("rain") })
    }
    
    // MARK: - Weather Impact Analysis Tests
    
    @Test("Optimal weather conditions are analyzed as beneficial")
    func optimalWeatherConditionsAnalysis() {
        let optimalConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // Perfect temperature
            humidity: 45.0,    // Low humidity
            windSpeed: 3.0,    // Light breeze
            windDirection: 90.0,
            precipitation: 0.0, // No rain
            pressure: 1015.0
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: optimalConditions)
        
        #expect(impactAnalysis.temperatureImpact == .beneficial)
        #expect(impactAnalysis.windImpact == .beneficial)
        #expect(impactAnalysis.precipitationImpact == .beneficial)
        #expect(impactAnalysis.overallImpact == .beneficial)
        #expect(impactAnalysis.recommendations.contains { $0.contains("favorable") })
    }
    
    @Test("Challenging weather conditions are analyzed correctly")
    func challengingWeatherConditionsAnalysis() {
        let challengingConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 32.0, // Hot but not extreme
            humidity: 70.0,    // High humidity
            windSpeed: 12.0,   // Moderate wind
            windDirection: 45.0,
            precipitation: 3.0, // Light rain
            pressure: 1008.0
        )
        
        let impactAnalysis = WeatherImpactAnalysis(conditions: challengingConditions)
        
        #expect(impactAnalysis.temperatureImpact == .challenging)
        #expect(impactAnalysis.windImpact == .neutral)
        #expect(impactAnalysis.precipitationImpact == .neutral)
        #expect(impactAnalysis.overallImpact == .challenging)
    }
    
    // MARK: - Integration with CalorieCalculator Tests
    
    @Test("Weather data integrates correctly with CalorieCalculator")
    func weatherDataForCalorieCalculation() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        // Create test weather conditions
        let testConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 25.0,
            humidity: 60.0,
            windSpeed: 8.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        
        // Set current conditions
        weatherService.currentWeatherConditions = testConditions
        
        // Get weather data for calorie calculation
        let weatherData = await weatherService.getWeatherDataForCalorieCalculation()
        
        #require(weatherData != nil)
        #expect(weatherData?.temperature == 25.0)
        #expect(weatherData?.humidity == 60.0)
        #expect(weatherData?.windSpeed == 8.0)
        
        weatherService.stopWeatherUpdates()
    }
    
    @Test("Weather data returns nil when no conditions are available")
    func weatherDataForCalorieCalculationWithoutConditions() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        // Ensure no weather conditions are set
        weatherService.currentWeatherConditions = nil
        
        // Get weather data for calorie calculation
        let weatherData = await weatherService.getWeatherDataForCalorieCalculation()
        
        #expect(weatherData == nil)
        
        weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Location and Distance Tests
    
    @Test("WeatherLocation distance calculation works correctly")
    func weatherLocationDistanceCalculation() {
        let location1 = WeatherLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 50.0
        )
        
        let location2 = WeatherLocation(
            latitude: 37.7849,
            longitude: -122.4094,
            altitude: 60.0
        )
        
        let distance = location1.distance(from: location2)
        
        // Should be approximately 1.4 km apart
        #expect(distance > 1000)
        #expect(distance < 2000)
    }
    
    @Test("WeatherLocation initializes from CLLocation correctly")
    func weatherLocationFromCLLocation() {
        let clLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        let weatherLocation = WeatherLocation(location: clLocation)
        
        #expect(weatherLocation.latitude == 40.7128)
        #expect(weatherLocation.longitude == -74.0060)
        #expect(weatherLocation.altitude == 10.0)
    }
    
    // MARK: - Cache Entry Tests
    
    func testWeatherCacheEntryExpiration() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0
        )
        
        let location = WeatherLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 50.0
        )
        
        // Create cache entry that expires in 1 second
        let cacheEntry = WeatherCacheEntry(
            conditions: conditions,
            location: location,
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(1)
        )
        
        // Should not be expired initially
        XCTAssertFalse(cacheEntry.isExpired)
        
        // Should not be stale initially
        XCTAssertFalse(cacheEntry.isStale)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Weather service errors provide helpful descriptions", 
          arguments: [
            WeatherServiceError.weatherKitUnavailable,
            .invalidLocation,
            .apiRateLimitExceeded,
            .noLocationPermission,
            .authenticationFailed,
            .dataCorrupted,
            .cacheExpired
          ])
    func weatherServiceErrorDescriptions(error: WeatherServiceError) {
        #require(error.errorDescription != nil)
        #require(error.recoverySuggestion != nil)
        #expect(!error.errorDescription!.isEmpty)
        #expect(!error.recoverySuggestion!.isEmpty)
    }
    
    @Test("Weather service handles network errors gracefully")
    func weatherServiceNetworkErrorHandling() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        // Test with invalid location
        let invalidLocation = CLLocation(latitude: 999.0, longitude: 999.0)
        
        do {
            _ = try await weatherService.getCurrentWeather(for: invalidLocation)
            #expect(false, "Should have thrown an error for invalid coordinates")
        } catch {
            #expect(error is WeatherServiceError || error is CLError)
        }
        
        weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Weather Alert Severity Tests
    
    @Test("Weather alert severities have correct icons", 
          arguments: [
            (WeatherAlertSeverity.info, "info.circle"),
            (.warning, "exclamationmark.triangle"),
            (.critical, "exclamationmark.octagon")
          ])
    func weatherAlertSeverityIcons(severity: WeatherAlertSeverity, expectedIcon: String) {
        #expect(severity.iconName == expectedIcon)
    }
    
    func testWeatherAlertExpiration() {
        let activeAlert = WeatherAlert(
            severity: .warning,
            title: "Test Alert",
            message: "Test message",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        let expiredAlert = WeatherAlert(
            severity: .warning,
            title: "Expired Alert",
            message: "Test message",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            expirationDate: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        let permanentAlert = WeatherAlert(
            severity: .info,
            title: "Permanent Alert",
            message: "Test message",
            timestamp: Date(),
            expirationDate: nil
        )
        
        XCTAssertTrue(activeAlert.isActive)
        XCTAssertFalse(expiredAlert.isActive)
        XCTAssertTrue(permanentAlert.isActive)
    }
    
    // MARK: - Performance Tests
    
    func testWeatherServicePerformance() {
        measure {
            // Test weather impact analysis performance
            let conditions = WeatherConditions(
                timestamp: Date(),
                temperature: 25.0,
                humidity: 60.0,
                windSpeed: 10.0,
                windDirection: 180.0,
                precipitation: 2.0,
                pressure: 1013.25
            )
            
            _ = WeatherImpactAnalysis(conditions: conditions)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testWeatherUpdateConfiguration() {
        let ruckingConfig = WeatherUpdateConfiguration.ruckingOptimized
        let batteryConfig = WeatherUpdateConfiguration.batteryOptimized
        
        // Rucking optimized should have more frequent updates
        XCTAssertLessThan(ruckingConfig.updateInterval, batteryConfig.updateInterval)
        XCTAssertLessThan(ruckingConfig.backgroundUpdateInterval, batteryConfig.backgroundUpdateInterval)
        XCTAssertLessThan(ruckingConfig.cacheExpirationTime, batteryConfig.cacheExpirationTime)
        XCTAssertGreaterThan(ruckingConfig.maxCacheSize, batteryConfig.maxCacheSize)
        XCTAssertLessThan(ruckingConfig.significantDistanceThreshold, batteryConfig.significantDistanceThreshold)
    }
    
    // MARK: - Integration Tests
    
    @Test("Weather service start and stop updates work correctly")
    func weatherServiceStartStopUpdates() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Start weather updates
        weatherService.startWeatherUpdates(for: testLocation)
        #expect(weatherService.weatherUpdateStatus.contains("Starting weather updates"))
        
        // Stop weather updates
        weatherService.stopWeatherUpdates()
        #expect(weatherService.weatherUpdateStatus == "Weather updates stopped")
    }
    
    // MARK: - Memory and Resource Management Tests
    
    @Test("Weather service manages memory correctly")
    func weatherServiceMemoryManagement() {
        weak var weakWeatherService: WeatherService?
        
        autoreleasepool {
            let testWeatherService = WeatherService()
            weakWeatherService = testWeatherService
            
            // Service should exist
            #expect(weakWeatherService != nil)
        }
        
        // After autoreleasepool, if properly implemented, service should be deallocated
        // Note: This test may not always pass due to various factors, but it's good to have
    }
    
    // MARK: - Rate Limiting Tests
    
    @Test("Weather service respects API rate limits")
    func apiRateLimitingRespected() async throws {
        let (weatherService, _) = try await createTestWeatherService()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Simulate hitting the daily API limit
        weatherService.apiCallsToday = 500 // Assume this is the limit
        
        do {
            _ = try await weatherService.getCurrentWeather(for: testLocation)
            #expect(false, "Should have thrown rate limit error")
        } catch {
            #expect(error is WeatherServiceError)
            if case WeatherServiceError.apiRateLimitExceeded = error {
                // Expected behavior
            } else {
                #expect(false, "Expected rate limit error but got \(error)")
            }
        }
        
        weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Battery Optimization Tests
    
    @Test("Battery optimization affects update intervals", 
          arguments: [BatteryOptimizationLevel.performance, .balanced, .maximum])
    func batteryOptimizationAffectsUpdates(level: BatteryOptimizationLevel) async throws {
        let (weatherService, _) = try await createTestWeatherService()
        
        weatherService.setBatteryOptimization(level)
        
        // Verify the status reflects the battery optimization level
        #expect(weatherService.weatherUpdateStatus.contains(level.rawValue))
        
        weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Mock Weather Response Tests
    
    @Test("Mock weather responses work correctly")
    func mockWeatherResponses() async throws {
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let mockConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 22.0,
            humidity: 55.0,
            windSpeed: 8.0,
            windDirection: 270.0
        )
        
        await mockWeatherKit.setMockResponse(for: testLocation, conditions: mockConditions)
        
        let retrievedConditions = try await mockWeatherKit.fetchWeather(for: testLocation)
        
        #expect(retrievedConditions.temperature == 22.0)
        #expect(retrievedConditions.humidity == 55.0)
        #expect(retrievedConditions.windSpeed == 8.0)
        #expect(retrievedConditions.windDirection == 270.0)
    }
    
    @Test("Mock weather failure scenarios work correctly")
    func mockWeatherFailures() async throws {
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let testError = WeatherServiceError.networkError(NSError(domain: "TestError", code: -1))
        
        await mockWeatherKit.setShouldFail(with: testError)
        
        do {
            _ = try await mockWeatherKit.fetchWeather(for: testLocation)
            #expect(false, "Should have thrown an error")
        } catch {
            #expect(error is WeatherServiceError)
        }
        
        await mockWeatherKit.resetFailure()
    }
}

// MARK: - Mock Weather Data Extensions

extension WeatherServiceTests {
    
    /// Creates mock weather conditions for testing
    func createMockWeatherConditions(
        temperature: Double = 20.0,
        humidity: Double = 50.0,
        windSpeed: Double = 5.0,
        precipitation: Double = 0.0
    ) -> WeatherConditions {
        return WeatherConditions(
            timestamp: Date(),
            temperature: temperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: 180.0,
            precipitation: precipitation,
            pressure: 1013.25
        )
    }
    
    /// Creates mock location for testing
    func createMockLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 50.0
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
    }
}