import Testing
import SwiftUI
@testable import RuckMap

// MARK: - Weather Display View Tests
/// Test suite for WeatherDisplayView component using Swift Testing framework
struct WeatherDisplayViewTests {
    
    // MARK: - Test Data Setup
    
    @Test("Weather Display View initializes correctly")
    func testWeatherDisplayViewInitialization() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 5.0,
            windDirection: 180.0
        )
        
        let weatherView = WeatherDisplayView(
            weatherConditions: conditions,
            showDetailed: true,
            showCalorieImpact: true
        )
        
        #expect(weatherView.weatherConditions != nil)
        #expect(weatherView.showDetailed == true)
        #expect(weatherView.showCalorieImpact == true)
    }
    
    @Test("Weather Display View handles nil weather conditions")
    func testWeatherDisplayViewWithNilConditions() {
        let weatherView = WeatherDisplayView(
            weatherConditions: nil,
            showDetailed: false,
            showCalorieImpact: false
        )
        
        #expect(weatherView.weatherConditions == nil)
        #expect(weatherView.showDetailed == false)
        #expect(weatherView.showCalorieImpact == false)
    }
    
    // MARK: - Weather Conditions Tests
    
    @Test("Temperature color mapping works correctly")
    func testTemperatureColorMapping() {
        // Test extreme cold
        let extremeColdColor = Color.temperatureColor(for: -15.0)
        #expect(extremeColdColor == .temperatureExtreme)
        
        // Test cold
        let coldColor = Color.temperatureColor(for: -5.0)
        #expect(coldColor == .temperatureCold)
        
        // Test comfortable
        let comfortableColor = Color.temperatureColor(for: 20.0)
        #expect(comfortableColor == .temperatureComfortable)
        
        // Test hot
        let hotColor = Color.temperatureColor(for: 40.0)
        #expect(hotColor == .temperatureHot)
        
        // Test extreme hot
        let extremeHotColor = Color.temperatureColor(for: 50.0)
        #expect(extremeHotColor == .temperatureExtreme)
    }
    
    @Test("Weather impact color mapping works correctly")
    func testWeatherImpactColorMapping() {
        let beneficialColor = Color.weatherImpactColor(for: .beneficial)
        #expect(beneficialColor == .weatherBeneficial)
        
        let neutralColor = Color.weatherImpactColor(for: .neutral)
        #expect(neutralColor == .weatherNeutral)
        
        let challengingColor = Color.weatherImpactColor(for: .challenging)
        #expect(challengingColor == .weatherChallenging)
        
        let dangerousColor = Color.weatherImpactColor(for: .dangerous)
        #expect(dangerousColor == .weatherDangerous)
    }
    
    @Test("Weather alert color mapping works correctly")
    func testWeatherAlertColorMapping() {
        let infoColor = Color.weatherAlertColor(for: .info)
        #expect(infoColor == .alertInfo)
        
        let warningColor = Color.weatherAlertColor(for: .warning)
        #expect(warningColor == .alertWarning)
        
        let criticalColor = Color.weatherAlertColor(for: .critical)
        #expect(criticalColor == .alertCritical)
    }
    
    // MARK: - Weather Impact Analysis Tests
    
    @Test("Weather impact analysis calculates correctly for cold conditions")
    func testColdWeatherImpactAnalysis() {
        let coldConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -5.0,
            humidity: 70.0,
            windSpeed: 10.0,
            windDirection: 0.0
        )
        
        let analysis = WeatherImpactAnalysis(conditions: coldConditions)
        
        #expect(analysis.temperatureImpact == .challenging)
        #expect(analysis.windImpact == .neutral)
        #expect(analysis.precipitationImpact == .beneficial)
        #expect(analysis.overallImpact == .challenging)
        #expect(!analysis.recommendations.isEmpty)
    }
    
    @Test("Weather impact analysis calculates correctly for hot conditions")
    func testHotWeatherImpactAnalysis() {
        let hotConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 38.0,
            humidity: 90.0,
            windSpeed: 2.0,
            windDirection: 90.0
        )
        
        let analysis = WeatherImpactAnalysis(conditions: hotConditions)
        
        #expect(analysis.temperatureImpact == .dangerous)
        #expect(analysis.windImpact == .beneficial)
        #expect(analysis.precipitationImpact == .beneficial)
        #expect(analysis.overallImpact == .dangerous)
        #expect(analysis.recommendations.contains { $0.contains("heat") })
    }
    
    @Test("Weather impact analysis calculates correctly for ideal conditions")
    func testIdealWeatherImpactAnalysis() {
        let idealConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 3.0,
            windDirection: 180.0,
            precipitation: 0.0
        )
        
        let analysis = WeatherImpactAnalysis(conditions: idealConditions)
        
        #expect(analysis.temperatureImpact == .beneficial)
        #expect(analysis.windImpact == .beneficial)
        #expect(analysis.precipitationImpact == .beneficial)
        #expect(analysis.overallImpact == .beneficial)
        #expect(analysis.recommendations.contains { $0.contains("favorable") })
    }
    
    @Test("Weather impact analysis handles extreme wind conditions")
    func testExtremeWindImpactAnalysis() {
        let windyConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 15.0,
            humidity: 60.0,
            windSpeed: 25.0,
            windDirection: 270.0
        )
        
        let analysis = WeatherImpactAnalysis(conditions: windyConditions)
        
        #expect(analysis.windImpact == .dangerous)
        #expect(analysis.overallImpact == .dangerous)
        #expect(analysis.recommendations.contains { $0.contains("wind") })
    }
    
    @Test("Weather impact analysis handles precipitation correctly")
    func testPrecipitationImpactAnalysis() {
        let rainyConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 18.0,
            humidity: 95.0,
            windSpeed: 5.0,
            windDirection: 45.0,
            precipitation: 12.0
        )
        
        let analysis = WeatherImpactAnalysis(conditions: rainyConditions)
        
        #expect(analysis.precipitationImpact == .challenging)
        #expect(analysis.recommendations.contains { $0.contains("rain") || $0.contains("precipitation") })
    }
    
    // MARK: - Temperature Adjustment Tests
    
    @Test("Temperature adjustment factor calculates correctly")
    func testTemperatureAdjustmentFactor() {
        // Cold weather should increase calorie burn
        let coldConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -8.0,
            humidity: 50.0
        )
        #expect(coldConditions.temperatureAdjustmentFactor > 1.0)
        
        // Hot weather should increase calorie burn
        let hotConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 32.0,
            humidity: 50.0
        )
        #expect(hotConditions.temperatureAdjustmentFactor > 1.0)
        
        // Moderate weather should have minimal impact
        let moderateConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 18.0,
            humidity: 50.0
        )
        #expect(moderateConditions.temperatureAdjustmentFactor == 1.0)
    }
    
    @Test("Harsh weather conditions are detected correctly")
    func testHarshWeatherDetection() {
        // Extreme cold
        let extremeCold = WeatherConditions(
            timestamp: Date(),
            temperature: -10.0,
            humidity: 50.0
        )
        #expect(extremeCold.isHarshConditions == true)
        
        // Extreme heat
        let extremeHeat = WeatherConditions(
            timestamp: Date(),
            temperature: 40.0,
            humidity: 50.0
        )
        #expect(extremeHeat.isHarshConditions == true)
        
        // High wind
        let highWind = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 20.0
        )
        #expect(highWind.isHarshConditions == true)
        
        // Heavy rain
        let heavyRain = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 90.0,
            precipitation: 15.0
        )
        #expect(heavyRain.isHarshConditions == true)
        
        // Normal conditions
        let normal = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 5.0,
            precipitation: 0.0
        )
        #expect(normal.isHarshConditions == false)
    }
    
    // MARK: - Unit Conversion Tests
    
    @Test("Temperature conversion works correctly")
    func testTemperatureConversion() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 0.0, // 0°C should be 32°F
            humidity: 50.0
        )
        
        #expect(conditions.temperatureFahrenheit == 32.0)
        
        let conditions2 = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // 20°C should be 68°F
            humidity: 50.0
        )
        
        #expect(abs(conditions2.temperatureFahrenheit - 68.0) < 0.1)
    }
    
    @Test("Wind speed conversion works correctly")
    func testWindSpeedConversion() {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 10.0 // 10 m/s should be ~22.37 mph
        )
        
        #expect(abs(conditions.windSpeedMPH - 22.37) < 0.1)
    }
    
    // MARK: - Weather Severity Score Tests
    
    @Test("Weather severity score calculates correctly")
    func testWeatherSeverityScore() {
        // Mild conditions
        let mildConditions = WeatherConditions(
            timestamp: Date(),
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 3.0,
            precipitation: 0.0
        )
        #expect(mildConditions.weatherSeverityScore == 1.0)
        
        // Severe conditions
        let severeConditions = WeatherConditions(
            timestamp: Date(),
            temperature: -15.0, // Extreme cold
            humidity: 90.0,
            windSpeed: 25.0, // High wind
            precipitation: 20.0 // Heavy rain
        )
        #expect(severeConditions.weatherSeverityScore > 1.5)
        #expect(severeConditions.weatherSeverityScore <= 2.0) // Should be capped at 2.0
    }
}

