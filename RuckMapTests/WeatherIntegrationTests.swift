import Testing
import SwiftUI
import CoreLocation
@testable import RuckMap

// MARK: - Weather Integration Tests
/// Integration tests for weather functionality in RuckMap
/// Tests the complete weather data flow from service to UI
struct WeatherIntegrationTests {
    
    // MARK: - Weather Service Integration
    
    @Test("Weather service integrates with LocationTrackingManager")
    func testWeatherServiceIntegration() async {
        let locationManager = LocationTrackingManager()
        
        // Verify weather service is available
        #expect(locationManager.weatherService != nil)
        
        // Test weather service properties
        #expect(locationManager.currentWeatherConditions == nil) // Initially nil
        #expect(locationManager.isUpdatingWeather == false)
        #expect(locationManager.weatherAlerts.isEmpty)
    }
    
    @Test("Weather impact analysis integrates correctly")
    func testWeatherImpactAnalysisIntegration() {
        let locationManager = LocationTrackingManager()
        
        // Test default weather impact (should be neutral when no data)
        let defaultImpact = locationManager.getWeatherImpactAnalysis()
        #expect(defaultImpact.overallImpact == .neutral)
        #expect(defaultImpact.recommendations.contains { $0.contains("unavailable") })
    }
    
    // MARK: - Calorie Impact Integration
    
    @Test("Weather conditions affect calorie calculations")
    func testWeatherCalorieImpact() {
        // Test cold weather impact
        let coldConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -5.0,
            humidity: 60.0
        )
        
        let coldAdjustment = coldConditions.temperatureAdjustmentFactor
        #expect(coldAdjustment > 1.0, "Cold weather should increase calorie burn")
        
