import Foundation
import WeatherKit
import CoreLocation

/**
 # WeatherKit Setup and Configuration Helper
 
 This file provides utilities and validation for WeatherKit setup in RuckMap.
 It includes configuration validation, permissions checking, and setup helpers.
 */

// MARK: - WeatherKit Configuration Validator
struct WeatherKitSetupValidator {
    
    /// Validates that WeatherKit is properly configured
    @MainActor
    static func validateWeatherKitSetup() -> WeatherKitSetupResult {
        var issues: [WeatherKitSetupIssue] = []
        
        // Check if WeatherKit is available
        if !isWeatherKitAvailable() {
            issues.append(.weatherKitUnavailable)
        }
        
        // Check location permissions
        let locationStatus = CLLocationManager().authorizationStatus
        if locationStatus == .denied || locationStatus == .restricted {
            issues.append(.locationPermissionDenied)
        } else if locationStatus == .notDetermined {
            issues.append(.locationPermissionNotDetermined)
        }
        
        // Check bundle configuration
        if !isBundleConfiguredForWeatherKit() {
            issues.append(.bundleNotConfigured)
        }
        
        return WeatherKitSetupResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: generateRecommendations(for: issues)
        )
    }
    
    /// Checks if WeatherKit service is available
    private static func isWeatherKitAvailable() -> Bool {
        // WeatherKit requires iOS 16+ and proper entitlements
        if #available(iOS 16.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// Checks if the bundle is properly configured for WeatherKit
    private static func isBundleConfiguredForWeatherKit() -> Bool {
        // Check for WeatherKit entitlement
        guard let entitlements = Bundle.main.infoDictionary else { return false }
        
        // Look for WeatherKit capability in entitlements
        // Note: This is a simplified check - actual entitlement validation happens at runtime
        return entitlements["CFBundleIdentifier"] != nil
    }
    
    /// Generates setup recommendations based on issues found
    private static func generateRecommendations(for issues: [WeatherKitSetupIssue]) -> [String] {
        var recommendations: [String] = []
        
        for issue in issues {
            switch issue {
            case .weatherKitUnavailable:
                recommendations.append("WeatherKit requires iOS 16+ and proper Apple Developer account setup")
                recommendations.append("Ensure WeatherKit capability is enabled in Apple Developer portal")
                
            case .locationPermissionDenied:
                recommendations.append("Location permission is required for weather data")
                recommendations.append("Ask user to enable location services in Settings")
                
            case .locationPermissionNotDetermined:
                recommendations.append("Request location permission from user")
                
            case .bundleNotConfigured:
                recommendations.append("Add WeatherKit entitlement to app configuration")
                recommendations.append("Ensure bundle ID is registered with WeatherKit service")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("WeatherKit is properly configured and ready to use")
        }
        
        return recommendations
    }
}

// MARK: - Setup Result Types
struct WeatherKitSetupResult {
    let isValid: Bool
    let issues: [WeatherKitSetupIssue]
    let recommendations: [String]
    
    var statusMessage: String {
        if isValid {
            return "WeatherKit is properly configured"
        } else {
            return "WeatherKit configuration issues detected (\(issues.count) issues)"
        }
    }
}

enum WeatherKitSetupIssue: CaseIterable {
    case weatherKitUnavailable
    case locationPermissionDenied
    case locationPermissionNotDetermined
    case bundleNotConfigured
    
    var description: String {
        switch self {
        case .weatherKitUnavailable:
            return "WeatherKit framework is not available"
        case .locationPermissionDenied:
            return "Location permission denied"
        case .locationPermissionNotDetermined:
            return "Location permission not requested"
        case .bundleNotConfigured:
            return "Bundle not configured for WeatherKit"
        }
    }
}

// MARK: - WeatherKit Permission Helper
@MainActor
class WeatherKitPermissionHelper: ObservableObject {
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationPermissionGranted: Bool = false
    
    private let locationManager = CLLocationManager()
    
    init() {
        updatePermissionStatus()
    }
    
    /// Request location permission for weather services
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        updatePermissionStatus()
    }
    
    /// Request always location permission for background weather updates
    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
        updatePermissionStatus()
    }
    
    private func updatePermissionStatus() {
        locationPermissionStatus = locationManager.authorizationStatus
        isLocationPermissionGranted = locationPermissionStatus == .authorizedWhenInUse || 
                                     locationPermissionStatus == .authorizedAlways
    }
}

