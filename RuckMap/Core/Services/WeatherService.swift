import Foundation
import WeatherKit
import CoreLocation
import SwiftData
import Observation
import UIKit

// MARK: - Weather Service Errors
enum WeatherServiceError: LocalizedError, Sendable {
    case weatherKitUnavailable
    case invalidLocation
    case apiRateLimitExceeded
    case noLocationPermission
    case networkError(Error)
    case authenticationFailed
    case dataCorrupted
    case cacheExpired
    
    var errorDescription: String? {
        switch self {
        case .weatherKitUnavailable:
            return "WeatherKit service is unavailable"
        case .invalidLocation:
            return "Invalid location coordinates"
        case .apiRateLimitExceeded:
            return "WeatherKit API rate limit exceeded"
        case .noLocationPermission:
            return "Location permission required for weather data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "WeatherKit authentication failed"
        case .dataCorrupted:
            return "Weather data corrupted"
        case .cacheExpired:
            return "Cached weather data expired"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .weatherKitUnavailable:
            return "Check internet connection and try again"
        case .invalidLocation:
            return "Ensure GPS is enabled and try again"
        case .apiRateLimitExceeded:
            return "Weather updates temporarily limited. Using cached data."
        case .noLocationPermission:
            return "Enable location services in Settings"
        case .networkError:
            return "Check internet connection"
        case .authenticationFailed:
            return "Contact support if problem persists"
        case .dataCorrupted:
            return "Clear app cache and try again"
        case .cacheExpired:
            return "Updating weather data..."
        }
    }
}

// MARK: - Lightweight Weather Data for Caching
struct CachedWeatherData: Codable, Sendable {
    let timestamp: Date
    let temperature: Double // Celsius
    let humidity: Double // percentage (0-100)
    let windSpeed: Double // m/s
    let windDirection: Double // degrees
    let precipitation: Double // mm/hr
    let pressure: Double // hPa
    let weatherDescription: String?
    let conditionCode: String?
    
    init(from conditions: WeatherConditions) {
        self.timestamp = conditions.timestamp
        self.temperature = conditions.temperature
        self.humidity = conditions.humidity
        self.windSpeed = conditions.windSpeed
        self.windDirection = conditions.windDirection
        self.precipitation = conditions.precipitation
        self.pressure = conditions.pressure
        self.weatherDescription = conditions.weatherDescription
        self.conditionCode = conditions.conditionCode
    }
    
    func toWeatherConditions() -> WeatherConditions {
        let conditions = WeatherConditions(
            timestamp: timestamp,
            temperature: temperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            precipitation: precipitation,
            pressure: pressure
        )
        conditions.weatherDescription = weatherDescription
        conditions.conditionCode = conditionCode
        return conditions
    }
}

// MARK: - Weather Cache Entry
struct WeatherCacheEntry: Codable, Sendable {
    let conditions: CachedWeatherData
    let location: WeatherLocation
    let timestamp: Date
    let expirationDate: Date
    
    var isExpired: Bool {
        Date() > expirationDate
    }
    
    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}

// MARK: - Weather Location
struct WeatherLocation: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
    }
    
    func distance(from other: WeatherLocation) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Weather Update Configuration
struct WeatherUpdateConfiguration: Sendable {
    let updateInterval: TimeInterval
    let backgroundUpdateInterval: TimeInterval
    let cacheExpirationTime: TimeInterval
    let maxCacheSize: Int
    let significantDistanceThreshold: Double // meters
    
    static let ruckingOptimized = WeatherUpdateConfiguration(
        updateInterval: 300, // 5 minutes during active tracking
        backgroundUpdateInterval: 900, // 15 minutes in background
        cacheExpirationTime: 1800, // 30 minutes cache expiration
        maxCacheSize: 50, // Cache up to 50 weather entries
        significantDistanceThreshold: 1000 // 1km threshold for location-based updates
    )
    
