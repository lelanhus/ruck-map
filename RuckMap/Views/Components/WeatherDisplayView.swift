import SwiftUI
import WeatherKit

// MARK: - Weather Display View
/// Comprehensive weather information display for RuckMap
/// Follows army green design system and iOS 18+ guidelines
struct WeatherDisplayView: View {
    let weatherConditions: WeatherConditions?
    let impactAnalysis: WeatherImpactAnalysis?
    let showDetailed: Bool
    let showCalorieImpact: Bool
    
    init(
        weatherConditions: WeatherConditions?,
        impactAnalysis: WeatherImpactAnalysis? = nil,
        showDetailed: Bool = true,
        showCalorieImpact: Bool = false
    ) {
        self.weatherConditions = weatherConditions
        self.impactAnalysis = impactAnalysis
        self.showDetailed = showDetailed
        self.showCalorieImpact = showCalorieImpact
    }
    
    var body: some View {
        Group {
            if let conditions = weatherConditions {
                if showDetailed {
                    detailedWeatherView(conditions: conditions)
                } else {
                    compactWeatherView(conditions: conditions)
                }
            } else {
                weatherUnavailableView
            }
        }
    }
    
    // MARK: - Detailed Weather View
    
    private func detailedWeatherView(conditions: WeatherConditions) -> some View {
        VStack(spacing: 16) {
            // Header with current conditions
            weatherHeaderView(conditions: conditions)
            
            // Temperature and feels like
            temperatureSection(conditions: conditions)
            
            // Wind and humidity
            environmentalConditionsView(conditions: conditions)
            
            // Weather impact on calories (if enabled)
            if showCalorieImpact {
                calorieImpactView(conditions: conditions)
            }
            
            // Weather alerts and warnings
            if let impact = impactAnalysis {
                weatherAlertsView(impact: impact)
            }
        }
        .padding()
        .background(Color.liquidGlassCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Compact Weather View
    
    private func compactWeatherView(conditions: WeatherConditions) -> some View {
        HStack(spacing: 12) {
            // Weather icon
            weatherIconView(conditions: conditions)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                // Temperature
                Text("\(Int(conditions.temperatureFahrenheit))°F")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.temperatureColor(for: conditions.temperature))
                
                // Condition description
                if let description = conditions.weatherDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Impact indicator
            if let impact = impactAnalysis {
                impactIndicator(impact: impact.overallImpact)
            }
            
            // Calorie impact percentage
            if showCalorieImpact {
                calorieImpactIndicator(conditions: conditions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ruckMapSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Weather Header
    
    private func weatherHeaderView(conditions: WeatherConditions) -> some View {
        HStack {
            weatherIconView(conditions: conditions)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Weather")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(formatLastUpdate(conditions.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let description = conditions.weatherDescription {
                    Text(description.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Temperature Section
    
    private func temperatureSection(conditions: WeatherConditions) -> some View {
        HStack(spacing: 20) {
            // Current temperature
            VStack(alignment: .leading, spacing: 4) {
                Text("Temperature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(conditions.temperatureFahrenheit))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.temperatureColor(for: conditions.temperature))
                    
                    Text("°F")
                        .font(.title2)
                        .foregroundStyle(Color.temperatureColor(for: conditions.temperature))
                }
            }
            
            Spacer()
            
            // Feels like temperature
            VStack(alignment: .trailing, spacing: 4) {
                Text("Feels Like")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(conditions.apparentTemperatureFahrenheit))°F")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.temperatureColor(for: conditions.apparentTemperature))
            }
        }
    }
    
    // MARK: - Environmental Conditions
    
    private func environmentalConditionsView(conditions: WeatherConditions) -> some View {
        HStack(spacing: 20) {
            // Wind information
            windInfoView(conditions: conditions)
            
            Spacer()
            
            // Humidity
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "humidity")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(Int(conditions.humidity))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Wind Information
    
    private func windInfoView(conditions: WeatherConditions) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: windDirectionIcon(conditions.windDirection))
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(conditions.windDirection))
                
                Text("Wind")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Text("\(Int(conditions.windSpeedMPH))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("mph")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(windDirectionText(conditions.windDirection))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Calorie Impact
    
    private func calorieImpactView(conditions: WeatherConditions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                
                Text("Weather Impact on Calories")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                calorieAdjustmentBadge(conditions: conditions)
            }
            
            weatherImpactExplanation(conditions: conditions)
        }
        .padding()
        .background(Color.ruckMapTertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func calorieImpactIndicator(conditions: WeatherConditions) -> some View {
        let adjustmentFactor = conditions.temperatureAdjustmentFactor
        let percentage = Int((adjustmentFactor - 1.0) * 100)
        
        return VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            
            Text("\(percentage >= 0 ? "+" : "")\(percentage)%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(percentage > 0 ? .orange : .green)
        }
    }
    
    private func calorieAdjustmentBadge(conditions: WeatherConditions) -> some View {
        let adjustmentFactor = conditions.temperatureAdjustmentFactor
        let percentage = Int((adjustmentFactor - 1.0) * 100)
        
        return Text("\(percentage >= 0 ? "+" : "")\(percentage)%")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(percentage > 0 ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            )
            .foregroundStyle(percentage > 0 ? .orange : .green)
    }
    
    private func weatherImpactExplanation(conditions: WeatherConditions) -> some View {
        let explanation: String = {
            if conditions.temperature < 0 {
                return "Cold weather increases calorie burn due to thermoregulation"
            } else if conditions.temperature > 30 {
                return "Hot weather increases calorie burn due to cooling effort"
            } else {
                return "Temperature is in optimal range for energy efficiency"
            }
        }()
        
        return Text(explanation)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Weather Alerts
    
    private func weatherAlertsView(impact: WeatherImpactAnalysis) -> some View {
        VStack(spacing: 8) {
            ForEach(impact.recommendations, id: \.self) { recommendation in
                weatherRecommendationRow(
                    recommendation: recommendation,
                    severity: impact.overallImpact
                )
            }
        }
    }
    
    private func weatherRecommendationRow(
        recommendation: String,
        severity: WeatherImpactAnalysis.ImpactLevel
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: severityIcon(severity))
                .foregroundStyle(Color.weatherImpactColor(for: severity))
                .frame(width: 20)
            
            Text(recommendation)
                .font(.caption)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.weatherImpactColor(for: severity).opacity(0.1))
        )
    }
    
    // MARK: - Impact Indicator
    
    private func impactIndicator(impact: WeatherImpactAnalysis.ImpactLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: severityIcon(impact))
                .font(.caption)
                .foregroundStyle(Color.weatherImpactColor(for: impact))
            
            Text(impact.description)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.weatherImpactColor(for: impact))
        }
    }
    
    // MARK: - Weather Icon
    
    private func weatherIconView(conditions: WeatherConditions) -> some View {
        Image(systemName: weatherIconName(conditions))
            .font(.title2)
            .foregroundStyle(weatherIconColor(conditions))
            .accessibilityLabel("Weather conditions: \(conditions.weatherDescription ?? "Unknown")")
    }
    
    // MARK: - Weather Unavailable
    
    private var weatherUnavailableView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("Weather data unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    
    private func weatherIconName(_ conditions: WeatherConditions) -> String {
        // Map weather condition codes to SF Symbols
        guard let conditionCode = conditions.conditionCode else {
            return "cloud"
        }
        
        // This is a simplified mapping - in production you'd use WeatherKit's full condition mapping
        switch conditionCode.lowercased() {
        case let code where code.contains("clear"):
            return "sun.max"
        case let code where code.contains("cloud"):
            return "cloud"
        case let code where code.contains("rain"):
            return "cloud.rain"
        case let code where code.contains("snow"):
            return "cloud.snow"
        case let code where code.contains("wind"):
            return "wind"
        default:
            return "cloud"
        }
    }
    
    private func weatherIconColor(_ conditions: WeatherConditions) -> Color {
        if conditions.isHarshConditions {
            return .red
        } else if conditions.temperature < 0 || conditions.temperature > 30 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func windDirectionIcon(_ degrees: Double) -> String {
        return "arrow.up"
    }
    
    private func windDirectionText(_ degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45) % 8
        return directions[index]
    }
    
    private func severityIcon(_ severity: WeatherImpactAnalysis.ImpactLevel) -> String {
        switch severity {
        case .beneficial:
            return "checkmark.circle.fill"
        case .neutral:
            return "minus.circle.fill"
        case .challenging:
            return "exclamationmark.triangle.fill"
        case .dangerous:
            return "exclamationmark.octagon.fill"
        }
    }
    
    private func formatLastUpdate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Weather Conditions Extensions

private extension WeatherConditions {
    var apparentTemperatureFahrenheit: Double {
        apparentTemperature * 9/5 + 32
    }
}

// MARK: - Preview

#Preview("Detailed Weather") {
    let conditions = WeatherConditions(
        timestamp: Date(),
        temperature: 22.0,
        humidity: 65.0,
        windSpeed: 3.0,
        windDirection: 225.0,
        precipitation: 0.0,
        pressure: 1013.25
    )
    conditions.weatherDescription = "Partly cloudy"
    conditions.conditionCode = "partlyCloudyDay"
    
    let impact = WeatherImpactAnalysis(conditions: conditions)
    
    return WeatherDisplayView(
        weatherConditions: conditions,
        impactAnalysis: impact,
        showDetailed: true,
        showCalorieImpact: true
    )
    .padding()
    .background(Color.ruckMapBackground)
}

#Preview("Compact Weather") {
    let conditions = WeatherConditions(
        timestamp: Date(),
        temperature: 28.0,
        humidity: 80.0,
        windSpeed: 5.0,
        windDirection: 180.0
    )
    conditions.weatherDescription = "Hot and humid"
    
    let impact = WeatherImpactAnalysis(conditions: conditions)
    
    return WeatherDisplayView(
        weatherConditions: conditions,
        impactAnalysis: impact,
        showDetailed: false,
        showCalorieImpact: true
    )
    .padding()
    .background(Color.ruckMapBackground)
}

#Preview("No Weather Data") {
    WeatherDisplayView(
        weatherConditions: nil,
        showDetailed: false
    )
    .padding()
    .background(Color.ruckMapBackground)
}