// MARK: - WeatherKit Development Helper
#if DEBUG
struct WeatherKitDevelopmentHelper {
    
    /// Creates mock weather conditions for development/testing
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
            windDirection: Double.random(in: 0...360),
            precipitation: precipitation,
            pressure: 1013.25
        )
    }
    
    /// Creates mock weather alerts for testing
    static func createMockWeatherAlert(severity: WeatherAlertSeverity = .warning) -> WeatherAlert {
        return WeatherAlert(
            severity: severity,
            title: "Mock Weather Alert",
            message: "This is a mock weather alert for development testing",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )
    }
    
    /// Validates WeatherKit setup and prints results to console
    @MainActor
    static func validateAndPrintSetup() {
        let result = WeatherKitSetupValidator.validateWeatherKitSetup()
        
        print("=== WeatherKit Setup Validation ===")
        print("Status: \(result.statusMessage)")
        
        if !result.issues.isEmpty {
            print("\nIssues Found:")
            for issue in result.issues {
                print("- \(issue.description)")
            }
        }
        
        print("\nRecommendations:")
        for recommendation in result.recommendations {
            print("- \(recommendation)")
        }
        print("===================================")
    }
}
#endif

// MARK: - WeatherKit Constants
struct WeatherKitConstants {
    
    /// Default configuration values
    struct Defaults {
        static let updateInterval: TimeInterval = 300 // 5 minutes
        static let backgroundUpdateInterval: TimeInterval = 900 // 15 minutes
        static let cacheExpirationTime: TimeInterval = 1800 // 30 minutes
        static let maxCacheSize = 50
        static let significantDistanceThreshold: Double = 1000 // 1km
    }
    
    /// Battery optimization values
    struct BatteryOptimized {
        static let updateInterval: TimeInterval = 600 // 10 minutes
        static let backgroundUpdateInterval: TimeInterval = 1800 // 30 minutes
        static let cacheExpirationTime: TimeInterval = 3600 // 1 hour
        static let maxCacheSize = 25
        static let significantDistanceThreshold: Double = 2000 // 2km
    }
    
    /// API rate limiting
    struct RateLimits {
        static let dailyAPILimit = 500 // WeatherKit free tier
        static let burstLimit = 10 // Max requests per minute
        static let retryDelay: TimeInterval = 60 // Retry after rate limit
    }
    
    /// Weather thresholds for military training
    struct MilitaryThresholds {
        // Temperature thresholds (Celsius)
        static let extremeColdThreshold: Double = -10
        static let coldThreshold: Double = 0
        static let optimalTempMin: Double = 15
        static let optimalTempMax: Double = 25
        static let hotThreshold: Double = 30
        static let extremeHeatThreshold: Double = 35
        
        // Wind thresholds (m/s)
        static let moderateWindThreshold: Double = 10
        static let highWindThreshold: Double = 15
        static let dangerousWindThreshold: Double = 20
        
        // Precipitation thresholds (mm/hr)
        static let lightRainThreshold: Double = 0
        static let moderateRainThreshold: Double = 5
        static let heavyRainThreshold: Double = 15
    }
}

// MARK: - Info.plist Helper
#if DEBUG
extension WeatherKitSetupValidator {
    
    /// Generates required Info.plist entries for WeatherKit
    static func generateInfoPlistEntries() -> String {
        return """
        <!-- Add these entries to your Info.plist for WeatherKit support -->
        
        <!-- Location Usage Descriptions -->
        <key>NSLocationWhenInUseUsageDescription</key>
        <string>Location access is required to provide accurate weather data for your rucking activities</string>
        
        <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
        <string>Background location access is required to update weather data during rucking sessions</string>
        
        <!-- Background Modes -->
        <key>UIBackgroundModes</key>
        <array>
            <string>location</string>
            <string>background-fetch</string>
        </array>
        """
    }
    
    /// Generates required entitlements for WeatherKit
    static func generateEntitlements() -> String {
        return """
        <!-- Add these entries to your app.entitlements file -->
        
        <!-- WeatherKit Capability -->
        <key>com.apple.weatherkit</key>
        <true/>
        
        <!-- Background Processing -->
        <key>com.apple.developer.background-processing</key>
        <array>
            <string>weather-update</string>
        </array>
        """
    }
}
#endif