// MARK: - Weather Settings Tests

struct WeatherSettingsTests {
    
    @Test("Weather update frequency enum works correctly")
    func testWeatherUpdateFrequency() {
        #expect(WeatherUpdateFrequency.frequent.interval == 120)
        #expect(WeatherUpdateFrequency.balanced.interval == 300)
        #expect(WeatherUpdateFrequency.conservative.interval == 600)
        
        #expect(WeatherUpdateFrequency.frequent.displayName.contains("2 min"))
        #expect(WeatherUpdateFrequency.balanced.displayName.contains("5 min"))
        #expect(WeatherUpdateFrequency.conservative.displayName.contains("10 min"))
    }
    
    @Test("Weather units enum works correctly")
    func testWeatherUnits() {
        #expect(WeatherUnits.imperial.displayName.contains("°F"))
        #expect(WeatherUnits.imperial.displayName.contains("mph"))
        #expect(WeatherUnits.metric.displayName.contains("°C"))
        #expect(WeatherUnits.metric.displayName.contains("km/h"))
    }
    
    @Test("Battery optimization descriptions are provided")
    func testBatteryOptimizationDescriptions() {
        #expect(!BatteryOptimizationLevel.performance.batteryImpactDescription.isEmpty)
        #expect(!BatteryOptimizationLevel.balanced.batteryImpactDescription.isEmpty)
        #expect(!BatteryOptimizationLevel.maximum.batteryImpactDescription.isEmpty)
    }
}

// MARK: - Weather Alert Tests

struct WeatherAlertTests {
    
    @Test("Weather alert severity has correct icons")
    func testWeatherAlertSeverityIcons() {
        #expect(WeatherAlertSeverity.info.iconName == "info.circle")
        #expect(WeatherAlertSeverity.warning.iconName == "exclamationmark.triangle")
        #expect(WeatherAlertSeverity.critical.iconName == "exclamationmark.octagon")
    }
    
    @Test("Weather alert expiration works correctly")
    func testWeatherAlertExpiration() {
        let activeAlert = WeatherAlert(
            severity: .warning,
            title: "Test Alert",
            message: "Test message",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        #expect(activeAlert.isActive == true)
        
        let expiredAlert = WeatherAlert(
            severity: .info,
            title: "Expired Alert",
            message: "This alert has expired",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            expirationDate: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        #expect(expiredAlert.isActive == false)
        
        let permanentAlert = WeatherAlert(
            severity: .critical,
            title: "Permanent Alert",
            message: "No expiration",
            timestamp: Date(),
            expirationDate: nil
        )
        
        #expect(permanentAlert.isActive == true)
    }
}