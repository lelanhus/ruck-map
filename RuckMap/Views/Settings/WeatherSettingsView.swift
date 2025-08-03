import SwiftUI

// MARK: - Weather Settings View
/// User preferences for weather functionality in RuckMap
/// Follows iOS 18+ Settings app design patterns
struct WeatherSettingsView: View {
    @AppStorage("weatherUpdatesEnabled") private var weatherUpdatesEnabled = true
    @AppStorage("weatherUpdateFrequency") private var weatherUpdateFrequency = WeatherUpdateFrequency.balanced.rawValue
    @AppStorage("batteryOptimizationLevel") private var batteryOptimizationLevel = BatteryOptimizationLevel.balanced.rawValue
    @AppStorage("weatherAlertsEnabled") private var weatherAlertsEnabled = true
    @AppStorage("extremeWeatherAlertsEnabled") private var extremeWeatherAlertsEnabled = true
    @AppStorage("temperatureAlertsEnabled") private var temperatureAlertsEnabled = true
    @AppStorage("windAlertsEnabled") private var windAlertsEnabled = true
    @AppStorage("precipitationAlertsEnabled") private var precipitationAlertsEnabled = true
    @AppStorage("showWeatherInSummary") private var showWeatherInSummary = true
    @AppStorage("showCalorieImpact") private var showCalorieImpact = true
    @AppStorage("weatherUnits") private var weatherUnits = WeatherUnits.imperial.rawValue
    
    @State private var showingAdvancedSettings = false
    @State private var showingBatteryImpactInfo = false
    
    var selectedUpdateFrequency: WeatherUpdateFrequency {
        WeatherUpdateFrequency(rawValue: weatherUpdateFrequency) ?? .balanced
    }
    
    var selectedBatteryLevel: BatteryOptimizationLevel {
        BatteryOptimizationLevel(rawValue: batteryOptimizationLevel) ?? .balanced
    }
    