    static let batteryOptimized = WeatherUpdateConfiguration(
        updateInterval: 600, // 10 minutes during active tracking
        backgroundUpdateInterval: 1800, // 30 minutes in background
        cacheExpirationTime: 3600, // 1 hour cache expiration
        maxCacheSize: 25, // Smaller cache
        significantDistanceThreshold: 2000 // 2km threshold
    )
}

// MARK: - Weather Alert
struct WeatherAlert: Sendable {
    let severity: WeatherAlertSeverity
    let title: String
    let message: String
    let timestamp: Date
    let expirationDate: Date?
    
    var isActive: Bool {
        if let expiration = expirationDate {
            return Date() < expiration
        }
        return true
    }
}

enum WeatherAlertSeverity: String, CaseIterable, Sendable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    
    var iconName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Weather Service
@MainActor
@Observable
final class WeatherService {
    
    // MARK: - Published Properties
    private(set) var currentWeatherConditions: WeatherConditions?
    private(set) var isUpdatingWeather: Bool = false
    private(set) var lastWeatherUpdate: Date?
    private(set) var weatherAlerts: [WeatherAlert] = []
    private(set) var cacheHitRate: Double = 0.0
    private(set) var apiCallsToday: Int = 0
    private(set) var weatherUpdateStatus: String = "Initializing..."
    
    // MARK: - Private Properties
    private let weatherKitService = WeatherKit.WeatherService.shared
    private var weatherCache: [String: WeatherCacheEntry] = [:]
    private var configuration: WeatherUpdateConfiguration
    private var weatherUpdateTask: Task<Void, Never>?
    private var lastKnownLocation: WeatherLocation?
    private var modelContext: ModelContext?
    
    // Rate limiting
    private let dailyAPILimit = 500 // WeatherKit free tier limit
    private var lastAPIResetDate = Date()
    private let maxCacheAge: TimeInterval = 1800 // 30 minutes
    
    // Statistics
    private var cacheHits = 0
    private var cacheMisses = 0
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    init(configuration: WeatherUpdateConfiguration = .ruckingOptimized) {
        self.configuration = configuration
        setupWeatherService()
        loadCachedData()
    }
    