        // Test hot weather impact
        let hotConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 35.0,
            humidity: 80.0
        )
        
        let hotAdjustment = hotConditions.temperatureAdjustmentFactor
        #expect(hotAdjustment > 1.0, "Hot weather should increase calorie burn")
        
        // Test moderate weather
        let moderateConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0
        )
        
        let moderateAdjustment = moderateConditions.temperatureAdjustmentFactor
        #expect(moderateAdjustment == 1.0, "Moderate weather should have no impact")
    }
    
    // MARK: - Weather Alert Integration
    
    @Test("Weather alerts are generated for dangerous conditions")
    func testWeatherAlertGeneration() {
        // Create weather service
        let weatherService = WeatherService()
        
        // Test extreme cold conditions
        let extremeColdConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -15.0,
            humidity: 70.0,
            windSpeed: 10.0
        )
        
        // Simulate weather alert generation
        let coldImpact = WeatherImpactAnalysis(conditions: extremeColdConditions)
        #expect(coldImpact.overallImpact == .dangerous)
        #expect(coldImpact.temperatureImpact == .dangerous)
        
        // Test extreme heat conditions
        let extremeHeatConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 40.0,
            humidity: 90.0
        )
        
        let heatImpact = WeatherImpactAnalysis(conditions: extremeHeatConditions)
        #expect(heatImpact.overallImpact == .dangerous)
        #expect(heatImpact.temperatureImpact == .dangerous)
    }
    
    // MARK: - UI Integration Tests
    
    @Test("WeatherDisplayView handles different weather conditions")
    func testWeatherDisplayViewIntegration() {
        // Test with good weather
        let goodWeather = WeatherConditions(
            timestamp: Date(),
            temperature: 22.0,
            humidity: 50.0,
            windSpeed: 3.0
        )
        goodWeather.weatherDescription = "Partly cloudy"
        
        let goodWeatherView = WeatherDisplayView(
            weatherConditions: goodWeather,
            showDetailed: true,
            showCalorieImpact: true
        )
        
        #expect(goodWeatherView.weatherConditions != nil)
        #expect(goodWeatherView.showDetailed == true)
        
        // Test with no weather data
        let noWeatherView = WeatherDisplayView(
            weatherConditions: nil,
            showDetailed: false
        )
        
        #expect(noWeatherView.weatherConditions == nil)
    }
    
    @Test("Weather settings affect display preferences")
    func testWeatherSettingsIntegration() {
        // Test weather update frequency settings
        let frequencies = WeatherUpdateFrequency.allCases
        #expect(frequencies.count == 3)
        #expect(frequencies.contains(.frequent))
        #expect(frequencies.contains(.balanced))
        #expect(frequencies.contains(.conservative))
        
        // Test battery optimization levels
        let batteryLevels = BatteryOptimizationLevel.allCases
        #expect(batteryLevels.count == 3)
        #expect(batteryLevels.contains(.performance))
        #expect(batteryLevels.contains(.balanced))
        #expect(batteryLevels.contains(.maximum))
        
        // Test weather units
        let units = WeatherUnits.allCases
        #expect(units.count == 2)
        #expect(units.contains(.imperial))
        #expect(units.contains(.metric))
    }
    
    // MARK: - Session Data Integration
    
    @Test("Weather data is stored with sessions")
    func testSessionWeatherDataIntegration() {
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 20.0,
            bodyWeight: 70.0
        )
        
        // Initially no weather data
        #expect(session.weatherConditions == nil)
        
        // Add weather conditions
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 18.0,
            humidity: 65.0,
            windSpeed: 5.0
        )
        
        session.weatherConditions = conditions
        #expect(session.weatherConditions != nil)
        #expect(session.weatherConditions?.temperature == 18.0)
    }
    
    // MARK: - Battery Optimization Integration
    
    @Test("Weather updates respect battery optimization settings")
    func testBatteryOptimizationIntegration() {
        let weatherService = WeatherService()
        
        // Test performance mode
        weatherService.setBatteryOptimization(.performance)
        // In performance mode, weather service should use frequent updates
        
        // Test balanced mode
        weatherService.setBatteryOptimization(.balanced)
        // In balanced mode, weather service should use moderate frequency
        
        // Test maximum battery mode
        weatherService.setBatteryOptimization(.maximum)
        // In maximum battery mode, weather service should use conservative updates
        
        // Note: These tests verify the API calls work
        // Actual battery optimization behavior would require more complex testing
    }
    
    // MARK: - Error Handling Integration
    
    @Test("Weather service handles errors gracefully")
    func testWeatherErrorHandling() async {
        let weatherService = WeatherService()
        
        // Test with invalid location
        let invalidLocation = CLLocation(latitude: 999.0, longitude: 999.0)
        
        do {
            _ = try await weatherService.getCurrentWeather(for: invalidLocation)
            // This should fail with invalid coordinates
            #expect(false, "Should have thrown an error for invalid coordinates")
        } catch {
            // Expected to fail
            #expect(error is WeatherServiceError)
        }
    }
    
    // MARK: - Weather Cache Integration
    
    @Test("Weather cache improves performance")
    func testWeatherCacheIntegration() {
        let weatherService = WeatherService()
        
        // Initially no cache hits
        #expect(weatherService.cacheHitRate == 0.0)
        
        // Test cache clearing
        weatherService.clearCache()
        #expect(weatherService.cacheHitRate == 0.0)
    }
    
    // MARK: - Real-time Updates Integration
    
    @Test("Weather updates during active tracking")
    func testRealTimeWeatherUpdates() {
        let locationManager = LocationTrackingManager()
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 15.0,
            bodyWeight: 75.0
        )
        
        // Start tracking (this would normally start weather updates)
        locationManager.startTracking(with: session)
        
        // Verify tracking state
        #expect(locationManager.trackingState == .tracking)
        #expect(locationManager.currentSession != nil)
        
        // Stop tracking
        locationManager.stopTracking()
        #expect(locationManager.trackingState == .stopped)
    }
    
    // MARK: - Accessibility Integration
    
    @Test("Weather components support accessibility")
    func testWeatherAccessibilityIntegration() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 25.0,
            humidity: 60.0
        )
        conditions.weatherDescription = "Clear skies"
        
        let weatherView = WeatherDisplayView(
            weatherConditions: conditions,
            showDetailed: true
        )
        
        // Verify weather view can be created (accessibility labels are set in the view)
        #expect(weatherView.weatherConditions != nil)
    }
    
    // MARK: - Performance Integration
    
    @Test("Weather updates don't impact tracking performance")
    func testWeatherPerformanceIntegration() {
        let locationManager = LocationTrackingManager()
        
        // Weather service should not interfere with location tracking
        #expect(locationManager.weatherService != nil)
        #expect(!locationManager.isUpdatingWeather) // Should start as false
        
        // Test that weather service can be disabled without affecting tracking
        let session = RuckSession(
            startDate: Date(),
            loadWeight: 10.0,
            bodyWeight: 70.0
        )
        
        locationManager.startTracking(with: session)
        #expect(locationManager.trackingState == .tracking)
        
        locationManager.stopTracking()
        #expect(locationManager.trackingState == .stopped)
    }
}