    var selectedUnits: WeatherUnits {
        WeatherUnits(rawValue: weatherUnits) ?? .imperial
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Main weather settings
                weatherFeatureSection
                
                // Update frequency and battery optimization
                updateSettingsSection
                
                // Weather alerts configuration
                alertsSection
                
                // Display preferences
                displaySection
                
                // Advanced settings
                advancedSection
                
                // Information and help
                informationSection
            }
            .navigationTitle("Weather Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Weather Feature Section
    
    private var weatherFeatureSection: some View {
        Section {
            Toggle("Enable Weather Updates", isOn: $weatherUpdatesEnabled)
                .accessibilityHint("Toggles weather data collection during rucks")
            
            if !weatherUpdatesEnabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    Text("Weather data improves calorie calculations and provides safety information")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Weather Features")
        } footer: {
            if weatherUpdatesEnabled {
                Text("Weather data enhances calorie calculations and provides important safety information during rucks.")
            }
        }
    }
    
    // MARK: - Update Settings Section
    
    private var updateSettingsSection: some View {
        Section {
            if weatherUpdatesEnabled {
                Picker("Update Frequency", selection: $weatherUpdateFrequency) {
                    ForEach(WeatherUpdateFrequency.allCases, id: \.rawValue) { frequency in
                        VStack(alignment: .leading) {
                            Text(frequency.displayName)
                                .tag(frequency.rawValue)
                            Text(frequency.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityLabel("Weather update frequency")
                
                Picker("Battery Optimization", selection: $batteryOptimizationLevel) {
                    ForEach(BatteryOptimizationLevel.allCases, id: \.rawValue) { level in
                        VStack(alignment: .leading) {
                            Text(level.description)
                                .tag(level.rawValue)
                            Text(level.batteryImpactDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityLabel("Battery optimization level")
                
                Button("Battery Impact Information") {
                    showingBatteryImpactInfo = true
                }
                .foregroundStyle(.blue)
                .font(.footnote)
            }
        } header: {
            Text("Update Settings")
        } footer: {
            if weatherUpdatesEnabled {
                Text("More frequent updates provide better accuracy but use more battery. Choose the level that matches your ruck duration and battery needs.")
            }
        }
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        Section {
            if weatherUpdatesEnabled {
                Toggle("Weather Alerts", isOn: $weatherAlertsEnabled)
                    .accessibilityHint("Enables weather-based safety alerts")
                
                if weatherAlertsEnabled {
                    VStack(spacing: 8) {
                        alertToggleRow(
                            "Extreme Weather Alerts",
                            isOn: $extremeWeatherAlertsEnabled,
                            description: "Dangerous conditions that could affect safety"
                        )
                        
                        alertToggleRow(
                            "Temperature Alerts",
                            isOn: $temperatureAlertsEnabled,
                            description: "Heat and cold warnings"
                        )
                        
                        alertToggleRow(
                            "Wind Alerts",
                            isOn: $windAlertsEnabled,
                            description: "High wind conditions"
                        )
                        
                        alertToggleRow(
                            "Precipitation Alerts",
                            isOn: $precipitationAlertsEnabled,
                            description: "Rain and storm warnings"
                        )
                    }
                }
            }
        } header: {
            Text("Weather Alerts")
        } footer: {
            if weatherAlertsEnabled {
                Text("Weather alerts help you stay safe by warning about dangerous conditions. Critical alerts cannot be disabled.")
            }
        }
    }
    
    // MARK: - Display Section
    
    private var displaySection: some View {
        Section {
            Picker("Temperature Units", selection: $weatherUnits) {
                ForEach(WeatherUnits.allCases, id: \.rawValue) { unit in
                    Text(unit.displayName).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("Show Weather in Session Summary", isOn: $showWeatherInSummary)
                .accessibilityHint("Displays weather conditions in completed session details")
            
            Toggle("Show Calorie Impact", isOn: $showCalorieImpact)
                .accessibilityHint("Shows how weather affects calorie burn calculations")
        } header: {
            Text("Display Preferences")
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section {
            Button("Advanced Settings") {
                showingAdvancedSettings = true
            }
            .foregroundStyle(.blue)
            
            Button("Reset to Defaults") {
                resetToDefaults()
            }
            .foregroundStyle(.red)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Advanced settings allow fine-tuning of weather data collection and processing.")
        }
    }
    
    // MARK: - Information Section
    
    private var informationSection: some View {
        Section {
            weatherInfoRow(
                title: "Data Source",
                value: "Apple WeatherKit",
                icon: "cloud.fill"
            )
            
            weatherInfoRow(
                title: "Update Accuracy",
                value: "±2°F, ±2mph",
                icon: "target"
            )
            
            weatherInfoRow(
                title: "Cache Duration",
                value: selectedUpdateFrequency.cacheDescription,
                icon: "clock.arrow.circlepath"
            )
        } header: {
            Text("Information")
        } footer: {
            Text("Weather data is provided by Apple WeatherKit service. Location access is required for accurate weather information.")
        }
    }
    
    // MARK: - Helper Views
    
    private func alertToggleRow(
        _ title: String,
        isOn: Binding<Bool>,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
        }
    }
    
    private func weatherInfoRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetToDefaults() {
        weatherUpdatesEnabled = true
        weatherUpdateFrequency = WeatherUpdateFrequency.balanced.rawValue
        batteryOptimizationLevel = BatteryOptimizationLevel.balanced.rawValue
        weatherAlertsEnabled = true
        extremeWeatherAlertsEnabled = true
        temperatureAlertsEnabled = true
        windAlertsEnabled = true
        precipitationAlertsEnabled = true
        showWeatherInSummary = true
        showCalorieImpact = true
        weatherUnits = WeatherUnits.imperial.rawValue
    }
}

// MARK: - Supporting Types

enum WeatherUpdateFrequency: String, CaseIterable {
    case frequent = "frequent"
    case balanced = "balanced"
    case conservative = "conservative"
    
    var displayName: String {
        switch self {
        case .frequent: return "Frequent (2 min)"
        case .balanced: return "Balanced (5 min)"
        case .conservative: return "Conservative (10 min)"
        }
    }
    
    var description: String {
        switch self {
        case .frequent: return "Best accuracy, higher battery use"
        case .balanced: return "Good accuracy, moderate battery use"
        case .conservative: return "Basic accuracy, lower battery use"
        }
    }
    
    var cacheDescription: String {
        switch self {
        case .frequent: return "15 minutes"
        case .balanced: return "30 minutes"
        case .conservative: return "60 minutes"
        }
    }
    
    var interval: TimeInterval {
        switch self {
        case .frequent: return 120
        case .balanced: return 300
        case .conservative: return 600
        }
    }
}

enum WeatherUnits: String, CaseIterable {
    case imperial = "imperial"
    case metric = "metric"
    
    var displayName: String {
        switch self {
        case .imperial: return "°F, mph"
        case .metric: return "°C, km/h"
        }
    }
}

// MARK: - Battery Optimization Extension

extension BatteryOptimizationLevel {
    var batteryImpactDescription: String {
        switch self {
        case .performance: return "Higher battery usage"
        case .balanced: return "Moderate battery usage"
        case .maximum: return "Minimal battery usage"
        }
    }
}

// MARK: - Advanced Settings Sheet

struct AdvancedWeatherSettingsView: View {
    @AppStorage("weatherCacheSize") private var cacheSize = 50
    @AppStorage("weatherTimeoutDuration") private var timeoutDuration = 30.0
    @AppStorage("allowBackgroundUpdates") private var allowBackgroundUpdates = true
    @AppStorage("weatherDataRetention") private var dataRetentionDays = 30
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper("Cache Size: \(cacheSize) entries", value: $cacheSize, in: 10...100, step: 10)
                    
                    VStack(alignment: .leading) {
                        Text("Request Timeout: \(String(format: "%.0f", timeoutDuration)) seconds")
                        Slider(value: $timeoutDuration, in: 10...60, step: 5)
                    }
                    
                    Toggle("Background Updates", isOn: $allowBackgroundUpdates)
                    
                    Stepper("Data Retention: \(dataRetentionDays) days", value: $dataRetentionDays, in: 7...90, step: 7)
                } header: {
                    Text("Advanced Configuration")
                } footer: {
                    Text("These settings affect weather data caching and network behavior. Default values are recommended for most users.")
                }
                
                Section {
                    Button("Reset Advanced Settings") {
                        resetAdvancedSettings()
                    }
                    .foregroundStyle(.red)
                } footer: {
                    Text("This will reset all advanced settings to their default values.")
                }
            }
            .navigationTitle("Advanced Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetAdvancedSettings() {
        cacheSize = 50
        timeoutDuration = 30.0
        allowBackgroundUpdates = true
        dataRetentionDays = 30
    }
}

// MARK: - Battery Impact Information

struct WeatherBatteryImpactView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Impact overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Battery Impact Overview")
                            .font(.headline)
                        
                        Text("Weather updates require network requests and GPS location access, which affect battery life. Here's how different settings impact your device:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Frequency impact
                    impactCard(
                        title: "Update Frequency",
                        items: [
                            "Frequent (2 min): ~5-8% battery per hour",
                            "Balanced (5 min): ~2-4% battery per hour",
                            "Conservative (10 min): ~1-2% battery per hour"
                        ]
                    )
                    
                    // Optimization impact
                    impactCard(
                        title: "Battery Optimization",
                        items: [
                            "Performance: Full accuracy, higher usage",
                            "Balanced: Good accuracy, moderate usage",
                            "Maximum: Basic accuracy, minimal usage"
                        ]
                    )
                    
                    // Tips
                    impactCard(
                        title: "Battery Saving Tips",
                        items: [
                            "Use Conservative updates for long rucks",
                            "Enable Maximum optimization on low battery",
                            "Weather data is cached to reduce requests",
                            "Background updates pause when stationary"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("Battery Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func impactCard(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.blue)
                    Text(item)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Weather Settings") {
    WeatherSettingsView()
}

#Preview("Advanced Settings") {
    AdvancedWeatherSettingsView()
}

#Preview("Battery Impact") {
    WeatherBatteryImpactView()
}