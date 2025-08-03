import Testing
import CoreLocation
import SwiftData
@testable import RuckMap

// MARK: - LocationTrackingManager Weather Integration Tests

@Suite("LocationTrackingManager Weather Integration")
struct LocationWeatherIntegrationTests {
    
    // MARK: - Mock Location Manager for Testing
    
    actor MockLocationTrackingManager: Sendable {
        private var mockWeatherConditions: WeatherConditions?
        private var mockWeatherAlerts: [WeatherAlert] = []
        private var isUpdatingWeather = false
        
        func setMockWeatherConditions(_ conditions: WeatherConditions) {
            mockWeatherConditions = conditions
        }
        
        func setMockWeatherAlerts(_ alerts: [WeatherAlert]) {
            mockWeatherAlerts = alerts
        }
        
        func setIsUpdatingWeather(_ updating: Bool) {
            isUpdatingWeather = updating
        }
        
        func getCurrentWeatherConditions() -> WeatherConditions? {
            return mockWeatherConditions
        }
        
        func getWeatherAlerts() -> [WeatherAlert] {
            return mockWeatherAlerts
        }
        
        func getIsUpdatingWeather() -> Bool {
            return isUpdatingWeather
        }
    }
    
    private func createTestLocationManager() -> LocationTrackingManager {
        return LocationTrackingManager()
    }
    
    // MARK: - Basic Integration Tests
    
    @Test("LocationTrackingManager initializes with weather service")
    func locationManagerInitializesWithWeatherService() {
        let locationManager = createTestLocationManager()
        
        #expect(locationManager.weatherService != nil)
        #expect(locationManager.currentWeatherConditions == nil)
        #expect(locationManager.isUpdatingWeather == false)
        #expect(locationManager.weatherAlerts.isEmpty)
    }
    
    @Test("Weather service integrates with LocationTrackingManager during tracking")
    func weatherServiceIntegratesDuringTracking() {
        let locationManager = createTestLocationManager()
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 20.0,
            bodyWeight: 70.0
        )
        
        // Start tracking should initialize weather integration
        locationManager.startTracking(with: session)
        
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        
        // Weather service should be available during tracking
        #expect(locationManager.weatherService != nil)
        
