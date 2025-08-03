import SwiftUI

// MARK: - Weather Alert View
/// Displays weather alerts and warnings for safety
/// Follows iOS 18+ alert design patterns with army green theme
struct WeatherAlertView: View {
    let alerts: [WeatherAlert]
    let onDismiss: ((WeatherAlert) -> Void)?
    
    init(alerts: [WeatherAlert], onDismiss: ((WeatherAlert) -> Void)? = nil) {
        self.alerts = alerts.filter { $0.isActive }
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(alerts, id: \.title) { alert in
                    WeatherAlertCard(alert: alert, onDismiss: onDismiss)
                }
            }
        }
    }
}

// MARK: - Weather Alert Card

private struct WeatherAlertCard: View {
    let alert: WeatherAlert
    let onDismiss: ((WeatherAlert) -> Void)?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Alert header
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle() 
                }
            }) {
                HStack(spacing: 12) {
                    // Severity icon
                    Image(systemName: alert.severity.iconName)
                        .font(.title3)
                        .foregroundStyle(alertColor)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("Alert severity: \(alert.severity.rawValue)")
                    
                    // Alert content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if !isExpanded {
                            Text(alert.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    // Dismiss button (if provided)
                    if onDismiss != nil {
                        Button(action: { onDismiss?(alert) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss alert")
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(alertColor.opacity(0.3))
                    
                    // Full message
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Alert metadata
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Issued")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatAlertTime(alert.timestamp))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        if let expiration = alert.expirationDate {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Expires")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatAlertTime(expiration))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    
                    // Safety recommendations for critical alerts
                    if alert.severity == .critical {
                        safetyRecommendations
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(alertBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alertColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: alertColor.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var alertColor: Color {
        Color.weatherAlertColor(for: alert.severity)
    }
    
    private var alertBackgroundColor: Color {
        alertColor.opacity(0.05)
    }
    
    // MARK: - Safety Recommendations
    
    private var safetyRecommendations: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundStyle(.red)
                Text("Safety Recommendations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            let recommendations = getSafetyRecommendations(for: alert)
            ForEach(recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                    Text(recommendation)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatAlertTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func getSafetyRecommendations(for alert: WeatherAlert) -> [String] {
        // Basic safety recommendations based on alert type
        if alert.title.lowercased().contains("temperature") {
            if alert.title.lowercased().contains("cold") {
                return [
                    "Dress in layers and protect extremities",
                    "Limit time outdoors",
                    "Stay dry and seek shelter if needed",
                    "Watch for signs of hypothermia"
                ]
            } else if alert.title.lowercased().contains("heat") {
                return [
                    "Stay hydrated and take frequent breaks",
                    "Seek shade when possible",
                    "Reduce physical activity intensity",
                    "Watch for signs of heat exhaustion"
                ]
            }
        } else if alert.title.lowercased().contains("wind") {
            return [
                "Avoid exposed areas and ridgelines",
                "Use caution near trees and structures",
                "Consider postponing outdoor activities",
                "Secure loose gear and equipment"
            ]
        } else if alert.title.lowercased().contains("precipitation") {
            return [
                "Wear waterproof gear",
                "Be aware of slippery conditions",
                "Avoid low-lying areas prone to flooding",
                "Have emergency shelter plan"
            ]
        }
        
        return [
            "Monitor weather conditions closely",
            "Be prepared to modify or cancel plans",
            "Ensure emergency communication device",
            "Inform others of your location and plans"
        ]
    }
}

// MARK: - Compact Weather Alert Banner

struct WeatherAlertBanner: View {
    let alerts: [WeatherAlert]
    let maxAlertsShown: Int
    
    init(alerts: [WeatherAlert], maxAlertsShown: Int = 2) {
        self.alerts = alerts.filter { $0.isActive }.prefix(maxAlertsShown).map { $0 }
        self.maxAlertsShown = maxAlertsShown
    }
    
    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 4) {
                ForEach(alerts, id: \.title) { alert in
                    CompactAlertRow(alert: alert)
                }
                
                if alerts.count < totalActiveAlerts {
                    Text("+\(totalActiveAlerts - alerts.count) more alerts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private var totalActiveAlerts: Int {
        alerts.count
    }
}

// MARK: - Compact Alert Row

private struct CompactAlertRow: View {
    let alert: WeatherAlert
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: alert.severity.iconName)
                .font(.caption)
                .foregroundStyle(Color.weatherAlertColor(for: alert.severity))
                .frame(width: 16)
            
            Text(alert.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if let expiration = alert.expirationDate {
                Text(timeUntilExpiration(expiration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.weatherAlertColor(for: alert.severity).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func timeUntilExpiration(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 3600 { // Less than 1 hour
            return "\(Int(interval / 60))m"
        } else {
            return "\(Int(interval / 3600))h"
        }
    }
}

// MARK: - Preview

#Preview("Weather Alerts") {
    let alerts = [
        WeatherAlert(
            severity: .critical,
            title: "Extreme Heat Warning",
            message: "Temperature is 105°F with high humidity. Risk of heat exhaustion is very high. Avoid prolonged outdoor activities.",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        ),
        WeatherAlert(
            severity: .warning,
            title: "High Wind Advisory",
            message: "Wind speeds up to 35 mph expected. Use caution in exposed areas.",
            timestamp: Date().addingTimeInterval(-1800),
            expirationDate: Date().addingTimeInterval(1800)
        ),
        WeatherAlert(
            severity: .info,
            title: "Weather Update",
            message: "Conditions are improving. Rain expected to end within the hour.",
            timestamp: Date().addingTimeInterval(-600),
            expirationDate: nil
        )
    ]
    
    return VStack(spacing: 20) {
        WeatherAlertView(alerts: alerts) { alert in
            print("Dismissed: \(alert.title)")
        }
        
        Divider()
        
        WeatherAlertBanner(alerts: alerts)
    }
    .padding()
    .background(Color.ruckMapBackground)
}

#Preview("Single Critical Alert") {
    let criticalAlert = WeatherAlert(
        severity: .critical,
        title: "Extreme Cold Warning",
        message: "Temperature is -15°F with wind chill of -30°F. Frostbite can occur in 10 minutes or less. Seek shelter immediately.",
        timestamp: Date(),
        expirationDate: Date().addingTimeInterval(7200)
    )
    
    return WeatherAlertView(alerts: [criticalAlert])
        .padding()
        .background(Color.ruckMapBackground)
}