    deinit {
        // Cleanup will happen when the instance is deallocated
        // Tasks are automatically cancelled
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupWeatherService() {
        // WeatherKit requires proper entitlements and bundle configuration
        // The service is automatically configured via WeatherKit framework
        weatherUpdateStatus = "Weather service initialized"
    }
    
    private func loadCachedData() {
        // Load cached weather data from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "weatherCache"),
           let cache = try? JSONDecoder().decode([String: WeatherCacheEntry].self, from: data) {
            weatherCache = cache
        }
        
        // Load API call count for today
        let lastReset = UserDefaults.standard.object(forKey: "lastAPIReset") as? Date ?? Date()
        if Calendar.current.isDate(lastReset, inSameDayAs: Date()) {
            apiCallsToday = UserDefaults.standard.integer(forKey: "apiCallsToday")
        } else {
            // Reset for new day
            apiCallsToday = 0
            lastAPIResetDate = Date()
            UserDefaults.standard.set(Date(), forKey: "lastAPIReset")
            UserDefaults.standard.set(0, forKey: "apiCallsToday")
        }
        
        updateCacheHitRate()
    }
    
    private func saveCachedData() {
        // Save weather cache to UserDefaults
        if let data = try? JSONEncoder().encode(weatherCache) {
            UserDefaults.standard.set(data, forKey: "weatherCache")
        }
        
        // Save API call count
        UserDefaults.standard.set(apiCallsToday, forKey: "apiCallsToday")
    }
    
    // MARK: - Public Interface
    
    /// Starts weather updates for an active rucking session
    func startWeatherUpdates(for location: CLLocation) {
        stopWeatherUpdates()
        
        lastKnownLocation = WeatherLocation(location: location)
        weatherUpdateStatus = "Starting weather updates..."
        
        weatherUpdateTask = Task { @MainActor in
            await performInitialWeatherUpdate(for: location)
            await startPeriodicWeatherUpdates()
        }
    }
    
    /// Stops weather updates
    func stopWeatherUpdates() {
        weatherUpdateTask?.cancel()
        weatherUpdateTask = nil
        endBackgroundTask()
        weatherUpdateStatus = "Weather updates stopped"
    }
    
    /// Gets current weather data with location and caching support
    func getCurrentWeather(for location: CLLocation) async throws -> WeatherConditions {
        isUpdatingWeather = true
        weatherUpdateStatus = "Fetching weather data..."
        defer { 
            isUpdatingWeather = false
        }
        
        let weatherLocation = WeatherLocation(location: location)
        let cacheKey = generateCacheKey(for: weatherLocation)
        
        // Try cache first
        if let cachedEntry = weatherCache[cacheKey],
           !cachedEntry.isExpired,
           weatherLocation.distance(from: cachedEntry.location) < configuration.significantDistanceThreshold {
            
            cacheHits += 1
            updateCacheHitRate()
            weatherUpdateStatus = "Using cached weather data"
            return cachedEntry.conditions.toWeatherConditions()
        }
        
        // Check rate limiting
        guard apiCallsToday < dailyAPILimit else {
            // Try to find any valid cached data within reasonable distance
            if let fallbackEntry = findNearestValidCacheEntry(for: weatherLocation) {
                weatherUpdateStatus = "Rate limited - using cached data"
                return fallbackEntry.conditions.toWeatherConditions()
            }
            throw WeatherServiceError.apiRateLimitExceeded
        }
        
        // Fetch from WeatherKit
        do {
            // Fetch and convert weather data in one step to avoid crossing isolation boundaries
            let conditions = try await fetchAndConvertWeather(for: location, weatherLocation: weatherLocation)
            
            // Cache the result
            cacheWeatherData(conditions, location: weatherLocation)
            
            // Update statistics
            cacheMisses += 1
            apiCallsToday += 1
            updateCacheHitRate()
            saveCachedData()
            
            weatherUpdateStatus = "Weather data updated"
            return conditions
            
        } catch {
            // If API fails, try cached data as fallback
            if let fallbackEntry = findNearestValidCacheEntry(for: weatherLocation) {
                weatherUpdateStatus = "API failed - using cached data"
                return fallbackEntry.conditions.toWeatherConditions()
            }
            
            weatherUpdateStatus = "Weather update failed"
            throw WeatherServiceError.networkError(error)
        }
    }
    
    /// Updates weather for current session with automatic caching and error handling
    func updateWeatherForCurrentSession(location: CLLocation, session: RuckSession) async {
        do {
            let conditions = try await getCurrentWeather(for: location)
            
            // Update session weather data
            session.weatherConditions = conditions
            currentWeatherConditions = conditions
            lastWeatherUpdate = Date()
            
            // Check for weather alerts
            checkForWeatherAlerts(conditions)
            
            // Save context if available
            try? modelContext?.save()
            
        } catch {
            print("Weather update failed: \(error.localizedDescription)")
            
            // Create default weather conditions if no data available
            if session.weatherConditions == nil {
                let defaultConditions = createDefaultWeatherConditions(for: location)
                session.weatherConditions = defaultConditions
                currentWeatherConditions = defaultConditions
            }
        }
    }
    
    /// Provides weather data to CalorieCalculator with intelligent caching
    func getWeatherDataForCalorieCalculation() async -> WeatherData? {
        guard let conditions = currentWeatherConditions else {
            return nil
        }
        
        return WeatherData(from: conditions)
    }
    
    /// Sets battery optimization level
    func setBatteryOptimization(_ level: BatteryOptimizationLevel) {
        switch level {
        case .maximum:
            configuration = .batteryOptimized
        case .balanced, .performance:
            configuration = .ruckingOptimized
        }
        
        weatherUpdateStatus = "Battery optimization: \(level.rawValue)"
    }
    
    /// Gets weather impact on rucking performance
    func getWeatherImpactAnalysis() -> WeatherImpactAnalysis {
        guard let conditions = currentWeatherConditions else {
            return WeatherImpactAnalysis.neutral
        }
        
        return WeatherImpactAnalysis(conditions: conditions)
    }
    
    /// Clears weather cache
    func clearCache() {
        weatherCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        updateCacheHitRate()
        saveCachedData()
        weatherUpdateStatus = "Cache cleared"
    }
    
    // MARK: - Private Implementation
    
    private func performInitialWeatherUpdate(for location: CLLocation) async {
        do {
            let conditions = try await getCurrentWeather(for: location)
            currentWeatherConditions = conditions
            lastWeatherUpdate = Date()
            weatherUpdateStatus = "Initial weather data loaded"
        } catch {
            print("Initial weather update failed: \(error)")
            weatherUpdateStatus = "Initial weather update failed"
        }
    }
    
    private func startPeriodicWeatherUpdates() async {
        while !Task.isCancelled {
            do {
                // Wait for update interval
                try await Task.sleep(for: .seconds(configuration.updateInterval))
                
                guard let lastLocation = lastKnownLocation else { continue }
                
                // Start background task for weather update
                beginBackgroundTask()
                
                let location = CLLocation(
                    latitude: lastLocation.latitude,
                    longitude: lastLocation.longitude
                )
                
                let conditions = try await getCurrentWeather(for: location)
                currentWeatherConditions = conditions
                lastWeatherUpdate = Date()
                
                endBackgroundTask()
                
            } catch {
                print("Periodic weather update failed: \(error)")
                endBackgroundTask()
                
                // Continue with exponential backoff on failure
                try? await Task.sleep(for: .seconds(min(configuration.updateInterval * 2, 1800)))
            }
        }
    }
    
    private func fetchAndConvertWeather(for location: CLLocation, weatherLocation: WeatherLocation) async throws -> WeatherConditions {
        do {
            // Fetch and immediately convert to avoid Weather sendability issues
            let weather = try await weatherKitService.weather(for: location)
            return convertToWeatherConditions(weather, location: weatherLocation)
        } catch {
            print("WeatherKit API error: \(error)")
            throw error
        }
    }
    
    private func convertToWeatherConditions(_ weather: Weather, location: WeatherLocation) -> WeatherConditions {
        let currentWeather = weather.currentWeather
        
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: currentWeather.temperature.value,
            humidity: currentWeather.humidity * 100, // Convert to percentage
            windSpeed: currentWeather.wind.speed.value,
            windDirection: currentWeather.wind.direction.value,
            precipitation: 0, // CurrentWeather doesn't have precipitation - use forecast if needed
            pressure: currentWeather.pressure.value
        )
        
        conditions.weatherDescription = currentWeather.condition.description
        conditions.conditionCode = String(currentWeather.condition.rawValue)
        
        return conditions
    }
    