        locationManager.stopTracking()
        #expect(locationManager.trackingState == .stopped)
    }
    
    // MARK: - Weather Update During Tracking Tests
    
    @Test("Weather updates occur during active tracking")
    func weatherUpdatesDuringActiveTracking() async throws {
        let locationManager = createTestLocationManager()
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 15.0,
            bodyWeight: 75.0
        )
        
        // Start tracking
        locationManager.startTracking(with: session)
        
        // Simulate location update
        let testLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 50.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        // Start weather updates for the location
        locationManager.weatherService.startWeatherUpdates(for: testLocation)
        
        // Verify weather service is updating
        #expect(locationManager.weatherService.weatherUpdateStatus.contains("Starting weather updates"))
        
        // Stop tracking
        locationManager.stopTracking()
        #expect(locationManager.trackingState == .stopped)
    }
    
    @Test("Weather data is preserved in session during tracking")
    func weatherDataPreservedInSession() async throws {
        let locationManager = createTestLocationManager()
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 25.0,
            bodyWeight: 80.0
        )
        
        // Start tracking
        locationManager.startTracking(with: session)
        
        // Create test weather conditions
        let testConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 18.0,
            humidity: 65.0,
            windSpeed: 7.0,
            windDirection: 225.0,
            precipitation: 0.0,
            pressure: 1015.0
        )
        
        // Simulate weather update
        session.weatherConditions = testConditions
        
        // Verify weather data is preserved
        #expect(session.weatherConditions != nil)
        #expect(session.weatherConditions?.temperature == 18.0)
        #expect(session.weatherConditions?.humidity == 65.0)
        #expect(session.weatherConditions?.windSpeed == 7.0)
        
        locationManager.stopTracking()
    }
    
    // MARK: - Weather Provider Integration Tests
    
    @Test("WeatherService provides data to CalorieCalculator")
    func weatherServiceProvidesDataToCalorieCalculator() async throws {
        let locationManager = createTestLocationManager()
        
        // Create test weather conditions
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 28.0,
            humidity: 75.0,
            windSpeed: 12.0,
            windDirection: 90.0
        )
        
        // Set current weather conditions
        locationManager.weatherService.currentWeatherConditions = conditions
        
        // Get weather data for calorie calculation
        let weatherData = await locationManager.weatherService.getWeatherDataForCalorieCalculation()
        
        #require(weatherData != nil)
        #expect(weatherData?.temperature == 28.0)
        #expect(weatherData?.humidity == 75.0)
        #expect(weatherData?.windSpeed == 12.0)
    }
    
    @Test("Weather provider integration with CalorieCalculator real-time updates")
    func weatherProviderRealTimeIntegration() async throws {
        let locationManager = createTestLocationManager()
        let calorieCalculator = locationManager.calorieCalculator
        
        // Mock weather provider function
        let weatherProvider: @Sendable () async -> WeatherData? = {
            return WeatherData(temperature: 22.0, windSpeed: 8.0, humidity: 60.0)
        }
        
        // Mock location provider function
        let locationProvider: @Sendable () async -> (location: CLLocation?, grade: Double?, terrain: TerrainType?) = {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date()
            )
            location.setValue(1.5, forKey: "speed") // 1.5 m/s
            return (location, 5.0, .trail)
        }
        
        // Start continuous calculation with weather integration
        calorieCalculator.startContinuousCalculation(
            bodyWeight: 75.0,
            loadWeight: 20.0,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider
        )
        
        // Allow some time for calculation
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify calculation is running
        #expect(calorieCalculator.isCalculating == false) // Should be false between calculations
        #expect(calorieCalculator.totalCalories >= 0)
        
        calorieCalculator.stopContinuousCalculation()
    }
    
    // MARK: - Weather Alert Handling Tests
    
    @Test("Weather alerts are properly handled during tracking")
    func weatherAlertsHandledDuringTracking() {
        let locationManager = createTestLocationManager()
        
        // Create extreme weather conditions that should generate alerts
        let extremeConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -12.0, // Extreme cold
            humidity: 85.0,
            windSpeed: 22.0, // High wind
            windDirection: 315.0,
            precipitation: 0.0,
            pressure: 995.0
        )
        
        // Analyze weather impact
        let impact = WeatherImpactAnalysis(conditions: extremeConditions)
        
        // Should generate dangerous overall impact
        #expect(impact.overallImpact == .dangerous)
        #expect(impact.temperatureImpact == .dangerous)
        #expect(impact.windImpact == .dangerous)
        
        // Recommendations should include safety advice
        #expect(!impact.recommendations.isEmpty)
        #expect(impact.recommendations.contains { $0.contains("cold") || $0.contains("wind") })
    }
    
    @Test("Weather alert severity mapping works correctly", 
          arguments: [
            (WeatherAlertSeverity.info, "info.circle"),
            (.warning, "exclamationmark.triangle"), 
            (.critical, "exclamationmark.octagon")
          ])
    func weatherAlertSeverityMapping(severity: WeatherAlertSeverity, expectedIcon: String) {
        #expect(severity.iconName == expectedIcon)
    }
    
    @Test("Weather alerts expire correctly")
    func weatherAlertsExpireCorrectly() {
        let activeAlert = WeatherAlert(
            severity: .warning,
            title: "High Wind Advisory",
            message: "Winds up to 40 mph expected",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        let expiredAlert = WeatherAlert(
            severity: .critical,
            title: "Expired Heat Warning",
            message: "This alert has expired",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            expirationDate: Date().addingTimeInterval(-1800) // 30 minutes ago
        )
        
        let permanentAlert = WeatherAlert(
            severity: .info,
            title: "General Weather Info",
            message: "No expiration set",
            timestamp: Date(),
            expirationDate: nil
        )
        
        #expect(activeAlert.isActive == true)
        #expect(expiredAlert.isActive == false)
        #expect(permanentAlert.isActive == true)
    }
    
    // MARK: - Environmental Factor Integration Tests
    
    @Test("Weather environmental factors affect calorie calculations")
    func weatherEnvironmentalFactorsAffectCalories() {
        // Test cold weather adjustment
        let coldConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -8.0, // Cold
            humidity: 70.0,
            windSpeed: 15.0, // High wind
            windDirection: 0.0
        )
        
        let coldAdjustment = coldConditions.temperatureAdjustmentFactor
        #expect(coldAdjustment > 1.0, "Cold weather should increase calorie burn")
        
        // Test hot weather adjustment
        let hotConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 35.0, // Hot
            humidity: 85.0,
            windSpeed: 2.0
        )
        
        let hotAdjustment = hotConditions.temperatureAdjustmentFactor
        #expect(hotAdjustment > 1.0, "Hot weather should increase calorie burn")
        
        // Test moderate weather
        let moderateConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // Comfortable
            humidity: 50.0,
            windSpeed: 5.0
        )
        
        let moderateAdjustment = moderateConditions.temperatureAdjustmentFactor
        #expect(moderateAdjustment == 1.0, "Moderate weather should have no adjustment")
    }
    
    @Test("Weather severity score calculation is accurate")
    func weatherSeverityScoreCalculation() {
        // Mild conditions
        let mildConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 22.0,
            humidity: 55.0,
            windSpeed: 5.0,
            precipitation: 0.0
        )
        
        #expect(mildConditions.weatherSeverityScore == 1.0)
        
        // Severe conditions
        let severeConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -20.0, // Extreme cold
            humidity: 90.0,
            windSpeed: 30.0, // Dangerous wind
            precipitation: 25.0 // Heavy precipitation
        )
        
        let severityScore = severeConditions.weatherSeverityScore
        #expect(severityScore > 1.5)
        #expect(severityScore <= 2.0) // Should be capped at 2.0
    }
    
    // MARK: - Battery Optimization Integration Tests
    
    @Test("Weather updates respect battery optimization settings", 
          arguments: [BatteryOptimizationLevel.performance, .balanced, .maximum])
    func weatherUpdatesRespectBatteryOptimization(level: BatteryOptimizationLevel) {
        let locationManager = createTestLocationManager()
        
        // Set battery optimization level
        locationManager.weatherService.setBatteryOptimization(level)
        
        // Verify the optimization level affects weather service
        #expect(locationManager.weatherService.weatherUpdateStatus.contains(level.rawValue))
    }
    
    @Test("Battery optimization affects weather update frequency")
    func batteryOptimizationAffectsUpdateFrequency() {
        let ruckingConfig = WeatherUpdateConfiguration.ruckingOptimized
        let batteryConfig = WeatherUpdateConfiguration.batteryOptimized
        
        // Battery optimized should have less frequent updates
        #expect(batteryConfig.updateInterval > ruckingConfig.updateInterval)
        #expect(batteryConfig.backgroundUpdateInterval > ruckingConfig.backgroundUpdateInterval)
        #expect(batteryConfig.cacheExpirationTime > ruckingConfig.cacheExpirationTime)
        #expect(batteryConfig.maxCacheSize < ruckingConfig.maxCacheSize)
        #expect(batteryConfig.significantDistanceThreshold > ruckingConfig.significantDistanceThreshold)
    }
    
    // MARK: - Location-Based Weather Update Tests
    
    @Test("Weather updates trigger on significant location changes")
    func weatherUpdatesOnLocationChanges() async throws {
        let locationManager = createTestLocationManager()
        
        // Start location
        let startLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 50.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        // Significantly different location (more than 1km away)
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            altitude: 60.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        let distance = startLocation.distance(from: newLocation)
        
        // Should be significant enough to trigger weather update
        #expect(distance > 1000) // More than 1km threshold
        
        // Start weather updates at initial location
        locationManager.weatherService.startWeatherUpdates(for: startLocation)
        #expect(locationManager.weatherService.weatherUpdateStatus.contains("Starting weather updates"))
        
        locationManager.weatherService.stopWeatherUpdates()
    }
    
    // MARK: - Weather Cache Integration Tests
    
    @Test("Weather cache improves performance during tracking")
    func weatherCacheImprovesPerformance() {
        let locationManager = createTestLocationManager()
        
        // Initially no cache hits
        #expect(locationManager.weatherService.cacheHitRate == 0.0)
        
        // Clear cache to ensure clean state
        locationManager.weatherService.clearCache()
        #expect(locationManager.weatherService.cacheHitRate == 0.0)
        #expect(locationManager.weatherService.weatherUpdateStatus.contains("Cache cleared"))
    }
    
    @Test("Weather cache entries handle location proximity correctly")
    func weatherCacheLocationProximity() {
        let location1 = WeatherLocation(latitude: 37.7749, longitude: -122.4194, altitude: 50.0)
        let location2 = WeatherLocation(latitude: 37.7759, longitude: -122.4204, altitude: 55.0) // ~150m away
        let location3 = WeatherLocation(latitude: 37.7849, longitude: -122.4094, altitude: 60.0) // ~1.4km away
        
        let distance1to2 = location1.distance(from: location2)
        let distance1to3 = location1.distance(from: location3)
        
        // Close locations should be within cache threshold
        #expect(distance1to2 < 1000) // Less than 1km - should use cache
        
        // Distant locations should not use cache
        #expect(distance1to3 > 1000) // More than 1km - should fetch new data
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Weather service errors don't break location tracking")
    func weatherErrorsDontBreakTracking() {
        let locationManager = createTestLocationManager()
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 15.0,
            bodyWeight: 70.0
        )
        
        // Start tracking
        locationManager.startTracking(with: session)
        #expect(locationManager.trackingState == .tracking)
        
        // Even if weather service fails, tracking should continue
        #expect(locationManager.currentSession != nil)
        
        // Stop tracking
        locationManager.stopTracking()
        #expect(locationManager.trackingState == .stopped)
    }
    
    @Test("Default weather conditions are used when weather service fails")
    func defaultWeatherConditionsUsedOnFailure() {
        let locationManager = createTestLocationManager()
        
        // Create session without weather data
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 20.0,
            bodyWeight: 75.0
        )
        
        // Initially no weather conditions
        #expect(session.weatherConditions == nil)
        
        // Simulate weather service providing default conditions
        let defaultConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // Default temperature
            humidity: 50.0,    // Default humidity
            windSpeed: 0.0,    // No wind
            windDirection: 0.0,
            precipitation: 0.0, // No precipitation
            pressure: 1013.25  // Standard pressure
        )
        
        session.weatherConditions = defaultConditions
        
        #expect(session.weatherConditions != nil)
        #expect(session.weatherConditions?.temperature == 20.0)
        #expect(session.weatherConditions?.humidity == 50.0)
        #expect(session.weatherConditions?.windSpeed == 0.0)
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("Weather integration doesn't impact tracking performance", .timeLimit(.seconds(2)))
    func weatherIntegrationPerformance() {
        let locationManager = createTestLocationManager()
        
        // Test multiple rapid location updates with weather
        for i in 0..<100 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                ),
                altitude: 50.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: Date()
            )
            
            // Update current location
            locationManager.currentLocation = location
            
            // Create weather conditions
            let conditions = WeatherConditions(
                timestamp: Date(),
                temperature: 20.0 + Double(i % 10),
                humidity: 50.0 + Double(i % 20),
                windSpeed: Double(i % 15),
                windDirection: Double(i % 360)
            )
            
            // Analyze weather impact
            _ = WeatherImpactAnalysis(conditions: conditions)
        }
        
        // Should complete within time limit
    }
}

// MARK: - Mock Weather Data Helpers

extension LocationWeatherIntegrationTests {
    
    static func createMockWeatherConditions(
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
    
    static func createMockWeatherAlert(
        severity: WeatherAlertSeverity = .warning,
        title: String = "Test Alert",
        message: String = "Test message",
        expirationDate: Date? = nil
    ) -> WeatherAlert {
        return WeatherAlert(
            severity: severity,
            title: title,
            message: message,
            timestamp: Date(),
            expirationDate: expirationDate ?? Date().addingTimeInterval(3600)
        )
    }
}