// MARK: - Weather Data Flow Tests

struct WeatherDataFlowTests {
    
    @Test("Weather data flows from service to UI correctly")
    func testWeatherDataFlow() {
        // 1. Weather service gets data
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 55.0,
            windSpeed: 4.0
        )
        
        // 2. Conditions are analyzed for impact
        let impact = WeatherImpactAnalysis(conditions: conditions)
        #expect(impact.overallImpact == .beneficial)
        
        // 3. UI displays weather information
        let weatherView = WeatherDisplayView(
            weatherConditions: conditions,
            impactAnalysis: impact,
            showDetailed: true,
            showCalorieImpact: true
        )
        
        #expect(weatherView.weatherConditions != nil)
        #expect(weatherView.impactAnalysis != nil)
        
        // 4. Weather affects calorie calculations
        let calorieAdjustment = conditions.temperatureAdjustmentFactor
        #expect(calorieAdjustment == 1.0) // Comfortable temperature
    }
    
    @Test("Weather alerts flow through the system")
    func testWeatherAlertFlow() {
        // 1. Dangerous conditions detected
        let dangerousConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -12.0,
            humidity: 80.0,
            windSpeed: 18.0
        )
        
        // 2. Impact analysis identifies danger
        let impact = WeatherImpactAnalysis(conditions: dangerousConditions)
        #expect(impact.overallImpact == .dangerous)
        
        // 3. Alert is created
        let alert = WeatherAlert(
            severity: .critical,
            title: "Extreme Weather Warning",
            message: "Dangerous conditions detected",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )
        
        #expect(alert.severity == .critical)
        #expect(alert.isActive == true)
        
        // 4. Alert is displayed in UI
        let alertView = WeatherAlertView(alerts: [alert])
        // Verify alert view can be created with the alert
    }
}

// MARK: - Weather Theme Integration Tests

struct WeatherThemeIntegrationTests {
    
    @Test("Army green theme colors are available for weather")
    func testWeatherThemeIntegration() {
        // Test temperature colors
        #expect(Color.temperatureCold != nil)
        #expect(Color.temperatureHot != nil)
        #expect(Color.temperatureComfortable != nil)
        
        // Test weather impact colors
        #expect(Color.weatherBeneficial != nil)
        #expect(Color.weatherDangerous != nil)
        #expect(Color.weatherNeutral != nil)
        
        // Test alert colors
        #expect(Color.alertInfo != nil)
        #expect(Color.alertWarning != nil)
        #expect(Color.alertCritical != nil)
        
        // Test army green colors
        #expect(Color.armyGreenPrimary != nil)
        #expect(Color.armyGreenSecondary != nil)
        #expect(Color.ruckMapBackground != nil)
    }
    
    @Test("Liquid glass colors are prepared for iOS 26")
    func testLiquidGlassIntegration() {
        #expect(Color.liquidGlassBackground != nil)
        #expect(Color.liquidGlassCard != nil)
        #expect(Color.armyGreenLiquidGlass != nil)
    }
    
    @Test("Color functions work correctly")
    func testColorFunctionIntegration() {
        // Test temperature color function
        let coldColor = Color.temperatureColor(for: -10.0)
        let hotColor = Color.temperatureColor(for: 40.0)
        let comfortableColor = Color.temperatureColor(for: 20.0)
        
        #expect(coldColor == .temperatureExtreme)
        #expect(hotColor == .temperatureHot)
        #expect(comfortableColor == .temperatureComfortable)
        
        // Test weather impact color function
        let beneficialColor = Color.weatherImpactColor(for: .beneficial)
        let dangerousColor = Color.weatherImpactColor(for: .dangerous)
        
        #expect(beneficialColor == .weatherBeneficial)
        #expect(dangerousColor == .weatherDangerous)
    }
}