    private func generateCacheKey(for location: WeatherLocation) -> String {
        // Round coordinates to reduce cache fragmentation
        let lat = round(location.latitude * 1000) / 1000
        let lon = round(location.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
    
    private func cacheWeatherData(_ conditions: WeatherConditions, location: WeatherLocation) {
        let cacheKey = generateCacheKey(for: location)
        let expirationDate = Date().addingTimeInterval(configuration.cacheExpirationTime)
        
        let entry = WeatherCacheEntry(
            conditions: CachedWeatherData(from: conditions),
            location: location,
            timestamp: Date(),
            expirationDate: expirationDate
        )
        
        weatherCache[cacheKey] = entry
        
        // Manage cache size
        if weatherCache.count > configuration.maxCacheSize {
            cleanupExpiredCacheEntries()
        }
    }
    
    private func cleanupExpiredCacheEntries() {
        let now = Date()
        weatherCache = weatherCache.filter { _, entry in
            !entry.isExpired
        }
        
        // If still too large, remove oldest entries
        if weatherCache.count > configuration.maxCacheSize {
            let sortedEntries = weatherCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(weatherCache.count - configuration.maxCacheSize)
            
            for (key, _) in entriesToRemove {
                weatherCache.removeValue(forKey: key)
            }
        }
    }
    
    private func findNearestValidCacheEntry(for location: WeatherLocation) -> WeatherCacheEntry? {
        let validEntries = weatherCache.values.filter { !$0.isExpired }
        
        guard !validEntries.isEmpty else { return nil }
        
        // Find entry with minimum distance
        let nearestEntry = validEntries.min { entry1, entry2 in
            location.distance(from: entry1.location) < location.distance(from: entry2.location)
        }
        
        // Only return if within reasonable distance (5km)
        if let entry = nearestEntry,
           location.distance(from: entry.location) < 5000 {
            return entry
        }
        
        return nil
    }
    
    private func updateCacheHitRate() {
        let totalRequests = cacheHits + cacheMisses
        cacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0
    }
    
    private func createDefaultWeatherConditions(for location: CLLocation) -> WeatherConditions {
        // Create reasonable default conditions when weather data is unavailable
        return WeatherConditions(
            timestamp: Date(),
            temperature: 20.0, // 20°C default
            humidity: 50.0,    // 50% humidity
            windSpeed: 0.0,    // No wind
            windDirection: 0.0,
            precipitation: 0.0, // No precipitation
            pressure: 1013.25  // Standard atmospheric pressure
        )
    }
    
    private func checkForWeatherAlerts(_ conditions: WeatherConditions) {
        weatherAlerts.removeAll { !$0.isActive }
        
        // Temperature alerts
        if conditions.temperature < -10 {
            let alert = WeatherAlert(
                severity: .critical,
                title: "Extreme Cold Warning",
                message: "Temperature is \(Int(conditions.temperatureFahrenheit))°F. Risk of frostbite and hypothermia.",
                timestamp: Date(),
                expirationDate: Date().addingTimeInterval(3600)
            )
            if !weatherAlerts.contains(where: { $0.title == alert.title }) {
                weatherAlerts.append(alert)
            }
        } else if conditions.temperature > 35 {
            let alert = WeatherAlert(
                severity: .critical,
                title: "Extreme Heat Warning",
                message: "Temperature is \(Int(conditions.temperatureFahrenheit))°F. Risk of heat exhaustion.",
                timestamp: Date(),
                expirationDate: Date().addingTimeInterval(3600)
            )
            if !weatherAlerts.contains(where: { $0.title == alert.title }) {
                weatherAlerts.append(alert)
            }
        }
        
        // Wind alerts
        if conditions.windSpeed > 15 {
            let windMph = Int(conditions.windSpeedMPH)
            let alert = WeatherAlert(
                severity: .warning,
                title: "High Wind Warning",
                message: "Wind speed is \(windMph) mph. Exercise caution.",
                timestamp: Date(),
                expirationDate: Date().addingTimeInterval(1800)
            )
            if !weatherAlerts.contains(where: { $0.title == alert.title }) {
                weatherAlerts.append(alert)
            }
        }
        
        // Precipitation alerts
        if conditions.precipitation > 10 {
            let alert = WeatherAlert(
                severity: .warning,
                title: "Heavy Precipitation",
                message: "Heavy rain detected. Consider postponing outdoor activities.",
                timestamp: Date(),
                expirationDate: Date().addingTimeInterval(1800)
            )
            if !weatherAlerts.contains(where: { $0.title == alert.title }) {
                weatherAlerts.append(alert)
            }
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}

// MARK: - Weather Impact Analysis
struct WeatherImpactAnalysis: Sendable {
    let temperatureImpact: ImpactLevel
    let windImpact: ImpactLevel
    let precipitationImpact: ImpactLevel
    let overallImpact: ImpactLevel
    let recommendations: [String]
    
    enum ImpactLevel: String, CaseIterable, Sendable {
        case beneficial = "beneficial"
        case neutral = "neutral"
        case challenging = "challenging"
        case dangerous = "dangerous"
        
        var description: String {
            switch self {
            case .beneficial: return "Beneficial"
            case .neutral: return "Neutral"
            case .challenging: return "Challenging"
            case .dangerous: return "Dangerous"
            }
        }
        
        var color: String {
            switch self {
            case .beneficial: return "green"
            case .neutral: return "blue"
            case .challenging: return "orange"
            case .dangerous: return "red"
            }
        }
    }
    
    static let neutral = WeatherImpactAnalysis(conditions: WeatherConditions(
        timestamp: Date(),
        temperature: 20.0,
        humidity: 50.0,
        windSpeed: 0,
        windDirection: 0,
        precipitation: 0,
        pressure: 1013.25
    ))
    
    init(conditions: WeatherConditions) {
        // Temperature impact analysis
        temperatureImpact = {
            if conditions.temperature < -10 || conditions.temperature > 35 {
                return .dangerous
            } else if conditions.temperature < 0 || conditions.temperature > 30 {
                return .challenging
            } else if conditions.temperature >= 15 && conditions.temperature <= 25 {
                return .beneficial
            } else {
                return .neutral
            }
        }()
        
        // Wind impact analysis
        windImpact = {
            if conditions.windSpeed > 20 {
                return .dangerous
            } else if conditions.windSpeed > 15 {
                return .challenging
            } else if conditions.windSpeed > 10 {
                return .neutral
            } else {
                return .beneficial
            }
        }()
        
        // Precipitation impact analysis
        precipitationImpact = {
            if conditions.precipitation > 15 {
                return .dangerous
            } else if conditions.precipitation > 5 {
                return .challenging
            } else if conditions.precipitation > 0 {
                return .neutral
            } else {
                return .beneficial
            }
        }()
        
        // Overall impact (worst case)
        let impacts = [temperatureImpact, windImpact, precipitationImpact]
        if impacts.contains(.dangerous) {
            overallImpact = .dangerous
        } else if impacts.contains(.challenging) {
            overallImpact = .challenging
        } else if impacts.allSatisfy({ $0 == .beneficial }) {
            overallImpact = .beneficial
        } else {
            overallImpact = .neutral
        }
        
        // Generate recommendations
        var recs: [String] = []
        
        if temperatureImpact == .dangerous {
            if conditions.temperature < -10 {
                recs.append("Extreme cold: Wear insulated layers and limit exposure time")
            } else {
                recs.append("Extreme heat: Stay hydrated and take frequent breaks")
            }
        } else if temperatureImpact == .challenging {
            if conditions.temperature < 0 {
                recs.append("Cold conditions: Dress in layers and stay dry")
            } else {
                recs.append("Hot conditions: Increase hydration and reduce pace")
            }
        }
        
        if windImpact == .dangerous {
            recs.append("Dangerous winds: Consider postponing outdoor activities")
        } else if windImpact == .challenging {
            recs.append("High winds: Adjust route to avoid exposed areas")
        }
        
        if precipitationImpact == .dangerous {
            recs.append("Heavy precipitation: Postpone activities or seek shelter")
        } else if precipitationImpact == .challenging {
            recs.append("Rain detected: Wear waterproof gear and use caution")
        }
        
        if recs.isEmpty {
            recs.append("Weather conditions are favorable for rucking")
        }
        
        recommendations = recs
    }
}

// MARK: - Battery Optimization Level
enum BatteryOptimizationLevel: String, CaseIterable, Sendable {
    case performance = "performance"
    case balanced = "balanced"
    case maximum = "maximum"
    
    var description: String {
        switch self {
        case .performance: return "Performance"
        case .balanced: return "Balanced"
        case .maximum: return "Maximum Battery"
        }
    }
}